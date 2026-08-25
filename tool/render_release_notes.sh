#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "release notes rendering: $*" >&2
  exit 1
}

render_notes() {
  local tag="$1"
  local template="$2"
  local fingerprint_file="$3"
  local output="$4"

  [[ "${tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] ||
    fail "invalid semantic version tag: ${tag}"
  [[ "$(basename -- "${template}")" == "${tag}.md" ]] ||
    fail "version-specific notes must be named ${tag}.md"
  [[ -s "${template}" ]] || fail "release note template is missing: ${template}"
  [[ -s "${fingerprint_file}" ]] || fail "signing fingerprint is missing: ${fingerprint_file}"

  local heading
  for heading in \
    '## 亮点 / Highlights' \
    '## 下载 / Downloads' \
    '## 校验 / Verify' \
    '## 已知限制 / Known limits' \
    '## 完整变更 / Full comparison'; do
    grep -Fqx "${heading}" "${template}" || fail "required bilingual section is missing: ${heading}"
  done
  grep -Fq 'https://github.com/hujizhou35-cmd/danggui-app/compare/' "${template}" ||
    fail "release notes must link to a full GitHub comparison"

  local token='{{ANDROID_SIGNING_CERT_SHA256}}'
  local token_count
  token_count="$({ grep -oF "${token}" "${template}" || true; } | wc -l | tr -d '[:space:]')"
  [[ "${token_count}" == "1" ]] ||
    fail "release notes must contain the signing fingerprint token exactly once"

  local normalized_fingerprint pretty_fingerprint
  normalized_fingerprint="$({ tr -d '[:space:]:' < "${fingerprint_file}" || true; } | tr '[:lower:]' '[:upper:]')"
  [[ "${normalized_fingerprint}" =~ ^[0-9A-F]{64}$ ]] ||
    fail "signing fingerprint must contain exactly 64 hexadecimal digits"
  pretty_fingerprint="$(printf '%s' "${normalized_fingerprint}" | fold -w2 | paste -sd: -)"

  mkdir -p -- "$(dirname -- "${output}")"
  sed "s/${token}/${pretty_fingerprint}/" "${template}" > "${output}"
  [[ -s "${output}" ]] || fail "rendered release notes are empty"
  if grep -Fq '{{' "${output}"; then
    fail "rendered release notes contain an unresolved template token"
  fi
}

self_test() (
  local test_root
  test_root="$(mktemp -d)"
  trap 'rm -rf -- "${test_root}"' EXIT
  printf '%s\n' \
    '# Fixture' \
    '## 亮点 / Highlights' \
    '## 下载 / Downloads' \
    '## 校验 / Verify' \
    '{{ANDROID_SIGNING_CERT_SHA256}}' \
    '## 已知限制 / Known limits' \
    '## 完整变更 / Full comparison' \
    'https://github.com/hujizhou35-cmd/danggui-app/compare/v9.8.6...v9.8.7' \
    > "${test_root}/v9.8.7.md"
  printf '%064d\n' 0 > "${test_root}/fingerprint.txt"
  render_notes \
    v9.8.7 "${test_root}/v9.8.7.md" "${test_root}/fingerprint.txt" "${test_root}/notes.md"
  grep -Fq '00:00:00:00:00:00:00:00' "${test_root}/notes.md" ||
    fail "self-test did not render the canonical colon-delimited fingerprint"
  if grep -Fq '{{' "${test_root}/notes.md"; then
    fail "self-test left an unresolved token"
  fi
  echo "release notes rendering self-test passed"
)

if [[ "${1:-}" == "--self-test" ]]; then
  self_test
  exit 0
fi

if (($# != 4)); then
  echo "Usage: $0 <vX.Y.Z tag> <version-specific notes.md> <fingerprint file> <output.md>" >&2
  echo "       $0 --self-test" >&2
  exit 64
fi

render_notes "$@"
