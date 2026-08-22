#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Unsigned iOS builds require macOS and Xcode." >&2
  exit 69
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

flutter build ios --release --no-codesign

app_path="build/ios/iphoneos/Runner.app"
if [[ ! -d "${app_path}" ]]; then
  echo "Expected unsigned app was not generated: ${app_path}" >&2
  exit 1
fi

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${app_path}/Info.plist")"
if [[ "${bundle_id}" != "com.danggui.memo" ]]; then
  echo "Unexpected iOS bundle identifier: ${bundle_id}" >&2
  exit 1
fi

version_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${app_path}/Info.plist")"
version_code="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${app_path}/Info.plist")"
minimum_os="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "${app_path}/Info.plist")"
if [[ "${version_name}" != "1.0.0" || "${version_code}" != "1" ]]; then
  echo "Unexpected iOS version: ${version_name}+${version_code}" >&2
  exit 1
fi
if [[ "${minimum_os}" != "15.0" ]]; then
  echo "Unexpected iOS deployment target: ${minimum_os}" >&2
  exit 1
fi

iphone_orientation="$(/usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations:0' "${app_path}/Info.plist")"
ipad_orientation="$(/usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations~ipad:0' "${app_path}/Info.plist")"
if [[ "${iphone_orientation}" != "UIInterfaceOrientationPortrait" || \
      "${ipad_orientation}" != "UIInterfaceOrientationPortrait" ]]; then
  echo "The final iOS app must remain portrait-only." >&2
  exit 1
fi
if /usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations:1' \
  "${app_path}/Info.plist" >/dev/null 2>&1 || \
   /usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations~ipad:1' \
  "${app_path}/Info.plist" >/dev/null 2>&1; then
  echo "The final iOS app contains an unapproved additional orientation." >&2
  exit 1
fi

if /usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity:NSAllowsArbitraryLoads' \
  "${app_path}/Info.plist" 2>/dev/null | grep -Eiq '^(true|yes)$'; then
  echo "NSAllowsArbitraryLoads must not be enabled." >&2
  exit 1
fi
if /usr/libexec/PlistBuddy -c 'Print :UIBackgroundModes' \
  "${app_path}/Info.plist" >/dev/null 2>&1; then
  echo "UIBackgroundModes must remain absent (including remote-notification)." >&2
  exit 1
fi
if find "${app_path}" -type f \( -name '*.entitlements' -o -name '*.plist' \) -print0 | \
  xargs -0 grep -Il 'aps-environment' | grep -q .; then
  echo "The final iOS app contains a remote-notification entitlement." >&2
  exit 1
fi

mkdir -p dist/ios
ditto -c -k --sequesterRsrc --keepParent "${app_path}" dist/ios/danggui-ios-unsigned.app.zip
xcodebuild -version > dist/ios/XCODE.txt
flutter --version > dist/ios/TOOLCHAIN.txt
shasum -a 256 dist/ios/danggui-ios-unsigned.app.zip > dist/ios/SHA256SUMS
printf '%s\n' \
  "This archive is unsigned build evidence, not an installable IPA." \
  > dist/ios/UNSIGNED.txt
printf '%s\n' \
  "bundle_id=${bundle_id}" \
  "version=${version_name}+${version_code}" \
  "minimum_os=${minimum_os}" \
  "orientation=portrait" \
  "background_modes=absent" \
  "remote_notification_entitlement=absent" \
  > dist/ios/PLATFORM_AUDIT.txt
