#!/usr/bin/env bash

# Shared, fail-closed infrastructure checks for Android emulator acceptance.
# This file is sourced by the smoke/acceptance wrappers and its self-test.
# The caller must provide bounded_adb(), api_level, evidence_dir, and
# emulator_attempt. No function here grants or changes an app permission.

readonly DANGGUI_INFRA_RETRY_EXIT_STATUS=75
readonly DANGGUI_INFRA_RETRY_SIGNAL='DANGGUI_FRESH_AVD_RETRY_V1'

danggui_alarm_dump_has_scheduled_notification() {
  local source_path="$1"
  local package_name="$2"
  local expected_epoch_millis="$3"

  [[ -s "${source_path}" ]] || return 1
  [[ -n "${package_name}" ]] || return 1
  [[ "${expected_epoch_millis}" =~ ^[0-9]+$ ]] || return 1

  # Match an active Alarm entry and its immediately following delivery tag.
  # v1.1.3 sound/vibration reminders use Danggui's native alarm receiver while
  # silent/legacy registrations can still use flutter_local_notifications.
  # Package allowlists and cancellation-history snapshots can contain the same
  # strings, so independent whole-file greps are not proof of a pending alarm.
  awk \
    -v package_name="${package_name}" \
    -v expected_epoch_millis="${expected_epoch_millis}" '
      BEGIN {
        native_tag = "tag=*walarm*:" package_name ".action.FIRE_ALARM"
        legacy_tag = "tag=*walarm*:" package_name \
          "/com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
      }
      index($0, "Alarm{") &&
      index($0, package_name) &&
      index($0, expected_epoch_millis) {
        candidate_line = NR
        next
      }
      candidate_line > 0 &&
      NR > candidate_line &&
      NR - candidate_line <= 3 &&
      (index($0, native_tag) || index($0, legacy_tag)) {
        found = 1
        exit
      }
      candidate_line > 0 && NR - candidate_line > 3 {
        candidate_line = 0
      }
      END { exit(found ? 0 : 1) }
    ' "${source_path}"
}

danggui_terminate_process_group() {
  local process_group_id="$1"
  local leader_pid="$2"
  local evidence_path="$3"
  local deadline
  local leader_status=0
  local term_signal_sent=false
  local kill_signal_sent=false
  local termination_signal='null'
  local termination_status='failed'

  [[ "${process_group_id}" =~ ^[0-9]+$ ]] || return 1
  [[ "${leader_pid}" =~ ^[0-9]+$ ]] || return 1
  # A negative PID targets the whole independent process group: shell,
  # timeout, flutter, and tee. Never target the acceptance script's own group.
  [[ "${process_group_id}" == "${leader_pid}" ]] || return 1
  [[ "${process_group_id}" != "$$" ]] || return 1

  if kill -TERM -- "-${process_group_id}" 2>/dev/null; then
    term_signal_sent=true
  fi
  deadline=$(( SECONDS + 5 ))
  while kill -0 -- "-${process_group_id}" 2>/dev/null &&
        (( SECONDS < deadline )); do
    sleep 1
  done
  if kill -0 -- "-${process_group_id}" 2>/dev/null; then
    if kill -KILL -- "-${process_group_id}" 2>/dev/null; then
      kill_signal_sent=true
    fi
  fi
  deadline=$(( SECONDS + 5 ))
  while kill -0 -- "-${process_group_id}" 2>/dev/null &&
        (( SECONDS < deadline )); do
    sleep 1
  done
  set +e
  wait "${leader_pid}" 2>/dev/null
  leader_status=$?
  set -e

  # A process group that disappeared naturally in the ANR/termination race is
  # an ordinary host/test failure. Only a signal-derived leader status paired
  # with a signal we actually sent proves that this function terminated it.
  if (( leader_status == 143 )) && [[ "${term_signal_sent}" == 'true' ]]; then
    termination_signal='"TERM"'
  elif (( leader_status == 137 )) &&
       [[ "${kill_signal_sent}" == 'true' ]]; then
    termination_signal='"KILL"'
  fi
  if ! kill -0 -- "-${process_group_id}" 2>/dev/null &&
     [[ "${termination_signal}" != 'null' ]]; then
    termination_status='terminated'
  fi
  printf '%s\n' \
    "{\"status\":\"${termination_status}\",\"processGroupId\":${process_group_id},\"leaderPid\":${leader_pid},\"leaderExitStatus\":${leader_status},\"terminationSignalSent\":${termination_signal}}" \
    > "${evidence_path}"
  [[ "${termination_status}" == 'terminated' ]]
}

