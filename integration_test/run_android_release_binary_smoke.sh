#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )) || [[ ! "$1" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <api-level> <universal-release-mode-apk>" >&2
  exit 64
fi

readonly api_level="$1"
readonly release_apk="$(realpath -- "$2")"
readonly package_name='com.danggui.memo'
readonly device_serial="${ANDROID_SERIAL:-emulator-5554}"
readonly emulator_attempt="${DANGGUI_EMULATOR_ATTEMPT:-1}"
readonly signing_mode="${DANGGUI_RELEASE_SIGNING_MODE:?DANGGUI_RELEASE_SIGNING_MODE is not set}"
readonly artifact_sha="${DANGGUI_RELEASE_ARTIFACT_SHA:?DANGGUI_RELEASE_ARTIFACT_SHA is not set}"
readonly expected_apk_sha256="${DANGGUI_RELEASE_APK_SHA256:?DANGGUI_RELEASE_APK_SHA256 is not set}"
readonly evidence_dir="${RUNNER_TEMP:?RUNNER_TEMP is not set}/danggui-emulator-api-${api_level}"
readonly workflow_phase="${evidence_dir}/workflow-phase.json"
readonly result_json="${evidence_dir}/release-binary-smoke.json"
readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd "${script_dir}/.." && pwd)"

if [[ ! "${emulator_attempt}" =~ ^[12]$ ]]; then
  echo 'DANGGUI_EMULATOR_ATTEMPT must be 1 or 2.' >&2
  exit 64
fi
if [[ "${signing_mode}" != 'release' &&
      "${signing_mode}" != 'debug-fallback' ]]; then
  echo "Unsupported Android signing mode: ${signing_mode}" >&2
  exit 65
fi
if [[ "$(basename -- "${release_apk}")" != \
      "danggui-android-universal-${signing_mode}.apk" ]]; then
  echo 'The downloaded universal APK name does not match SIGNING_MODE.txt.' >&2
  exit 65
fi
if [[ ! -s "${release_apk}" ]]; then
  echo "Downloaded universal APK is missing or empty: ${release_apk}" >&2
  exit 66
fi
if [[ -n "${GITHUB_SHA:-}" && "${artifact_sha}" != "${GITHUB_SHA}" ]]; then
  echo 'The downloaded Android artifact SHA does not match this workflow SHA.' >&2
  exit 65
fi
if [[ ! "${expected_apk_sha256}" =~ ^[0-9a-f]{64}$ ]]; then
  echo 'DANGGUI_RELEASE_APK_SHA256 must be a lowercase SHA-256 digest.' >&2
  exit 65
fi

