#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "release asset verification: $*" >&2
  exit 1
}

require_exact_line_once() {
  local path="$1"
  local expected="$2"
  local count
  count="$({ grep -Fxc -- "${expected}" "${path}" || true; })"
  [[ "${count}" == '1' ]] ||
    fail "$(basename -- "${path}") must contain exactly once: ${expected}"
}

verify_ios_contract_summary() {
  local path="$1"
  local expected_runtime="$2"
  [[ -f "${path}" && ! -L "${path}" ]] ||
    fail "missing regular iOS contract summary: ${path}"

  require_exact_line_once "${path}" 'status=passed'
  require_exact_line_once "${path}" "runtime_version=${expected_runtime}"
  require_exact_line_once "${path}" 'test_targets=RunnerTests,RunnerUITests'
  require_exact_line_once "${path}" 'ui_test_count=2'
  require_exact_line_once "${path}" \
    'ui_test=RunnerUITests/RunnerUITests/testTaskReminderDeleteAndRestoreContract'
  require_exact_line_once "${path}" \
    'ui_test=RunnerUITests/RunnerUITests/testBackupRestoreRebuildsReminderContract'
  require_exact_line_once "${path}" \
    'notification_gateway=in-process-contract-double'
  require_exact_line_once "${path}" 'system_delivery=device-unverified'

  local ui_test_lines
  ui_test_lines="$({ grep -c '^ui_test=' "${path}" || true; })"
  [[ "${ui_test_lines}" == '2' ]] ||
    fail "$(basename -- "${path}") must attest exactly two UI tests"

  local total_test_count
  total_test_count="$({ sed -n 's/^total_test_count=//p' "${path}" || true; })"
  [[ "${total_test_count}" =~ ^[0-9]+$ ]] && ((total_test_count >= 3)) ||
    fail "$(basename -- "${path}") has no positive RunnerTests test count"

  local marker
  for marker in \
    '^runtime_identifier=.+$' \
    '^runtime_build=.+$' \
    '^runner_image=.+$' \
    '^runner_image_version=.+$' \
    '^runner_arch=.+$' \
    '^host_arch=.+$' \
    '^xcode=Xcode .+;Build version .+$'; do
    grep -Eq "${marker}" "${path}" ||
      fail "$(basename -- "${path}") lacks environment evidence: ${marker}"
  done
}