danggui_revoke_retry_authorization() {
  local reason="$1"
  local classification_path="${evidence_dir}/infrastructure-classification.json"
  local classification_partial="${classification_path}.partial"

  rm -f -- "${evidence_dir}/retry-on-fresh-avd.signal"
  if [[ -s "${classification_path}" ]]; then
    jq --arg reason "${reason}" \
      '.retryEligible = false | .freshAvdRequired = false |
       .authorizationRevokedReason = $reason' \
      "${classification_path}" > "${classification_partial}" &&
      mv -- "${classification_partial}" "${classification_path}"
  fi
}

DANGGUI_SEED_FAILURE_STATUS=1
DANGGUI_SEED_PROCESS_REAPED=false

danggui_seed_log_has_product_failure() {
  local log_path="$1"
  [[ -s "${log_path}" ]] &&
    grep -Eq 'Some tests failed|Test failed|EXCEPTION CAUGHT BY|Expected:|Actual:' \
      "${log_path}"
}

danggui_probe_seed_product_failure() {
  local completion_path="$1"
  local log_path="$2"
  local partial_path="${3:-}"
  local candidate_path
  local final_status

  DANGGUI_SEED_FAILURE_STATUS=1
  if danggui_seed_log_has_product_failure "${log_path}"; then
    return 0
  fi
  if [[ -n "${partial_path}" && -e "${partial_path}" ]]; then
    candidate_path="${partial_path}"
  elif [[ -e "${completion_path}" ]]; then
    candidate_path="${completion_path}"
  else
    return 1
  fi
  if ! jq -e '
      type == "object" and .status == "naturally-completed" and
      (.pipeStatuses | type == "array" and length == 2 and
       all(.[]; type == "number" and . >= 0 and . <= 255)) and
      (.timeoutStatus == .pipeStatuses[0]) and
      (.teeStatus == .pipeStatuses[1]) and
      (.finalStatus | type == "number" and . >= 0 and . <= 255)
    ' "${candidate_path}" >/dev/null 2>&1; then
    # A malformed natural-completion contract is an ordinary host/test
    # failure. It must never be interpreted as retryable SystemUI evidence.
    return 0
  fi
  final_status="$(jq -r '.finalStatus' "${candidate_path}")"
  if (( final_status != 0 )); then
    DANGGUI_SEED_FAILURE_STATUS="${final_status}"
    return 0
  fi
  if [[ "${candidate_path}" == "${partial_path}" ]]; then
    # The producer reached sidecar serialization but not the atomic rename.
    # Even a zero payload is an interrupted natural completion, not retryable
    # SystemUI infrastructure evidence.
    DANGGUI_SEED_FAILURE_STATUS=1
    return 0
  fi
  return 1
}

danggui_wait_for_seed_product_failure() {
  local seed_pid="$1"
  local completion_path="$2"
  local log_path="$3"
  local partial_path="$4"
  local grace_seconds="$5"
  local deadline=$(( SECONDS + grace_seconds ))
  local natural_status

  DANGGUI_SEED_PROCESS_REAPED=false
  while true; do
    if danggui_probe_seed_product_failure \
      "${completion_path}" "${log_path}" "${partial_path}"; then
      return 0
    fi
    if ! kill -0 "${seed_pid}" 2>/dev/null; then
      set +e
      wait "${seed_pid}" 2>/dev/null
      natural_status=$?
      set -e
      DANGGUI_SEED_PROCESS_REAPED=true
      # Re-read the atomically renamed sidecar and complete log after wait.
      if danggui_probe_seed_product_failure \
        "${completion_path}" "${log_path}" "${partial_path}"; then
        return 0
      fi
      # An ANR candidate followed by any unplanned natural wrapper exit is an
      # ordinary acceptance failure. Non-zero status is propagated exactly;
      # zero without a failing sidecar is still not a retry authorization.
      if (( natural_status != 0 )); then
        DANGGUI_SEED_FAILURE_STATUS="${natural_status}"
      else
        DANGGUI_SEED_FAILURE_STATUS=1
      fi
      return 0
    fi
    if (( SECONDS >= deadline )); then
      return 1
    fi
    sleep 1
  done
}

