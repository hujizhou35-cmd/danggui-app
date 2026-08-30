#!/usr/bin/env bash
set -euo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly installer="${script_dir}/install_adb_no_streaming_wrapper.sh"
readonly wrapper="${script_dir}/adb_no_streaming_wrapper.sh"
readonly fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "${fixture_dir}"' EXIT

make_sdk() {
  local sdk_root="$1"
  local marker="$2"
  mkdir -p "${sdk_root}/platform-tools"
  cat > "${sdk_root}/platform-tools/adb" <<FAKE_ADB
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == version ]]; then
  printf '%s\n' 'Android Debug Bridge version 1.0.41 ${marker}'
  exit 0
fi
printf '%s\n' "\$@" > "\${DANGGUI_INSTALLER_CAPTURE:?}"
FAKE_ADB
  chmod +x "${sdk_root}/platform-tools/adb"
  printf '%s\n' 'Pkg.Revision = 36.0.0' \
    > "${sdk_root}/platform-tools/source.properties"
}

readonly sdk24="${fixture_dir}/sdk24"
readonly sdk36="${fixture_dir}/sdk36"
readonly evidence_root="${fixture_dir}/evidence"
readonly capture="${fixture_dir}/capture.txt"
make_sdk "${sdk24}" original
make_sdk "${sdk36}" control

ANDROID_SDK_ROOT="${sdk24}" RUNNER_TEMP="${evidence_root}" \
  DANGGUI_EMULATOR_ATTEMPT=1 \
  DANGGUI_INSTALLER_CAPTURE="${capture}" bash "${installer}" 24
cmp -s "${sdk24}/platform-tools/adb" "${wrapper}"
[[ -x "${sdk24}/platform-tools/adb.danggui-real" ]]
"${sdk24}/platform-tools/adb" version | grep -Fq 'original'
jq -e '
  .apiLevel == 24 and .wrapperInstalled == true and
  .effectiveMode == "script-scoped-no-streaming" and
  .attempt == 1 and
  .canonicalAdbSha256 == .sourceWrapperSha256 and
  .installedWrapperSha256 == .sourceWrapperSha256 and
  .realAdbSha256 != .sourceWrapperSha256
' "${evidence_root}/danggui-emulator-api-24/adb-install-mode.json" >/dev/null

# A second invocation is idempotent when platform-tools did not change.
first_real_sha="$(sha256sum "${sdk24}/platform-tools/adb.danggui-real" | awk '{print $1}')"
ANDROID_SDK_ROOT="${sdk24}" RUNNER_TEMP="${evidence_root}" \
  DANGGUI_EMULATOR_ATTEMPT=1 \
  DANGGUI_INSTALLER_CAPTURE="${capture}" bash "${installer}" 24
[[ "$(sha256sum "${sdk24}/platform-tools/adb.danggui-real" | awk '{print $1}')" == \
   "${first_real_sha}" ]]

# Model sdkmanager replacing the wrapper with the same native client.
install -m 0755 \
  "${sdk24}/platform-tools/adb.danggui-real" \
  "${sdk24}/platform-tools/adb"
ANDROID_SDK_ROOT="${sdk24}" RUNNER_TEMP="${evidence_root}" \
  DANGGUI_EMULATOR_ATTEMPT=2 \
  DANGGUI_INSTALLER_CAPTURE="${capture}" bash "${installer}" 24
cmp -s "${sdk24}/platform-tools/adb" "${wrapper}"
[[ "$(sha256sum "${sdk24}/platform-tools/adb.danggui-real" | awk '{print $1}')" == \
   "${first_real_sha}" ]]

# Model sdkmanager replacing the wrapper with a refreshed native client.
make_sdk "${sdk24}" refreshed
ANDROID_SDK_ROOT="${sdk24}" RUNNER_TEMP="${evidence_root}" \
  DANGGUI_EMULATOR_ATTEMPT=2 \
  DANGGUI_INSTALLER_CAPTURE="${capture}" bash "${installer}" 24
