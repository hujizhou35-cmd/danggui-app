#!/usr/bin/env bash
set -euo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd "${script_dir}/.." && pwd)"

if [[ "${1:-}" == '__process-group-writer' ]]; then
  while true; do
    printf '%s\n' 'descendant-alive'
    sleep 0.1
  done
fi

if [[ "${1:-}" == '__process-group-pipeline' ]]; then
  (( $# == 3 )) || exit 64
  set +e
  set -o pipefail
  timeout --foreground --signal=TERM --kill-after=2s 60s \
    bash "$0" __process-group-writer 2>&1 | tee "$2"
  pipeline_statuses=("${PIPESTATUS[@]}")
  pipeline_final_status="${pipeline_statuses[0]}"
  if (( pipeline_final_status == 0 )); then
    pipeline_final_status="${pipeline_statuses[1]}"
  fi
  pipeline_partial="${3}.partial.${BASHPID}"
  printf '%s\n' \
    "{\"status\":\"naturally-completed\",\"pipeStatuses\":[${pipeline_statuses[0]},${pipeline_statuses[1]}],\"timeoutStatus\":${pipeline_statuses[0]},\"teeStatus\":${pipeline_statuses[1]},\"finalStatus\":${pipeline_final_status}}" \
    > "${pipeline_partial}"
  mv -- "${pipeline_partial}" "$3"
  exit "${pipeline_final_status}"
fi

if [[ "${1:-}" == '__delayed-product-failure' ]]; then
  (( $# == 3 )) || exit 64
  sleep 1
  delayed_partial="${3}.partial.${BASHPID}"
  printf '%s\n' \
    '{"status":"naturally-completed","pipeStatuses":[42,0],"timeoutStatus":42,"teeStatus":0,"finalStatus":42}' \
    > "${delayed_partial}"
  mv -- "${delayed_partial}" "$3"
  exit 42
fi

command -v jq >/dev/null

run_health_case() {
  local scenario="$1"
  local attempt="$2"
  local expected_status="$3"
  local expected_retry="$4"
  local case_root
  local status
  local sample_count

  case_root="$(mktemp -d "${TMPDIR:-/tmp}/danggui-system-health.XXXXXX")"
  mkdir -p "${case_root}/danggui-emulator-api-36"
  set +e
  SCENARIO="${scenario}" TEST_ATTEMPT="${attempt}" \
    RUNNER_TEMP="${case_root}" REPOSITORY_ROOT="${repository_root}" \
    bash -c '
      set -euo pipefail
      api_level=36
      emulator_attempt="${TEST_ATTEMPT}"
      evidence_dir="${RUNNER_TEMP}/danggui-emulator-api-36"
      workflow_phase="${evidence_dir}/workflow-phase.json"
      event_log="${evidence_dir}/events.log"
      systemui_read_count=0
      : > "${event_log}"
      printf "%s\n" "{\"status\":\"running\",\"phase\":\"self-test\"}" \
        > "${workflow_phase}"
      sleep() { :; }
      bounded_adb() {
        printf "%s\n" "$*" >> "${event_log}"
        case " $* " in
          *" shell getprop ro.boot.qemu.avd_name "*) printf "%s\n" "danggui-self-test" ;;
          *" shell getprop ro.build.fingerprint "*) printf "%s\n" "aosp/test/build:fingerprint" ;;
          *" shell getprop ro.system.build.fingerprint "*) printf "%s\n" "aosp/test/system:fingerprint" ;;
          *" shell getprop ro.build.version.incremental "*) printf "%s\n" "123456" ;;
          *" shell getprop ro.product.cpu.abi "*) printf "%s\n" "x86_64" ;;
          *" shell pm path android "*) printf "%s\n" "package:/system/framework/framework-res.apk" ;;
          *" shell pm list packages com.danggui.memo "*)
            [[ "${SCENARIO}" == "app-query-failure" ]] && return 1
            [[ "${SCENARIO}" == "app-installed" ]] && \
              printf "%s\n" "package:com.danggui.memo"
            return 0
            ;;
          *" shell pm path com.android.systemui "*)
            printf "%s\n" "package:/system_ext/priv-app/SystemUI/SystemUI.apk" ;;
          *" shell cmd package resolve-activity --brief -a android.intent.action.MANAGE_PERMISSIONS "*)
            printf "%s\n" "com.android.permissioncontroller/.permission.ui.ManagePermissionsActivity" ;;
          *" shell pm path com.android.permissioncontroller "*)
            printf "%s\n" "package:/apex/com.android.permission/priv-app/PermissionController/PermissionController.apk" ;;
          *" shell pm list packages -e com.android.permissioncontroller "*)
            printf "%s\n" "package:com.android.permissioncontroller" ;;
          *" shell pidof com.android.systemui "*) printf "%s\n" "4242" ;;
          *" shell cmd statusbar expand-settings "*)
            [[ "${SCENARIO}" == "timeout" ]] && return 124
            [[ "${SCENARIO}" == "generic-failure" ]] && return 1
            return 0
            ;;
          *" shell am start -W -a android.intent.action.MANAGE_PERMISSIONS "*)
            printf "%s\n" "Starting: Intent" "Status: ok" "Complete" ;;
          *" shell uiautomator dump "*) ;;
          *" exec-out cat /sdcard/danggui-system-ui"*)
            systemui_read_count=$(( systemui_read_count + 1 ))
            if [[ "${SCENARIO}" == "systemui-anr" ||
                  "${SCENARIO}" == "classifier-copy-failure" ]]; then
              printf "%s\n" "<hierarchy><node package=\"android\" text=\"System UI is not responding\" resource-id=\"android:id/aerr_close\"/><node package=\"android\" resource-id=\"android:id/aerr_wait\"/></hierarchy>"
            elif [[ "${SCENARIO}" == "all-launcher" ]] ||
                 { [[ "${SCENARIO}" == "launcher-then-systemui" ]] &&
                   (( systemui_read_count <= 3 )); }; then
              printf "%s\n" "<hierarchy><node package=\"com.android.launcher3\"/></hierarchy>"
            else
              printf "%s\n" "<hierarchy><node package=\"com.android.systemui\"/></hierarchy>"
            fi
            ;;
          *" exec-out cat /sdcard/danggui-permission-controller"*)
            if [[ "${SCENARIO}" == "permission-anr" ]]; then
              printf "%s\n" "<hierarchy><node package=\"android\" text=\"Permission Controller is not responding\" resource-id=\"android:id/aerr_close\"/><node package=\"android\" resource-id=\"android:id/aerr_wait\"/></hierarchy>"
            else
              printf "%s\n" "<hierarchy><node package=\"com.android.permissioncontroller\"/></hierarchy>"
            fi
            ;;
          *" shell cmd statusbar collapse "*|*" shell input keyevent KEYCODE_HOME "*) ;;
          *) return 97 ;;
        esac
      }

      cp() {
        if [[ "${SCENARIO}" == 'copy-failure' ]] ||
           { [[ "${SCENARIO}" == 'classifier-copy-failure' ]] &&
             [[ "$*" == *'system-ui-anr-1.xml'* ]]; }; then
          return 1
        fi
        command cp "$@"
      }

      grep() {
        if [[ "${SCENARIO}" == 'grep-failure' &&
              "$*" == *'system-ui-health-1.xml'* ]]; then
          return 2
        fi
        command grep "$@"
      }
      source "${REPOSITORY_ROOT}/integration_test/android_emulator_infrastructure.sh"
      set +e
      danggui_run_system_component_health_gate
      status=$?
      set -e
      printf "%s\n" "${status}" > "${evidence_dir}/health-status.txt"
      exit "${status}"
    '
  status=$?
  set -e

  [[ "${status}" == "${expected_status}" ]]
  evidence_dir="${case_root}/danggui-emulator-api-36"
  if [[ "${expected_retry}" == 'true' ]]; then
    [[ "$(<"${evidence_dir}/retry-on-fresh-avd.signal")" == \
      'DANGGUI_FRESH_AVD_RETRY_V1' ]]
    jq -e '.retryEligible == true and .ordinaryProductFailure == false' \
      "${evidence_dir}/infrastructure-classification.json" >/dev/null
  else
    [[ ! -e "${evidence_dir}/retry-on-fresh-avd.signal" ]]
  fi

  if [[ "${scenario}" == 'healthy' ]]; then
    jq -e '.status == "healthy" and .stableSamples == 2 and
      .postNotificationsChanged == false' \
      "${evidence_dir}/system-component-health.json" >/dev/null
    sample_count="$(grep -c \
      'shell cmd statusbar expand-settings' \
      "${evidence_dir}/events.log")"
    [[ "${sample_count}" == '2' ]]
  elif [[ "${scenario}" == 'launcher-then-systemui' ]]; then
    sample_count="$(grep -c 'shell cmd statusbar expand-settings' \
      "${evidence_dir}/events.log")"
    [[ "${sample_count}" == '5' ]]
    [[ ! -e "${evidence_dir}/retry-on-fresh-avd.signal" ]]
  elif [[ "${scenario}" == 'all-launcher' ]]; then
    sample_count="$(grep -c 'shell cmd statusbar expand-settings' \
      "${evidence_dir}/events.log")"
    [[ "${sample_count}" == '10' ]]
    jq -e '.reason == "bounded-ui-observation-exhausted" and
      .component == "system-ui" and .phase == "system-component-health-gate" and
      .appAbsentBeforeHealth == true and .observationPolls == 10 and
      .allCommandsSucceeded == true' \
      "${evidence_dir}/infrastructure-classification.json" >/dev/null
  elif [[ "${scenario}" == 'generic-failure' ]]; then
    jq -e '.status == "health-gate-failure" and
      .retryEligible == false' \
      "${evidence_dir}/infrastructure-classification.json" >/dev/null
  elif [[ "${scenario}" == 'copy-failure' ]]; then
    jq -e '.status == "health-gate-failure" and
      .reason == "host-ui-evidence-copy-failed" and
      .retryEligible == false' \
      "${evidence_dir}/infrastructure-classification.json" >/dev/null
  elif [[ "${scenario}" == 'classifier-copy-failure' ]]; then
    jq -e '.status == "health-gate-failure" and
      .reason == "anr-evidence-copy-failed" and
      .retryEligible == false' \
      "${evidence_dir}/infrastructure-classification.json" >/dev/null
  elif [[ "${scenario}" == 'grep-failure' ]]; then
    jq -e '.status == "health-gate-failure" and
      .reason == "host-ui-evidence-read-failed" and
      .retryEligible == false' \
      "${evidence_dir}/infrastructure-classification.json" >/dev/null
  elif (( attempt == 2 )); then
    jq -e '.attempt == 2 and .retryEligible == false' \
      "${evidence_dir}/infrastructure-classification.json" >/dev/null
  fi
  rm -rf -- "${case_root}"
}