technical_version="$(
  sed -n -E 's/^version:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' \
    "${repository_root}/pubspec.yaml" | head -n 1
)"
if [[ "${technical_version}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([1-9][0-9]*)$ ]]; then
  readonly expected_version_name="${BASH_REMATCH[1]}"
  readonly expected_version_code="${BASH_REMATCH[2]}"
else
  echo "Invalid pubspec release version: ${technical_version}" >&2
  exit 65
fi

mkdir -p "${evidence_dir}"
current_phase='release-binary-input-verification'
printf '%s\n' \
  "{\"status\":\"running\",\"phase\":\"${current_phase}\",\"attempt\":${emulator_attempt}}" \
  > "${workflow_phase}"
printf '%s\n' \
  '{"status":"running","phase":"release-binary-input-verification"}' \
  > "${result_json}"

bounded_adb() {
  timeout --signal=TERM --kill-after=5s 45s \
    adb -s "${device_serial}" "$@"
}

bounded_ui_adb() {
  timeout --signal=TERM --kill-after=5s 20s \
    adb -s "${device_serial}" "$@"
}

set_phase() {
  current_phase="$1"
  printf '%s\n' \
    "{\"status\":\"running\",\"phase\":\"${current_phase}\",\"attempt\":${emulator_attempt}}" \
    > "${workflow_phase}"
}

capture_final_diagnostics() {
  bounded_adb shell pidof "${package_name}" \
    > "${evidence_dir}/release-binary-app-pid-final.txt" 2>&1 || true
  bounded_adb shell dumpsys activity activities \
    > "${evidence_dir}/release-binary-activity-final.txt" 2>&1 || true
  bounded_adb shell dumpsys window \
    > "${evidence_dir}/release-binary-window-final.txt" 2>&1 || true
  bounded_adb shell dumpsys package "${package_name}" \
    > "${evidence_dir}/release-binary-package-final.txt" 2>&1 || true
  bounded_adb logcat -d -v threadtime \
    > "${evidence_dir}/release-binary-logcat.txt" 2>&1 || true
  bounded_adb exec-out screencap -p \
    > "${evidence_dir}/release-binary-final.png" 2>/dev/null || true
}

finish() {
  local status=$?
  trap - EXIT
  set +e
  capture_final_diagnostics
  printf '%s\n' "${status}" \
    > "${evidence_dir}/release-binary-exit-status.txt"
  if (( status == 0 )); then
    printf '%s\n' \
      "{\"status\":\"passed\",\"phase\":\"release-binary-smoke-complete\",\"attempt\":${emulator_attempt},\"exitStatus\":0}" \
      > "${workflow_phase}"
  else
    printf '%s\n' \
      "{\"status\":\"failed\",\"phase\":\"${current_phase}\",\"attempt\":${emulator_attempt},\"exitStatus\":${status}}" \
      > "${workflow_phase}"
    jq -n \
      --arg phase "${current_phase}" \
      --argjson apiLevel "${api_level}" \
      --argjson attempt "${emulator_attempt}" \
      --argjson exitStatus "${status}" \
      '{status:"failed", phase:$phase, apiLevel:$apiLevel,
        attempt:$attempt, exitStatus:$exitStatus}' \
      > "${result_json}" 2>/dev/null || true
  fi
  exit "${status}"
}
trap finish EXIT

capture_ui_tree() {
  local destination="$1"
  local remote_path="/sdcard/danggui-release-binary-${api_level}-${emulator_attempt}.xml"
  if ! bounded_ui_adb shell uiautomator dump "${remote_path}" \
      > "${destination}.command.log" 2>&1; then
    return 1
  fi
  if ! bounded_ui_adb pull "${remote_path}" "${destination}" \
      > "${destination}.pull.log" 2>&1; then
    return 1
  fi
  bounded_ui_adb shell rm -f "${remote_path}" >/dev/null 2>&1 || true
  [[ -s "${destination}" ]]
}

parse_navigation_state() {
  local source_xml="$1"
  local expected_selected="$2"
  local output_json="$3"
  python3 - "${source_xml}" "${expected_selected}" "${output_json}" <<'PY'
import json
import re
import sys
import xml.etree.ElementTree as ET

source_path, expected_selected, output_path = sys.argv[1:]
labels = {
    "tasks": {"事项", "Tasks", "事項", "Дела"},
    "past": {"过往", "Past", "過往", "Прошлое"},
    "notes": {"笔记", "Notes", "ノート", "Заметки"},
    "settings": {"设置", "Settings", "設定", "Настройки"},
}
screen_markers = {
    "tasks": {"新建事项", "New task", "事項を追加", "Новое дело"},
    "notes": {"新建笔记", "New note", "新規ノート", "Новая заметка"},
    "settings": {"显示", "Appearance", "表示", "Внешний вид"},
}
bounds_pattern = re.compile(r"^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$")
root = ET.parse(source_path).getroot()
visible_values = {
    value
    for node in root.iter("node")
    for value in (node.attrib.get("content-desc"), node.attrib.get("text"))
    if value
}
matches = {key: [] for key in labels}
for node in root.iter("node"):
    value = node.attrib.get("content-desc") or node.attrib.get("text") or ""
    for key, variants in labels.items():
        if value not in variants or node.attrib.get("clickable") != "true":
            continue
        bounds_match = bounds_pattern.match(node.attrib.get("bounds", ""))
        if bounds_match is None:
            continue
        left, top, right, bottom = map(int, bounds_match.groups())
        if right <= left or bottom <= top:
            continue
        matches[key].append(
            {
                "label": value,
                "bounds": [left, top, right, bottom],
                "tapX": (left + right) // 2,
                "tapY": (top + bottom) // 2,
                "selected": node.attrib.get("selected") == "true",
            }
        )

resolved = {}
for key, candidates in matches.items():
    if not candidates:
        raise SystemExit(f"No clickable bottom-navigation node found for {key}.")
    # A page heading can share a translated label. The navigation node is the
    # lowest clickable candidate in the hierarchy.
    resolved[key] = max(candidates, key=lambda item: item["bounds"][1])

selected = sorted(key for key, value in resolved.items() if value["selected"])
if selected != [expected_selected]:
    raise SystemExit(
        f"Selected tab mismatch: expected {[expected_selected]!r}, got {selected!r}."
    )
marker = None
if expected_selected in screen_markers:
    marker = next(
        (
            candidate
            for candidate in sorted(screen_markers[expected_selected])
            if candidate in visible_values
        ),
        None,
    )
    if marker is None:
        raise SystemExit(
            f"No screen-specific marker found for {expected_selected}."
        )
with open(output_path, "w", encoding="utf-8") as output:
    json.dump(
        {
            "status": "passed",
            "selected": expected_selected,
            "screenMarker": marker,
            "tabs": resolved,
        },
        output,
        ensure_ascii=False,
        sort_keys=True,
    )
    output.write("\n")
PY
}

wait_for_selected_tab() {
  local selected_tab="$1"
  local xml_path="$2"
  local json_path="$3"
  local deadline=$(( SECONDS + 45 ))
  rm -f -- "${json_path}"
  while (( SECONDS < deadline )); do
    if capture_ui_tree "${xml_path}" &&
       parse_navigation_state "${xml_path}" "${selected_tab}" "${json_path}" \
         2>> "${evidence_dir}/release-binary-ui-parse.stderr"; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for release-binary tab: ${selected_tab}" >&2
  return 1
}

ensure_app_foreground() {
  local suffix="$1"
  local deadline=$(( SECONDS + 20 ))
  while (( SECONDS < deadline )); do
    bounded_adb shell dumpsys activity activities \
      > "${evidence_dir}/release-binary-activity-${suffix}.txt"
    bounded_adb shell dumpsys window \
      > "${evidence_dir}/release-binary-window-${suffix}.txt"
    if grep -Eq \
         '(mResumedActivity|topResumedActivity).*com\.danggui\.memo' \
         "${evidence_dir}/release-binary-activity-${suffix}.txt" &&
       grep -Eq 'mCurrentFocus=.*com\.danggui\.memo' \
         "${evidence_dir}/release-binary-window-${suffix}.txt"; then
      return 0
    fi
    sleep 1
  done
  echo "Danggui was not foreground after release-binary phase: ${suffix}" >&2
  return 1
}

release_apk_sha256="$(sha256sum "${release_apk}" | awk '{print $1}')"
if [[ "${release_apk_sha256}" != "${expected_apk_sha256}" ]]; then
  echo 'The universal APK changed after the upstream artifact checksum gate.' >&2
  exit 1
fi
printf '%s  %s\n' "${release_apk_sha256}" "$(basename -- "${release_apk}")" \
  > "${evidence_dir}/release-binary-apk.sha256"

# Re-run the repository's complete APK contract against the exact downloaded
# bytes. This proves application ID, product/build version, SDK levels,
# debuggable=false, permissions, receivers, orientation, and APK signature.
bash "${repository_root}/tool/verify_android_artifacts.sh" \
  "${release_apk}" '' "${expected_version_code}" \
  > "${evidence_dir}/release-binary-apk-verification.txt" 2>&1

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
apkanalyzer="$(command -v apkanalyzer || true)"
if [[ -z "${apkanalyzer}" ]]; then
  apkanalyzer="$(
    find "${sdk_root:?Android SDK path is not set}/cmdline-tools" \
      -type f -name apkanalyzer 2>/dev/null | sort -V | tail -n 1
  )"
