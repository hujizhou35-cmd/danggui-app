#!/usr/bin/env bash
set -euo pipefail

if (( $# != 1 )) || [[ ! "$1" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <api-level>" >&2
  exit 64
fi

readonly api_level="$1"
readonly emulator_attempt="${DANGGUI_EMULATOR_ATTEMPT:-1}"
if [[ ! "${emulator_attempt}" =~ ^[12]$ ]]; then
  echo 'DANGGUI_EMULATOR_ATTEMPT must be 1 or 2.' >&2
  exit 64
fi
readonly device_serial="${ANDROID_SERIAL:-emulator-5554}"
readonly package_name='com.danggui.memo'
readonly evidence_dir="${RUNNER_TEMP:?RUNNER_TEMP is not set}/danggui-emulator-api-${api_level}"
readonly acceptance_define="DANGGUI_ACCEPTANCE_API_LEVEL=${api_level}"
readonly build_apk='build/app/outputs/flutter-apk/app-debug.apk'
readonly app_evidence_path='files/danggui/release-acceptance'
readonly host_signal_name='notification-observed.signal'
readonly snooze_alarm_signal_name='snooze-alarm-observed.signal'
mkdir -p "${evidence_dir}"

verify_pid=''
verify_status=''

readonly before_json="${evidence_dir}/before.json"
readonly after_json="${evidence_dir}/after.json"
readonly notification_before="${evidence_dir}/notification-before.txt"
readonly notification_after="${evidence_dir}/notification-after.txt"
readonly notification_screenshot="${evidence_dir}/notification-shade.png"
readonly notification_click_json="${evidence_dir}/notification-click.json"
readonly snooze_callback_json="${evidence_dir}/snooze-callback.json"
readonly workflow_phase="${evidence_dir}/workflow-phase.json"
readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=integration_test/android_emulator_infrastructure.sh
source "${script_dir}/android_emulator_infrastructure.sh"

# These explicit placeholders make early, fail-closed exits diagnosable while
# keeping the always-uploaded artifact contract stable.
printf '%s\n' '{"status":"not-captured","phase":"before-overlay-install"}' > "${before_json}"
printf '%s\n' '{"status":"not-captured","phase":"after-overlay-install"}' > "${after_json}"
printf '%s\n' 'not captured' > "${notification_before}"
printf '%s\n' 'not captured' > "${notification_after}"
: > "${notification_screenshot}"
printf '%s\n' '{"status":"not-captured","phase":"notification-content-click"}' \
  > "${notification_click_json}"
printf '%s\n' '{"status":"not-captured","phase":"notification-action-callbacks"}' \
  > "${snooze_callback_json}"
printf '%s\n' '{"status":"running","phase":"release-acceptance"}' \
  > "${workflow_phase}"
rm -f -- "${evidence_dir}/infrastructure-classification.json" \
  "${evidence_dir}/retry-on-fresh-avd.signal" \
  "${evidence_dir}/permission-dialog-action.json"

bounded_adb() {
  timeout --signal=TERM --kill-after=5s 45s \
    adb -s "${device_serial}" "$@"
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
  local expected_epoch_millis="$2"
  local deadline=$(( SECONDS + 30 ))
  while true; do
    bounded_adb shell dumpsys alarm > "${destination}"
    if danggui_alarm_dump_has_scheduled_notification \
         "${destination}" "${package_name}" "${expected_epoch_millis}"; then
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
      adb -s "${device_serial}" exec-out screencap -p \
      > "${notification_screenshot}" 2>/dev/null
  fi
  timeout --signal=TERM --kill-after=5s 30s \
    adb -s "${device_serial}" logcat -d -v threadtime \
    > "${evidence_dir}/logcat-final.txt" 2>&1
  printf '%s\n' "${status}" > "${evidence_dir}/script-exit-status.txt"
  if (( status == 0 )); then
    printf '%s\n' \
      "{\"status\":\"passed\",\"phase\":\"release-acceptance-complete\",\"attempt\":${emulator_attempt},\"exitStatus\":0}" \
      > "${workflow_phase}"
  else
    failed_phase="$(jq -r '.phase // "release-acceptance"' \
      "${workflow_phase}" 2>/dev/null || printf '%s' 'release-acceptance')"
    printf '%s\n' \
      "{\"status\":\"failed\",\"phase\":\"${failed_phase}\",\"attempt\":${emulator_attempt},\"exitStatus\":${status}}" \
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
    flutter test --no-pub "${target}" -d "${device_serial}" \
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
    "${app_evidence_path}/${host_signal_name}" \
    "${app_evidence_path}/${snooze_alarm_signal_name}" \
    "${app_evidence_path}/snooze-callback.json"
  (
    set -o pipefail
    timeout --signal=TERM --kill-after=30s 20m \
      flutter test --no-pub \
        integration_test/release_acceptance_verify_test.dart \
        -d "${device_serial}" --no-uninstall --reporter expanded \
        --dart-define="${acceptance_define}" 2>&1 |
      tee "${evidence_dir}/verify.log"
  ) &
  verify_pid=$!
}

wait_for_verify_evidence() {
  local destination="$1"
  local evidence_name="${2:-after.json}"
  local deadline=$(( SECONDS + 180 ))
  local candidate="${destination}.partial"
  local read_status
  while (( SECONDS < deadline )); do
    set +e
    bounded_adb exec-out run-as "${package_name}" \
      cat "${app_evidence_path}/${evidence_name}" \
      > "${candidate}" 2>/dev/null
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
  echo "Verify integration test did not publish ${evidence_name} within 180 seconds." >&2
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
  local natural_completion_path="${evidence_dir}/seed-natural-completion.json"
  local natural_completion_partial_path
  rm -f -- "${natural_completion_path}"
  command -v setsid > "${evidence_dir}/setsid-path.txt"
  setsid bash -c '
    set -o pipefail
    set +e
    timeout --foreground --signal=TERM --kill-after=30s 12m \
      flutter test --no-pub \
        integration_test/release_acceptance_seed_test.dart \
        -d "$1" --no-uninstall --reporter expanded \
        --dart-define="$2" 2>&1 | tee "$3"
    pipe_statuses=("${PIPESTATUS[@]}")
    final_status="${pipe_statuses[0]}"
    if (( final_status == 0 )); then
      final_status="${pipe_statuses[1]}"
    fi
    completion_partial="${4}.partial.${BASHPID}"
    printf "%s\n" \
      "{\"status\":\"naturally-completed\",\"pipeStatuses\":[${pipe_statuses[0]},${pipe_statuses[1]}],\"timeoutStatus\":${pipe_statuses[0]},\"teeStatus\":${pipe_statuses[1]},\"finalStatus\":${final_status}}" \
      > "${completion_partial}"
    mv -- "${completion_partial}" "$4"
    exit "${final_status}"
  ' _ "${device_serial}" "${acceptance_define}" \
    "${evidence_dir}/seed.log" "${natural_completion_path}" &
  local test_pid=$!
  natural_completion_partial_path="${natural_completion_path}.partial.${test_pid}"
  local test_pgid=''
  local process_group_ready=0
  if test_pgid="$(
    danggui_wait_for_independent_process_group "${test_pid}" 5
  )"; then
    process_group_ready=1
  fi
  printf '%s\n' \
    "{\"leaderPid\":${test_pid},\"processGroupId\":${test_pgid:-0},\"independent\":$([[ "${test_pgid}" == "${test_pid}" ]] && echo true || echo false)}" \
    > "${evidence_dir}/seed-process-group.json"
  if (( process_group_ready != 1 )) || [[ "${test_pgid}" != "${test_pid}" ]]; then
    kill -TERM "${test_pid}" 2>/dev/null || true
    set +e
    wait "${test_pid}"
    set -e
    echo 'Seed pipeline did not obtain an independent process group.' >&2
    return 1
  fi
  local dialog_handled=0
  local deadline=$(( SECONDS + 600 ))
  local dump_device_path='/sdcard/danggui-permission-dialog.xml'
  local dump_host_path="${evidence_dir}/permission-dialog-poll.xml"
  local node
  local tap_x
  local tap_y
  local infrastructure_anr=0
  local seed_log_size_after_termination
  local seed_log_size_after_quiet_period
  local product_failure_status

  while kill -0 "${test_pid}" 2>/dev/null && (( SECONDS < deadline )); do
    if bounded_adb shell uiautomator dump "${dump_device_path}" \
         > "${evidence_dir}/permission-uiautomator.log" 2>&1 &&
       bounded_adb exec-out cat "${dump_device_path}" \
         > "${dump_host_path}" 2>/dev/null; then
      if danggui_classify_permission_flow_anr \
        "${dump_host_path}" 'permission-flow-system-component-anr.xml' \
        "${test_pid}"; then
        infrastructure_anr=1
        break
      fi
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
        # Pre-grant exact-alarm special access before dismissing the ordinary
        # notification dialog. This prevents a race where the app opens the
        # special-access Settings screen before the host can establish the
        # deterministic exact-delivery acceptance state.
        bounded_adb shell cmd appops set "${package_name}" \
          SCHEDULE_EXACT_ALARM allow \
          > "${evidence_dir}/exact-alarm-appop-grant.txt" 2>&1
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

  if (( infrastructure_anr == 1 )); then
    # Give a naturally completing failing test a short opportunity to publish
    # its atomic sidecar. Product/test failure always outranks coincident ANR.
    if danggui_wait_for_seed_product_failure "${test_pid}" \
      "${natural_completion_path}" "${evidence_dir}/seed.log" \
      "${natural_completion_partial_path}" 3; then
      product_failure_status="${DANGGUI_SEED_FAILURE_STATUS}"
      danggui_revoke_retry_authorization \
        'natural-or-delayed-product-failure'
      if [[ "${DANGGUI_SEED_PROCESS_REAPED}" != 'true' ]]; then
        danggui_terminate_process_group "${test_pgid}" "${test_pid}" \
          "${evidence_dir}/seed-process-group-termination.json" || true
      fi
      printf '%s\n' \
        "{\"status\":\"product-failure-precedence\",\"exitStatus\":${product_failure_status},\"retryRevoked\":true}" \
        > "${evidence_dir}/seed-product-failure-precedence.json"
      echo 'Product/test failure took precedence over coincident system ANR.' >&2
      return "${product_failure_status}"
    fi

    # Stop the independent host process group (bash, timeout, flutter, tee)
    # before authorizing another AVD. Never press either ANR action.
    if ! danggui_terminate_process_group "${test_pgid}" "${test_pid}" \
      "${evidence_dir}/seed-process-group-termination.json"; then
      danggui_revoke_retry_authorization \
        'seed-process-group-not-terminated'
      echo 'Seed process group could not be fully terminated; retry revoked.' >&2
      return 1
    fi
    seed_log_size_after_termination="$(wc -c < "${evidence_dir}/seed.log")"
    sleep 2
    seed_log_size_after_quiet_period="$(wc -c < "${evidence_dir}/seed.log")"
    printf '%s\n' \
      "{\"bytesAfterTermination\":${seed_log_size_after_termination},\"bytesAfterQuietPeriod\":${seed_log_size_after_quiet_period},\"unchanged\":$([[ "${seed_log_size_after_termination}" == "${seed_log_size_after_quiet_period}" ]] && echo true || echo false)}" \
      > "${evidence_dir}/seed-log-quiescence.json"
    if [[ "${seed_log_size_after_termination}" != \
          "${seed_log_size_after_quiet_period}" ]]; then
      danggui_revoke_retry_authorization 'seed-log-still-changing'
      echo 'Seed log changed after process-group termination; retry revoked.' >&2
      return 1
    fi
    # Close the TOCTOU window once more after the entire pipeline is gone and
    # tee has flushed the complete log. A late natural sidecar or failure
    # marker revokes the token and propagates an ordinary failure.
    if danggui_probe_seed_product_failure \
      "${natural_completion_path}" "${evidence_dir}/seed.log" \
      "${natural_completion_partial_path}"; then
      product_failure_status="${DANGGUI_SEED_FAILURE_STATUS}"
      danggui_revoke_retry_authorization \
        'post-termination-product-failure'
      printf '%s\n' \
        "{\"status\":\"product-failure-precedence\",\"exitStatus\":${product_failure_status},\"retryRevoked\":true,\"detectedAfterTermination\":true}" \
        > "${evidence_dir}/seed-product-failure-precedence.json"
      echo 'Late product/test failure revoked the fresh-AVD authorization.' >&2
      return "${product_failure_status}"
    fi
    echo 'Confirmed SystemUI/PermissionController ANR; fresh AVD is required.' >&2
    return "${DANGGUI_INFRA_RETRY_EXIT_STATUS}"
  fi

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
    adb -s "${device_serial}" install --no-streaming "$@" 2>&1 |
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

# The smoke wrapper must have completed the health gate before its very first
# Flutter build/install/launch. Acceptance never reruns or repairs that gate;
# it only validates evidence for this exact API and AVD attempt.
if (( api_level >= 33 )); then
  jq -e --argjson apiLevel "${api_level}" \
    --argjson attempt "${emulator_attempt}" '
      type == "object" and .status == "healthy" and
      .apiLevel == $apiLevel and .attempt == $attempt and
      .stableSamples == 2 and .postNotificationsChanged == false
    ' "${evidence_dir}/system-component-health.json" >/dev/null
else
  jq -e --argjson apiLevel "${api_level}" \
    --argjson attempt "${emulator_attempt}" '
      type == "object" and .status == "not-applicable" and
      .apiLevel == $apiLevel and .attempt == $attempt
    ' "${evidence_dir}/system-component-health.json" >/dev/null
fi
danggui_set_acceptance_phase 'production-debug-build'

# Build the ordinary debug application once and prove a fresh package state.
# The seed integration test is then the only first installation, avoiding an
# immediate redundant reinstall while still exercising the real application.
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
danggui_set_acceptance_phase 'fresh-package-proof'
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
bounded_adb shell getprop ro.build.version.sdk \
  > "${evidence_dir}/device-api-level.txt"
observed_api="$(tr -d '\r[:space:]' < "${evidence_dir}/device-api-level.txt")"
[[ "${observed_api}" == "${api_level}" ]]
if (( api_level >= 33 )); then
  printf '%s\n' \
    "{\"apiLevel\":${api_level},\"status\":\"pending\",\"packageAbsentBeforeSeed\":true,\"runtimePermissionApplicable\":true,\"initialPermissionDeniedByAcceptanceTest\":false,\"grantPerformedByCi\":false,\"appPromptExpected\":true,\"appPromptInvokedByAcceptanceTest\":false,\"dialogHandledThroughSystemUi\":false}" \
    > "${evidence_dir}/permission-policy.json"
else
  printf '%s\n' \
    "{\"apiLevel\":${api_level},\"status\":\"completed\",\"packageAbsentBeforeSeed\":true,\"runtimePermissionApplicable\":false,\"initialPermissionDeniedByAcceptanceTest\":null,\"grantPerformedByCi\":false,\"appPromptExpected\":false,\"appPromptInvokedByAcceptanceTest\":false,\"dialogHandledThroughSystemUi\":false}" \
    > "${evidence_dir}/permission-policy.json"
fi
jq -e . "${evidence_dir}/permission-policy.json" >/dev/null

danggui_set_acceptance_phase 'app-notification-permission-flow'
run_seed_with_permission_contract
if (( api_level >= 33 )); then
  printf '%s\n' \
    "{\"apiLevel\":${api_level},\"status\":\"completed\",\"packageAbsentBeforeSeed\":true,\"runtimePermissionApplicable\":true,\"initialPermissionDeniedByAcceptanceTest\":true,\"grantPerformedByCi\":false,\"appPromptExpected\":true,\"appPromptInvokedByAcceptanceTest\":true,\"dialogHandledThroughSystemUi\":true}" \
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
if (( api_level >= 31 )); then
  bounded_adb shell cmd appops get "${package_name}" SCHEDULE_EXACT_ALARM \
    > "${evidence_dir}/exact-alarm-appop-after-permission.txt" 2>&1
  grep -Eqi 'allow' \
    "${evidence_dir}/exact-alarm-appop-after-permission.txt"
fi
jq -e '.status == "completed"' \
  "${evidence_dir}/permission-policy.json" >/dev/null
extract_app_evidence before.json "${before_json}"
danggui_set_acceptance_phase 'same-signature-overlay-and-retention'
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
scheduled_millis=$(( scheduled_micros / 1000 ))

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
capture_alarm_when_scheduled \
  "${evidence_dir}/alarm-after-verify.txt" "${scheduled_millis}"
printf '%s\n' \
  "{\"platformNotificationId\":${platform_notification_id},\"scheduledEpochSeconds\":${scheduled_seconds},\"scheduledEpochMillis\":${scheduled_millis},\"solePersistedReminder\":true,\"observedAfterVerifyProductionStartup\":true,\"recoverySourceAttributed\":false,\"alarmDump\":\"alarm-after-verify.txt\",\"overlayPreLaunchDump\":\"alarm-after-explicit-overlay.txt\"}" \
  > "${evidence_dir}/alarm-contract.json"
jq -e . "${evidence_dir}/alarm-contract.json" >/dev/null
sha256sum "${evidence_dir}/alarm-after-explicit-overlay.txt" \
  "${evidence_dir}/alarm-after-verify.txt" \
  > "${evidence_dir}/alarm-dumps.sha256"

deadline_seconds=$(( scheduled_seconds + 30 ))
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
  "{\"scheduledEpochSeconds\":${scheduled_seconds},\"observedEpochSeconds\":${observed_seconds},\"latenessSeconds\":$(( observed_seconds - scheduled_seconds )),\"maximumAllowedLatenessSeconds\":30}" \
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
  adb -s "${device_serial}" exec-out screencap -p \
    > "${notification_screenshot}"
[[ -s "${notification_screenshot}" ]]
png_signature="$(od -An -t x1 -N8 "${notification_screenshot}" | tr -d ' \r\n')"
[[ "${png_signature}" == '89504e470d0a1a0a' ]]
bounded_adb shell uiautomator dump /sdcard/danggui-notification-shade.xml \
  > "${evidence_dir}/uiautomator.log" 2>&1
bounded_adb exec-out cat /sdcard/danggui-notification-shade.xml \
  > "${evidence_dir}/notification-shade.xml" 2>&1
grep -Fq "${expected_title}" "${evidence_dir}/notification-shade.xml"
bounded_adb shell dumpsys alarm > "${evidence_dir}/alarm-after-notification.txt"

# Tap the exact title node of the notification whose content was already
# validated above. Parsing XML avoids language-, density-, and API-specific
# coordinates while still exercising a genuine SystemUI notification click.
notification_click_partial="${notification_click_json}.partial"
notification_tap="$({
  python3 - "${evidence_dir}/notification-shade.xml" "${expected_title}" \
    "${notification_click_partial}" <<'PY'
import json
import re
import sys
import xml.etree.ElementTree as ET

xml_path, expected_title, evidence_path = sys.argv[1:]
bounds_pattern = re.compile(r"^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$")
matches = []
for node in ET.parse(xml_path).getroot().iter("node"):
    if node.attrib.get("text") != expected_title:
        continue
    match = bounds_pattern.match(node.attrib.get("bounds", ""))
    if match is None:
        continue
    left, top, right, bottom = map(int, match.groups())
    if right <= left or bottom <= top:
        continue
    matches.append((left, top, right, bottom))

if not matches:
    raise SystemExit("No exact notification-title node with usable bounds was found.")
left, top, right, bottom = matches[0]
tap_x = (left + right) // 2
tap_y = (top + bottom) // 2
with open(evidence_path, "w", encoding="utf-8") as output:
    json.dump(
        {
            "status": "title-node-resolved",
            "expectedTitle": expected_title,
            "exactTitleNodeCount": len(matches),
            "selectedBounds": [left, top, right, bottom],
            "tapX": tap_x,
            "tapY": tap_y,
        },
        output,
        ensure_ascii=False,
        sort_keys=True,
    )
    output.write("\n")
print(f"{tap_x} {tap_y}")
PY
} 2> "${evidence_dir}/notification-click-parse.stderr")"
read -r notification_tap_x notification_tap_y <<< "${notification_tap}"
[[ "${notification_tap_x}" =~ ^[0-9]+$ ]]
[[ "${notification_tap_y}" =~ ^[0-9]+$ ]]
bounded_adb shell input tap "${notification_tap_x}" "${notification_tap_y}" \
  > "${evidence_dir}/notification-click-tap.log" 2>&1

