#!/usr/bin/env bash
set -euo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly wrapper="${script_dir}/adb_no_streaming_wrapper.sh"
readonly fixture_dir="$(mktemp -d)"
readonly fake_adb="${fixture_dir}/adb-real"
readonly capture="${fixture_dir}/args.txt"
readonly mode_evidence="${fixture_dir}/mode-evidence.txt"
trap 'rm -rf -- "${fixture_dir}"' EXIT

cat > "${fake_adb}" <<'FAKE_ADB'
#!/usr/bin/env bash
set -euo pipefail
: "${DANGGUI_ADB_CAPTURE:?}"
printf '%s\n' "$@" > "${DANGGUI_ADB_CAPTURE}"
[[ -z "${DANGGUI_FAKE_STDOUT:-}" ]] || printf '%s\n' "${DANGGUI_FAKE_STDOUT}"
[[ -z "${DANGGUI_FAKE_STDERR:-}" ]] || printf '%s\n' "${DANGGUI_FAKE_STDERR}" >&2
exit "${DANGGUI_FAKE_EXIT:-0}"
FAKE_ADB
chmod +x "${fake_adb}"

invoke() {
  DANGGUI_REAL_ADB="${fake_adb}" \
    DANGGUI_ADB_FORCE_NO_STREAMING=1 \
    DANGGUI_ADB_CAPTURE="${capture}" \
    DANGGUI_ADB_MODE_EVIDENCE="${mode_evidence}" \
    bash "${wrapper}" "$@"
}

assert_args() {
  local -a expected=("$@")
  mapfile -t actual < "${capture}"
  if (( ${#actual[@]} != ${#expected[@]} )); then
    printf 'Argument count mismatch. expected=%s actual=%s\n' \
      "${#expected[@]}" "${#actual[@]}" >&2
    exit 1
  fi
  local index
  for ((index = 0; index < ${#expected[@]}; index++)); do
    if [[ "${actual[index]}" != "${expected[index]}" ]]; then
      printf 'Argument mismatch at %s. expected=%q actual=%q\n' \
        "${index}" "${expected[index]}" "${actual[index]}" >&2
      exit 1
    fi
  done
}

invoke -s emulator-5554 shell echo install --streaming
assert_args -s emulator-5554 shell echo install --streaming

DANGGUI_REAL_ADB="${fake_adb}" \
  DANGGUI_ADB_CAPTURE="${capture}" \
  bash "${wrapper}" -s emulator-5554 install -t -r app-debug.apk
assert_args -s emulator-5554 install -t -r app-debug.apk

invoke -s emulator-5554 shell pm list packages com.danggui.memo
assert_args -s emulator-5554 shell pm list packages com.danggui.memo

invoke -s emulator-5554 install -t -r app-debug.apk
assert_args -s emulator-5554 install --no-streaming -t -r app-debug.apk
grep -Fxq 'top_level_command=install mode=no-streaming' "${mode_evidence}"
if grep -Eq 'emulator|app-debug|[/\\]' "${mode_evidence}"; then
  echo 'ADB mode evidence contains a serial, package path, or filesystem path.' >&2
  exit 1
fi

invoke -H 127.0.0.1 -P 5037 install --no-streaming -r app-debug.apk
assert_args -H 127.0.0.1 -P 5037 install --no-streaming -r app-debug.apk

invoke install-multiple -r base.apk split.apk
assert_args install-multiple --no-streaming -r base.apk split.apk

invoke install-multi-package base.apk feature.apk
assert_args install-multi-package --no-streaming base.apk feature.apk

set +e
: > "${capture}"
DANGGUI_REAL_ADB="${fake_adb}" \
  DANGGUI_ADB_FORCE_NO_STREAMING=1 \
  DANGGUI_ADB_CAPTURE="${capture}" \
  bash "${wrapper}" install --streaming app-debug.apk \
  > "${fixture_dir}/streaming.stdout" \
  2> "${fixture_dir}/streaming.stderr"
streaming_status=$?
set -e
[[ "${streaming_status}" == 64 ]]
[[ ! -s "${capture}" ]]
grep -Fq 'forbids explicit streamed or incremental ADB installs' \
  "${fixture_dir}/streaming.stderr"

set +e
: > "${capture}"
DANGGUI_REAL_ADB="${fake_adb}" \
  DANGGUI_ADB_FORCE_NO_STREAMING=1 \
  DANGGUI_ADB_CAPTURE="${capture}" \
  bash "${wrapper}" install --incremental app-debug.apk \
  > "${fixture_dir}/incremental.stdout" \
  2> "${fixture_dir}/incremental.stderr"
incremental_status=$?
set -e
[[ "${incremental_status}" == 64 ]]
[[ ! -s "${capture}" ]]
grep -Fq 'forbids explicit streamed or incremental ADB installs' \
  "${fixture_dir}/incremental.stderr"

set +e
DANGGUI_REAL_ADB="${fake_adb}" \
  DANGGUI_ADB_FORCE_NO_STREAMING=1 \
  DANGGUI_ADB_CAPTURE="${capture}" \
  bash "${wrapper}" -s \
  > "${fixture_dir}/missing.stdout" \
  2> "${fixture_dir}/missing.stderr"
missing_status=$?
set -e
[[ "${missing_status}" == 64 ]]
grep -Fq 'global option without a value' "${fixture_dir}/missing.stderr"

set +e
DANGGUI_REAL_ADB="${fake_adb}" \
  DANGGUI_ADB_CAPTURE="${capture}" \
  DANGGUI_FAKE_STDOUT='fake stdout' \
  DANGGUI_FAKE_STDERR='fake stderr' \
  DANGGUI_FAKE_EXIT=7 \
  bash "${wrapper}" version \
  > "${fixture_dir}/passthrough.stdout" \
  2> "${fixture_dir}/passthrough.stderr"
passthrough_status=$?
set -e
[[ "${passthrough_status}" == 7 ]]
grep -Fxq 'fake stdout' "${fixture_dir}/passthrough.stdout"
grep -Fxq 'fake stderr' "${fixture_dir}/passthrough.stderr"

echo 'ADB no-streaming wrapper self-test passed.'
