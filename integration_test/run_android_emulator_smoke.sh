#!/usr/bin/env bash
set -uo pipefail
set +e

if (( $# != 1 )) || [[ ! "$1" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <api-level>" >&2
  exit 64
fi

api_level="$1"
device_serial="${ANDROID_SERIAL:-emulator-5554}"
emulator_attempt="${DANGGUI_EMULATOR_ATTEMPT:-1}"
if [[ ! "${emulator_attempt}" =~ ^[12]$ ]]; then
  echo 'DANGGUI_EMULATOR_ATTEMPT must be 1 or 2.' >&2
  exit 64
fi
evidence_dir="${RUNNER_TEMP:?RUNNER_TEMP is not set}/danggui-emulator-api-${api_level}"
workflow_phase="${evidence_dir}/workflow-phase.json"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "${evidence_dir}"
[[ -e "${evidence_dir}/before.json" ]] ||
  printf '%s\n' '{"status":"not-captured","phase":"before-overlay-install"}' \
    > "${evidence_dir}/before.json"
[[ -e "${evidence_dir}/after.json" ]] ||
  printf '%s\n' '{"status":"not-captured","phase":"after-overlay-install"}' \
    > "${evidence_dir}/after.json"
[[ -e "${evidence_dir}/notification-before.txt" ]] ||
  printf '%s\n' 'not captured' > "${evidence_dir}/notification-before.txt"
[[ -e "${evidence_dir}/notification-after.txt" ]] ||
  printf '%s\n' 'not captured' > "${evidence_dir}/notification-after.txt"
[[ -e "${evidence_dir}/notification-shade.png" ]] ||
  : > "${evidence_dir}/notification-shade.png"
[[ -e "${workflow_phase}" ]] ||
  printf '%s\n' \
    "{\"status\":\"initialized\",\"phase\":\"smoke-started\",\"attempt\":${emulator_attempt}}" \
    > "${workflow_phase}"

validate_adb_transport_setup() (
  set -euo pipefail
  local canonical_adb
  local discovered_adb
  local real_adb
  local wrapper_source
  local canonical_sha
  local real_sha
  local source_sha
  local attestation
  transport_fail() {
    echo "ADB transport validation failed: $1" >&2
    exit 1
  }

  canonical_adb="${ANDROID_SDK_ROOT:?ANDROID_SDK_ROOT is not set}/platform-tools/adb"
  discovered_adb="$(type -P adb)"
  real_adb="${canonical_adb}.danggui-real"
  wrapper_source="${script_dir}/adb_no_streaming_wrapper.sh"
  attestation="${evidence_dir}/adb-install-mode.json"
  [[ -x "${canonical_adb}" && ! -L "${canonical_adb}" ]] ||
    transport_fail 'canonical-adb'
  [[ -x "${discovered_adb}" ]] || transport_fail 'path-adb'
  [[ "$(realpath -- "${discovered_adb}")" == "$(realpath -- "${canonical_adb}")" ]] ||
    transport_fail 'path-canonical-mismatch'
  [[ -s "${wrapper_source}" && ! -L "${wrapper_source}" ]] ||
    transport_fail 'wrapper-source'
  [[ -s "${attestation}" ]] || transport_fail 'attestation-missing'
  canonical_sha="$(sha256sum "${canonical_adb}" | awk '{print $1}')"
  source_sha="$(sha256sum "${wrapper_source}" | awk '{print $1}')"

  if (( api_level == 24 )); then
    [[ -x "${real_adb}" && ! -L "${real_adb}" ]] ||
      transport_fail 'real-adb'
    [[ "$(realpath -- "${real_adb}")" != "$(realpath -- "${canonical_adb}")" ]] ||
      transport_fail 'recursive-real-adb'
    real_sha="$(sha256sum "${real_adb}" | awk '{print $1}')"
    [[ "${canonical_sha}" == "${source_sha}" ]] ||
      transport_fail 'installed-wrapper-hash'
    [[ "${real_sha}" != "${source_sha}" ]] ||
      transport_fail 'real-adb-hash'
    [[ -s "${evidence_dir}/adb-version.txt" ]] ||
      transport_fail 'real-version-evidence'
    [[ -s "${evidence_dir}/adb-wrapper-version.txt" ]] ||
      transport_fail 'wrapper-version-evidence'
    cmp -s \
      "${evidence_dir}/adb-version.txt" \
      "${evidence_dir}/adb-wrapper-version.txt" ||
      transport_fail 'version-pass-through'
    jq -e \
      --argjson expectedApiLevel "${api_level}" \
      --argjson expectedAttempt "${emulator_attempt}" \
      --arg expectedCanonicalSha "${canonical_sha}" \
      --arg expectedRealSha "${real_sha}" \
      --arg expectedSourceSha "${source_sha}" '
        .apiLevel == $expectedApiLevel and
        .attempt == $expectedAttempt and
        .deploymentPhase == "post-sdk-install-pre-emulator-launch" and
        .configuredMode == "api-24-script-scoped-no-streaming" and
        .effectiveMode == "script-scoped-no-streaming" and
        .wrapperInstalled == true and
        .defaultBehavior == "pass-through" and
        .explicitStreamingAndIncrementalRejectedWhenActive == true and
        .platformToolsRevision != "" and
        .canonicalAdbSha256 == $expectedCanonicalSha and
        .installedWrapperSha256 == $expectedCanonicalSha and
        .sourceWrapperSha256 == $expectedSourceSha and
        .realAdbSha256 == $expectedRealSha
      ' "${attestation}" >/dev/null ||
      transport_fail 'api24-attestation-content'
  else
    [[ ! -e "${real_adb}" ]] || transport_fail 'api36-sidecar-present'
    [[ "${canonical_sha}" != "${source_sha}" ]] ||
      transport_fail 'api36-wrapper-installed'
    real_sha="${canonical_sha}"
    [[ -s "${evidence_dir}/adb-version.txt" ]] ||
      transport_fail 'api36-version-evidence'
    [[ ! -e "${evidence_dir}/adb-wrapper-version.txt" ]] ||
      transport_fail 'api36-wrapper-evidence'
    jq -e \
      --argjson expectedApiLevel "${api_level}" \
      --argjson expectedAttempt "${emulator_attempt}" \
      --arg expectedCanonicalSha "${canonical_sha}" \
      --arg expectedSourceSha "${source_sha}" '
        .apiLevel == $expectedApiLevel and
        .attempt == $expectedAttempt and
        .deploymentPhase == "post-sdk-install-pre-emulator-launch" and
        .configuredMode == "api-24-script-scoped-no-streaming" and
        .effectiveMode == "native-default-pass-through" and
        .wrapperInstalled == false and
        .defaultBehavior == "pass-through" and
        .explicitStreamingAndIncrementalRejectedWhenActive == false and
        .platformToolsRevision != "" and
        .canonicalAdbSha256 == $expectedCanonicalSha and
        .realAdbSha256 == $expectedCanonicalSha and
        .sourceWrapperSha256 == $expectedSourceSha and
        .installedWrapperSha256 == null
      ' "${attestation}" >/dev/null ||
      transport_fail 'api36-attestation-content'
  fi

  # This evidence is intentionally content-free. Reject accidental paths,
  # device serials, or APK names before any product test starts.
  if grep -Eiq '[/\\]|emulator-[0-9]|[.]apk|runner|users' "${attestation}"; then
    privacy_classes="$(
      grep -Eio '[/\\]|emulator-[0-9]|[.]apk|runner|users' "${attestation}" |
        tr '\n' ',' |
        sed 's/,$//'
    )"
    transport_fail "attestation-privacy-${privacy_classes}"
  fi
  exit 0
)

if ! validate_adb_transport_setup; then
  echo 'Post-SDK ADB transport attestation failed; refusing to start product tests.' >&2
  printf '%s\n' '65' > "${evidence_dir}/script-exit-status.txt"
  printf '%s\n' \
    "{\"status\":\"failed\",\"phase\":\"adb-transport-attestation\",\"attempt\":${emulator_attempt},\"exitStatus\":65}" \
    > "${workflow_phase}"
  exit 65
fi

unset DANGGUI_REAL_ADB
unset DANGGUI_ADB_FORCE_NO_STREAMING
unset DANGGUI_ADB_MODE_EVIDENCE
# Flutter 3.47.1 invokes ADB's default streamed install mode. Android 7.0
# occasionally stalls that path during a same-signature test overlay, while
# the official push-then-Package-Manager mode remains healthy. Scope the shim
# to API 24 and this child script; android-emulator-runner itself and API 36
# keep native/pass-through ADB behavior, and product assertions are unchanged.
if (( api_level == 24 )); then
  export DANGGUI_ADB_FORCE_NO_STREAMING=1
  export DANGGUI_ADB_MODE_EVIDENCE="${evidence_dir}/adb-install-invocations.txt"
  : > "${DANGGUI_ADB_MODE_EVIDENCE}"
else
  if [[ -e "${evidence_dir}/adb-install-invocations.txt" ]]; then
    echo 'API 36 unexpectedly inherited API 24 install-mode evidence.' >&2
    printf '%s\n' '65' > "${evidence_dir}/script-exit-status.txt"
    printf '%s\n' \
      "{\"status\":\"failed\",\"phase\":\"adb-transport-scope\",\"attempt\":${emulator_attempt},\"exitStatus\":65}" \
      > "${workflow_phase}"
    exit 65
  fi
fi

# shellcheck source=integration_test/android_emulator_infrastructure.sh
source "${script_dir}/android_emulator_infrastructure.sh"

bounded_adb() {
  timeout --signal=TERM --kill-after=5s 45s \
    adb -s "${device_serial}" "$@"
}

bounded_diagnostic_adb() {
  timeout --signal=TERM --kill-after=5s 30s adb "$@"
}

capture_smoke_failure_evidence() {
  bounded_diagnostic_adb devices -l \
    > "${evidence_dir}/adb-devices.txt" 2>&1 || true
  bounded_diagnostic_adb -s "${device_serial}" \
    shell pidof com.danggui.memo \
    > "${evidence_dir}/app-pid.txt" 2>&1 || true
  bounded_diagnostic_adb -s "${device_serial}" \
    shell dumpsys activity activities \
    > "${evidence_dir}/activity.txt" 2>&1 || true
  bounded_diagnostic_adb -s "${device_serial}" \
    shell dumpsys package com.danggui.memo \
    > "${evidence_dir}/package.txt" 2>&1 || true
  bounded_diagnostic_adb -s "${device_serial}" \
    logcat -d -v threadtime \
    > "${evidence_dir}/logcat.txt" 2>&1 || true
  bounded_diagnostic_adb -s "${device_serial}" shell dumpsys alarm \
    > "${evidence_dir}/alarm-final.txt" 2>&1 || true
  bounded_diagnostic_adb -s "${device_serial}" \
    shell dumpsys notification --noredact \
    > "${evidence_dir}/notification-final.txt" 2>&1 || true
  if [[ ! -s "${evidence_dir}/notification-shade.png" ]]; then
    bounded_diagnostic_adb -s "${device_serial}" exec-out screencap -p \
      > "${evidence_dir}/notification-shade.png" 2>/dev/null || true
  fi
}

validate_adb_install_invocations() {
  local invocation_count=0
  local attestation_next="${evidence_dir}/adb-install-invocation-attestation.json.next.$$"
  if (( api_level == 24 )); then
    [[ -s "${DANGGUI_ADB_MODE_EVIDENCE}" ]] || return 65
    if grep -Evq \
      '^top_level_command=(install|install-multiple|install-multi-package) mode=no-streaming$' \
      "${DANGGUI_ADB_MODE_EVIDENCE}"; then
      return 65
    fi
    invocation_count="$(wc -l < "${DANGGUI_ADB_MODE_EVIDENCE}")"
    invocation_count="${invocation_count//[[:space:]]/}"
    [[ "${invocation_count}" =~ ^[1-9][0-9]*$ ]] || return 65
  else
    [[ ! -e "${evidence_dir}/adb-install-invocations.txt" ]] || return 65
  fi
  jq -n \
    --argjson apiLevel "${api_level}" \
    --argjson attempt "${emulator_attempt}" \
    --argjson invocationCount "${invocation_count}" \
    --arg effectiveMode \
      "$([[ "${api_level}" == 24 ]] && printf '%s' 'script-scoped-no-streaming' || printf '%s' 'native-default-pass-through')" \
    '{
      status: "passed",
      apiLevel: $apiLevel,
      attempt: $attempt,
      effectiveMode: $effectiveMode,
      invocationCount: $invocationCount,
      evidenceContainsPathsSerialsOrApkNames: false
    }' > "${attestation_next}" || {
      rm -f -- "${attestation_next}"
      return 65
    }
  mv -f -- \
    "${attestation_next}" \
    "${evidence_dir}/adb-install-invocation-attestation.json"
}

