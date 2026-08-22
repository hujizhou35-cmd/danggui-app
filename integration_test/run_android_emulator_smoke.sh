#!/usr/bin/env bash
set -uo pipefail

if (( $# != 1 )) || [[ ! "$1" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <api-level>" >&2
  exit 64
fi

api_level="$1"
evidence_dir="${RUNNER_TEMP:?RUNNER_TEMP is not set}/danggui-emulator-api-${api_level}"

set +e
timeout --signal=TERM --kill-after=30s 25m \
  flutter test --no-pub integration_test/app_cold_start_test.dart \
  -d emulator-5554 --reporter expanded
test_status=$?
set -e

if (( test_status == 0 )); then
  exit 0
fi

# Capture evidence while android-emulator-runner still owns a live AVD. Every
# diagnostic is best-effort so the original Flutter test status is preserved.
mkdir -p "${evidence_dir}"
adb devices -l > "${evidence_dir}/adb-devices.txt" 2>&1 || true
adb shell pidof com.danggui.memo \
  > "${evidence_dir}/app-pid.txt" 2>&1 || true
adb shell dumpsys activity activities \
  > "${evidence_dir}/activity.txt" 2>&1 || true
adb shell dumpsys package com.danggui.memo \
  > "${evidence_dir}/package.txt" 2>&1 || true
timeout --signal=TERM --kill-after=5s 30s adb logcat -d -v threadtime \
  > "${evidence_dir}/logcat.txt" 2>&1 || true

exit "${test_status}"
