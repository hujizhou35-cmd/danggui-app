#!/usr/bin/env bash
set -euo pipefail

readonly retry_signal='DANGGUI_FRESH_AVD_RETRY_V1'

usage() {
  echo "Usage: $0 prepare <api-level> | enforce <api-level> <primary-outcome> <retry-authorized> <retry-outcome>" >&2
  exit 64
}

initialize_root_evidence() {
  local evidence_dir="$1"
  printf '%s\n' \
    '{"status":"initialized","phase":"fresh-avd-retry-started","attempt":2}' \
    > "${evidence_dir}/workflow-phase.json"
  printf '%s\n' \
    '{"status":"not-captured","phase":"before-overlay-install"}' \
    > "${evidence_dir}/before.json"
  printf '%s\n' \
    '{"status":"not-captured","phase":"after-overlay-install"}' \
    > "${evidence_dir}/after.json"
  printf '%s\n' 'not captured' > "${evidence_dir}/notification-before.txt"
  printf '%s\n' 'not captured' > "${evidence_dir}/notification-after.txt"
  : > "${evidence_dir}/notification-shade.png"
}

prepare_retry() {
  local api_level="$1"
  local evidence_dir
  local classification
  local output_file="${GITHUB_OUTPUT:?GITHUB_OUTPUT is not set}"
  local attempt_archive
  local path
  local classification_reason
  local expected_completion_partial

  deny_retry() {
    printf '%s\n' 'retry-authorized=false' >> "${output_file}"
  }

  [[ "${api_level}" =~ ^[0-9]+$ ]] || usage
  evidence_dir="${RUNNER_TEMP:?RUNNER_TEMP is not set}/danggui-emulator-api-${api_level}"
  classification="${evidence_dir}/infrastructure-classification.json"
  if (( api_level < 33 )); then
    echo 'Fresh-AVD SystemUI retry is not applicable below API 33.'
    deny_retry
    return 0
  fi

  # A failed action alone is never retryable. Require every independent piece
  # of the classification contract plus the original exit status and token.
  if [[ ! -s "${classification}" ]] ||
     [[ ! -s "${evidence_dir}/retry-on-fresh-avd.signal" ]] ||
     [[ ! -s "${evidence_dir}/script-exit-status.txt" ]] ||
     [[ "$(tr -d '\r[:space:]' \
       < "${evidence_dir}/retry-on-fresh-avd.signal")" != "${retry_signal}" ]] ||
     [[ "$(tr -d '\r[:space:]' \
       < "${evidence_dir}/script-exit-status.txt")" != '75' ]]; then
    echo 'Primary emulator failure has no complete fresh-AVD authorization.'
    deny_retry
    return 0
  fi

  if ! jq -e --argjson apiLevel "${api_level}" '
      .status == "confirmed-infrastructure-failure" and
      .scope == "system-ui-permission-controller" and
      .apiLevel == $apiLevel and .attempt == 1 and
      (.component == "system-ui" or
       .component == "permission-controller")
    ' "${classification}" >/dev/null; then
    echo 'Primary classification does not identify an allowed system component.'
    deny_retry
    return 0
  fi
  if ! jq -e '
      .status == "confirmed-infrastructure-failure" and
      .scope == "system-ui-permission-controller" and
      .attempt == 1 and .exitStatus == 75 and
      .freshAvdRequired == true and .retryEligible == true and
      .ordinaryProductFailure == false and
      (.reason == "health-gate-anr-dialog" or
       .reason == "permission-flow-anr-dialog" or
       .reason == "bounded-command-timeout")
    ' "${classification}" >/dev/null; then
    echo 'Primary classification failed the strict retry contract.'
    deny_retry
    return 0
  fi
  if ! jq -e '
      if .reason == "permission-flow-anr-dialog" then
        .phase == "app-notification-permission-flow" and
        .packageAbsentBeforeSeed == true and
        .permissionPolicyPending == true and
        .dialogTapAbsent == true and .seedProcessAlive == true
      elif (.reason == "health-gate-anr-dialog" or
            .reason == "bounded-command-timeout") then
        .phase == "system-component-health-gate"
      else
        false
      end
    ' "${classification}" >/dev/null; then
    echo 'Primary classification is missing phase-specific evidence.'
    deny_retry
    return 0
  fi
  classification_reason="$(jq -r '.reason' "${classification}")"
  if [[ "${classification_reason}" == 'permission-flow-anr-dialog' ]]; then
    expected_completion_partial="${evidence_dir}/seed-natural-completion.json.partial.$(
      jq -r '.leaderPid // 0' "${evidence_dir}/seed-process-group.json" \
        2>/dev/null || printf '%s' '0'
    )"
    if [[ ! -s "${evidence_dir}/seed-process-group.json" ]] ||
       [[ ! -s "${evidence_dir}/seed-process-group-termination.json" ]] ||
       [[ ! -s "${evidence_dir}/seed-log-quiescence.json" ]] ||
       [[ ! -e "${evidence_dir}/seed.log" ]] ||
       [[ -e "${evidence_dir}/seed-natural-completion.json" ]] ||
       [[ -e "${expected_completion_partial}" ]] ||
       ! jq -e \
         --slurpfile termination \
           "${evidence_dir}/seed-process-group-termination.json" \
         --slurpfile quiescence \
           "${evidence_dir}/seed-log-quiescence.json" '
           . as $group |
           .independent == true and
           (.leaderPid | type == "number" and . > 1) and
           (.processGroupId == .leaderPid) and
           (($termination | length) == 1) and
           ($termination[0].status == "terminated") and
           ($termination[0].leaderPid == $group.leaderPid) and
           ($termination[0].processGroupId == $group.processGroupId) and
           ((($termination[0].leaderExitStatus == 143) and
             ($termination[0].terminationSignalSent == "TERM")) or
            (($termination[0].leaderExitStatus == 137) and
             ($termination[0].terminationSignalSent == "KILL"))) and
           (($quiescence | length) == 1) and
           ($quiescence[0].unchanged == true) and
           ($quiescence[0].bytesAfterTermination ==
             $quiescence[0].bytesAfterQuietPeriod)
         ' "${evidence_dir}/seed-process-group.json" >/dev/null 2>&1 ||
       grep -Eq \
         'Some tests failed|Test failed|EXCEPTION CAUGHT BY|Expected:|Actual:' \
         "${evidence_dir}/seed.log"; then
      echo 'Permission-flow cleanup evidence failed independent validation.'
      deny_retry
      return 0
    fi
  fi

  attempt_archive="${evidence_dir}/attempt-1"
  if [[ -e "${attempt_archive}" ]]; then
    echo "Refusing to overwrite existing attempt archive: ${attempt_archive}" >&2
    deny_retry
    return 1
  fi
  mkdir -p "${attempt_archive}"
  shopt -s dotglob nullglob
  for path in "${evidence_dir}"/*; do
    [[ "${path}" == "${attempt_archive}" ]] && continue
    mv -- "${path}" "${attempt_archive}/"
  done
  shopt -u dotglob nullglob

  initialize_root_evidence "${evidence_dir}"
  jq -n --argjson apiLevel "${api_level}" \
    '{
      apiLevel: $apiLevel,
      primaryAttemptArchivedAt: "attempt-1",
      retryAttempt: 2,
      retryBudget: 1,
      freshAvdRequired: true
    }' > "${evidence_dir}/retry-provenance.json"
  printf '%s\n' 'retry-authorized=true' >> "${output_file}"
  echo 'One fresh-AVD retry is authorized by confirmed system infrastructure evidence.'
}

enforce_result() {
  local api_level="$1"
  local primary_outcome="$2"
  local retry_authorized="$3"
  local retry_outcome="$4"
  local evidence_dir
  local final_status='failed'
  local retry_used='false'
  local expected_attempt=0
  local phase_valid='false'

  [[ "${api_level}" =~ ^[0-9]+$ ]] || usage
  evidence_dir="${RUNNER_TEMP:?RUNNER_TEMP is not set}/danggui-emulator-api-${api_level}"
  mkdir -p "${evidence_dir}"

  if [[ "${retry_authorized}" == 'true' ]]; then
    retry_used='true'
  fi
  if [[ "${primary_outcome}" == 'success' &&
        "${retry_authorized}" != 'true' &&
        "${retry_outcome}" == 'skipped' ]]; then
    expected_attempt=1
    final_status='passed-primary'
  elif [[ "${primary_outcome}" == 'failure' &&
          "${retry_authorized}" == 'true' &&
          "${retry_outcome}" == 'success' ]]; then
    expected_attempt=2
    final_status='passed-fresh-avd-retry'
  fi

  if (( expected_attempt > 0 )) &&
     [[ -s "${evidence_dir}/workflow-phase.json" ]] &&
     jq -e --argjson expectedAttempt "${expected_attempt}" '
       type == "object" and .status == "passed" and
       .phase == "release-acceptance-complete" and
       .exitStatus == 0 and .attempt == $expectedAttempt
     ' "${evidence_dir}/workflow-phase.json" >/dev/null; then
    phase_valid='true'
  else
    final_status='failed'
  fi
  jq -n \
    --argjson apiLevel "${api_level}" \
    --arg primaryOutcome "${primary_outcome}" \
    --argjson retryAuthorized "$([[ "${retry_authorized}" == 'true' ]] && echo true || echo false)" \
    --arg retryOutcome "${retry_outcome}" \
    --argjson retryUsed "${retry_used}" \
    --arg finalStatus "${final_status}" \
    --argjson expectedAttempt "${expected_attempt}" \
    --argjson workflowPhaseValid "${phase_valid}" \
    '{
      apiLevel: $apiLevel,
      primaryOutcome: $primaryOutcome,
      retryAuthorized: $retryAuthorized,
      retryOutcome: $retryOutcome,
      retryUsed: $retryUsed,
      retryBudget: 1,
      primaryDeviceSerial: "emulator-5554",
      retryDeviceSerial: "emulator-5556",
      expectedSuccessfulAttempt: $expectedAttempt,
      workflowPhaseValid: $workflowPhaseValid,
      finalStatus: $finalStatus
    }' > "${evidence_dir}/retry-decision.json"

  if [[ "${final_status}" == 'passed-primary' ]]; then
    echo 'Primary emulator acceptance passed; no retry was used.'
    return 0
  fi
  if [[ "${final_status}" == 'passed-fresh-avd-retry' ]]; then
    echo 'Primary system infrastructure failed; the sole fresh-AVD retry passed.'
    return 0
  fi

  echo "Emulator acceptance failed closed (primary=${primary_outcome}, retryAuthorized=${retry_authorized}, retry=${retry_outcome})." >&2
  return 1
}

(( $# >= 1 )) || usage
case "$1" in
  prepare)
    (( $# == 2 )) || usage
    prepare_retry "$2"
    ;;
  enforce)
    (( $# == 5 )) || usage
    enforce_result "$2" "$3" "$4" "$5"
    ;;
  *) usage ;;
esac