run_flutter_test() {
  local attempt="$1"
  local attempt_log="${evidence_dir}/${attempt}.log"
  local -a command_statuses

  timeout --signal=TERM --kill-after=30s 12m \
    flutter test --no-pub integration_test/app_cold_start_test.dart \
    -d "${device_serial}" --reporter expanded 2>&1 | tee "${attempt_log}"
  command_statuses=("${PIPESTATUS[@]}")
  if (( command_statuses[0] != 0 )); then
    return "${command_statuses[0]}"
  fi
  return "${command_statuses[1]}"
}

# API 33+ infrastructure attribution must be established before the first
# Flutter build, install, or launch in this attempt. API 24 records an explicit
# not-applicable contract and cannot authorize a SystemUI fresh-AVD retry.
danggui_run_system_component_health_gate
health_gate_status=$?
if (( health_gate_status != 0 )); then
  printf '%s\n' "${health_gate_status}" \
    > "${evidence_dir}/script-exit-status.txt"
  failed_phase="$(jq -r '.phase // "system-component-health-gate"' \
    "${workflow_phase}" 2>/dev/null || \
    printf '%s' 'system-component-health-gate')"
  printf '%s\n' \
    "{\"status\":\"failed\",\"phase\":\"${failed_phase}\",\"attempt\":${emulator_attempt},\"exitStatus\":${health_gate_status}}" \
    > "${workflow_phase}"
  capture_smoke_failure_evidence
  exit "${health_gate_status}"
