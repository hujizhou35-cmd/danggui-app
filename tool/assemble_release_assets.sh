#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

fail() {
  echo "release asset assembly: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -s "${path}" ]] || fail "required non-empty file is missing: ${path}"
}

copy_required() {
  local source="$1"
  local destination="$2"
  require_file "${source}"
  cp -- "${source}" "${destination}"
}

assemble_release_assets() (
  local tag="$1"
  local android_dir="$2"
  local ios_dir="$3"
  local output_dir="$4"

  [[ "${tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] ||
    fail "tag must be a semantic version beginning with v: ${tag}"
  [[ -d "${android_dir}" ]] || fail "Android artifact directory is missing: ${android_dir}"
  [[ -d "${ios_dir}" ]] || fail "iOS artifact directory is missing: ${ios_dir}"
  android_dir="$(cd -- "${android_dir}" && pwd)"
  ios_dir="$(cd -- "${ios_dir}" && pwd)"

  mkdir -p -- "${output_dir}"
  output_dir="$(cd -- "${output_dir}" && pwd)"
  if [[ -n "$(find "${output_dir}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    fail "output directory must be empty: ${output_dir}"
  fi

  local version="${tag#v}"
  local universal_apk="danggui-android-universal-release.apk"
  local ios_source="danggui-ios-source-${tag}.zip"
  local developer_archive="danggui-developer-assets-${tag}.zip"
  local signing_mode

  require_file "${android_dir}/SIGNING_MODE.txt"
  signing_mode="$(tr -d '\r\n' < "${android_dir}/SIGNING_MODE.txt")"
  [[ "${signing_mode}" == "release" ]] ||
    fail "protected tags require SIGNING_MODE.txt=release, found: ${signing_mode}"

  local android_payloads=(
    "danggui-android-universal-release.apk"
    "danggui-android-armeabi-v7a-release.apk"
    "danggui-android-arm64-v8a-release.apk"
    "danggui-android-x86_64-release.apk"
    "danggui-android-release.aab"
  )
  local android_evidence=(
    "SIGNING_MODE.txt"
    "SIGNING_CERTIFICATE.txt"
    "SIGNING_CERTIFICATE_SHA256.txt"
    "TOOLCHAIN.txt"
    "ANDROID_NATIVE_TESTS.txt"
  )
  local ios_evidence=(
    "danggui-ios-unsigned.app.zip"
    "PLATFORM_AUDIT.txt"
    "UNSIGNED.txt"
    "XCODE.txt"
    "TOOLCHAIN.txt"
    "RUNNER_TESTS.txt"
    "IOS_ALARMKIT_SUMMARY.txt"
    "IOS_FALLBACK_TESTS.txt"
    "IOS_FALLBACK_XCODE.txt"
    "SOURCE_COMMIT.txt"
    "SOURCE_ARCHIVE_CONTENTS.txt"
  )

  local filename
  for filename in "${android_payloads[@]}" "${android_evidence[@]}"; do
    require_file "${android_dir}/${filename}"
  done
  require_file "${android_dir}/SHA256SUMS"
  (
    cd -- "${android_dir}"
    sha256sum --check --strict SHA256SUMS
  )

  require_file "${ios_dir}/${ios_source}"
  for filename in "${ios_evidence[@]}"; do
    require_file "${ios_dir}/${filename}"
  done
  local source_commit
  source_commit="$({ tr -d '\r\n' < "${ios_dir}/SOURCE_COMMIT.txt" || true; })"
  [[ "${source_commit}" =~ ^[0-9a-f]{40}$ ]] ||
    fail "SOURCE_COMMIT.txt must contain one lowercase 40-character commit"
  if [[ -n "${EXPECTED_SOURCE_COMMIT:-}" ]]; then
    [[ "${EXPECTED_SOURCE_COMMIT}" =~ ^[0-9a-f]{40}$ ]] ||
      fail "EXPECTED_SOURCE_COMMIT must be a lowercase 40-character commit"
    [[ "${source_commit}" == "${EXPECTED_SOURCE_COMMIT}" ]] ||
      fail "SOURCE_COMMIT.txt does not match the protected tag commit"
  fi
  require_file "${ios_dir}/SHA256SUMS"
  (
    cd -- "${ios_dir}"
    sha256sum --check --strict SHA256SUMS
  )
  unzip -tqq "${ios_dir}/${ios_source}"
  unzip -tqq "${ios_dir}/danggui-ios-unsigned.app.zip"

  local normalized_fingerprint
  normalized_fingerprint="$({ tr -d '[:space:]:' < "${android_dir}/SIGNING_CERTIFICATE_SHA256.txt" || true; } | tr '[:lower:]' '[:upper:]')"
  [[ "${normalized_fingerprint}" =~ ^[0-9A-F]{64}$ ]] ||
    fail "SIGNING_CERTIFICATE_SHA256.txt must contain exactly 64 hexadecimal digits"

  local workspace
  workspace="$(mktemp -d)"
  trap 'rm -rf -- "${workspace}"' EXIT
  local bundle_root="${workspace}/danggui-developer-assets-${tag}"
  mkdir -p -- "${bundle_root}/android" "${bundle_root}/ios"

  for filename in \
    "danggui-android-armeabi-v7a-release.apk" \
    "danggui-android-arm64-v8a-release.apk" \
    "danggui-android-x86_64-release.apk" \
    "danggui-android-release.aab" \
    "${android_evidence[@]}"; do
    copy_required "${android_dir}/${filename}" "${bundle_root}/android/${filename}"
  done
  for filename in "${ios_evidence[@]}"; do
    copy_required "${ios_dir}/${filename}" "${bundle_root}/ios/${filename}"
  done

  printf '%s\n' \
    "# Danggui ${tag} developer assets / 当归 ${tag} 开发者附件" \
    "" \
    "This archive contains advanced distribution and build evidence. Most Android users should download the universal APK from the Release page instead." \
    "" \
    "本归档包含高级分发文件与构建证据。普通 Android 用户应直接下载 Release 页面上的通用 APK。" \
    "" \
    "## Contents / 内容" \
    "" \
    "- \`android/\`: ABI-specific APKs, the AAB, native-test/lint output, signing mode/certificate evidence, and the pinned Flutter toolchain record." \
    "- \`ios/\`: unsigned \`Runner.app\` build evidence, fixed iOS 18.5 fallback and iOS 26.5 AlarmKit API contract output, platform/Xcode/toolchain records, and the source commit/archive manifest. Simulator evidence uses an in-process notification double and does not prove system alarm delivery. The app archive is not an IPA and cannot be installed on a normal iPhone." \
    "- \`SHA256SUMS\`: SHA-256 for every other file in this archive, including this README." \
    "" \
    "- \`android/\`：分架构 APK、AAB、原生测试/Lint 输出、签名模式/证书证据及 Flutter 工具链记录。" \
    "- \`ios/\`：无签名 \`Runner.app\` 构建证据、固定 iOS 18.5 回退路径与 iOS 26.5 AlarmKit API 合同测试输出、平台/Xcode/工具链记录，以及源码提交和归档清单。Simulator 证据使用进程内通知替身，不证明系统闹钟投递。该 app 压缩包不是 IPA，不能安装到普通 iPhone。" \
    "- \`SHA256SUMS\`：本归档内除校验清单自身外所有文件（包括本说明）的 SHA-256。" \
    "" \
    "## Verify / 校验" \
    "" \
    "Run \`sha256sum --check SHA256SUMS\` from the extracted archive root." \
    "在解压后的归档根目录运行 \`sha256sum --check SHA256SUMS\`。" \
    > "${bundle_root}/README.md"

  (
    cd -- "${bundle_root}"
    mapfile -d '' -t checksum_files < <(
      find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z
    )
    ((${#checksum_files[@]} > 0)) || fail "developer archive has no payload files"
    sha256sum "${checksum_files[@]}" > SHA256SUMS
  )

  # ZIP timestamps are normalized so identical gated inputs create the same
  # developer archive even when artifact downloads assign different mtimes.
  find "${bundle_root}" -type f -exec touch -t 198001010000.00 {} +
  local developer_archive_tmp="${output_dir}/../.${developer_archive}.tmp.zip"
  (
    cd -- "${workspace}"
    mapfile -t bundle_files < <(
      find "danggui-developer-assets-${tag}" -type f -print | LC_ALL=C sort
    )
    zip -X -q "${developer_archive_tmp}" "${bundle_files[@]}"
  )
  mv -- "${developer_archive_tmp}" "${output_dir}/${developer_archive}"

  copy_required "${android_dir}/${universal_apk}" "${output_dir}/${universal_apk}"
  copy_required "${ios_dir}/${ios_source}" "${output_dir}/${ios_source}"
  (
    cd -- "${output_dir}"
    sha256sum \
      "${universal_apk}" \
      "${ios_source}" \
      "${developer_archive}" \
      > SHA256SUMS
  )

  bash "${script_dir}/verify_release_assets.sh" "${tag}" "${output_dir}"
  printf 'Assembled exact public release contract for %s (%s).\n' "${tag}" "${version}"
)

self_test() (
  local test_root
  test_root="$(mktemp -d)"
  trap 'rm -rf -- "${test_root}"' EXIT
  mkdir -p "${test_root}/android" "${test_root}/ios" "${test_root}/zip-input"

  local filename
  for filename in \
    danggui-android-universal-release.apk \
    danggui-android-armeabi-v7a-release.apk \
    danggui-android-arm64-v8a-release.apk \
    danggui-android-x86_64-release.apk \
    danggui-android-release.aab; do
    printf 'fixture:%s\n' "${filename}" > "${test_root}/android/${filename}"
  done
  printf 'release\n' > "${test_root}/android/SIGNING_MODE.txt"
  printf 'fixture certificate report\n' > "${test_root}/android/SIGNING_CERTIFICATE.txt"
  printf '%064d\n' 0 > "${test_root}/android/SIGNING_CERTIFICATE_SHA256.txt"
  printf 'fixture Android toolchain\n' > "${test_root}/android/TOOLCHAIN.txt"
  printf 'fixture Android native tests passed\n' > "${test_root}/android/ANDROID_NATIVE_TESTS.txt"
  (
    cd "${test_root}/android"
    sha256sum ./*.apk ./*.aab > SHA256SUMS
  )

  printf 'fixture source\n' > "${test_root}/zip-input/source.txt"
  (
    cd "${test_root}/zip-input"
    zip -X -q "${test_root}/ios/danggui-ios-source-v9.8.7.zip" source.txt
    zip -X -q "${test_root}/ios/danggui-ios-unsigned.app.zip" source.txt
  )
  printf 'fixture platform audit\n' > "${test_root}/ios/PLATFORM_AUDIT.txt"
  printf 'This archive is unsigned build evidence, not an installable IPA.\n' > "${test_root}/ios/UNSIGNED.txt"
  printf 'Xcode 26.6\nBuild version fixture\n' > "${test_root}/ios/XCODE.txt"
  printf 'fixture iOS toolchain\n' > "${test_root}/ios/TOOLCHAIN.txt"
  write_ios_summary() {
    local path="$1"
    local runtime="$2"
    local xcode="$3"
    printf '%s\n' \
      'status=passed' \
      'suite=fixture' \
      "runtime_version=${runtime}" \
      "runtime_identifier=com.apple.CoreSimulator.SimRuntime.iOS-${runtime//./-}" \
      'runtime_build=fixture' \
      'runner_image=fixture-macos' \
      'runner_image_version=fixture' \
      'runner_arch=ARM64' \
      'host_arch=arm64' \
      "xcode=Xcode version ${xcode};Build version fixture" \
      'test_targets=RunnerTests,RunnerUITests' \
      'total_test_count=3' \
      'ui_test_count=2' \
      'ui_test=RunnerUITests/RunnerUITests/testTaskReminderDeleteAndRestoreContract' \
      'ui_test=RunnerUITests/RunnerUITests/testBackupRestoreRebuildsReminderContract' \
      'notification_gateway=in-process-contract-double' \
      'system_delivery=device-unverified' \
      > "${path}"
  }
  write_ios_summary "${test_root}/ios/IOS_ALARMKIT_SUMMARY.txt" 26.5 26.6
  cp \
    "${test_root}/ios/IOS_ALARMKIT_SUMMARY.txt" \
    "${test_root}/ios/RUNNER_TESTS.txt"
  write_ios_summary "${test_root}/ios/IOS_FALLBACK_TESTS.txt" 18.5 16.4
  printf 'Xcode 16.4\nBuild version fixture\n' \
    > "${test_root}/ios/IOS_FALLBACK_XCODE.txt"
  printf '%040d\n' 0 > "${test_root}/ios/SOURCE_COMMIT.txt"
  printf 'source.txt\n' > "${test_root}/ios/SOURCE_ARCHIVE_CONTENTS.txt"
  (
    cd "${test_root}/ios"
    sha256sum ./*.zip > SHA256SUMS
  )

  EXPECTED_SOURCE_COMMIT="$(printf '%040d' 0)" \
    assemble_release_assets \
      v9.8.7 "${test_root}/android" "${test_root}/ios" "${test_root}/release"
  printf 'unexpected\n' > "${test_root}/release/extra.txt"
  if bash "${script_dir}/verify_release_assets.sh" \
    v9.8.7 "${test_root}/release" >/dev/null 2>&1; then
    fail "self-test verifier accepted an extra public release asset"
  fi
  rm -f -- "${test_root}/release/extra.txt"
  mv -- \
    "${test_root}/release/danggui-android-universal-release.apk" \
    "${test_root}/missing-universal.apk"
  if bash "${script_dir}/verify_release_assets.sh" \
    v9.8.7 "${test_root}/release" >/dev/null 2>&1; then
    fail "self-test verifier accepted a missing public release asset"
  fi
  mv -- \
    "${test_root}/missing-universal.apk" \
    "${test_root}/release/danggui-android-universal-release.apk"
  bash "${script_dir}/verify_release_assets.sh" \
    v9.8.7 "${test_root}/release" >/dev/null
  if EXPECTED_SOURCE_COMMIT="$(printf '%040d' 1)" \
    bash "${script_dir}/verify_release_assets.sh" \
      v9.8.7 "${test_root}/release" >/dev/null 2>&1; then
    fail "self-test verifier accepted evidence from a different commit"
  fi
  echo "release asset assembly self-test passed"
)

if [[ "${1:-}" == "--self-test" ]]; then
  self_test
  exit 0
fi

if (($# != 4)); then
  echo "Usage: $0 <vX.Y.Z tag> <android artifact dir> <ios artifact dir> <empty output dir>" >&2
  echo "       $0 --self-test" >&2
  exit 64
fi

assemble_release_assets "$@"