danggui_set_acceptance_phase() {
  local phase="$1"
  printf '%s\n' \
    "{\"status\":\"running\",\"phase\":\"${phase}\",\"attempt\":${emulator_attempt}}" \
    > "${workflow_phase}"
}

danggui_write_infrastructure_classification() {
  local retry_eligible="$1"
  local component="$2"
  local reason="$3"
  local evidence_file="$4"
  local command_status="$5"
  local classification_path="${evidence_dir}/infrastructure-classification.json"
  local phase
  local app_absent_before_health='false'

  phase="$(jq -r '.phase // "unknown"' "${workflow_phase}" 2>/dev/null || \
    printf '%s' 'unknown')"
  if [[ "${phase}" == 'system-component-health-gate' &&
        -e "${evidence_dir}/app-package-before-health.txt" &&
        -z "$(tr -d '\r[:space:]' \
          < "${evidence_dir}/app-package-before-health.txt")" ]]; then
    app_absent_before_health='true'
  fi

  jq -n \
    --argjson apiLevel "${api_level}" \
    --argjson attempt "${emulator_attempt}" \
    --argjson retryEligible "${retry_eligible}" \
    --arg component "${component}" \
    --arg reason "${reason}" \
    --arg evidenceFile "${evidence_file}" \
    --arg phase "${phase}" \
    --argjson commandStatus "${command_status}" \
    --argjson exitStatus "${DANGGUI_INFRA_RETRY_EXIT_STATUS}" \
    --argjson appAbsentBeforeHealth "${app_absent_before_health}" \
    '{
      status: "confirmed-infrastructure-failure",
      scope: "system-ui-permission-controller",
      apiLevel: $apiLevel,
      attempt: $attempt,
      component: $component,
      reason: $reason,
      phase: $phase,
      evidenceFile: $evidenceFile,
      commandStatus: $commandStatus,
      exitStatus: $exitStatus,
      freshAvdRequired: true,
      retryEligible: $retryEligible,
      appAbsentBeforeHealth: $appAbsentBeforeHealth,
      ordinaryProductFailure: false
    }' > "${classification_path}"

  rm -f -- "${evidence_dir}/retry-on-fresh-avd.signal"
  if [[ "${retry_eligible}" == 'true' ]]; then
    printf '%s\n' "${DANGGUI_INFRA_RETRY_SIGNAL}" \
      > "${evidence_dir}/retry-on-fresh-avd.signal"
  fi
}

danggui_mark_retryable_infrastructure_failure() {
  local component="$1"
  local reason="$2"
  local evidence_file="$3"
  local command_status="$4"
  local retry_eligible='false'

  # The workflow owns exactly one fresh-AVD retry. A second-attempt
  # infrastructure failure remains classified, but can never authorize a
  # third emulator or turn the job green.
  if (( emulator_attempt == 1 )); then
    retry_eligible='true'
  fi
  danggui_write_infrastructure_classification \
    "${retry_eligible}" "${component}" "${reason}" \
    "${evidence_file}" "${command_status}"
}

danggui_mark_nonretryable_health_failure() {
  local component="$1"
  local reason="$2"
  local evidence_file="$3"
  local command_status="$4"

  jq -n \
    --argjson apiLevel "${api_level}" \
    --argjson attempt "${emulator_attempt}" \
    --arg component "${component}" \
    --arg reason "${reason}" \
    --arg evidenceFile "${evidence_file}" \
    --argjson commandStatus "${command_status}" \
    '{
      status: "health-gate-failure",
      scope: "system-ui-permission-controller",
      apiLevel: $apiLevel,
      attempt: $attempt,
      component: $component,
      reason: $reason,
      evidenceFile: $evidenceFile,
      commandStatus: $commandStatus,
      freshAvdRequired: false,
      retryEligible: false,
      ordinaryProductFailure: false
    }' > "${evidence_dir}/infrastructure-classification.json"
  rm -f -- "${evidence_dir}/retry-on-fresh-avd.signal"
}