fi
danggui_set_acceptance_phase 'cold-start-smoke'

# Pixel AVD profiles expose a hardware keyboard to the host. Force the system
# soft keyboard to remain visible as well, so the production-route smoke test
# observes real WindowInsets transitions instead of only injecting text through
# Flutter's test channel.
bounded_adb shell settings put secure show_ime_with_hard_keyboard 1
soft_keyboard_setting="$(
  bounded_adb shell settings get secure show_ime_with_hard_keyboard
)"
printf '%s\n' "${soft_keyboard_setting}" \
  > "${evidence_dir}/soft-keyboard-setting.txt"
soft_keyboard_setting="${soft_keyboard_setting//$'\r'/}"
soft_keyboard_setting="${soft_keyboard_setting//[[:space:]]/}"
[[ "${soft_keyboard_setting}" == '1' ]]

run_flutter_test first-attempt
test_status=$?

# A runner can occasionally stall while ADB is streaming the APK. Retry once
# only when the outer timeout fired after the APK was built and installation
# started, before any test ran, while Package Manager positively confirms that
# the app package is currently absent. An installed app, unknown device state,
# assertion failure, build failure, or second failure is never retried or
# converted to success.
if (( test_status == 124 )) &&
   grep -Fq 'Built build/app/outputs/flutter-apk/app-debug.apk' \
     "${evidence_dir}/first-attempt.log" &&
   grep -Fq 'Installing build/app/outputs/flutter-apk/app-debug.apk' \
     "${evidence_dir}/first-attempt.log" &&
   grep -Fq 'No tests ran.' "${evidence_dir}/first-attempt.log"; then
  echo 'First attempt timed out during installation; performing one bounded ADB recovery before checking package state.'
  recovery_ok=1
  timeout --signal=TERM --kill-after=5s 20s adb kill-server \
    >/dev/null 2>&1 || recovery_ok=0
  if (( recovery_ok == 1 )); then
    timeout --signal=TERM --kill-after=5s 20s adb start-server \
      >/dev/null 2>&1 || recovery_ok=0
  fi
  if (( recovery_ok == 1 )); then
    timeout --signal=TERM --kill-after=5s 60s \
      adb -s "${device_serial}" wait-for-device \
      >/dev/null 2>&1 || recovery_ok=0
  fi
  if (( recovery_ok == 1 )); then
    boot_completed="$(
      timeout --signal=TERM --kill-after=5s 20s \
        adb -s "${device_serial}" shell getprop sys.boot_completed 2>/dev/null
    )"
    boot_query_status=$?
    boot_completed="${boot_completed//$'\r'/}"
    boot_completed="${boot_completed//[[:space:]]/}"
    if (( boot_query_status != 0 )) || [[ "${boot_completed}" != '1' ]]; then
      recovery_ok=0
    fi
  fi
  if (( recovery_ok == 1 )); then
    system_package_path="$(
      timeout --signal=TERM --kill-after=5s 20s \
        adb -s "${device_serial}" shell pm path android 2>/dev/null
    )"
    system_package_query_status=$?
    if (( system_package_query_status != 0 )) ||
       [[ "${system_package_path}" != *'package:'* ]]; then
      recovery_ok=0
    fi
  fi

  if (( recovery_ok == 1 )); then
    package_listing="$(
      timeout --signal=TERM --kill-after=5s 20s \
        adb -s "${device_serial}" shell pm list packages \
          com.danggui.memo 2>/dev/null
    )"
    package_query_status=$?
    if (( package_query_status != 0 )) ||
       [[ -n "${package_listing//[[:space:]]/}" ]]; then
      recovery_ok=0
    fi
  fi

  if (( recovery_ok == 1 )); then
    timeout --signal=TERM --kill-after=5s 30s \
      adb -s "${device_serial}" uninstall com.danggui.memo \
      >/dev/null 2>&1 || true
    clean_package_listing="$(
      timeout --signal=TERM --kill-after=5s 20s \
        adb -s "${device_serial}" shell pm list packages \
          com.danggui.memo 2>/dev/null
    )"
    clean_package_query_status=$?
    if (( clean_package_query_status != 0 )) ||
       [[ -n "${clean_package_listing//[[:space:]]/}" ]]; then
      recovery_ok=0
    fi
  fi

  if (( recovery_ok == 1 )); then
    run_flutter_test retry-after-adb-recovery
    test_status=$?
  else
    echo 'ADB recovery could not prove a healthy clean device with the app absent; refusing to retry.' >&2
  fi
