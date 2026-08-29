#!/usr/bin/env bash
set -euo pipefail

parse_xcresult_summary() {
  local summary_file="$1"
  local minimum_test_count="$2"

  jq -er --argjson minimum "${minimum_test_count}" '
    if .result != "Passed" then
      error("xcresult did not report Passed")
    elif (.totalTestCount | type) != "number" or .totalTestCount % 1 != 0 then
      error("xcresult totalTestCount is missing or is not an integer")
    elif (.passedTests | type) != "number" or .passedTests % 1 != 0 then
      error("xcresult passedTests is missing or is not an integer")
    elif (.failedTests | type) != "number" or .failedTests % 1 != 0 then
      error("xcresult failedTests is missing or is not an integer")
    elif .failedTests != 0 then
      error("xcresult contains failed tests")
    elif .totalTestCount < $minimum then
      error("xcresult contains fewer tests than the required minimum")
    elif .passedTests < $minimum then
      error("xcresult contains fewer passing tests than the required minimum")
    else
      .totalTestCount
    end
  ' "${summary_file}"
}

extract_passing_xcui_test_names() {
  local log_file="$1"

  sed -n -E \
    -e "s/^Test case 'RunnerUITests\.RunnerUITests\.([[:alnum:]_]+)\(\)' passed on .*/\\1/p" \
    -e "s/^Test case 'RunnerUITests\.([[:alnum:]_]+)\(\)' passed on .*/\\1/p" \
    -e "s/^Test Case '-\[RunnerUITests\.RunnerUITests ([[:alnum:]_]+)\]' passed.*/\\1/p" \
    "${log_file}"
}

validate_xcui_test_log() {
  local log_file="$1"
  shift
  local actual expected
  actual="$(extract_passing_xcui_test_names "${log_file}" | LC_ALL=C sort)"
  expected="$(printf '%s\n' "$@" | LC_ALL=C sort)"
  [[ "${actual}" == "${expected}" ]]
}

xcconfig_value() {
  local xcconfig_file="$1"
  local key="$2"

  awk -v expected_key="${key}" '
    index($0, expected_key "=") == 1 {
      value = substr($0, length(expected_key) + 2)
      sub(/\r$/, "", value)
      matches += 1
    }
    END {
      if (matches != 1) exit 1
      print value
    }
  ' "${xcconfig_file}"
}

validate_xcui_flutter_config() {
  local xcconfig_file="$1"
  local expected_target="$2"
  local actual_target

  actual_target="$(xcconfig_value "${xcconfig_file}" FLUTTER_TARGET)" || return 1
  [[ "${actual_target}" == "${expected_target}" ]] || return 1
  printf '%s\n' "${actual_target}"
}