fi
[[ -x "${apkanalyzer}" ]]
apk_application_id="$("${apkanalyzer}" manifest application-id "${release_apk}")"
apk_version_name="$("${apkanalyzer}" manifest version-name "${release_apk}")"
apk_version_code="$("${apkanalyzer}" manifest version-code "${release_apk}")"
apk_min_sdk="$("${apkanalyzer}" manifest min-sdk "${release_apk}")"
apk_target_sdk="$("${apkanalyzer}" manifest target-sdk "${release_apk}")"
apk_debuggable="$("${apkanalyzer}" manifest debuggable "${release_apk}")"
apk_permissions="$("${apkanalyzer}" manifest permissions "${release_apk}")"
permissions_json="$(
  printf '%s\n' "${apk_permissions}" |
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' |
    sort -u | jq -Rsc 'split("\n") | map(select(length > 0))'
)"
jq -n \
  --arg artifactWorkflowSha "${artifact_sha}" \
  --arg artifactFile "$(basename -- "${release_apk}")" \
  --arg apkSha256 "${release_apk_sha256}" \
  --arg signingMode "${signing_mode}" \
  --arg applicationId "${apk_application_id}" \
  --arg versionName "${apk_version_name}" \
  --argjson versionCode "${apk_version_code}" \
  --argjson minSdk "${apk_min_sdk}" \
  --argjson targetSdk "${apk_target_sdk}" \
  --argjson debuggable "${apk_debuggable}" \
  --argjson permissions "${permissions_json}" \
  '{status:"passed", buildMode:"release", signingMode:$signingMode,
    artifactWorkflowSha:$artifactWorkflowSha, artifactFile:$artifactFile,
    apkSha256:$apkSha256, upstreamChecksumMatched:true,
    applicationId:$applicationId,
    versionName:$versionName, versionCode:$versionCode, minSdk:$minSdk,
    targetSdk:$targetSdk, debuggable:$debuggable, permissions:$permissions}' \
  > "${evidence_dir}/release-binary-apk-metadata.json"