cmp -s "${sdk24}/platform-tools/adb" "${wrapper}"
"${sdk24}/platform-tools/adb" version | grep -Fq 'refreshed'

ANDROID_SDK_ROOT="${sdk36}" RUNNER_TEMP="${evidence_root}" \
  DANGGUI_EMULATOR_ATTEMPT=1 \
  DANGGUI_INSTALLER_CAPTURE="${capture}" bash "${installer}" 36
[[ ! -e "${sdk36}/platform-tools/adb.danggui-real" ]]
"${sdk36}/platform-tools/adb" version | grep -Fq 'control'
jq -e '
  .apiLevel == 36 and .wrapperInstalled == false and
  .attempt == 1 and .effectiveMode == "native-default-pass-through" and
  .canonicalAdbSha256 == .realAdbSha256 and
  .installedWrapperSha256 == null and
  .canonicalAdbSha256 != .sourceWrapperSha256
' "${evidence_root}/danggui-emulator-api-36/adb-install-mode.json" >/dev/null

# PATH invocation must still locate the sibling without an environment override.
PATH="${sdk24}/platform-tools:${PATH}" \
  DANGGUI_INSTALLER_CAPTURE="${capture}" adb shell echo safe
grep -Fxq 'shell' "${capture}"
grep -Fxq 'echo' "${capture}"
grep -Fxq 'safe' "${capture}"

# Inconsistent wrapper states and invalid invocation metadata fail closed.
readonly broken_sdk="${fixture_dir}/broken-sdk"
make_sdk "${broken_sdk}" broken
install -m 0755 "${wrapper}" "${broken_sdk}/platform-tools/adb"
readonly recursive_sdk="${fixture_dir}/recursive-sdk"
make_sdk "${recursive_sdk}" recursive
install -m 0755 "${wrapper}" "${recursive_sdk}/platform-tools/adb"
install -m 0755 \
  "${wrapper}" \
  "${recursive_sdk}/platform-tools/adb.danggui-real"
set +e
ANDROID_SDK_ROOT="${broken_sdk}" RUNNER_TEMP="${evidence_root}" \
  DANGGUI_EMULATOR_ATTEMPT=1 \
  DANGGUI_INSTALLER_CAPTURE="${capture}" bash "${installer}" 24 >/dev/null 2>&1
missing_sibling_status=$?
ANDROID_SDK_ROOT="${recursive_sdk}" RUNNER_TEMP="${evidence_root}" \
  DANGGUI_EMULATOR_ATTEMPT=1 \
  DANGGUI_INSTALLER_CAPTURE="${capture}" bash "${installer}" 24 >/dev/null 2>&1
recursive_sibling_status=$?
ANDROID_SDK_ROOT="${sdk36}" RUNNER_TEMP="${evidence_root}" \
  DANGGUI_EMULATOR_ATTEMPT=3 \
  DANGGUI_INSTALLER_CAPTURE="${capture}" bash "${installer}" 36 >/dev/null 2>&1
invalid_attempt_status=$?
ANDROID_SDK_ROOT="${sdk36}" RUNNER_TEMP="${evidence_root}" \
  DANGGUI_EMULATOR_ATTEMPT=1 \
  DANGGUI_INSTALLER_CAPTURE="${capture}" bash "${installer}" 35 >/dev/null 2>&1
invalid_api_status=$?
set -e
[[ "${missing_sibling_status}" != 0 ]]
[[ "${recursive_sibling_status}" != 0 ]]
[[ "${invalid_attempt_status}" == 64 ]]
[[ "${invalid_api_status}" == 64 ]]
if find "${evidence_root}" -name 'adb-install-mode.json.next.*' -print -quit |
   grep -q .; then
  echo 'ADB attestation left a non-atomic temporary file.' >&2
  exit 1
fi

echo 'ADB wrapper installer self-test passed.'
