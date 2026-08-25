#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "release asset verification: $*" >&2
  exit 1
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
  "${archive_root}/android/SIGNING_CERTIFICATE.txt"
  "${archive_root}/android/SIGNING_CERTIFICATE_SHA256.txt"
  "${archive_root}/android/SIGNING_MODE.txt"
  "${archive_root}/android/TOOLCHAIN.txt"
  "${archive_root}/android/danggui-android-arm64-v8a-release.apk"
  "${archive_root}/android/danggui-android-armeabi-v7a-release.apk"
  "${archive_root}/android/danggui-android-release.aab"
  "${archive_root}/android/danggui-android-x86_64-release.apk"
  "${archive_root}/ios/PLATFORM_AUDIT.txt"
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
[[ "$(tr -d '\r\n' < "${bundle_root}/android/SIGNING_MODE.txt")" == "release" ]] ||
  fail "developer signing evidence is not release mode"
normalized_fingerprint="$({ tr -d '[:space:]:' < "${bundle_root}/android/SIGNING_CERTIFICATE_SHA256.txt" || true; } | tr '[:lower:]' '[:upper:]')"
[[ "${normalized_fingerprint}" =~ ^[0-9A-F]{64}$ ]] ||
  fail "developer signing fingerprint is malformed"
grep -Fq 'not an installable IPA' "${bundle_root}/ios/UNSIGNED.txt" ||
  fail "unsigned iOS evidence must explicitly say it is not an installable IPA"

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
