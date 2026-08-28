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

  echo 'xcresult summary and XCUITest log parser self-test passed'
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
readonly summary_path="${canonical_evidence_dir}/${suite_name}.summary.txt"
readonly metadata_path="${canonical_evidence_dir}/${suite_name}.environment.txt"
readonly xcresult_summary_path="${canonical_evidence_dir}/${suite_name}.xcresult-summary.json"
for managed_path in \
  "${result_bundle}" "${log_path}" "${summary_path}" "${metadata_path}" \
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
  "${log_path}" "${summary_path}" "${metadata_path}" \
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
device_type_identifier="$(
  xcrun simctl list devicetypes -j |
    jq -r --arg prefix "${device_prefix}" '
      .devicetypes
      | map(select(.name | startswith($prefix)))
      | .[0].identifier // empty
    '
)"
if [[ -z "${device_type_identifier}" ]]; then
  echo "No ${device_prefix} Simulator device type is installed." >&2
  exit 1
fi

simulator_udid=""
cleanup_simulator() {
  if [[ -n "${simulator_udid}" ]]; then
    xcrun simctl shutdown "${simulator_udid}" >/dev/null 2>&1 || true
    xcrun simctl delete "${simulator_udid}" >/dev/null 2>&1 || true
  fi
}
trap cleanup_simulator EXIT INT TERM

readonly simulator_name="Danggui-${suite_name}-$$-${RANDOM}"
simulator_udid="$(
  xcrun simctl create \
    "${simulator_name}" "${device_type_identifier}" "${runtime_identifier}"
)"
[[ "${simulator_udid}" =~ ^[0-9A-Fa-f-]{36}$ ]] || {
  echo "simctl returned an invalid Simulator identifier." >&2
  exit 1
}
xcrun simctl boot "${simulator_udid}"
xcrun simctl bootstatus "${simulator_udid}" -b

{
  printf 'suite=%s\n' "${suite_name}"
  printf 'runtime_identifier=%s\n' "${runtime_identifier}"
  printf 'runtime_build=%s\n' "${runtime_build}"
  printf 'simulator_name=%s\n' "${simulator_name}"
  printf 'simulator_udid=%s\n' "${simulator_udid}"
  printf 'device_type_identifier=%s\n' "${device_type_identifier}"
  printf 'runner_image=%s\n' "${ImageOS:-unknown}"
  printf 'runner_image_version=%s\n' "${ImageVersion:-unknown}"
  printf 'runner_arch=%s\n' "${RUNNER_ARCH:-unknown}"
  printf 'host_arch=%s\n' "$(uname -m)"
  xcodebuild -version
  flutter --version
} > "${metadata_path}"

# This compile-time opt-in keeps the destructive contract harness unreachable
# in an ordinary Debug launch. The test itself runs in a disposable Simulator.
xcui_dart_define="$(
  printf '%s' 'DANGGUI_XCUITEST_BUILD=true' | base64 | tr -d '\r\n'
)"
readonly xcui_dart_define
{
  cat "${metadata_path}"
  xcodebuild test \
    -workspace ios/Runner.xcworkspace \
    -scheme Runner \
    -destination "platform=iOS Simulator,id=${simulator_udid}" \
    -resultBundlePath "${result_bundle}" \
    -parallel-testing-enabled NO \
    -only-testing:RunnerTests \
    -only-testing:RunnerUITests \
    DART_DEFINES="${xcui_dart_define}" \
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