device_api_level="$(
  bounded_adb shell getprop ro.build.version.sdk |
    tr -d '\r' | tr -d '[:space:]'
)"
[[ "${device_api_level}" == "${api_level}" ]]
device_fingerprint="$(
  bounded_adb shell getprop ro.build.fingerprint | tr -d '\r'
)"
jq -n \
  --arg serial "${device_serial}" \
  --argjson expectedApiLevel "${api_level}" \
  --argjson actualApiLevel "${device_api_level}" \
  --arg fingerprint "${device_fingerprint}" \
  '{status:"passed", serial:$serial, expectedApiLevel:$expectedApiLevel,
    actualApiLevel:$actualApiLevel, fingerprint:$fingerprint}' \
  > "${evidence_dir}/release-binary-device.json"

set_phase 'release-binary-install'
package_before_uninstall="$(
  bounded_adb shell pm path "${package_name}" 2>&1
)"
printf '%s\n' "${package_before_uninstall}" \
  > "${evidence_dir}/release-binary-package-before-uninstall.txt"
if [[ "${package_before_uninstall}" == *'package:'* ]]; then
  bounded_adb uninstall "${package_name}" \
    > "${evidence_dir}/release-binary-uninstall.txt" 2>&1
else
  printf '%s\n' 'Package was already absent.' \
    > "${evidence_dir}/release-binary-uninstall.txt"
fi
package_after_uninstall="$(bounded_adb shell pm list packages "${package_name}")"
[[ -z "${package_after_uninstall//[[:space:]]/}" ]]

bounded_adb install --no-streaming "${release_apk}" \
  > "${evidence_dir}/release-binary-install.txt" 2>&1
grep -Eq '^Success\r?$' "${evidence_dir}/release-binary-install.txt"
bounded_adb shell pm path "${package_name}" \
  > "${evidence_dir}/release-binary-package-path.txt"
grep -Fq 'package:' "${evidence_dir}/release-binary-package-path.txt"
bounded_adb shell dumpsys package "${package_name}" \
  > "${evidence_dir}/release-binary-package.txt"
installed_version_name="$(
  sed -n -E 's/^[[:space:]]*versionName=([^[:space:]]+).*$/\1/p' \
    "${evidence_dir}/release-binary-package.txt" | head -n 1
)"
installed_version_code="$(
  sed -n -E 's/^[[:space:]]*versionCode=([0-9]+).*$/\1/p' \
    "${evidence_dir}/release-binary-package.txt" | head -n 1
)"
[[ "${installed_version_name}" == "${expected_version_name}" ]]
[[ "${installed_version_code}" == "${expected_version_code}" ]]

set_phase 'release-binary-cold-start'
bounded_adb logcat -c
launcher_component="$(
  bounded_adb shell cmd package resolve-activity --brief \
    -a android.intent.action.MAIN \
    -c android.intent.category.LAUNCHER "${package_name}" |
    tr -d '\r' | grep -E '^com\.danggui\.memo/' | tail -n 1
)"
[[ "${launcher_component}" == "${package_name}/"* ]]
bounded_adb shell am force-stop "${package_name}"
bounded_adb shell am start -W -S -n "${launcher_component}" \
  > "${evidence_dir}/release-binary-cold-start.txt"
grep -Eq '^Status: ok\r?$' "${evidence_dir}/release-binary-cold-start.txt"
bounded_adb exec-out screencap -p \
  > "${evidence_dir}/release-binary-cold-start.png"

wait_for_selected_tab \
  tasks \
  "${evidence_dir}/release-binary-tasks-initial.xml" \
  "${evidence_dir}/release-binary-tasks-initial-navigation.json"
ensure_app_foreground tasks-initial
bounded_adb exec-out screencap -p \
  > "${evidence_dir}/release-binary-tasks-initial.png"
initial_pid="$(bounded_adb shell pidof "${package_name}" | tr -d '\r')"
[[ "${initial_pid}" =~ ^[0-9]+([[:space:]][0-9]+)*$ ]]

