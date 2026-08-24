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
  exit $?
fi

# Capture evidence while android-emulator-runner still owns a live AVD. Every
# diagnostic is best-effort so the original Flutter test status is preserved.
capture_smoke_failure_evidence

exit "${test_status}"