notification_click_deadline=$(( SECONDS + 30 ))
notification_app_resumed=0
notification_shade_collapsed=0
while (( SECONDS < notification_click_deadline )); do
  bounded_adb shell dumpsys activity activities \
    > "${evidence_dir}/notification-click-activity.txt"
  bounded_adb shell dumpsys window \
    > "${evidence_dir}/notification-click-window.txt"
  if grep -Eq \
       '(mResumedActivity|topResumedActivity).*com\.danggui\.memo' \
       "${evidence_dir}/notification-click-activity.txt"; then
    notification_app_resumed=1
  fi
  if grep -Eq 'mCurrentFocus=.*com\.danggui\.memo' \
       "${evidence_dir}/notification-click-window.txt"; then
    notification_shade_collapsed=1
  fi
  if (( notification_app_resumed == 1 && notification_shade_collapsed == 1 )); then
    break
  fi
  sleep 1
done
if (( notification_app_resumed != 1 || notification_shade_collapsed != 1 )); then
  echo 'The exact notification click did not return Danggui to the foreground.' >&2
  exit 1
fi
jq \
  --argjson apiLevel "${api_level}" \
  '. + {
    status: "passed",
    phase: "notification-content-click",
    apiLevel: $apiLevel,
    exactTitleMatched: true,
    tapIssuedThroughSystemUi: true,
    appResumed: true,
    systemUiCollapsed: true
  }' "${notification_click_partial}" > "${notification_click_json}"
