#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

technical_version="$(sed -n -E 's/^version:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' pubspec.yaml | head -n 1)"
if [[ "${technical_version}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([1-9][0-9]*)$ ]]; then
  version_name="${BASH_REMATCH[1]}"
else
  echo "pubspec.yaml version must use semantic-name+positive-build-number: ${technical_version}" >&2
  exit 65
fi

if ! git diff --quiet --ignore-submodules -- || \
   ! git diff --cached --quiet --ignore-submodules --; then
  echo "The deterministic source archive must be built from a clean Git tree." >&2
  exit 1
fi

output_dir="${repo_root}/dist/ios"
archive_name="danggui-ios-source-v${version_name}.zip"
archive_path="${output_dir}/${archive_name}"
prefix="danggui-ios-source-v${version_name}/"
mkdir -p "${output_dir}"

rm -f "${archive_path}"
git archive \
  --format=zip \
  --prefix="${prefix}" \
  --output="${archive_path}" \
  HEAD

unzip -tqq "${archive_path}"
archive_contents="$(unzip -Z1 "${archive_path}")"
if grep -Eq \
  '(^|/)(\.env($|\.)|\.npmrc$|\.pypirc$|\.netrc$|build(/|$)|dist(/|$)|coverage(/|$)|\.dart_tool(/|$)|\.pub-cache(/|$)|\.gradle(/|$)|Pods(/|$)|\.symlinks(/|$)|ephemeral(/|$)|DerivedData(/|$)|xcuserdata(/|$)|[^/]*\.xcarchive(/|$)|keystore\.properties$|key\.properties$|local\.properties$|google-services\.json$|GoogleService-Info\.plist$|id_(rsa|dsa|ecdsa|ed25519)$|[^/]*(secret|credential)[^/]*\.(json|properties|ya?ml)$|[^/]*\.(jks|keystore|key|p7b|p7c|p8|p12|pfx|pem|cer|crt|der|mobileprovision|provisionprofile|ipa)$)' \
  <<<"${archive_contents}"; then
  echo "The iOS source archive contains an excluded secret, certificate, profile, or build/cache path." >&2
  exit 1
fi
private_key_markers="$(
  unzip -p "${archive_path}" |
    LC_ALL=C grep -aE -- \
      '-----BEGIN ([A-Z0-9]+[[:space:]]+)*PRIVATE KEY-----' || true
)"
if [[ -n "${private_key_markers}" ]]; then
  echo "The iOS source archive contains private-key material." >&2
  exit 1
fi

# Prove the archive contains every file tracked by the tagged commit. This is
# deliberately stronger than a representative allowlist: the delivery is
# iOS-focused, but its documented `flutter test` commands require the complete
# cross-platform Flutter repository and test tree.
tracked_manifest="$(git ls-tree -r --name-only HEAD | LC_ALL=C sort)"
archive_manifest="$(
  sed -n "s#^${prefix}##p" <<<"${archive_contents}" |
    sed '/\/$/d' |
    LC_ALL=C sort
)"
if ! diff -u \
  <(printf '%s\n' "${tracked_manifest}") \
  <(printf '%s\n' "${archive_manifest}"); then
  echo "The iOS source archive does not exactly match the tracked source manifest." >&2
  exit 1
fi

required_archive_entries=(
  .github/workflows/mobile-ci.yml
  android/app/build.gradle.kts
  assets/brand/danggui-launch-artwork.png
  docs/architecture/ios-source-build.md
  integration_test/app_cold_start_test.dart
  ios/Runner.xcodeproj/project.pbxproj
  lib/main.dart
  LICENSE
  pubspec.lock
  pubspec.yaml
  test/platform/privacy_platform_config_test.dart
  THIRD_PARTY_NOTICES.md
  tool/build_ios_unsigned.sh
)
for entry in "${required_archive_entries[@]}"; do
  if ! grep -Fxq "${prefix}${entry}" <<<"${archive_contents}"; then
    echo "The iOS source archive is missing required tracked content: ${entry}" >&2
    exit 1
  fi
done

git rev-parse HEAD > "${output_dir}/SOURCE_COMMIT.txt"
printf '%s\n' "${archive_manifest}" > "${output_dir}/SOURCE_ARCHIVE_CONTENTS.txt"
(
  cd "${output_dir}"
  shasum -a 256 ./*.zip > SHA256SUMS
)

printf 'Deterministic iOS source archive created: %s\n' "${archive_path}"