danggui_xml_has_system_component_anr() {
  local xml_path="$1"
  local component_pattern='(System UI|Permission Controller) (isn.t|is not) responding'

  [[ -s "${xml_path}" ]] &&
    grep -Fq 'package="android"' "${xml_path}" &&
    grep -Fq 'resource-id="android:id/aerr_close"' "${xml_path}" &&
    grep -Fq 'resource-id="android:id/aerr_wait"' "${xml_path}" &&
    grep -Eqi "text=\"${component_pattern}\"" "${xml_path}"
}

danggui_classify_system_component_anr() {
  local xml_path="$1"
  local evidence_name="$2"
  local reason="${3:-health-gate-anr-dialog}"
  local component=''
  local required_package_evidence=''
  local copy_status

  danggui_xml_has_system_component_anr "${xml_path}" || return 1
  if grep -Eqi 'text="System UI (isn.t|is not) responding"' "${xml_path}"; then
    component='system-ui'
    required_package_evidence="${evidence_dir}/systemui-package-path.txt"
  elif grep -Eqi \
    'text="Permission Controller (isn.t|is not) responding"' "${xml_path}"; then
    component='permission-controller'
    required_package_evidence="${evidence_dir}/permission-controller-package-path.txt"
  else
    return 1
  fi

  # A generic Android error dialog is insufficient. The corresponding system
  # package must already have been positively resolved by the health gate.
  [[ -s "${required_package_evidence}" ]] || return 1
  grep -Fq 'package:' "${required_package_evidence}" || return 1

  if cp -- "${xml_path}" "${evidence_dir}/${evidence_name}"; then
    :
  else
    copy_status=$?
    danggui_mark_nonretryable_health_failure \
      "${component}" 'anr-evidence-copy-failed' \
      "$(basename -- "${xml_path}")" "${copy_status}"
    return 2
  fi
  danggui_mark_retryable_infrastructure_failure \
    "${component}" "${reason}" "${evidence_name}" 0
  return 0
}

danggui_classify_permission_flow_anr() {
  local xml_path="$1"
  local evidence_name="$2"
  local seed_pid="$3"
  local classification_path="${evidence_dir}/infrastructure-classification.json"
  local classification_partial="${classification_path}.partial"

  (( api_level >= 33 )) || return 1
  kill -0 "${seed_pid}" 2>/dev/null || return 1
  # A product/test failure always outranks coincident UI state. These are
  # Flutter's stable failure markers; if present, the ordinary non-zero test
  # result is allowed to propagate and no infrastructure token is minted.
  if danggui_seed_log_has_product_failure "${evidence_dir}/seed.log"; then
    return 1
  fi
  [[ ! -e "${evidence_dir}/permission-dialog-action.json" ]] || return 1
  jq -e '.phase == "app-notification-permission-flow"' \
    "${workflow_phase}" >/dev/null 2>&1 || return 1
  jq -e '.status == "pending" and .packageAbsentBeforeSeed == true and
    .runtimePermissionApplicable == true and .grantPerformedByCi == false and
    .dialogHandledThroughSystemUi == false' \
    "${evidence_dir}/permission-policy.json" >/dev/null 2>&1 || return 1
  [[ -s "${evidence_dir}/fresh-package-query.txt" ]] || return 1
  [[ -z "$(tr -d '\r[:space:]' \
    < "${evidence_dir}/fresh-package-query.txt")" ]] || return 1

  danggui_classify_system_component_anr "${xml_path}" "${evidence_name}" \
    'permission-flow-anr-dialog' || return 1
  jq '. + {
      packageAbsentBeforeSeed: true,
      permissionPolicyPending: true,
      dialogTapAbsent: true,
      seedProcessAlive: true
    }' "${classification_path}" > "${classification_partial}"
  mv -- "${classification_partial}" "${classification_path}"
}

