#!/usr/bin/env bash
set -uo pipefail
set +e

if (( $# != 1 )) || [[ ! "$1" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <api-level>" >&2
  exit 64
fi

api_level="$1"
evidence_dir="${RUNNER_TEMP:?RUNNER_TEMP is not set}/danggui-emulator-api-${api_level}"
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

run_flutter_test() {
  local attempt="$1"
  local attempt_log="${evidence_dir}/${attempt}.log"
  local -a command_statuses

  timeout --signal=TERM --kill-after=30s 12m \
    flutter test --no-pub integration_test/app_cold_start_test.dart \
    -d emulator-5554 --reporter expanded 2>&1 | tee "${attempt_log}"
  command_statuses=("${PIPESTATUS[@]}")
  if (( command_statuses[0] != 0 )); then
    return "${command_statuses[0]}"
  fi
  return "${command_statuses[1]}"
}

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
      adb -s emulator-5554 wait-for-device \
      >/dev/null 2>&1 || recovery_ok=0
  fi
  if (( recovery_ok == 1 )); then
    boot_completed="$(
      timeout --signal=TERM --kill-after=5s 20s \
        adb -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null
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
        adb -s emulator-5554 shell pm path android 2>/dev/null
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
        adb -s emulator-5554 shell pm list packages \
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
      adb -s emulator-5554 uninstall com.danggui.memo \
      >/dev/null 2>&1 || true
    clean_package_listing="$(
      timeout --signal=TERM --kill-after=5s 20s \
        adb -s emulator-5554 shell pm list packages \
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
  exit $?
fi

# Capture evidence while android-emulator-runner still owns a live AVD. Every
# diagnostic is best-effort so the original Flutter test status is preserved.
adb devices -l > "${evidence_dir}/adb-devices.txt" 2>&1 || true
adb shell pidof com.danggui.memo \
  > "${evidence_dir}/app-pid.txt" 2>&1 || true
adb shell dumpsys activity activities \
  > "${evidence_dir}/activity.txt" 2>&1 || true
adb shell dumpsys package com.danggui.memo \
  > "${evidence_dir}/package.txt" 2>&1 || true
timeout --signal=TERM --kill-after=5s 30s adb logcat -d -v threadtime \
  > "${evidence_dir}/logcat.txt" 2>&1 || true
adb shell dumpsys alarm > "${evidence_dir}/alarm-final.txt" 2>&1 || true
adb shell dumpsys notification --noredact \
  > "${evidence_dir}/notification-final.txt" 2>&1 || true
if [[ ! -s "${evidence_dir}/notification-shade.png" ]]; then
  timeout --signal=TERM --kill-after=5s 30s adb exec-out screencap -p \
    > "${evidence_dir}/notification-shade.png" 2>/dev/null || true
fi

exit "${test_status}"