if (($# != 2)); then
  echo "Usage: $0 <vX.Y.Z tag> <release asset directory>" >&2
  exit 64
fi

tag="$1"
release_dir="$2"
[[ "${tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] ||
  fail "invalid semantic version tag: ${tag}"
[[ -d "${release_dir}" ]] || fail "directory is missing: ${release_dir}"

public_payloads=(
  "danggui-android-universal-release.apk"
  "danggui-ios-source-${tag}.zip"
  "danggui-developer-assets-${tag}.zip"
)
expected_public=("${public_payloads[@]}" "SHA256SUMS")
mapfile -t expected_public_sorted < <(printf '%s\n' "${expected_public[@]}" | LC_ALL=C sort)
mapfile -t actual_public < <(
  find "${release_dir}" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort
)
if ! diff -u \
  <(printf '%s\n' "${expected_public_sorted[@]}") \
  <(printf '%s\n' "${actual_public[@]}"); then
  fail "public assets differ from the exact allowlist"
fi

for filename in "${expected_public[@]}"; do
  [[ -s "${release_dir}/${filename}" ]] || fail "empty public asset: ${filename}"
done

mapfile -t checksum_targets < <(
  awk '{print $2}' "${release_dir}/SHA256SUMS" | sed 's/^\*//' | LC_ALL=C sort
)
mapfile -t expected_payloads_sorted < <(
  printf '%s\n' "${public_payloads[@]}" | LC_ALL=C sort
)
if ! diff -u \
  <(printf '%s\n' "${expected_payloads_sorted[@]}") \
  <(printf '%s\n' "${checksum_targets[@]}"); then
  fail "public SHA256SUMS does not cover exactly the public payloads"
fi
(
  cd -- "${release_dir}"
  sha256sum --check --strict SHA256SUMS
)

developer_archive="${release_dir}/danggui-developer-assets-${tag}.zip"
archive_root="danggui-developer-assets-${tag}"
expected_developer=(
  "${archive_root}/README.md"
  "${archive_root}/SHA256SUMS"
  "${archive_root}/android/ANDROID_NATIVE_TESTS.txt"
  "${archive_root}/android/SIGNING_CERTIFICATE.txt"
  "${archive_root}/android/SIGNING_CERTIFICATE_SHA256.txt"
  "${archive_root}/android/SIGNING_MODE.txt"
  "${archive_root}/android/TOOLCHAIN.txt"
  "${archive_root}/android/danggui-android-arm64-v8a-release.apk"
  "${archive_root}/android/danggui-android-armeabi-v7a-release.apk"
  "${archive_root}/android/danggui-android-release.aab"
  "${archive_root}/android/danggui-android-x86_64-release.apk"
  "${archive_root}/ios/PLATFORM_AUDIT.txt"
  "${archive_root}/ios/IOS_ALARMKIT_SUMMARY.txt"
  "${archive_root}/ios/IOS_FALLBACK_TESTS.txt"
  "${archive_root}/ios/IOS_FALLBACK_XCODE.txt"
  "${archive_root}/ios/RUNNER_TESTS.txt"
  "${archive_root}/ios/SOURCE_ARCHIVE_CONTENTS.txt"
  "${archive_root}/ios/SOURCE_COMMIT.txt"
  "${archive_root}/ios/TOOLCHAIN.txt"
  "${archive_root}/ios/UNSIGNED.txt"
  "${archive_root}/ios/XCODE.txt"
  "${archive_root}/ios/danggui-ios-unsigned.app.zip"
)
mapfile -t expected_developer_sorted < <(
  printf '%s\n' "${expected_developer[@]}" | LC_ALL=C sort
)
mapfile -t actual_developer < <(
  unzip -Z1 "${developer_archive}" | sed '/\/$/d' | LC_ALL=C sort
)
if ! diff -u \
  <(printf '%s\n' "${expected_developer_sorted[@]}") \
  <(printf '%s\n' "${actual_developer[@]}"); then
  fail "developer archive differs from the exact internal allowlist"
fi
unzip -tqq "${developer_archive}"

workspace="$(mktemp -d)"
trap 'rm -rf -- "${workspace}"' EXIT
unzip -q "${developer_archive}" -d "${workspace}"
bundle_root="${workspace}/${archive_root}"
if [[ -n "$(find "${bundle_root}" -type l -print -quit)" ]]; then
  fail "developer archive must not contain symbolic links"
fi
[[ "$(tr -d '\r\n' < "${bundle_root}/android/SIGNING_MODE.txt")" == "release" ]] ||
  fail "developer signing evidence is not release mode"
normalized_fingerprint="$({ tr -d '[:space:]:' < "${bundle_root}/android/SIGNING_CERTIFICATE_SHA256.txt" || true; } | tr '[:lower:]' '[:upper:]')"
[[ "${normalized_fingerprint}" =~ ^[0-9A-F]{64}$ ]] ||
  fail "developer signing fingerprint is malformed"
grep -Fq 'not an installable IPA' "${bundle_root}/ios/UNSIGNED.txt" ||
  fail "unsigned iOS evidence must explicitly say it is not an installable IPA"

verify_ios_contract_summary \
  "${bundle_root}/ios/IOS_FALLBACK_TESTS.txt" 18.5
verify_ios_contract_summary \
  "${bundle_root}/ios/IOS_ALARMKIT_SUMMARY.txt" 26.5
cmp -s \
  "${bundle_root}/ios/IOS_ALARMKIT_SUMMARY.txt" \
  "${bundle_root}/ios/RUNNER_TESTS.txt" ||
  fail "RUNNER_TESTS.txt must be the compact iOS 26.5 contract summary"
grep -Fq 'Xcode 16.4' "${bundle_root}/ios/IOS_FALLBACK_XCODE.txt" ||
  fail "fallback evidence must come from Xcode 16.4"
grep -Fq 'Xcode 26.6' "${bundle_root}/ios/XCODE.txt" ||
  fail "AlarmKit API contract evidence must come from Xcode 26.6"

source_commit="$({ tr -d '\r\n' < "${bundle_root}/ios/SOURCE_COMMIT.txt" || true; })"
[[ "${source_commit}" =~ ^[0-9a-f]{40}$ ]] ||
  fail "SOURCE_COMMIT.txt must contain one lowercase 40-character commit"
if [[ -n "${EXPECTED_SOURCE_COMMIT:-}" ]]; then
  [[ "${EXPECTED_SOURCE_COMMIT}" =~ ^[0-9a-f]{40}$ ]] ||
    fail "EXPECTED_SOURCE_COMMIT must be a lowercase 40-character commit"
  [[ "${source_commit}" == "${EXPECTED_SOURCE_COMMIT}" ]] ||
    fail "SOURCE_COMMIT.txt does not match the protected tag commit"
fi

mapfile -t expected_internal_checksum_targets < <(
  cd -- "${bundle_root}"
  find . -type f ! -name SHA256SUMS -printf '%P\n' | LC_ALL=C sort
)
mapfile -t internal_checksum_targets < <(
  awk '{print $2}' "${bundle_root}/SHA256SUMS" | sed -e 's/^\*//' -e 's|^\./||' | LC_ALL=C sort
)
if ! diff -u \
  <(printf '%s\n' "${expected_internal_checksum_targets[@]}") \
  <(printf '%s\n' "${internal_checksum_targets[@]}"); then
  fail "developer SHA256SUMS does not cover every internal payload exactly once"
fi
(
  cd -- "${bundle_root}"
  sha256sum --check --strict SHA256SUMS
)

printf 'Verified exact public and developer release asset contracts for %s.\n' "${tag}"
