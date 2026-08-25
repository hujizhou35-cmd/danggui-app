#!/usr/bin/env bash

set -euo pipefail

: "${DANGGUI_README_SCREENSHOT_OUTPUT:?screenshot output directory is required}"
: "${README_SCREENSHOT_LOCALE:?screenshot locale is required}"
: "${ANDROID_SERIAL:?Android device id is required}"

mkdir -p "${DANGGUI_README_SCREENSHOT_OUTPUT}"
adb shell wm size 1080x2400
adb shell wm density 420
adb shell settings put system font_scale 1.0
adb shell settings put system time_12_24 24

timeout --signal=INT --kill-after=30s 20m flutter drive \
  --driver=integration_test/support/readme_screenshot_driver.dart \
  --target=integration_test/readme_screenshots_test.dart \
  --device-id="${ANDROID_SERIAL}" \
  --dart-define="README_SCREENSHOT_LOCALE=${README_SCREENSHOT_LOCALE}"

dart run tool/readme_screenshots/verify_outputs.dart \
  --locale "${README_SCREENSHOT_LOCALE}" \
  --directory "${DANGGUI_README_SCREENSHOT_OUTPUT}"
