#!/usr/bin/env bash
set -euo pipefail

if (( $# != 1 )) || [[ ! "$1" =~ ^(24|36)$ ]]; then
  echo "Usage: $0 <24|36>" >&2
  exit 64
fi

readonly api_level="$1"
readonly emulator_attempt="${DANGGUI_EMULATOR_ATTEMPT:-}"
if [[ ! "${emulator_attempt}" =~ ^[12]$ ]]; then
  echo 'DANGGUI_EMULATOR_ATTEMPT must be 1 or 2.' >&2
  exit 64
fi
readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly wrapper_source="${script_dir}/adb_no_streaming_wrapper.sh"
readonly sdk_root="${ANDROID_SDK_ROOT:?ANDROID_SDK_ROOT is not set}"
readonly adb_path="${sdk_root}/platform-tools/adb"
readonly real_adb="${adb_path}.danggui-real"
readonly source_properties="${sdk_root}/platform-tools/source.properties"
readonly evidence_dir="${RUNNER_TEMP:?RUNNER_TEMP is not set}/danggui-emulator-api-${api_level}"

command -v jq >/dev/null
command -v sha256sum >/dev/null
[[ -s "${wrapper_source}" ]]
[[ -x "${adb_path}" ]]
[[ -s "${source_properties}" ]]
[[ ! -L "${wrapper_source}" ]]
[[ ! -L "${adb_path}" ]]
mkdir -p "${evidence_dir}"

wrapper_source_sha="$(sha256sum "${wrapper_source}" | awk '{print $1}')"
canonical_sha="$(sha256sum "${adb_path}" | awk '{print $1}')"
effective_mode='native-default-pass-through'
wrapper_installed=false
real_adb_sha=''

if (( api_level == 24 )); then
  effective_mode='script-scoped-no-streaming'
  wrapper_installed=true
  if [[ "${canonical_sha}" != "${wrapper_source_sha}" ]]; then
    "${adb_path}" version >/dev/null
    if [[ -e "${real_adb}" ]]; then
      [[ -x "${real_adb}" ]]
      [[ ! -L "${real_adb}" ]]
      [[ "$(sha256sum "${real_adb}" | awk '{print $1}')" != "${wrapper_source_sha}" ]]
      "${real_adb}" version >/dev/null
    fi
    # android-emulator-runner installs platform-tools before invoking this
    # script. Copy that exact post-install client to an atomic sidecar, then
    # atomically replace the canonical entry point with the audited wrapper.
    # Re-running this step after a platform-tools refresh safely replaces the
    # prior sidecar with the newly installed native client.
    readonly real_adb_next="${real_adb}.next.$$"
    readonly wrapper_next="${adb_path}.wrapper.next.$$"
    cleanup() {
      rm -f -- "${real_adb_next}" "${wrapper_next}"
    }
    trap cleanup EXIT
    install -m 0755 "${adb_path}" "${real_adb_next}"
    "${real_adb_next}" version >/dev/null
    mv -f -- "${real_adb_next}" "${real_adb}"
    install -m 0755 "${wrapper_source}" "${wrapper_next}"
    mv -f -- "${wrapper_next}" "${adb_path}"
    trap - EXIT
  fi
  [[ -x "${real_adb}" ]]
  [[ ! -L "${real_adb}" ]]
  [[ "$(sha256sum "${adb_path}" | awk '{print $1}')" == "${wrapper_source_sha}" ]]
  real_adb_sha="$(sha256sum "${real_adb}" | awk '{print $1}')"
  [[ "${real_adb_sha}" != "${wrapper_source_sha}" ]]
  "${real_adb}" version > "${evidence_dir}/adb-version.txt"
  env -u DANGGUI_REAL_ADB -u DANGGUI_ADB_FORCE_NO_STREAMING \
    -u DANGGUI_ADB_MODE_EVIDENCE \
    "${adb_path}" version > "${evidence_dir}/adb-wrapper-version.txt"
  cmp -s \
    "${evidence_dir}/adb-version.txt" \
    "${evidence_dir}/adb-wrapper-version.txt"
else
  # API 36 is the control lane: no wrapper or transport override is allowed.
  [[ "${canonical_sha}" != "${wrapper_source_sha}" ]]
  [[ ! -e "${real_adb}" ]]
  real_adb_sha="${canonical_sha}"
  "${adb_path}" version > "${evidence_dir}/adb-version.txt"
fi

canonical_sha="$(sha256sum "${adb_path}" | awk '{print $1}')"
platform_tools_revision="$(
  awk -F= '/^Pkg.Revision[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' \
    "${source_properties}"
)"
[[ -n "${platform_tools_revision}" ]]

installed_wrapper_sha=''
if (( api_level == 24 )); then
  installed_wrapper_sha="${canonical_sha}"
fi
readonly attestation="${evidence_dir}/adb-install-mode.json"
readonly attestation_next="${attestation}.next.$$"
cleanup_attestation() {
  rm -f -- "${attestation_next}"
}
trap cleanup_attestation EXIT

jq -n \
  --argjson apiLevel "${api_level}" \
  --argjson attempt "${emulator_attempt}" \
  --arg deploymentPhase 'post-sdk-install-pre-emulator-launch' \
  --arg configuredMode 'api-24-script-scoped-no-streaming' \
  --arg effectiveMode "${effective_mode}" \
  --argjson wrapperInstalled "${wrapper_installed}" \
  --arg platformToolsRevision "${platform_tools_revision}" \
  --arg canonicalAdbSha256 "${canonical_sha}" \
  --arg realAdbSha256 "${real_adb_sha}" \
  --arg sourceWrapperSha256 "${wrapper_source_sha}" \
  --arg installedWrapperSha256 "${installed_wrapper_sha}" \
  '{
    apiLevel: $apiLevel,
    attempt: $attempt,
    deploymentPhase: $deploymentPhase,
    configuredMode: $configuredMode,
    effectiveMode: $effectiveMode,
    wrapperInstalled: $wrapperInstalled,
    platformToolsRevision: $platformToolsRevision,
    canonicalAdbSha256: $canonicalAdbSha256,
    realAdbSha256: $realAdbSha256,
    sourceWrapperSha256: $sourceWrapperSha256,
    installedWrapperSha256:
      (if $installedWrapperSha256 == "" then null else $installedWrapperSha256 end),
    defaultBehavior: "pass-through",
    explicitStreamingAndIncrementalRejectedWhenActive: ($apiLevel == 24)
  }' > "${attestation_next}"