fi

if (( test_status == 0 )); then
  bash integration_test/run_android_release_acceptance.sh "${api_level}"
  acceptance_status=$?
  if (( acceptance_status != 0 )); then
    exit "${acceptance_status}"
  fi

  # The interaction acceptance above intentionally uses a debuggable test
  # host. Only after it has completed do we uninstall that package and install
  # the exact universal release-mode APK produced by android-linux for this
  # workflow SHA. The second phase is host-driven and has no Flutter
  # instrumentation or test-only manifest overlay.
  bash integration_test/run_android_release_binary_smoke.sh \
    "${api_level}" \
    "${DANGGUI_RELEASE_APK:?DANGGUI_RELEASE_APK is not set}"
  release_binary_status=$?
  if (( release_binary_status != 0 )); then
    exit "${release_binary_status}"
  fi
  validate_adb_install_invocations
  adb_invocation_status=$?
  if (( adb_invocation_status != 0 )); then
    echo 'ADB install invocation evidence failed the release gate.' >&2
    printf '%s\n' "${adb_invocation_status}" \
      > "${evidence_dir}/script-exit-status.txt"
    printf '%s\n' \
      "{\"status\":\"failed\",\"phase\":\"adb-install-invocation-attestation\",\"attempt\":${emulator_attempt},\"exitStatus\":${adb_invocation_status}}" \
      > "${workflow_phase}"
    capture_smoke_failure_evidence
    exit "${adb_invocation_status}"
  fi
  exit 0
fi

# Capture evidence while android-emulator-runner still owns a live AVD. Every
# diagnostic is best-effort so the original Flutter test status is preserved.
capture_smoke_failure_evidence

exit "${test_status}"