set_phase 'release-binary-basic-navigation'
for destination in notes settings tasks; do
  current_navigation_json="${evidence_dir}/release-binary-${destination}-navigation.json"
  source_navigation_json="${evidence_dir}/release-binary-tasks-initial-navigation.json"
  if [[ "${destination}" == 'settings' ]]; then
    source_navigation_json="${evidence_dir}/release-binary-notes-navigation.json"
  elif [[ "${destination}" == 'tasks' ]]; then
    source_navigation_json="${evidence_dir}/release-binary-settings-navigation.json"
  fi
  tap_x="$(jq -r --arg tab "${destination}" '.tabs[$tab].tapX' \
    "${source_navigation_json}")"
  tap_y="$(jq -r --arg tab "${destination}" '.tabs[$tab].tapY' \
    "${source_navigation_json}")"
  [[ "${tap_x}" =~ ^[0-9]+$ && "${tap_y}" =~ ^[0-9]+$ ]]
  bounded_adb shell input tap "${tap_x}" "${tap_y}"
  wait_for_selected_tab \
    "${destination}" \
    "${evidence_dir}/release-binary-${destination}.xml" \
    "${current_navigation_json}"
  ensure_app_foreground "${destination}"
  bounded_adb exec-out screencap -p \
    > "${evidence_dir}/release-binary-${destination}.png"
done

final_pid="$(bounded_adb shell pidof "${package_name}" | tr -d '\r')"
[[ "${final_pid}" == "${initial_pid}" ]]
printf '%s\n' "${initial_pid}" \
  > "${evidence_dir}/release-binary-app-pid-stable.txt"

set_phase 'release-binary-no-crash-scan'
bounded_adb logcat -d -v threadtime \
  > "${evidence_dir}/release-binary-logcat.txt"
python3 - \
  "${evidence_dir}/release-binary-logcat.txt" \
  "${package_name}" "${initial_pid}" \
  "${evidence_dir}/release-binary-crash-scan.json" <<'PY'
import json
import re
import sys

log_path, package_name, pid_text, output_path = sys.argv[1:]
lines = open(log_path, encoding="utf-8", errors="replace").read().splitlines()
pids = set(pid_text.split())
hits = []
for index, line in enumerate(lines):
    if f"ANR in {package_name}" in line:
        hits.append(line)
    if "FATAL EXCEPTION" in line:
        context = "\n".join(lines[index : index + 25])
        if package_name in context:
            hits.append(context)
    if re.search(rf"Process {re.escape(package_name)} .* has died", line):
        hits.append(line)
    if "Fatal signal" in line and any(
        re.search(rf"\b{re.escape(pid)}\b", line) for pid in pids
    ):
        hits.append(line)

with open(output_path, "w", encoding="utf-8") as output:
    json.dump(
        {
            "status": "passed" if not hits else "failed",
            "package": package_name,
            "stablePid": pid_text,
            "fatalEvidence": hits,
        },
        output,
        ensure_ascii=False,
        sort_keys=True,
    )
    output.write("\n")
if hits:
    raise SystemExit("Release-binary logcat contains app crash evidence.")
PY

jq -n \
  --argjson apiLevel "${api_level}" \
  --argjson attempt "${emulator_attempt}" \
  --arg artifactWorkflowSha "${artifact_sha}" \
  --arg artifactFile "$(basename -- "${release_apk}")" \
  --arg apkSha256 "${release_apk_sha256}" \
  --arg signingMode "${signing_mode}" \
  --arg packageName "${package_name}" \
  --arg versionName "${expected_version_name}" \
  --argjson versionCode "${expected_version_code}" \
  --arg launcherComponent "${launcher_component}" \
  --arg stablePid "${initial_pid}" \
  '{status:"passed", phase:"release-binary-smoke-complete",
    apiLevel:$apiLevel, attempt:$attempt, buildMode:"release",
    signingMode:$signingMode, artifactWorkflowSha:$artifactWorkflowSha,
    artifactFile:$artifactFile, apkSha256:$apkSha256,
    upstreamChecksumMatched:true,
    packageName:$packageName, versionName:$versionName,
    versionCode:$versionCode, launcherComponent:$launcherComponent,
    deviceApiLevel:$apiLevel,
    coldStartPassed:true, basicNavigation:["tasks","notes","settings","tasks"],
    stablePid:$stablePid, crashScanPassed:true,
    interactionBoundary:"host-adb-and-uiautomator-no-flutter-instrumentation"}' \
  > "${result_json}"
current_phase='release-binary-smoke-complete'