jq -e \
  --argjson expectedApiLevel "${api_level}" \
  --argjson expectedAttempt "${emulator_attempt}" '
  .apiLevel == $expectedApiLevel and
  .attempt == $expectedAttempt and
  .deploymentPhase == "post-sdk-install-pre-emulator-launch" and
  .configuredMode == "api-24-script-scoped-no-streaming" and
  .defaultBehavior == "pass-through" and
  .platformToolsRevision != "" and
  (.canonicalAdbSha256 | test("^[0-9a-f]{64}$")) and
  (.realAdbSha256 | test("^[0-9a-f]{64}$")) and
  (.sourceWrapperSha256 | test("^[0-9a-f]{64}$")) and
  (if $expectedApiLevel == 24 then
     .effectiveMode == "script-scoped-no-streaming" and
     .wrapperInstalled == true and
     .explicitStreamingAndIncrementalRejectedWhenActive == true and
     (.installedWrapperSha256 | test("^[0-9a-f]{64}$")) and
     .installedWrapperSha256 == .sourceWrapperSha256 and
     .canonicalAdbSha256 == .sourceWrapperSha256 and
     .realAdbSha256 != .sourceWrapperSha256
   else
     .effectiveMode == "native-default-pass-through" and
     .wrapperInstalled == false and
     .explicitStreamingAndIncrementalRejectedWhenActive == false and
     .installedWrapperSha256 == null and
     .canonicalAdbSha256 == .realAdbSha256 and
     .canonicalAdbSha256 != .sourceWrapperSha256
   end)
' "${attestation_next}" >/dev/null
mv -f -- "${attestation_next}" "${attestation}"
trap - EXIT

echo "ADB transport setup attested for API ${api_level}: ${effective_mode}."