danggui_health_command() {
  local component="$1"
  local label="$2"
  shift 2
  local destination="${evidence_dir}/${label}"
  local status

  if bounded_adb "$@" > "${destination}" 2>&1; then
    return 0
  else
    status=$?
  fi

  if (( status == 124 )); then
    danggui_mark_retryable_infrastructure_failure \
      "${component}" 'bounded-command-timeout' "${label}" "${status}"
    return "${DANGGUI_INFRA_RETRY_EXIT_STATUS}"
  fi

  danggui_mark_nonretryable_health_failure \
    "${component}" 'health-command-failed' "${label}" "${status}"
  return 1
}

danggui_metadata_command() {
  local label="$1"
  shift
  local destination="${evidence_dir}/${label}"
  local status

  if bounded_adb "$@" > "${destination}" 2>&1; then
    return 0
  else
    status=$?
  fi
  # Metadata capture is required evidence, but it is not itself proof that
  # SystemUI or PermissionController failed. Therefore it can never mint a
  # fresh-AVD token, even if its bounded ADB command times out.
  danggui_mark_nonretryable_health_failure emulator-metadata \
    'metadata-command-failed' "${label}" "${status}"
  return 1
}

danggui_expect_health_evidence() {
  local component="$1"
  local label="$2"
  local pattern="$3"

  if grep -Eq "${pattern}" "${evidence_dir}/${label}"; then
    return 0
  fi
  danggui_mark_nonretryable_health_failure \
    "${component}" 'unexpected-health-evidence' "${label}" 0
  return 1
}

danggui_capture_responsive_ui() {
  local component="$1"
  local sample="$2"
  local expected_package="$3"
  local device_xml="/sdcard/danggui-${component}-health-${sample}.xml"
  local host_xml="${evidence_dir}/${component}-health-${sample}.xml"
  local poll
  local command_status
  local max_polls=10
  local classification_path
  local classification_partial

  for (( poll = 1; poll <= max_polls; poll += 1 )); do
    # The just-booted SystemUI can acknowledge an expansion before its shade
    # surface is attached. Re-issue the bounded action on every observation
    # instead of repeatedly sampling an expansion request that was ignored.
    if [[ "${component}" == 'system-ui' ]]; then
      if danggui_health_command system-ui \
        "system-ui-expand-${sample}-${poll}.log" \
        shell cmd statusbar expand-settings; then
        :
      else
        command_status=$?
        return "${command_status}"
      fi
      sleep 1
    fi
    if danggui_health_command "${component}" \
      "${component}-uiautomator-${sample}-${poll}.log" \
      shell uiautomator dump "${device_xml}"; then
      :
    else
      command_status=$?
      return "${command_status}"
    fi
    if danggui_health_command "${component}" \
      "${component}-ui-read-${sample}-${poll}.xml" \
      exec-out cat "${device_xml}"; then
      if cp -- "${evidence_dir}/${component}-ui-read-${sample}-${poll}.xml" \
        "${host_xml}"; then
        :
      else
        command_status=$?
        danggui_mark_nonretryable_health_failure \
          "${component}" 'host-ui-evidence-copy-failed' \
          "${component}-ui-read-${sample}-${poll}.xml" \
          "${command_status}"
        return 1
      fi
    else
      command_status=$?
      return "${command_status}"
    fi

    if danggui_classify_system_component_anr \
      "${host_xml}" "${component}-anr-${sample}.xml"; then
      return "${DANGGUI_INFRA_RETRY_EXIT_STATUS}"
    else
      command_status=$?
      if (( command_status > 1 )); then
        return 1
      fi
    fi
    if grep -Fq "package=\"${expected_package}\"" "${host_xml}"; then
      return 0
    else
      command_status=$?
      if (( command_status > 1 )); then
        danggui_mark_nonretryable_health_failure \
          "${component}" 'host-ui-evidence-read-failed' \
          "${component}-health-${sample}.xml" "${command_status}"
        return 1
      fi
    fi
    sleep 1
  done

  if [[ "${component}" == 'system-ui' ]]; then
    danggui_mark_retryable_infrastructure_failure \
      system-ui 'bounded-ui-observation-exhausted' \
      "system-ui-health-${sample}.xml" 0
    classification_path="${evidence_dir}/infrastructure-classification.json"
    classification_partial="${classification_path}.partial"
    jq --argjson observationPolls "${max_polls}" \
      '. + {
        observationPolls: $observationPolls,
        allCommandsSucceeded: true
      }' "${classification_path}" > "${classification_partial}"
    mv -- "${classification_partial}" "${classification_path}"
    return "${DANGGUI_INFRA_RETRY_EXIT_STATUS}"
  fi

  danggui_mark_nonretryable_health_failure \
    "${component}" 'expected-system-ui-not-observed' \
    "${component}-health-${sample}.xml" 0
  return 1
}

