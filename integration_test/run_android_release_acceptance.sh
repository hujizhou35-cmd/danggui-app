#!/usr/bin/env bash
set -euo pipefail

if (( $# != 1 )) || [[ ! "$1" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <api-level>" >&2
  exit 64
fi

readonly api_level="$1"
readonly package_name='com.danggui.memo'
readonly evidence_dir="${RUNNER_TEMP:?RUNNER_TEMP is not set}/danggui-emulator-api-${api_level}"
readonly acceptance_define="DANGGUI_ACCEPTANCE_API_LEVEL=${api_level}"
readonly build_apk='build/app/outputs/flutter-apk/app-debug.apk'
readonly app_evidence_path='files/danggui/release-acceptance'
readonly host_signal_name='notification-observed.signal'
mkdir -p "${evidence_dir}"

verify_pid=''
verify_status=''

readonly before_json="${evidence_dir}/before.json"
readonly after_json="${evidence_dir}/after.json"
readonly notification_before="${evidence_dir}/notification-before.txt"
readonly notification_after="${evidence_dir}/notification-after.txt"
readonly notification_screenshot="${evidence_dir}/notification-shade.png"
readonly workflow_phase="${evidence_dir}/workflow-phase.json"

# These explicit placeholders make early, fail-closed exits diagnosable while
# keeping the always-uploaded artifact contract stable.
printf '%s\n' '{"status":"not-captured","phase":"before-overlay-install"}' > "${before_json}"
printf '%s\n' '{"status":"not-captured","phase":"after-overlay-install"}' > "${after_json}"
printf '%s\n' 'not captured' > "${notification_before}"
printf '%s\n' 'not captured' > "${notification_after}"
: > "${notification_screenshot}"
printf '%s\n' '{"status":"running","phase":"release-acceptance"}' \
  > "${workflow_phase}"

bounded_adb() {
  timeout --signal=TERM --kill-after=5s 45s adb -s emulator-5554 "$@"
}

capture_notification_dump() {
  local destination="$1"
  if ! bounded_adb shell dumpsys notification --noredact > "${destination}" 2>&1 ||
     grep -Eqi 'unknown (argument|option)|invalid (argument|option)|usage:' \
       "${destination}"; then
    bounded_adb shell dumpsys notification > "${destination}" 2>&1
  fi
}

capture_alarm_when_scheduled() {
  local destination="$1"
  local deadline=$(( SECONDS + 30 ))
  while true; do
    bounded_adb shell dumpsys alarm > "${destination}"
    if grep -Fq "${package_name}" "${destination}" &&
       grep -Fq 'flutterlocalnotifications' "${destination}"; then
      return 0
    fi
    if (( SECONDS >= deadline )); then
      return 1
    fi
    sleep 2
  done
}

capture_exit_evidence() {
  local status=$?
  trap - EXIT
  set +e
  if [[ -n "${verify_pid}" ]] && kill -0 "${verify_pid}" 2>/dev/null; then
    kill "${verify_pid}" 2>/dev/null
    wait "${verify_pid}" 2>/dev/null
  fi
  timeout --signal=TERM --kill-after=5s 20s adb devices -l \
    > "${evidence_dir}/adb-devices-final.txt" 2>&1
  bounded_adb shell dumpsys package "${package_name}" \
    > "${evidence_dir}/package-final.txt" 2>&1
  bounded_adb shell dumpsys alarm > "${evidence_dir}/alarm-final.txt" 2>&1
  capture_notification_dump "${evidence_dir}/notification-final.txt"
  if [[ ! -s "${notification_screenshot}" ]]; then
    bounded_adb shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1
    bounded_adb shell wm dismiss-keyguard >/dev/null 2>&1
    bounded_adb shell cmd statusbar expand-notifications >/dev/null 2>&1
    timeout --signal=TERM --kill-after=5s 30s \
      adb -s emulator-5554 exec-out screencap -p \
      > "${notification_screenshot}" 2>/dev/null
  fi
  timeout --signal=TERM --kill-after=5s 30s \
    adb -s emulator-5554 logcat -d -v threadtime \
    > "${evidence_dir}/logcat-final.txt" 2>&1
  printf '%s\n' "${status}" > "${evidence_dir}/script-exit-status.txt"
  if (( status == 0 )); then
    printf '%s\n' \
      '{"status":"passed","phase":"release-acceptance-complete","exitStatus":0}' \
      > "${workflow_phase}"
  else
    printf '%s\n' \
      "{\"status\":\"failed\",\"phase\":\"release-acceptance\",\"exitStatus\":${status}}" \
      > "${workflow_phase}"
  fi
  exit "${status}"
}
trap capture_exit_evidence EXIT

run_flutter_logged() {
  local label="$1"
  local target="$2"
  local -a statuses
  set +e
  timeout --signal=TERM --kill-after=30s 12m \
    flutter test --no-pub "${target}" -d emulator-5554 \
      --no-uninstall --reporter expanded \
      --dart-define="${acceptance_define}" 2>&1 |
    tee "${evidence_dir}/${label}.log"
  statuses=("${PIPESTATUS[@]}")
  set -e
  if (( statuses[0] != 0 )); then
    return "${statuses[0]}"
  fi
  return "${statuses[1]}"
}

start_verify_logged() {
  bounded_adb shell run-as "${package_name}" rm -f \
    "${app_evidence_path}/${host_signal_name}"
  (
    set -o pipefail
    timeout --signal=TERM --kill-after=30s 20m \
      flutter test --no-pub \
        integration_test/release_acceptance_verify_test.dart \
        -d emulator-5554 --no-uninstall --reporter expanded \
        --dart-define="${acceptance_define}" 2>&1 |
      tee "${evidence_dir}/verify.log"
  ) &
  verify_pid=$!
}

wait_for_verify_evidence() {
  local destination="$1"
  local deadline=$(( SECONDS + 180 ))
  local candidate="${destination}.partial"
  local read_status
  while (( SECONDS < deadline )); do
    set +e
    bounded_adb exec-out run-as "${package_name}" \
      cat "${app_evidence_path}/after.json" > "${candidate}" 2>/dev/null
    read_status=$?
    set -e
    if (( read_status == 0 )) && jq -e . "${candidate}" >/dev/null 2>&1; then
      mv "${candidate}" "${destination}"
      return 0
    fi
    if ! kill -0 "${verify_pid}" 2>/dev/null; then
      set +e
      wait "${verify_pid}"
      verify_status=$?
      set -e
      verify_pid=''
      echo "Verify integration test exited before evidence was ready (status ${verify_status})." >&2
      return 1
    fi
    sleep 1
  done
  echo 'Verify integration test did not publish after.json within 180 seconds.' >&2
  return 1
}

finish_verify_logged() {
  local status
  if [[ -z "${verify_pid}" ]]; then
    [[ -n "${verify_status}" ]] || return 1
    return "${verify_status}"
  fi
  set +e
  wait "${verify_pid}"
  status=$?
  set -e
  verify_pid=''
  verify_status="${status}"
  return "${status}"
}

run_seed_with_permission_contract() {
  if (( api_level < 33 )); then
    run_flutter_logged seed integration_test/release_acceptance_seed_test.dart
    return
  fi

  # API 33+ must exercise the app-initiated runtime request. The Flutter test
  # runs in the background while the host observes the real Permission
  # Controller dialog and taps its Allow button by bounds. No pm grant is used.
  (
    set -o pipefail
    timeout --signal=TERM --kill-after=30s 12m \
      flutter test --no-pub \
        integration_test/release_acceptance_seed_test.dart \
        -d emulator-5554 --no-uninstall --reporter expanded \
        --dart-define="${acceptance_define}" 2>&1 |
      tee "${evidence_dir}/seed.log"
  ) &
  local test_pid=$!
  local dialog_handled=0
  local deadline=$(( SECONDS + 600 ))
  local dump_device_path='/sdcard/danggui-permission-dialog.xml'
  local dump_host_path="${evidence_dir}/permission-dialog-poll.xml"
  local node
  local tap_x
  local tap_y

  while kill -0 "${test_pid}" 2>/dev/null && (( SECONDS < deadline )); do
    if bounded_adb shell uiautomator dump "${dump_device_path}" \
         > "${evidence_dir}/permission-uiautomator.log" 2>&1 &&
       bounded_adb exec-out cat "${dump_device_path}" \
         > "${dump_host_path}" 2>/dev/null; then
      node="$(
        grep -oE \
          '<node[^>]*resource-id="[^"]*permission_allow_button"[^>]*/>' \
          "${dump_host_path}" | head -n 1 || true
      )"
      if [[ -n "${node}" ]] &&
         [[ "${node}" =~ bounds=\"\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]\" ]]; then
        tap_x=$(( (BASH_REMATCH[1] + BASH_REMATCH[3]) / 2 ))
        tap_y=$(( (BASH_REMATCH[2] + BASH_REMATCH[4]) / 2 ))
        cp "${dump_host_path}" "${evidence_dir}/permission-dialog.xml"
        bounded_adb shell input tap "${tap_x}" "${tap_y}" \
          > "${evidence_dir}/permission-dialog-tap.log" 2>&1
        printf '%s\n' \
          "{\"resourceIdSuffix\":\"permission_allow_button\",\"tapX\":${tap_x},\"tapY\":${tap_y}}" \
          > "${evidence_dir}/permission-dialog-action.json"
        dialog_handled=1
        break
      fi
    fi
    sleep 2
  done

  set +e
  wait "${test_pid}"
  local test_status=$?
  set -e
  if (( dialog_handled != 1 )); then
    echo 'The app-initiated notification permission dialog was not observed.' >&2
    return 1
  fi
  if (( test_status != 0 )); then
    return "${test_status}"
  fi
  jq -e . "${evidence_dir}/permission-dialog-action.json" >/dev/null
}

install_apk_logged() {
  local label="$1"
  shift
  local -a statuses
  set +e
  timeout --signal=TERM --kill-after=10s 3m \
    adb -s emulator-5554 install --no-streaming "$@" 2>&1 |
    tee "${evidence_dir}/${label}.log"
  statuses=("${PIPESTATUS[@]}")
  set -e
  if (( statuses[0] != 0 )); then
    return "${statuses[0]}"
  fi
  if (( statuses[1] != 0 )); then
    return "${statuses[1]}"
  fi
  grep -Fxq 'Success' "${evidence_dir}/${label}.log"
}

extract_app_evidence() {
  local name="$1"
  local destination="$2"
  bounded_adb exec-out run-as "${package_name}" \
    cat "${app_evidence_path}/${name}" > "${destination}"
  jq -e . "${destination}" >/dev/null
}

device_epoch_seconds() {
  local value
  value="$(bounded_adb shell date +%s 2>/dev/null)"
  value="${value//$'\r'/}"
  value="${value//[[:space:]]/}"
  [[ "${value}" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "${value}"
}

command -v jq > "${evidence_dir}/jq-path.txt"
bounded_adb wait-for-device
boot_completed="$(bounded_adb shell getprop sys.boot_completed)"
boot_completed="${boot_completed//$'\r'/}"
boot_completed="${boot_completed//[[:space:]]/}"
[[ "${boot_completed}" == '1' ]]
bounded_adb shell input keyevent KEYCODE_WAKEUP >/dev/null
bounded_adb shell wm dismiss-keyguard >/dev/null 2>&1 || true
bounded_adb shell svc power stayon true >/dev/null
bounded_adb shell dumpsys power > "${evidence_dir}/power-before.txt"

# Build and install the ordinary debug application first so API 33+ permission
# can be granted to the real package before the seed test performs scheduling.
# The workflow-only debug manifest supplies VM-service transport; no release
# manifest or production permission is changed.
timeout --signal=TERM --kill-after=30s 12m \
  flutter build apk --debug --no-pub --dart-define="${acceptance_define}" \
  > "${evidence_dir}/production-debug-build.log" 2>&1
[[ -s "${build_apk}" ]]
sha256sum "${build_apk}" > "${evidence_dir}/production-debug-apk.sha256"

set +e
bounded_adb uninstall "${package_name}" \
  > "${evidence_dir}/fresh-uninstall.log" 2>&1
uninstall_status=$?
set -e
if (( uninstall_status != 0 )) &&
   ! grep -Eq 'Unknown package|not installed|DELETE_FAILED_INTERNAL_ERROR' \
     "${evidence_dir}/fresh-uninstall.log"; then
  echo 'Could not establish a fresh package state.' >&2
  exit "${uninstall_status}"
fi
bounded_adb shell pm path android \
  > "${evidence_dir}/package-manager-health.txt" 2>&1
grep -Fq 'package:' "${evidence_dir}/package-manager-health.txt"
set +e
package_listing="$(
  bounded_adb shell pm list packages "${package_name}" \
    2> "${evidence_dir}/fresh-package-query.stderr"
)"
package_query_status=$?
set -e
printf '%s\n' "${package_listing}" \
  > "${evidence_dir}/fresh-package-query.txt"
if (( package_query_status != 0 )) ||
   [[ -n "${package_listing//[[:space:]]/}" ]]; then
  echo 'Package Manager could not prove that the app package is absent.' >&2
  exit 1
fi
install_apk_logged initial-install -t "${build_apk}"

bounded_adb shell getprop ro.build.version.sdk \
  > "${evidence_dir}/device-api-level.txt"
observed_api="$(tr -d '\r[:space:]' < "${evidence_dir}/device-api-level.txt")"
[[ "${observed_api}" == "${api_level}" ]]
if (( api_level >= 33 )); then
  bounded_adb shell pm revoke "${package_name}" \
    android.permission.POST_NOTIFICATIONS \
    > "${evidence_dir}/notification-permission-initial-state.log" 2>&1
  printf '%s\n' \
    "{\"apiLevel\":${api_level},\"status\":\"pending\",\"runtimePermissionApplicable\":true,\"grantPerformedByCi\":false,\"appPromptExpected\":true,\"appPromptInvokedByAcceptanceTest\":false,\"dialogHandledThroughSystemUi\":false}" \
    > "${evidence_dir}/permission-policy.json"
else
  printf '%s\n' \
    "{\"apiLevel\":${api_level},\"status\":\"completed\",\"runtimePermissionApplicable\":false,\"grantPerformedByCi\":false,\"appPromptExpected\":false,\"appPromptInvokedByAcceptanceTest\":false,\"dialogHandledThroughSystemUi\":false}" \
    > "${evidence_dir}/permission-policy.json"
fi
bounded_adb shell dumpsys package "${package_name}" \
  > "${evidence_dir}/package-initial.txt"
if (( api_level >= 33 )); then
  grep -Eq 'android.permission.POST_NOTIFICATIONS: granted=false' \
    "${evidence_dir}/package-initial.txt"
fi
bounded_adb shell cmd appops get "${package_name}" POST_NOTIFICATION \
  > "${evidence_dir}/notification-appop.txt" 2>&1 || true
jq -e . "${evidence_dir}/permission-policy.json" >/dev/null

run_seed_with_permission_contract
if (( api_level >= 33 )); then
  printf '%s\n' \
    "{\"apiLevel\":${api_level},\"status\":\"completed\",\"runtimePermissionApplicable\":true,\"grantPerformedByCi\":false,\"appPromptExpected\":true,\"appPromptInvokedByAcceptanceTest\":true,\"dialogHandledThroughSystemUi\":true}" \
    > "${evidence_dir}/permission-policy.json"
fi
bounded_adb shell dumpsys package "${package_name}" \
  > "${evidence_dir}/package-after-permission-flow.txt"
if (( api_level >= 33 )); then
  grep -Eq 'android.permission.POST_NOTIFICATIONS: granted=true' \
    "${evidence_dir}/package-after-permission-flow.txt"
fi
bounded_adb shell cmd appops get "${package_name}" POST_NOTIFICATION \
  > "${evidence_dir}/notification-appop-after-permission.txt" 2>&1 || true
jq -e '.status == "completed"' \
  "${evidence_dir}/permission-policy.json" >/dev/null
extract_app_evidence before.json "${before_json}"
jq -e \
  --argjson api "${api_level}" \
  '.phase == "before-overlay-install" and .apiLevel == $api and
   .scope.sameVersionSignedOverlayOnly == true and
   .scope.schemaMigrationClaimed == false and
   .scope.crossDomainSentinels == ["task", "reminder", "note", "folder", "past", "settings"] and
   .quickCheck == ["ok"] and .foreignKeyCheck == [] and
   .counts.reminders == 1 and .counts.notes == 1 and .counts.folders == 1 and
   .counts.past_events == 1 and
   .task.reminderStatus == "scheduled" and
   .ui.reminderTextVisible == true' "${before_json}" >/dev/null
if (( api_level >= 33 )); then
  jq -e '.scope.runtimeNotificationPermissionRequestedByApp == true' \
    "${before_json}" >/dev/null
else
  jq -e '.scope.runtimeNotificationPermissionRequestedByApp == false' \
    "${before_json}" >/dev/null
fi

# The APK produced by the seed integration target is the exact artifact used
# for the explicit same-signature overlay. No uninstall occurs between the two
# package snapshots.
[[ -s "${build_apk}" ]]
sha256sum "${build_apk}" > "${evidence_dir}/overlay-debug-apk.sha256"
readonly apksigner="${ANDROID_SDK_ROOT:?ANDROID_SDK_ROOT is not set}/build-tools/${ANDROID_BUILD_TOOLS:?ANDROID_BUILD_TOOLS is not set}/apksigner"
[[ -x "${apksigner}" ]]
"${apksigner}" verify --verbose --print-certs "${build_apk}" \
  > "${evidence_dir}/overlay-apk-signature.txt" 2>&1
grep -Fq 'Verified using v' "${evidence_dir}/overlay-apk-signature.txt"
grep -Fxq 'Number of signers: 1' \
  "${evidence_dir}/overlay-apk-signature.txt"
mapfile -t signer_digests < <(
  sed -n -E 's/^.*certificate SHA-256 digest:[[:space:]]*//p' \
    "${evidence_dir}/overlay-apk-signature.txt"
)
(( ${#signer_digests[@]} > 0 ))
normalized_signer_digest="${signer_digests[0]//:/}"
normalized_signer_digest="${normalized_signer_digest,,}"
[[ "${normalized_signer_digest}" =~ ^[0-9a-f]{64}$ ]]
for signer_digest in "${signer_digests[@]}"; do
  signer_digest="${signer_digest//:/}"
  signer_digest="${signer_digest,,}"
  [[ "${signer_digest}" == "${normalized_signer_digest}" ]]
done
printf '%s\n' "${normalized_signer_digest}" \
  > "${evidence_dir}/overlay-apk-certificate-sha256.txt"

bounded_adb shell dumpsys package "${package_name}" \
  > "${evidence_dir}/package-before-overlay.txt"
bounded_adb shell dumpsys alarm > "${evidence_dir}/alarm-before-overlay.txt"
capture_notification_dump "${notification_before}"
expected_title="$(jq -er '.expectedSystemNotification.title' "${before_json}")"
expected_body="$(jq -er '.expectedSystemNotification.body' "${before_json}")"
if grep -Fq "${expected_title}" "${notification_before}"; then
  echo 'The acceptance reminder fired before the overlay boundary.' >&2
  exit 1
fi

install_apk_logged overlay-install -r -t "${build_apk}"
bounded_adb shell dumpsys package "${package_name}" \
  > "${evidence_dir}/package-after-explicit-overlay.txt"
bounded_adb shell dumpsys alarm \
  > "${evidence_dir}/alarm-after-explicit-overlay.txt"
platform_notification_id="$(
  jq -er '.notificationRegistration.platformNotificationId' "${before_json}"
)"
[[ "${platform_notification_id}" =~ ^[0-9]+$ ]]
scheduled_micros="$(jq -er '.task.reminderScheduledAtUtcMicros' "${before_json}")"
[[ "${scheduled_micros}" =~ ^[0-9]+$ ]]
scheduled_seconds=$(( scheduled_micros / 1000000 ))

start_verify_logged
wait_for_verify_evidence "${after_json}"
if ! kill -0 "${verify_pid}" 2>/dev/null; then
  echo 'Verify integration test stopped before host notification checks.' >&2
  exit 1
fi
jq -e \
  --argjson api "${api_level}" \
  '.phase == "after-overlay-install" and .apiLevel == $api and
   ([.retentionAssertions[]] | all) and
   .scope.crossDomainSentinels == ["task", "reminder", "note", "folder", "past", "settings"] and
   .scope.schemaMigrationClaimed == false and
   .scope.physicalDeviceHapticsOrOemClaimed == false' "${after_json}" >/dev/null
if (( api_level >= 33 )); then
  jq -e '.scope.runtimeNotificationPermissionRequestedByApp == true' \
    "${after_json}" >/dev/null
else
  jq -e '.scope.runtimeNotificationPermissionRequestedByApp == false' \
    "${after_json}" >/dev/null
fi
bounded_adb shell dumpsys package "${package_name}" \
  > "${evidence_dir}/package-after-verify.txt"
capture_alarm_when_scheduled "${evidence_dir}/alarm-after-verify.txt"
printf '%s\n' \
  "{\"platformNotificationId\":${platform_notification_id},\"scheduledEpochSeconds\":${scheduled_seconds},\"solePersistedReminder\":true,\"observedAfterVerifyProductionStartup\":true,\"recoverySourceAttributed\":false,\"alarmDump\":\"alarm-after-verify.txt\",\"overlayPreLaunchDump\":\"alarm-after-explicit-overlay.txt\"}" \
  > "${evidence_dir}/alarm-contract.json"
jq -e . "${evidence_dir}/alarm-contract.json" >/dev/null
sha256sum "${evidence_dir}/alarm-after-explicit-overlay.txt" \
  "${evidence_dir}/alarm-after-verify.txt" \
  > "${evidence_dir}/alarm-dumps.sha256"

deadline_seconds=$(( scheduled_seconds + 720 ))
current_seconds="$(device_epoch_seconds)"
remaining_seconds=$(( deadline_seconds - current_seconds ))
if (( remaining_seconds < 0 )); then
  remaining_seconds=0
elif (( remaining_seconds > 1020 )); then
  echo 'The persisted reminder deadline is outside the bounded acceptance window.' >&2
  exit 1
fi
host_deadline=$(( SECONDS + remaining_seconds + 30 ))
notification_seen=0
observed_seconds=0
while true; do
  if ! kill -0 "${verify_pid}" 2>/dev/null; then
    echo 'Verify integration test stopped before notification evidence completed.' >&2
    exit 1
  fi
  capture_notification_dump "${evidence_dir}/notification-poll.txt"
  current_seconds="$(device_epoch_seconds)"
  if grep -Fq "${expected_title}" "${evidence_dir}/notification-poll.txt" &&
     grep -Fq "${expected_body}" "${evidence_dir}/notification-poll.txt"; then
    observed_seconds="${current_seconds}"
    notification_seen=1
    break
  fi
  if (( current_seconds >= deadline_seconds || SECONDS >= host_deadline )); then
    break
  fi
  sleep 5
done
cp "${evidence_dir}/notification-poll.txt" "${notification_after}"
if (( notification_seen != 1 )); then
  echo 'The real scheduled notification did not appear within the bounded window.' >&2
  exit 1
fi
if (( observed_seconds + 2 < scheduled_seconds )); then
  echo 'The notification appeared before its persisted scheduled instant.' >&2
  exit 1
fi
printf '%s\n' \
  "{\"scheduledEpochSeconds\":${scheduled_seconds},\"observedEpochSeconds\":${observed_seconds},\"latenessSeconds\":$(( observed_seconds - scheduled_seconds )),\"maximumAllowedLatenessSeconds\":720}" \
  > "${evidence_dir}/notification-timing.json"
jq -e '.latenessSeconds >= -2 and .latenessSeconds <= .maximumAllowedLatenessSeconds' \
  "${evidence_dir}/notification-timing.json" >/dev/null

bounded_adb shell input keyevent KEYCODE_WAKEUP >/dev/null
bounded_adb shell wm dismiss-keyguard >/dev/null 2>&1 || true
if ! bounded_adb shell cmd statusbar expand-notifications \
  > "${evidence_dir}/statusbar-expand.log" 2>&1; then
  bounded_adb shell service call statusbar 1 \
    >> "${evidence_dir}/statusbar-expand.log" 2>&1
fi
sleep 2
timeout --signal=TERM --kill-after=5s 30s \
  adb -s emulator-5554 exec-out screencap -p > "${notification_screenshot}"
[[ -s "${notification_screenshot}" ]]
png_signature="$(od -An -t x1 -N8 "${notification_screenshot}" | tr -d ' \r\n')"
[[ "${png_signature}" == '89504e470d0a1a0a' ]]
bounded_adb shell uiautomator dump /sdcard/danggui-notification-shade.xml \
  > "${evidence_dir}/uiautomator.log" 2>&1
bounded_adb exec-out cat /sdcard/danggui-notification-shade.xml \
  > "${evidence_dir}/notification-shade.xml" 2>&1
grep -Fq "${expected_title}" "${evidence_dir}/notification-shade.xml"
bounded_adb shell dumpsys alarm > "${evidence_dir}/alarm-after-notification.txt"

bounded_adb shell run-as "${package_name}" touch \
  "${app_evidence_path}/${host_signal_name}"
finish_verify_logged

printf '%s\n' 'release acceptance passed' \
  > "${evidence_dir}/acceptance-result.txt"