list_simulator_device_type_candidates() {
  local device_family="$1"

  jq -r --arg family "${device_family}" '
    .devicetypes
    | map(select(
        (.identifier | type) == "string" and
        (
          ((.productFamily? // "") == $family) or
          ((.name? // "") | startswith($family))
        )
      ))
    | sort_by([(.minRuntimeVersion? // 0), (.name? // ""), .identifier])
    | reverse
    | .[].identifier
  ' | tr -d '\r'
}

self_test_xcresult_summary_parser() (
  local test_root
  test_root="$(mktemp -d)"
  trap 'rm -rf -- "${test_root}"' EXIT

  printf '%s\n' \
    '{"result":"Passed","totalTestCount":7,"passedTests":7,"failedTests":0,"skippedTests":0}' \
    > "${test_root}/passed.json"
  [[ "$(parse_xcresult_summary "${test_root}/passed.json" 3)" == '7' ]] || {
    echo 'xcresult summary parser rejected a valid passing fixture.' >&2
    exit 1
  }

  printf '%s\n' \
    '{"result":"Failed","totalTestCount":7,"passedTests":6,"failedTests":1,"skippedTests":0}' \
    > "${test_root}/failed.json"
  if parse_xcresult_summary "${test_root}/failed.json" 3 >/dev/null 2>&1; then
    echo 'xcresult summary parser accepted a failed result.' >&2
    exit 1
  fi

  printf '%s\n' \
    '{"result":"Passed","totalTestCount":0,"passedTests":0,"failedTests":0,"skippedTests":0}' \
    > "${test_root}/zero.json"
  if parse_xcresult_summary "${test_root}/zero.json" 3 >/dev/null 2>&1; then
    echo 'xcresult summary parser accepted a zero-test result.' >&2
    exit 1
  fi

  printf '%s\n' \
    '{"result":"Passed","passedTests":7,"failedTests":0,"skippedTests":0}' \
    > "${test_root}/missing.json"
  if parse_xcresult_summary "${test_root}/missing.json" 3 >/dev/null 2>&1; then
    echo 'xcresult summary parser accepted a missing totalTestCount field.' >&2
    exit 1
  fi

  printf '%s\n' \
    "Test case 'RunnerUITests.testBackupRestoreRebuildsReminderContract()' passed on 'iPhone' (1.0 seconds)" \
    "Test case 'RunnerUITests.testTaskReminderDeleteAndRestoreContract()' passed on 'iPhone' (1.0 seconds)" \
    > "${test_root}/modern.log"
  validate_xcui_test_log \
    "${test_root}/modern.log" \
    testTaskReminderDeleteAndRestoreContract \
    testBackupRestoreRebuildsReminderContract || {
      echo 'XCUITest log parser rejected the Xcode 26 output format.' >&2
      exit 1
    }

  printf '%s\n' \
    "Test Case '-[RunnerUITests.RunnerUITests testBackupRestoreRebuildsReminderContract]' passed (1.0 seconds)." \
    "Test Case '-[RunnerUITests.RunnerUITests testTaskReminderDeleteAndRestoreContract]' passed (1.0 seconds)." \
    > "${test_root}/legacy.log"
  validate_xcui_test_log \
    "${test_root}/legacy.log" \
    testTaskReminderDeleteAndRestoreContract \
    testBackupRestoreRebuildsReminderContract || {
      echo 'XCUITest log parser rejected the legacy XCTest output format.' >&2
      exit 1
    }

  printf '%s\n' \
    "Test case 'RunnerUITests.testTaskReminderDeleteAndRestoreContract()' passed on 'iPhone' (1.0 seconds)" \
    "Test case 'RunnerUITests.testTaskReminderDeleteAndRestoreContract()' passed on 'iPhone' (1.0 seconds)" \
    > "${test_root}/duplicate.log"
  if validate_xcui_test_log \
    "${test_root}/duplicate.log" \
    testTaskReminderDeleteAndRestoreContract \
    testBackupRestoreRebuildsReminderContract; then
    echo 'XCUITest log parser accepted duplicate and missing test evidence.' >&2
    exit 1
  fi

  printf '%s\n' \
    'FLUTTER_TARGET=lib/xcui_main.dart' \
    > "${test_root}/Generated.xcconfig"
  [[ "$(
    validate_xcui_flutter_config \
      "${test_root}/Generated.xcconfig" \
      lib/xcui_main.dart
  )" == 'lib/xcui_main.dart' ]] || {
    echo 'XCUITest Flutter config parser rejected a valid fixture.' >&2
    exit 1
  }
  if validate_xcui_flutter_config \
    "${test_root}/Generated.xcconfig" \
    lib/main.dart >/dev/null 2>&1; then
    echo 'XCUITest Flutter config parser accepted the production entrypoint.' >&2
    exit 1
  fi

  printf '%s\n' \
    '{"devicetypes":[' \
    '{"name":"iPhone Old","productFamily":"iPhone","minRuntimeVersion":1,"identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-Old"},' \
    '{"name":"iPad New","productFamily":"iPad","minRuntimeVersion":3,"identifier":"com.apple.CoreSimulator.SimDeviceType.iPad-New"},' \
    '{"name":"iPhone New","productFamily":"iPhone","minRuntimeVersion":4,"identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-New"},' \
    '{"name":"iPhone Mid","minRuntimeVersion":2,"identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-Mid"}' \
    ']}' > "${test_root}/device-types.json"
  [[ "$(
    list_simulator_device_type_candidates iPhone \
      < "${test_root}/device-types.json"
  )" == $'com.apple.CoreSimulator.SimDeviceType.iPhone-New\ncom.apple.CoreSimulator.SimDeviceType.iPhone-Mid\ncom.apple.CoreSimulator.SimDeviceType.iPhone-Old' ]] || {
    echo 'Simulator device-type selector rejected a valid mixed fixture.' >&2
    exit 1
  }
  [[ "$(
    list_simulator_device_type_candidates iPad \
      < "${test_root}/device-types.json"
  )" == 'com.apple.CoreSimulator.SimDeviceType.iPad-New' ]] || {
    echo 'Simulator device-type selector crossed product families.' >&2
    exit 1
  }

  echo 'xcresult, XCUITest log, Flutter target and device selector self-test passed'
)

if [[ "${1:-}" == '--self-test' ]]; then
  if (( $# != 1 )); then
    echo 'Usage: run_ios_simulator_tests.sh --self-test' >&2
    exit 64
  fi
  self_test_xcresult_summary_parser
  exit 0
fi

if (( $# < 3 || $# > 4 )); then
  echo 'Usage: run_ios_simulator_tests.sh <runtime-version> <evidence-dir> <suite-name> [device-prefix]' >&2
  exit 64
fi

readonly runtime_version="$1"
readonly evidence_dir="$2"
readonly suite_name="$3"
readonly device_prefix="${4:-iPhone}"
[[ "${runtime_version}" =~ ^[0-9]+\.[0-9]+$ ]] || {
  echo "Invalid runtime version: ${runtime_version}" >&2
  exit 64
}
[[ "${suite_name}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$ ]] || {
  echo "Invalid suite name: ${suite_name}" >&2
  exit 64
}
[[ "${device_prefix}" == "iPhone" || "${device_prefix}" == "iPad" ]] || {
  echo "Device prefix must be iPhone or iPad." >&2
  exit 64
}
mkdir -p "${evidence_dir}"
canonical_evidence_dir="$(cd -- "${evidence_dir}" && pwd -P)"
readonly canonical_evidence_dir
readonly result_bundle="${canonical_evidence_dir}/${suite_name}.xcresult"
readonly log_path="${canonical_evidence_dir}/${suite_name}.log"
readonly boot_log_path="${canonical_evidence_dir}/${suite_name}.boot.log"
readonly summary_path="${canonical_evidence_dir}/${suite_name}.summary.txt"
readonly metadata_path="${canonical_evidence_dir}/${suite_name}.environment.txt"
readonly xcresult_summary_path="${canonical_evidence_dir}/${suite_name}.xcresult-summary.json"
for managed_path in \
  "${result_bundle}" "${log_path}" "${boot_log_path}" \
  "${summary_path}" "${metadata_path}" \
  "${xcresult_summary_path}"; do
  case "${managed_path}" in
    "${canonical_evidence_dir}"/*) ;;
    *)
      echo "Refusing to manage a path outside the evidence directory." >&2
      exit 64
      ;;
  esac
done
rm -rf -- "${result_bundle}"
rm -f -- \
  "${log_path}" "${boot_log_path}" "${summary_path}" "${metadata_path}" \
  "${xcresult_summary_path}"

runtime_identifier="$(
  xcrun simctl list runtimes available -j |
    jq -r --arg version "${runtime_version}" '
      .runtimes
      | map(select(
          (.identifier | startswith("com.apple.CoreSimulator.SimRuntime.iOS-"))
          and .version == $version
        ))
      | .[0].identifier // empty
    '
)"
if [[ -z "${runtime_identifier}" ]]; then
  echo "Required iOS ${runtime_version} Simulator runtime is unavailable." >&2
  xcrun simctl list runtimes available
  exit 1
fi

runtime_build="$(
  xcrun simctl list runtimes available -j |
    jq -r --arg identifier "${runtime_identifier}" '
      .runtimes
      | map(select(.identifier == $identifier))
      | .[0].buildversion // "unknown"
    '
)"
device_type_candidates="$(
  xcrun simctl list devicetypes -j |
    list_simulator_device_type_candidates "${device_prefix}"
)"
if [[ -z "${device_type_candidates}" ]]; then
  echo "No ${device_prefix} Simulator device type is installed." >&2
  exit 1
fi

simulator_udid=""
simulator_name=""
simulator_boot_attempt=0
device_type_identifier=""
flutter_config_backup_dir=""
generated_xcconfig_existed=false
flutter_export_environment_existed=false
readonly generated_xcconfig_path="ios/Flutter/Generated.xcconfig"
readonly flutter_export_environment_path="ios/Flutter/flutter_export_environment.sh"
destroy_simulator() {
  if [[ -n "${simulator_udid}" ]]; then
    xcrun simctl shutdown "${simulator_udid}" >/dev/null 2>&1 || true
    xcrun simctl delete "${simulator_udid}" >/dev/null 2>&1 || true
    simulator_udid=""
  fi
}
restore_flutter_config() {
  if [[ -z "${flutter_config_backup_dir}" ]]; then
    return
  fi
  if [[ "${generated_xcconfig_existed}" == true ]]; then
    cp "${flutter_config_backup_dir}/Generated.xcconfig" \
      "${generated_xcconfig_path}"
  else
    rm -f -- "${generated_xcconfig_path}"
  fi
  if [[ "${flutter_export_environment_existed}" == true ]]; then
    cp "${flutter_config_backup_dir}/flutter_export_environment.sh" \
      "${flutter_export_environment_path}"
  else
    rm -f -- "${flutter_export_environment_path}"
  fi
  rm -rf -- "${flutter_config_backup_dir}"
  flutter_config_backup_dir=""
}
cleanup_simulator() {
  destroy_simulator
  restore_flutter_config
}
trap cleanup_simulator EXIT INT TERM

: > "${boot_log_path}"
boot_succeeded=false
for simulator_boot_attempt in 1 2; do
  simulator_name="Danggui-${suite_name}-$$-${RANDOM}-${simulator_boot_attempt}"
  printf 'boot_attempt=%s simulator=%s\n' \
    "${simulator_boot_attempt}" "${simulator_name}" >> "${boot_log_path}"
  create_succeeded=false
  candidates_for_attempt="${device_type_candidates}"
  if [[ -n "${device_type_identifier}" ]]; then
    candidates_for_attempt="${device_type_identifier}"$'\n'"${device_type_candidates}"
  fi
  while IFS= read -r candidate_identifier; do
    [[ -n "${candidate_identifier}" ]] || continue
    [[ "${candidate_identifier}" =~ ^com[.]apple[.]CoreSimulator[.]SimDeviceType[.][A-Za-z0-9._-]+$ ]] || {
      printf 'Rejected malformed Simulator device type: %s\n' \
        "${candidate_identifier}" >> "${boot_log_path}"
      continue
    }
    printf 'create_candidate=%s\n' \
      "${candidate_identifier}" >> "${boot_log_path}"
    if simulator_udid="$(
      xcrun simctl create \
        "${simulator_name}" "${candidate_identifier}" "${runtime_identifier}" \
        2>> "${boot_log_path}"
    )"; then
      device_type_identifier="${candidate_identifier}"
      create_succeeded=true
      break
    else
      create_status=$?
      printf 'Simulator candidate %s was rejected with status %s.\n' \
        "${candidate_identifier}" "${create_status}" >> "${boot_log_path}"
      simulator_udid=""
    fi
  done <<< "${candidates_for_attempt}"
  if [[ "${create_succeeded}" == true ]]; then
    if [[ ! "${simulator_udid}" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
      printf 'simctl returned an invalid Simulator identifier: %s\n' \
        "${simulator_udid}" >> "${boot_log_path}"
      simulator_udid=""
    elif xcrun simctl boot "${simulator_udid}" >> "${boot_log_path}" 2>&1 &&
      xcrun simctl bootstatus "${simulator_udid}" -b >> "${boot_log_path}" 2>&1; then
      boot_succeeded=true
      break
    else
      boot_status=$?
      printf 'Simulator boot attempt %s failed with status %s.\n' \
        "${simulator_boot_attempt}" "${boot_status}" >> "${boot_log_path}"
    fi
  else
    printf 'Simulator creation attempt %s exhausted all compatible candidates.\n' \
      "${simulator_boot_attempt}" >> "${boot_log_path}"
  fi
  destroy_simulator
done
if [[ "${boot_succeeded}" != true ]]; then
  echo 'Unable to boot a disposable Simulator after two fresh-device attempts.' >&2
  cat "${boot_log_path}" >&2
  exit 1
fi

{
  printf 'suite=%s\n' "${suite_name}"
  printf 'runtime_identifier=%s\n' "${runtime_identifier}"
  printf 'runtime_build=%s\n' "${runtime_build}"
  printf 'simulator_name=%s\n' "${simulator_name}"
  printf 'simulator_udid=%s\n' "${simulator_udid}"
  printf 'simulator_boot_attempt=%s\n' "${simulator_boot_attempt}"
  printf 'device_type_identifier=%s\n' "${device_type_identifier}"
  printf 'runner_image=%s\n' "${ImageOS:-unknown}"
  printf 'runner_image_version=%s\n' "${ImageVersion:-unknown}"
  printf 'runner_arch=%s\n' "${RUNNER_ARCH:-unknown}"
  printf 'host_arch=%s\n' "$(uname -m)"
  xcodebuild -version
  flutter --version
} > "${metadata_path}"

# The production lib/main.dart does not import the destructive harness. Generate
# an explicit Debug-Simulator Flutter configuration for its dedicated entrypoint
# and pass the target through raw xcodebuild as a second guard. The dedicated
# entrypoint itself requires kDebugMode and an allow-listed launch scenario.
readonly xcui_flutter_target="lib/xcui_main.dart"
flutter_config_backup_dir="$(mktemp -d)"
if [[ -f "${generated_xcconfig_path}" ]]; then
  generated_xcconfig_existed=true
  cp "${generated_xcconfig_path}" \
    "${flutter_config_backup_dir}/Generated.xcconfig"
fi
if [[ -f "${flutter_export_environment_path}" ]]; then
  flutter_export_environment_existed=true
  cp "${flutter_export_environment_path}" \
    "${flutter_config_backup_dir}/flutter_export_environment.sh"
fi
flutter build ios \
  --simulator \
  --debug \
  --config-only \
  --no-codesign \
  --target="${xcui_flutter_target}"
validated_xcui_flutter_target="$(
  validate_xcui_flutter_config \
    "${generated_xcconfig_path}" \
    "${xcui_flutter_target}"
)" || {
  echo 'Flutter did not generate the required XCUITest target.' >&2
  exit 1
}
readonly validated_xcui_flutter_target
{
  cat "${metadata_path}"
  xcodebuild test \
    -workspace ios/Runner.xcworkspace \
    -scheme Runner \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=${simulator_udid}" \
    -resultBundlePath "${result_bundle}" \
    -parallel-testing-enabled NO \
    -only-testing:RunnerTests \
    -only-testing:RunnerUITests \
    FLUTTER_TARGET="${validated_xcui_flutter_target}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO
} 2>&1 | tee "${log_path}"

grep -Fq '** TEST SUCCEEDED **' "${log_path}" || {
  echo 'xcodebuild did not report a successful test action.' >&2
  exit 1
}

xcrun xcresulttool get test-results summary \
  --path "${result_bundle}" --compact > "${xcresult_summary_path}"
total_test_count="$(
  parse_xcresult_summary "${xcresult_summary_path}" 3
)"
readonly total_test_count

readonly first_ui_test='testTaskReminderDeleteAndRestoreContract'
readonly second_ui_test='testBackupRestoreRebuildsReminderContract'
if ! validate_xcui_test_log \
  "${log_path}" "${first_ui_test}" "${second_ui_test}"; then
  observed_ui_tests="$(
    extract_passing_xcui_test_names "${log_path}" | LC_ALL=C sort | paste -sd, -
  )"
  echo "Expected each required RunnerUITest exactly once; observed: ${observed_ui_tests:-none}." >&2
  exit 1
fi

{
  printf 'status=passed\n'
  printf 'suite=%s\n' "${suite_name}"
  printf 'runtime_version=%s\n' "${runtime_version}"
  printf 'runtime_identifier=%s\n' "${runtime_identifier}"
  printf 'runtime_build=%s\n' "${runtime_build}"
  printf 'runner_image=%s\n' "${ImageOS:-unknown}"
  printf 'runner_image_version=%s\n' "${ImageVersion:-unknown}"
  printf 'runner_arch=%s\n' "${RUNNER_ARCH:-unknown}"
  printf 'host_arch=%s\n' "$(uname -m)"
  printf 'xcode=%s\n' "$(xcodebuild -version | tr '\n' ';' | sed 's/;$//')"
  printf 'test_targets=RunnerTests,RunnerUITests\n'
  printf 'total_test_count=%s\n' "${total_test_count}"
  printf 'ui_test_count=2\n'
  printf 'ui_test=RunnerUITests/RunnerUITests/%s\n' "${first_ui_test}"
  printf 'ui_test=RunnerUITests/RunnerUITests/%s\n' "${second_ui_test}"
  printf 'notification_gateway=in-process-contract-double\n'
  printf 'system_delivery=device-unverified\n'
} | tee "${summary_path}"