rm -f -- "${notification_click_partial}"
jq -e \
  --argjson api "${api_level}" '
    .status == "passed" and .apiLevel == $api and
    .exactTitleMatched == true and .tapIssuedThroughSystemUi == true and
    .appResumed == true and .systemUiCollapsed == true
  ' "${notification_click_json}" >/dev/null

bounded_adb shell run-as "${package_name}" touch \
  "${app_evidence_path}/${host_signal_name}"
danggui_set_acceptance_phase 'production-notification-action-callbacks'
wait_for_verify_evidence "${snooze_callback_json}" 'snooze-callback.json'
jq -e \
  --argjson api "${api_level}" '
    .phase == "production-notification-action-callbacks" and
    .apiLevel == $api and
    .scope.productionCoordinator == true and
    .scope.productionDatabase == true and
    .scope.nativeNotificationGateway == true and
    .scope.systemNotificationPreviouslyObserved == true and
    .scope.systemUiActionClickClaimed == false and
    [.actions[].minutes] == [10, 30, 60] and
    ([.actions[].assertions[]] | all)
  ' "${snooze_callback_json}" >/dev/null
snooze_scheduled_micros="$(
  jq -er '.actions[-1].scheduledAtUtcMicros' "${snooze_callback_json}"
)"
[[ "${snooze_scheduled_micros}" =~ ^[0-9]+$ ]]
snooze_scheduled_millis=$(( snooze_scheduled_micros / 1000 ))
capture_alarm_when_scheduled \
  "${evidence_dir}/alarm-after-snooze-callback.txt" \
  "${snooze_scheduled_millis}"
printf '%s\n' \
  "{\"status\":\"passed\",\"expectedEpochMillis\":${snooze_scheduled_millis},\"activePendingAlarmObserved\":true,\"capturedBeforeFlutterTeardown\":true}" \
  > "${evidence_dir}/snooze-alarm-contract.json"
jq -e '.status == "passed" and .activePendingAlarmObserved == true and
  .capturedBeforeFlutterTeardown == true' \
  "${evidence_dir}/snooze-alarm-contract.json" >/dev/null
bounded_adb shell run-as "${package_name}" touch \
  "${app_evidence_path}/${snooze_alarm_signal_name}"
finish_verify_logged

printf '%s\n' 'release acceptance passed' \
  > "${evidence_dir}/acceptance-result.txt"