danggui_run_system_component_health_gate() {
  local status
  local permission_controller_package
  local sample

  if (( api_level < 33 )); then
    printf '%s\n' \
      "{\"status\":\"not-applicable\",\"apiLevel\":${api_level},\"attempt\":${emulator_attempt}}" \
      > "${evidence_dir}/system-component-health.json"
    return 0
  fi

  danggui_set_acceptance_phase 'system-component-health-gate'

  if danggui_metadata_command emulator-avd-name.txt \
    shell getprop ro.boot.qemu.avd_name; then :; else status=$?; return "${status}"; fi
  if danggui_metadata_command emulator-build-fingerprint.txt \
    shell getprop ro.build.fingerprint; then :; else status=$?; return "${status}"; fi
  if danggui_metadata_command emulator-system-image-fingerprint.txt \
    shell getprop ro.system.build.fingerprint; then :; else status=$?; return "${status}"; fi
  if danggui_metadata_command emulator-build-incremental.txt \
    shell getprop ro.build.version.incremental; then :; else status=$?; return "${status}"; fi
  if danggui_metadata_command emulator-cpu-abi.txt \
    shell getprop ro.product.cpu.abi; then :; else status=$?; return "${status}"; fi

  # Every retryable pre-product health result is anchored to a healthy Package
  # Manager and a successful, empty query for the Danggui package. This proves
  # that no app build/install/launch has occurred in the current AVD attempt.
  if danggui_metadata_command emulator-package-manager-health.txt \
    shell pm path android; then :; else status=$?; return "${status}"; fi
  danggui_expect_health_evidence emulator-package-manager \
    emulator-package-manager-health.txt '^package:.+' || return $?
  if danggui_metadata_command app-package-before-health.txt \
    shell pm list packages com.danggui.memo; then :; else status=$?; return "${status}"; fi
  if [[ -n "$(tr -d '\r[:space:]' \
    < "${evidence_dir}/app-package-before-health.txt")" ]]; then
    danggui_mark_nonretryable_health_failure emulator-package-manager \
      'app-present-before-health-gate' app-package-before-health.txt 0
    return 1
  fi

  if danggui_health_command system-ui systemui-package-path.txt \
    shell pm path com.android.systemui; then :; else status=$?; return "${status}"; fi
  danggui_expect_health_evidence system-ui systemui-package-path.txt \
    '^package:.+' || return $?

  if danggui_health_command permission-controller \
    permission-controller-selection.txt \
    shell cmd package resolve-activity --brief \
      -a android.intent.action.MANAGE_PERMISSIONS; then
    :
  else
    status=$?
    return "${status}"
  fi
  permission_controller_package="$(
    tr -d '\r' < "${evidence_dir}/permission-controller-selection.txt" |
      sed -n -E 's#^([A-Za-z0-9._]+)/[A-Za-z0-9._$]+$#\1#p' |
      head -n 1
  )"
  if [[ ! "${permission_controller_package}" =~ ^[A-Za-z0-9._]+$ ]]; then
    danggui_mark_nonretryable_health_failure permission-controller \
      'invalid-selected-package' permission-controller-selection.txt 0
    return 1
  fi
  printf '%s\n' "${permission_controller_package}" \
    > "${evidence_dir}/permission-controller-package.txt"

  if danggui_health_command permission-controller \
    permission-controller-package-path.txt \
    shell pm path "${permission_controller_package}"; then
    :
  else
    status=$?
    return "${status}"
  fi
  danggui_expect_health_evidence permission-controller \
    permission-controller-package-path.txt '^package:.+' || return $?

  if danggui_health_command permission-controller \
    permission-controller-enabled.txt \
    shell pm list packages -e "${permission_controller_package}"; then
    :
  else
    status=$?
    return "${status}"
  fi
  danggui_expect_health_evidence permission-controller \
    permission-controller-enabled.txt \
    "^package:${permission_controller_package//./\\.}$" || return $?

  # Two complete, separated samples reject the just-booted/CPU-starved state.
  # Each sample exercises SystemUI and the selected PermissionController UI,
  # but never installs Danggui and never grants or revokes any permission.
  for sample in 1 2; do
    if danggui_health_command system-ui "systemui-pid-${sample}.txt" \
      shell pidof com.android.systemui; then :; else status=$?; return "${status}"; fi
    danggui_expect_health_evidence system-ui "systemui-pid-${sample}.txt" \
      '^[0-9]+([[:space:]][0-9]+)*[[:space:]]*$' || return $?

    if danggui_health_command system-ui "statusbar-collapse-${sample}.log" \
      shell cmd statusbar collapse; then :; else status=$?; return "${status}"; fi
    if danggui_capture_responsive_ui system-ui "${sample}" \
      com.android.systemui; then :; else status=$?; return "${status}"; fi
    if danggui_health_command system-ui "statusbar-final-collapse-${sample}.log" \
      shell cmd statusbar collapse; then :; else status=$?; return "${status}"; fi

    if danggui_health_command permission-controller \
      "permission-controller-launch-${sample}.txt" \
      shell am start -W -a android.intent.action.MANAGE_PERMISSIONS; then
      :
    else
      status=$?
      return "${status}"
    fi
    danggui_expect_health_evidence permission-controller \
      "permission-controller-launch-${sample}.txt" \
      '(^|[[:space:]])Status:[[:space:]]+ok([[:space:]]|$)' || return $?
    sleep 1
    if danggui_capture_responsive_ui permission-controller "${sample}" \
      "${permission_controller_package}"; then
      :
    else
      status=$?
      return "${status}"
    fi
    if danggui_health_command permission-controller \
      "permission-controller-home-${sample}.log" \
      shell input keyevent KEYCODE_HOME; then :; else status=$?; return "${status}"; fi

    if (( sample == 1 )); then
      sleep 5
    fi
  done

  jq -n \
    --argjson apiLevel "${api_level}" \
    --argjson attempt "${emulator_attempt}" \
    --arg permissionControllerPackage "${permission_controller_package}" \
    --arg avdName "$(tr -d '\r\n' < "${evidence_dir}/emulator-avd-name.txt")" \
    --arg buildFingerprint "$(tr -d '\r\n' < "${evidence_dir}/emulator-build-fingerprint.txt")" \
    --arg systemImageFingerprint "$(tr -d '\r\n' < "${evidence_dir}/emulator-system-image-fingerprint.txt")" \
    --arg buildIncremental "$(tr -d '\r\n' < "${evidence_dir}/emulator-build-incremental.txt")" \
    --arg cpuAbi "$(tr -d '\r\n' < "${evidence_dir}/emulator-cpu-abi.txt")" \
    '{
      status: "healthy",
      apiLevel: $apiLevel,
      attempt: $attempt,
      stableSamples: 2,
      sampleIntervalSeconds: 5,
      systemUiPackage: "com.android.systemui",
      permissionControllerPackage: $permissionControllerPackage,
      emulator: {
        avdName: $avdName,
        buildFingerprint: $buildFingerprint,
        systemImageFingerprint: $systemImageFingerprint,
        buildIncremental: $buildIncremental,
        cpuAbi: $cpuAbi
      },
      postNotificationsChanged: false
    }' > "${evidence_dir}/system-component-health.json"
  jq -e '.status == "healthy" and .stableSamples == 2 and
    .postNotificationsChanged == false' \
    "${evidence_dir}/system-component-health.json" >/dev/null
}