run_classifier_contract_tests() {
  local case_root
  case_root="$(mktemp -d "${TMPDIR:-/tmp}/danggui-anr-contract.XXXXXX")"
  RUNNER_TEMP="${case_root}" REPOSITORY_ROOT="${repository_root}" bash -c '
    set -euo pipefail
    api_level=36
    emulator_attempt=1
    evidence_dir="${RUNNER_TEMP}/danggui-emulator-api-36"
    workflow_phase="${evidence_dir}/workflow-phase.json"
    mkdir -p "${evidence_dir}"
    source "${REPOSITORY_ROOT}/integration_test/android_emulator_infrastructure.sh"
    reset_context() {
      rm -f -- "${evidence_dir}/infrastructure-classification.json" \
        "${evidence_dir}/retry-on-fresh-avd.signal" \
        "${evidence_dir}/permission-dialog-action.json"
      printf "%s\n" "{\"status\":\"running\",\"phase\":\"app-notification-permission-flow\",\"attempt\":1}" \
        > "${workflow_phase}"
      printf "%s\n" "{\"status\":\"pending\",\"packageAbsentBeforeSeed\":true,\"runtimePermissionApplicable\":true,\"grantPerformedByCi\":false,\"dialogHandledThroughSystemUi\":false}" \
        > "${evidence_dir}/permission-policy.json"
      printf "\n" > "${evidence_dir}/fresh-package-query.txt"
      printf "%s\n" "package:/system/SystemUI.apk" \
        > "${evidence_dir}/systemui-package-path.txt"
      printf "%s\n" "package:/system/PermissionController.apk" \
        > "${evidence_dir}/permission-controller-package-path.txt"
      : > "${evidence_dir}/seed.log"
    }
    exact="${evidence_dir}/exact.xml"
    app_anr="${evidence_dir}/app-anr.xml"
    ordinary_permission="${evidence_dir}/ordinary-permission.xml"
    missing_close="${evidence_dir}/missing-close.xml"
    missing_wait="${evidence_dir}/missing-wait.xml"
    printf "%s\n" "<hierarchy><node package=\"android\" text=\"System UI is not responding\" resource-id=\"android:id/aerr_close\"/><node package=\"android\" resource-id=\"android:id/aerr_wait\"/></hierarchy>" > "${exact}"
    printf "%s\n" "<hierarchy><node package=\"android\" text=\"Danggui is not responding\" resource-id=\"android:id/aerr_close\"/><node package=\"android\" resource-id=\"android:id/aerr_wait\"/></hierarchy>" > "${app_anr}"
    printf "%s\n" "<hierarchy><node package=\"com.android.permissioncontroller\" text=\"Allow notifications?\" resource-id=\"com.android.permissioncontroller:id/permission_allow_button\"/></hierarchy>" > "${ordinary_permission}"
    printf "%s\n" "<hierarchy><node package=\"android\" text=\"System UI is not responding\" resource-id=\"android:id/aerr_wait\"/></hierarchy>" > "${missing_close}"
    printf "%s\n" "<hierarchy><node package=\"android\" text=\"System UI is not responding\" resource-id=\"android:id/aerr_close\"/></hierarchy>" > "${missing_wait}"

    reset_context
    danggui_classify_permission_flow_anr "${exact}" exact-anr.xml "$$"
    jq -e ".reason == \"permission-flow-anr-dialog\" and
      .packageAbsentBeforeSeed == true and .permissionPolicyPending == true and
      .dialogTapAbsent == true and .seedProcessAlive == true" \
      "${evidence_dir}/infrastructure-classification.json" >/dev/null

    reset_context
    ! danggui_classify_permission_flow_anr "${app_anr}" app-anr-copy.xml "$$"
    [[ ! -e "${evidence_dir}/retry-on-fresh-avd.signal" ]]
    reset_context
    ! danggui_classify_permission_flow_anr "${ordinary_permission}" ordinary.xml "$$"
    [[ ! -e "${evidence_dir}/retry-on-fresh-avd.signal" ]]
    reset_context
    ! danggui_classify_permission_flow_anr "${missing_close}" missing.xml "$$"
    [[ ! -e "${evidence_dir}/retry-on-fresh-avd.signal" ]]
    reset_context
    ! danggui_classify_permission_flow_anr "${missing_wait}" missing.xml "$$"
    [[ ! -e "${evidence_dir}/retry-on-fresh-avd.signal" ]]

    reset_context
    : > "${evidence_dir}/permission-dialog-action.json"
    ! danggui_classify_permission_flow_anr "${exact}" tapped.xml "$$"
    [[ ! -e "${evidence_dir}/retry-on-fresh-avd.signal" ]]

    reset_context
    printf "%s\n" "Some tests failed." > "${evidence_dir}/seed.log"
    ! danggui_classify_permission_flow_anr "${exact}" product-failure.xml "$$"
    [[ ! -e "${evidence_dir}/retry-on-fresh-avd.signal" ]]
  '

  RUNNER_TEMP="${case_root}" REPOSITORY_ROOT="${repository_root}" bash -c '
    set -euo pipefail
    api_level=24
    emulator_attempt=1
    evidence_dir="${RUNNER_TEMP}/danggui-emulator-api-24"
    workflow_phase="${evidence_dir}/workflow-phase.json"
    mkdir -p "${evidence_dir}"
    bounded_adb() { return 99; }
    source "${REPOSITORY_ROOT}/integration_test/android_emulator_infrastructure.sh"
    danggui_run_system_component_health_gate
    [[ ! -e "${evidence_dir}/retry-on-fresh-avd.signal" ]]
    grep -Fq "\"status\":\"not-applicable\"" \
      "${evidence_dir}/system-component-health.json"
  '
  rm -rf -- "${case_root}"
}

run_process_group_termination_test() {
  local case_root
  case_root="$(mktemp -d "${TMPDIR:-/tmp}/danggui-process-group.XXXXXX")"
  RUNNER_TEMP="${case_root}" REPOSITORY_ROOT="${repository_root}" bash -c '
    set -euo pipefail
    api_level=36
    emulator_attempt=1
    evidence_dir="${RUNNER_TEMP}/danggui-emulator-api-36"
    workflow_phase="${evidence_dir}/workflow-phase.json"
    mkdir -p "${evidence_dir}"
    source "${REPOSITORY_ROOT}/integration_test/android_emulator_infrastructure.sh"
    log_path="${evidence_dir}/host-test.log"
    completion_path="${evidence_dir}/host-test-natural-completion.json"
    setsid bash \
      "${REPOSITORY_ROOT}/integration_test/android_emulator_infrastructure_self_test.sh" \
      __process-group-pipeline "${log_path}" "${completion_path}" &
    leader_pid=$!
    process_group_id="$(ps -o pgid= -p "${leader_pid}" | tr -d "[:space:]")"
    [[ "${process_group_id}" == "${leader_pid}" ]]
    sleep 1
    ps -eo pid=,pgid=,comm= \
      | awk -v group="${process_group_id}" '\''$2 == group {print}'\'' \
      > "${evidence_dir}/process-group-before.txt"
    grep -Eq "[[:space:]]timeout$" \
      "${evidence_dir}/process-group-before.txt"
    grep -Eq "[[:space:]]tee$" \
      "${evidence_dir}/process-group-before.txt"
    (( $(wc -l < "${evidence_dir}/process-group-before.txt") >= 4 ))
    danggui_terminate_process_group "${process_group_id}" "${leader_pid}" \
      "${evidence_dir}/termination.json"
    bytes_after="$(wc -c < "${log_path}")"
    sleep 1
    bytes_quiet="$(wc -c < "${log_path}")"
    [[ "${bytes_after}" == "${bytes_quiet}" ]]
    ! kill -0 -- "-${process_group_id}" 2>/dev/null
    ! ps -eo pgid= | tr -d " " | grep -Fxq "${process_group_id}"
    [[ ! -e "${completion_path}" ]]
    jq -e ".status == \"terminated\" and
      ((.leaderExitStatus == 143 and .terminationSignalSent == \"TERM\") or
       (.leaderExitStatus == 137 and .terminationSignalSent == \"KILL\"))" \
      "${evidence_dir}/termination.json" >/dev/null
  '
  rm -rf -- "${case_root}"
}

run_product_failure_precedence_tests() {
  local case_root
  case_root="$(mktemp -d "${TMPDIR:-/tmp}/danggui-product-precedence.XXXXXX")"
  RUNNER_TEMP="${case_root}" REPOSITORY_ROOT="${repository_root}" bash -c '
    set -euo pipefail
    api_level=36
    emulator_attempt=1
    evidence_dir="${RUNNER_TEMP}/danggui-emulator-api-36"
    workflow_phase="${evidence_dir}/workflow-phase.json"
    mkdir -p "${evidence_dir}"
    source "${REPOSITORY_ROOT}/integration_test/android_emulator_infrastructure.sh"
    log_path="${evidence_dir}/seed.log"
    completion_path="${evidence_dir}/seed-natural-completion.json"
    printf "%s\n" "{\"status\":\"running\",\"phase\":\"app-notification-permission-flow\"}" \
      > "${workflow_phase}"
    printf "%s\n" "DANGGUI_FRESH_AVD_RETRY_V1" \
      > "${evidence_dir}/retry-on-fresh-avd.signal"
    printf "%s\n" "{\"retryEligible\":true,\"freshAvdRequired\":true}" \
      > "${evidence_dir}/infrastructure-classification.json"
    : > "${log_path}"
    bash \
      "${REPOSITORY_ROOT}/integration_test/android_emulator_infrastructure_self_test.sh" \
      __delayed-product-failure "${log_path}" "${completion_path}" &
    delayed_pid=$!
    partial_path="${completion_path}.partial.${delayed_pid}"
    danggui_wait_for_seed_product_failure "${delayed_pid}" \
      "${completion_path}" "${log_path}" "${partial_path}" 3
    [[ "${DANGGUI_SEED_FAILURE_STATUS}" == "42" ]]
    danggui_revoke_retry_authorization "delayed-product-self-test"
    set +e
    wait "${delayed_pid}"
    delayed_status=$?
    set -e
    [[ "${delayed_status}" == "42" ]]
    [[ ! -e "${evidence_dir}/retry-on-fresh-avd.signal" ]]
    jq -e ".retryEligible == false and .freshAvdRequired == false and
      .authorizationRevokedReason == \"delayed-product-self-test\"" \
      "${evidence_dir}/infrastructure-classification.json" >/dev/null

    printf "%s\n" \
      "{\"status\":\"naturally-completed\",\"pipeStatuses\":[124,141],\"timeoutStatus\":124,\"teeStatus\":141,\"finalStatus\":124}" \
      > "${completion_path}"
    : > "${log_path}"
    danggui_probe_seed_product_failure "${completion_path}" "${log_path}" \
      "${partial_path}"
    [[ "${DANGGUI_SEED_FAILURE_STATUS}" == "124" ]]
    rm -f -- "${completion_path}"
    printf "%s\n" "Some tests failed." > "${log_path}"
    danggui_probe_seed_product_failure "${completion_path}" "${log_path}" \
      "${partial_path}"
    [[ "${DANGGUI_SEED_FAILURE_STATUS}" == "1" ]]

    : > "${log_path}"
    rm -f -- "${completion_path}"
    printf "%s\n" \
      "{\"status\":\"naturally-completed\",\"pipeStatuses\":[42,0],\"timeoutStatus\":42,\"teeStatus\":0,\"finalStatus\":42}" \
      > "${partial_path}"
    danggui_probe_seed_product_failure "${completion_path}" "${log_path}" \
      "${partial_path}"
    [[ "${DANGGUI_SEED_FAILURE_STATUS}" == "42" ]]
  '
  rm -rf -- "${case_root}"
}

write_retry_fixture() {
  local evidence_dir="$1"
  local retry_eligible="$2"
  local attempt="$3"
  mkdir -p "${evidence_dir}"
  printf '%s\n' '75' > "${evidence_dir}/script-exit-status.txt"
  printf '%s\n' 'DANGGUI_FRESH_AVD_RETRY_V1' \
    > "${evidence_dir}/retry-on-fresh-avd.signal"
  jq -n --argjson retryEligible "${retry_eligible}" \
    --argjson attempt "${attempt}" '
    {
      status: "confirmed-infrastructure-failure",
      scope: "system-ui-permission-controller",
      apiLevel: 36,
      attempt: $attempt,
      component: "system-ui",
      reason: "health-gate-anr-dialog",
      evidenceFile: "system-ui-anr-1.xml",
      phase: "system-component-health-gate",
      exitStatus: 75,
      freshAvdRequired: true,
      retryEligible: $retryEligible,
      appAbsentBeforeHealth: true,
      ordinaryProductFailure: false
    }' > "${evidence_dir}/infrastructure-classification.json"
  printf '%s\n' '<hierarchy><node package="android" text="System UI is not responding"/></hierarchy>' \
    > "${evidence_dir}/system-ui-anr-1.xml"
  printf '%s\n' 'attempt evidence' > "${evidence_dir}/seed.log"
}

write_observation_retry_fixture() {
  local evidence_dir="$1"
  mkdir -p "${evidence_dir}"
  printf '%s\n' '75' > "${evidence_dir}/script-exit-status.txt"
  printf '%s\n' 'DANGGUI_FRESH_AVD_RETRY_V1' \
    > "${evidence_dir}/retry-on-fresh-avd.signal"
  printf '%s\n' 'pre-product SystemUI observation exhausted' \
    > "${evidence_dir}/system-ui-health-1.xml"
  printf '%s\n' \
    '{"status":"confirmed-infrastructure-failure","scope":"system-ui-permission-controller","apiLevel":36,"attempt":1,"component":"system-ui","reason":"bounded-ui-observation-exhausted","evidenceFile":"system-ui-health-1.xml","phase":"system-component-health-gate","exitStatus":75,"freshAvdRequired":true,"retryEligible":true,"ordinaryProductFailure":false,"appAbsentBeforeHealth":true,"observationPolls":10,"allCommandsSucceeded":true}' \
    > "${evidence_dir}/infrastructure-classification.json"
}

write_permission_retry_fixture() {
  local evidence_dir="$1"
  mkdir -p "${evidence_dir}"
  printf '%s\n' '75' > "${evidence_dir}/script-exit-status.txt"
  printf '%s\n' 'DANGGUI_FRESH_AVD_RETRY_V1' \
    > "${evidence_dir}/retry-on-fresh-avd.signal"
  printf '%s\n' 'seed still running at ANR observation' \
    > "${evidence_dir}/seed.log"
  printf '%s\n' \
    '{"status":"confirmed-infrastructure-failure","scope":"system-ui-permission-controller","apiLevel":36,"attempt":1,"component":"system-ui","reason":"permission-flow-anr-dialog","evidenceFile":"permission-dialog-system-ui-anr.xml","phase":"app-notification-permission-flow","exitStatus":75,"freshAvdRequired":true,"retryEligible":true,"ordinaryProductFailure":false,"packageAbsentBeforeSeed":true,"permissionPolicyPending":true,"dialogTapAbsent":true,"seedProcessAlive":true}' \
    > "${evidence_dir}/infrastructure-classification.json"
  printf '%s\n' '<hierarchy><node package="android" text="System UI is not responding"/></hierarchy>' \
    > "${evidence_dir}/permission-dialog-system-ui-anr.xml"
  printf '%s\n' \
    '{"leaderPid":4242,"processGroupId":4242,"independent":true}' \
    > "${evidence_dir}/seed-process-group.json"
  printf '%s\n' \
    '{"status":"terminated","processGroupId":4242,"leaderPid":4242,"leaderExitStatus":143,"terminationSignalSent":"TERM"}' \
    > "${evidence_dir}/seed-process-group-termination.json"
  printf '%s\n' \
    '{"bytesAfterTermination":128,"bytesAfterQuietPeriod":128,"unchanged":true}' \
    > "${evidence_dir}/seed-log-quiescence.json"
}

assert_prepare_denied() {
  local case_root="$1"
  local output_file="$2"
  : > "${output_file}"
  RUNNER_TEMP="${case_root}" GITHUB_OUTPUT="${output_file}" \
    bash "${script_dir}/android_emulator_retry_gate.sh" prepare 36 \
    >/dev/null 2>&1
  [[ "$(wc -l < "${output_file}" | tr -d "[:space:]")" == '1' ]]
  [[ "$(<"${output_file}")" == 'retry-authorized=false' ]]
}

run_retry_gate_tests() {
  local case_root
  local evidence_dir
  local output_file

  case_root="$(mktemp -d "${TMPDIR:-/tmp}/danggui-retry-gate.XXXXXX")"
  evidence_dir="${case_root}/danggui-emulator-api-36"
  output_file="${case_root}/github-output.txt"
  write_retry_fixture "${evidence_dir}" true 1
  RUNNER_TEMP="${case_root}" GITHUB_OUTPUT="${output_file}" \
    bash "${script_dir}/android_emulator_retry_gate.sh" prepare 36 \
    >/dev/null
  [[ "$(wc -l < "${output_file}" | tr -d "[:space:]")" == '1' ]]
  [[ "$(tail -n 1 "${output_file}")" == 'retry-authorized=true' ]]
  [[ -s "${evidence_dir}/attempt-1/seed.log" ]]
  [[ -s "${evidence_dir}/retry-provenance.json" ]]
  [[ -s "${evidence_dir}/before.json" ]]

  rm -rf -- "${evidence_dir}"
  : > "${output_file}"
  write_observation_retry_fixture "${evidence_dir}"
  RUNNER_TEMP="${case_root}" GITHUB_OUTPUT="${output_file}" \
    bash "${script_dir}/android_emulator_retry_gate.sh" prepare 36 \
    >/dev/null
  [[ "$(<"${output_file}")" == 'retry-authorized=true' ]]
  [[ -s "${evidence_dir}/attempt-1/system-ui-health-1.xml" ]]

  for tamper_filter in \
    '.component = "permission-controller"' \
    '.phase = "app-notification-permission-flow"' \
    '.observationPolls = 9' \
    '.appAbsentBeforeHealth = false' \
    '.allCommandsSucceeded = false' \
    '.evidenceFile = "../outside.xml"'; do
    rm -rf -- "${evidence_dir}"
    write_observation_retry_fixture "${evidence_dir}"
    jq "${tamper_filter}" \
      "${evidence_dir}/infrastructure-classification.json" \
      > "${evidence_dir}/classification-tampered.json"
    mv -- "${evidence_dir}/classification-tampered.json" \
      "${evidence_dir}/infrastructure-classification.json"
    assert_prepare_denied "${case_root}" "${output_file}"
  done

  rm -rf -- "${evidence_dir}"
  write_observation_retry_fixture "${evidence_dir}"
  rm -- "${evidence_dir}/system-ui-health-1.xml"
  assert_prepare_denied "${case_root}" "${output_file}"

  rm -rf -- "${evidence_dir}"
  write_retry_fixture "${evidence_dir}" true 1
  : > "${evidence_dir}/system-ui-anr-1.xml"
  assert_prepare_denied "${case_root}" "${output_file}"

  rm -rf -- "${evidence_dir}"
  : > "${output_file}"
  write_permission_retry_fixture "${evidence_dir}"
  RUNNER_TEMP="${case_root}" GITHUB_OUTPUT="${output_file}" \
    bash "${script_dir}/android_emulator_retry_gate.sh" prepare 36 \
    >/dev/null
  [[ "$(<"${output_file}")" == 'retry-authorized=true' ]]
  [[ -s "${evidence_dir}/attempt-1/seed-process-group-termination.json" ]]

  rm -rf -- "${evidence_dir}"
  write_permission_retry_fixture "${evidence_dir}"
  rm -f -- "${evidence_dir}/seed-process-group-termination.json"
  assert_prepare_denied "${case_root}" "${output_file}"

  rm -rf -- "${evidence_dir}"
  write_permission_retry_fixture "${evidence_dir}"
  printf '%s\n' \
    '{"leaderPid":4242,"processGroupId":4242,"independent":false}' \
    > "${evidence_dir}/seed-process-group.json"
  assert_prepare_denied "${case_root}" "${output_file}"

  rm -rf -- "${evidence_dir}"
  write_permission_retry_fixture "${evidence_dir}"
  printf '%s\n' \
    '{"status":"failed","processGroupId":4242,"leaderPid":4242,"leaderExitStatus":1}' \
    > "${evidence_dir}/seed-process-group-termination.json"
  assert_prepare_denied "${case_root}" "${output_file}"

  rm -rf -- "${evidence_dir}"
  write_permission_retry_fixture "${evidence_dir}"
  printf '%s\n' \
    '{"status":"terminated","processGroupId":4242,"leaderPid":4242,"leaderExitStatus":0,"terminationSignalSent":null}' \
    > "${evidence_dir}/seed-process-group-termination.json"
  assert_prepare_denied "${case_root}" "${output_file}"

  rm -rf -- "${evidence_dir}"
  write_permission_retry_fixture "${evidence_dir}"
  printf '%s\n' \
    '{"status":"terminated","processGroupId":4242,"leaderPid":4242,"leaderExitStatus":143}' \
    > "${evidence_dir}/seed-process-group-termination.json"
  assert_prepare_denied "${case_root}" "${output_file}"

  rm -rf -- "${evidence_dir}"
  write_permission_retry_fixture "${evidence_dir}"
  printf '%s\n' \
    '{"status":"terminated","processGroupId":4242,"leaderPid":4242,"leaderExitStatus":137,"terminationSignalSent":"TERM"}' \
    > "${evidence_dir}/seed-process-group-termination.json"
  assert_prepare_denied "${case_root}" "${output_file}"

  rm -rf -- "${evidence_dir}"
  write_permission_retry_fixture "${evidence_dir}"
  printf '%s\n' \
    '{"bytesAfterTermination":128,"bytesAfterQuietPeriod":129,"unchanged":false}' \
    > "${evidence_dir}/seed-log-quiescence.json"
  assert_prepare_denied "${case_root}" "${output_file}"

  rm -rf -- "${evidence_dir}"
  write_permission_retry_fixture "${evidence_dir}"
  printf '%s\n' \
    '{"status":"naturally-completed","pipeStatuses":[42,0],"timeoutStatus":42,"teeStatus":0,"finalStatus":42}' \
    > "${evidence_dir}/seed-natural-completion.json.partial.4242"
  assert_prepare_denied "${case_root}" "${output_file}"

  rm -rf -- "${evidence_dir}"
  : > "${output_file}"
  write_retry_fixture "${evidence_dir}" false 2
  RUNNER_TEMP="${case_root}" GITHUB_OUTPUT="${output_file}" \
    bash "${script_dir}/android_emulator_retry_gate.sh" prepare 36 \
    >/dev/null
  [[ "$(wc -l < "${output_file}" | tr -d "[:space:]")" == '1' ]]
  [[ "$(tail -n 1 "${output_file}")" == 'retry-authorized=false' ]]
  [[ ! -e "${evidence_dir}/attempt-1" ]]

  printf '%s\n' \
    '{"status":"passed","phase":"release-acceptance-complete","attempt":1,"exitStatus":0}' \
    > "${evidence_dir}/workflow-phase.json"
  RUNNER_TEMP="${case_root}" bash "${script_dir}/android_emulator_retry_gate.sh" \
    enforce 36 success false skipped >/dev/null
  jq -e '.finalStatus == "passed-primary" and
    .workflowPhaseValid == true' "${evidence_dir}/retry-decision.json" >/dev/null
  printf '%s\n' \
    '{"status":"passed","phase":"release-acceptance-complete","attempt":2,"exitStatus":0}' \
    > "${evidence_dir}/workflow-phase.json"
  RUNNER_TEMP="${case_root}" bash "${script_dir}/android_emulator_retry_gate.sh" \
    enforce 36 failure true success >/dev/null
  if RUNNER_TEMP="${case_root}" bash \
    "${script_dir}/android_emulator_retry_gate.sh" \
    enforce 36 failure false skipped >/dev/null 2>&1; then
    echo 'Ordinary product failure was incorrectly accepted.' >&2
    return 1
  fi
  if RUNNER_TEMP="${case_root}" bash \
    "${script_dir}/android_emulator_retry_gate.sh" \
    enforce 36 failure true failure >/dev/null 2>&1; then
    echo 'Failed second attempt was incorrectly accepted.' >&2
    return 1
  fi
  if RUNNER_TEMP="${case_root}" bash \
    "${script_dir}/android_emulator_retry_gate.sh" \
    enforce 36 success true failure >/dev/null 2>&1; then
    echo 'Unexpected retry failure after primary success was incorrectly accepted.' >&2
    return 1
  fi

  printf '%s\n' '{malformed' > "${evidence_dir}/workflow-phase.json"
  if RUNNER_TEMP="${case_root}" bash \
    "${script_dir}/android_emulator_retry_gate.sh" \
    enforce 36 success false skipped >/dev/null 2>&1; then
    echo 'Malformed final phase was incorrectly accepted.' >&2
    return 1
  fi
  rm -f -- "${evidence_dir}/workflow-phase.json"
  if RUNNER_TEMP="${case_root}" bash \
    "${script_dir}/android_emulator_retry_gate.sh" \
    enforce 36 failure true success >/dev/null 2>&1; then
    echo 'Missing final phase was incorrectly accepted.' >&2
    return 1
  fi

  rm -rf -- "${evidence_dir}"
  : > "${output_file}"
  RUNNER_TEMP="${case_root}" GITHUB_OUTPUT="${output_file}" \
    bash "${script_dir}/android_emulator_retry_gate.sh" prepare 36 \
    >/dev/null 2>&1
  [[ "$(wc -l < "${output_file}" | tr -d "[:space:]")" == '1' ]]
  [[ "$(<"${output_file}")" == 'retry-authorized=false' ]]

  mkdir -p "${evidence_dir}"
  printf '%s\n' '{malformed' \
    > "${evidence_dir}/infrastructure-classification.json"
  printf '%s\n' '75' > "${evidence_dir}/script-exit-status.txt"
  printf '%s\n' 'DANGGUI_FRESH_AVD_RETRY_V1' \
    > "${evidence_dir}/retry-on-fresh-avd.signal"
  : > "${output_file}"
  RUNNER_TEMP="${case_root}" GITHUB_OUTPUT="${output_file}" \
    bash "${script_dir}/android_emulator_retry_gate.sh" prepare 36 \
    >/dev/null 2>&1
  [[ "$(wc -l < "${output_file}" | tr -d "[:space:]")" == '1' ]]
  [[ "$(<"${output_file}")" == 'retry-authorized=false' ]]

  : > "${output_file}"
  RUNNER_TEMP="${case_root}" GITHUB_OUTPUT="${output_file}" \
    bash "${script_dir}/android_emulator_retry_gate.sh" prepare 24 >/dev/null
  [[ "$(wc -l < "${output_file}" | tr -d "[:space:]")" == '1' ]]
  [[ "$(<"${output_file}")" == 'retry-authorized=false' ]]
  rm -rf -- "${case_root}"
}

run_health_case healthy 1 0 false
run_health_case launcher-then-systemui 1 0 false
run_health_case all-launcher 1 75 true
run_health_case all-launcher 2 75 false
run_health_case systemui-anr 1 75 true
run_health_case permission-anr 1 75 true
run_health_case timeout 1 75 true
run_health_case generic-failure 1 1 false
run_health_case copy-failure 1 1 false
run_health_case classifier-copy-failure 1 1 false
run_health_case grep-failure 1 1 false
run_health_case app-installed 1 1 false
run_health_case app-query-failure 1 1 false
run_health_case timeout 2 75 false
run_classifier_contract_tests
run_product_failure_precedence_tests
if command -v setsid >/dev/null; then
  run_process_group_termination_test
else
  echo 'Process-group runtime self-test skipped: setsid is unavailable.'
fi
run_retry_gate_tests

echo 'Android emulator infrastructure health/retry self-test passed.'
