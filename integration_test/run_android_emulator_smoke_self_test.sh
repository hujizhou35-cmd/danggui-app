#!/usr/bin/env bash
set -uo pipefail
set +e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "${script_dir}/.." && pwd)"

run_case() {
  local scenario="$1"
  local case_root output status retry_log event_log release_apk events expected_events
  local sdk_root
  local expected_status=124 failed=0
  case_root="$(mktemp -d "${TMPDIR:-/tmp}/danggui-smoke-gate.XXXXXX")" || return 1
  retry_log="${case_root}/danggui-emulator-api-24/retry-after-adb-recovery.log"
  event_log="${case_root}/events.log"
  release_apk="${case_root}/danggui-android-universal-debug-fallback.apk"
  sdk_root="${case_root}/android-sdk"
  : > "${event_log}"
  : > "${release_apk}"
  mkdir -p "${sdk_root}/platform-tools"
  cat > "${sdk_root}/platform-tools/adb" <<'FAKE_ADB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == version ]]; then
  printf '%s\n' 'Android Debug Bridge version 1.0.41 smoke-self-test'
  exit 0
fi
exit 0
FAKE_ADB
  chmod +x "${sdk_root}/platform-tools/adb"
  printf '%s\n' 'Pkg.Revision = 36.0.0' \
    > "${sdk_root}/platform-tools/source.properties"
  ANDROID_SDK_ROOT="${sdk_root}" RUNNER_TEMP="${case_root}" \
    DANGGUI_EMULATOR_ATTEMPT=1 \
    bash "${repository_root}/integration_test/install_adb_no_streaming_wrapper.sh" \
      24 >/dev/null || return 1
  if [[ "${scenario}" == 'missing-attestation' ]]; then
    rm -f -- \
      "${case_root}/danggui-emulator-api-24/adb-install-mode.json"
  fi
  output="$(
    cd "${repository_root}" || exit 98
    SCENARIO="${scenario}" RUNNER_TEMP="${case_root}" \
      EVENT_LOG="${event_log}" \
      DANGGUI_RELEASE_APK="${release_apk}" \
      DANGGUI_RELEASE_APK_SHA256='0000000000000000000000000000000000000000000000000000000000000000' \
      DANGGUI_RELEASE_SIGNING_MODE='debug-fallback' \
      DANGGUI_RELEASE_ARTIFACT_SHA='self-test-sha' \
      DANGGUI_EMULATOR_ATTEMPT=1 \
      ANDROID_SDK_ROOT="${sdk_root}" \
      PATH="${sdk_root}/platform-tools:${PATH}" bash -c '
      timeout() {
        case " $* " in
          *" flutter test "*)
            printf "%s\n" "flutter-test" >> "${EVENT_LOG}"
            flutter_invocations="$(grep -c "^flutter-test$" "${EVENT_LOG}")"
            if [[ "${SCENARIO}" == "clean" ||
                  "${SCENARIO}" == "acceptance-failure" ||
                  "${SCENARIO}" == "release-binary-failure" ||
                  "${SCENARIO}" == "empty-install-evidence" ||
                  "${SCENARIO}" == "invalid-install-evidence" ]] &&
               (( flutter_invocations == 2 )); then
              printf "%s\n" "All tests passed!"
              return 0
            fi
            if [[ "${SCENARIO}" == "retry-failure" ]] &&
               (( flutter_invocations == 2 )); then
              printf "%s\n" "An integration assertion failed on retry."
              return 1
            fi
            if [[ "${SCENARIO}" == "ordinary-failure" ]]; then
              printf "%s\n" "An integration assertion failed."
              return 1
            elif [[ "${SCENARIO}" == "non-install-timeout" ]]; then
              printf "%s\n" "No tests ran."
            elif [[ "${SCENARIO}" == "missing-built" ]]; then
              printf "%s\n" \
                "Installing build/app/outputs/flutter-apk/app-debug.apk" \
                "No tests ran."
            elif [[ "${SCENARIO}" == "missing-installing" ]]; then
              printf "%s\n" \
                "Built build/app/outputs/flutter-apk/app-debug.apk" \
                "No tests ran."
            elif [[ "${SCENARIO}" == "missing-no-tests" ]]; then
              printf "%s\n" \
                "Built build/app/outputs/flutter-apk/app-debug.apk" \
                "Installing build/app/outputs/flutter-apk/app-debug.apk"
            else
              printf "%s\n" \
                "Built build/app/outputs/flutter-apk/app-debug.apk" \
                "Installing build/app/outputs/flutter-apk/app-debug.apk" \
                "No tests ran."
            fi
            return 124
            ;;
          *" adb kill-server "*)
            printf "%s\n" "kill-server" >> "${EVENT_LOG}"
            return 0
            ;;
          *" adb start-server "*)
            printf "%s\n" "start-server" >> "${EVENT_LOG}"
            return 0
            ;;
          *" wait-for-device "*)
            printf "%s\n" "wait-for-device" >> "${EVENT_LOG}"
            return 0
            ;;
          *" getprop sys.boot_completed "*)
            printf "%s\n" "boot-query" >> "${EVENT_LOG}"
            printf "%s\n" "1"
            return 0
            ;;
          *" pm path android "*)
            printf "%s\n" "system-package-query" >> "${EVENT_LOG}"
            printf "%s\n" "package:/system/framework/framework-res.apk"
            [[ "${SCENARIO}" == "system-pm-failure" ]] && return 124
            return 0
            ;;
          *" pm path com.danggui.memo "*)
            printf "%s\n" "forbidden-target-path-query" >> "${EVENT_LOG}"
            return 91
            ;;
          *" pm list packages com.danggui.memo "*)
            printf "%s\n" "target-package-query" >> "${EVENT_LOG}"
            case "${SCENARIO}" in
              clean|retry-failure|acceptance-failure|release-binary-failure|empty-install-evidence|invalid-install-evidence)
                # The historical bug queried the target through the unhealthy
                # daemon before restart. Make that ordering fail closed.
                grep -Fqx "start-server" "${EVENT_LOG}" || return 42
                return 0
                ;;
              installed)
                printf "%s\n" "package:/data/app/com.danggui.memo/base.apk"
                return 0
                ;;
              unknown) return 42 ;;
              *) return 0 ;;
            esac
            ;;
          *" uninstall com.danggui.memo "*)
            printf "%s\n" "uninstall" >> "${EVENT_LOG}"
            return 1
            ;;
          *" logcat "*) return 0 ;;
          *) return 97 ;;
        esac
      }
      adb() { return 0; }
      bash() {
        if [[ "$1" == "integration_test/run_android_release_acceptance.sh" ]]; then
          printf "%s\n" "release-acceptance" >> "${EVENT_LOG}"
          if [[ "${SCENARIO}" != "empty-install-evidence" ]]; then
            printf "%s\n" \
              "top_level_command=install mode=no-streaming" \
              >> "${DANGGUI_ADB_MODE_EVIDENCE}"
          fi
          [[ "${SCENARIO}" == "acceptance-failure" ]] && return 1
          return 0
        fi
        if [[ "$1" == "integration_test/run_android_release_binary_smoke.sh" ]]; then
          printf "%s\n" "release-binary-smoke" >> "${EVENT_LOG}"
          if [[ "${SCENARIO}" == "invalid-install-evidence" ]]; then
            printf "%s\n" \
              "top_level_command=install mode=no-streaming apk=/tmp/private.apk" \
              >> "${DANGGUI_ADB_MODE_EVIDENCE}"
          elif [[ "${SCENARIO}" != "empty-install-evidence" ]]; then
            printf "%s\n" \
              "top_level_command=install mode=no-streaming" \
              >> "${DANGGUI_ADB_MODE_EVIDENCE}"
          fi
          [[ "${SCENARIO}" == "release-binary-failure" ]] && return 1
          return 0
        fi
        command bash "$@"
      }
      source integration_test/run_android_emulator_smoke.sh 24
    ' 2>&1
  )"
  status=$?
  events="$(<"${event_log}")"

  case "${scenario}" in
    clean) expected_status=0 ;;
    ordinary-failure|retry-failure|acceptance-failure|release-binary-failure)
      expected_status=1
      ;;
    missing-attestation) expected_status=65 ;;
    empty-install-evidence|invalid-install-evidence) expected_status=65 ;;
  esac
  if (( status != expected_status )); then
    failed=1
  fi
  case "${scenario}" in
    clean)
      expected_events=$'flutter-test\nkill-server\nstart-server\nwait-for-device\nboot-query\nsystem-package-query\ntarget-package-query\nuninstall\ntarget-package-query\nflutter-test\nrelease-acceptance\nrelease-binary-smoke'
      [[ -f "${retry_log}" ]] || failed=1
      [[ "${output}" == *'performing one bounded ADB recovery'* ]] || failed=1
      [[ "${output}" != *'refusing to retry'* ]] || failed=1
      [[ "${output}" == *'All tests passed!'* ]] || failed=1
      [[ "${events}" == "${expected_events}" ]] || failed=1
      [[ "$(grep -c '^target-package-query$' "${event_log}")" == '2' ]] ||
        failed=1
      ;;
    acceptance-failure)
      expected_events=$'flutter-test\nkill-server\nstart-server\nwait-for-device\nboot-query\nsystem-package-query\ntarget-package-query\nuninstall\ntarget-package-query\nflutter-test\nrelease-acceptance'
      [[ -f "${retry_log}" ]] || failed=1
      [[ "${output}" == *'All tests passed!'* ]] || failed=1
      [[ "${events}" == "${expected_events}" ]] || failed=1
      ;;
    release-binary-failure)
      expected_events=$'flutter-test\nkill-server\nstart-server\nwait-for-device\nboot-query\nsystem-package-query\ntarget-package-query\nuninstall\ntarget-package-query\nflutter-test\nrelease-acceptance\nrelease-binary-smoke'
      [[ -f "${retry_log}" ]] || failed=1
      [[ "${output}" == *'All tests passed!'* ]] || failed=1
      [[ "${events}" == "${expected_events}" ]] || failed=1
      ;;
    retry-failure)
      expected_events=$'flutter-test\nkill-server\nstart-server\nwait-for-device\nboot-query\nsystem-package-query\ntarget-package-query\nuninstall\ntarget-package-query\nflutter-test'
      [[ -f "${retry_log}" ]] || failed=1
      [[ "${output}" == *'performing one bounded ADB recovery'* ]] || failed=1
      [[ "${output}" != *'refusing to retry'* ]] || failed=1
      [[ "${output}" == *'An integration assertion failed on retry.'* ]] ||
        failed=1
      [[ "${events}" == "${expected_events}" ]] || failed=1
      ;;
    installed|unknown|system-pm-failure)
      [[ ! -f "${retry_log}" ]] || failed=1
      [[ "${output}" == *'refusing to retry'* ]] || failed=1
      ;;
    non-install-timeout|missing-built|missing-installing|missing-no-tests|ordinary-failure)
      [[ ! -f "${retry_log}" ]] || failed=1
      [[ "${output}" != *'performing one bounded ADB recovery'* ]] || failed=1
      ;;
    missing-attestation)
      [[ -z "${events}" ]] || failed=1
      [[ "${output}" == *'refusing to start product tests'* ]] || failed=1
      ;;
    empty-install-evidence|invalid-install-evidence)
      expected_events=$'flutter-test\nkill-server\nstart-server\nwait-for-device\nboot-query\nsystem-package-query\ntarget-package-query\nuninstall\ntarget-package-query\nflutter-test\nrelease-acceptance\nrelease-binary-smoke'
      [[ "${events}" == "${expected_events}" ]] || failed=1
      [[ "${output}" == *'install invocation evidence failed'* ]] || failed=1
      ;;
  esac

  rm -rf -- "${case_root}"
  if (( failed != 0 )); then
    printf 'Smoke retry gate self-test failed for %s (status %s).\nEvents:\n%s\nOutput:\n%s\n' \
      "${scenario}" "${status}" "${events}" "${output}" >&2
    return 1
  fi
}

run_api36_scope_case() {
  local case_root sdk_root output status
  case_root="$(mktemp -d "${TMPDIR:-/tmp}/danggui-api36-scope.XXXXXX")" ||
    return 1
  sdk_root="${case_root}/android-sdk"
  mkdir -p "${sdk_root}/platform-tools"
  cat > "${sdk_root}/platform-tools/adb" <<'FAKE_ADB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == version ]]; then
  printf '%s\n' 'Android Debug Bridge version 1.0.41 api36-scope-self-test'
  exit 0
fi
exit 0
FAKE_ADB
  chmod +x "${sdk_root}/platform-tools/adb"
  printf '%s\n' 'Pkg.Revision = 36.0.0' \
    > "${sdk_root}/platform-tools/source.properties"
  ANDROID_SDK_ROOT="${sdk_root}" RUNNER_TEMP="${case_root}" \
    DANGGUI_EMULATOR_ATTEMPT=1 \
    bash "${repository_root}/integration_test/install_adb_no_streaming_wrapper.sh" \
      36 >/dev/null || return 1
  : > "${case_root}/danggui-emulator-api-36/adb-install-invocations.txt"
  set +e
  output="$(
    cd "${repository_root}" || exit 98
    RUNNER_TEMP="${case_root}" \
      DANGGUI_EMULATOR_ATTEMPT=1 \
      ANDROID_SDK_ROOT="${sdk_root}" \
      PATH="${sdk_root}/platform-tools:${PATH}" \
      bash integration_test/run_android_emulator_smoke.sh 36 2>&1
  )"
  status=$?
  set -e
  if (( status != 65 )) ||
     [[ "${output}" != *'unexpectedly inherited API 24 install-mode evidence'* ]] ||
     ! jq -e '
       .status == "failed" and .phase == "adb-transport-scope" and
       .attempt == 1 and .exitStatus == 65
     ' "${case_root}/danggui-emulator-api-36/workflow-phase.json" >/dev/null; then
    echo "API 36 ADB scope self-test failed (status ${status}): ${output}" >&2
    rm -rf -- "${case_root}"
    return 1
  fi
  rm -rf -- "${case_root}"
}

for scenario in \
  clean acceptance-failure release-binary-failure retry-failure installed unknown system-pm-failure non-install-timeout \
  missing-built missing-installing missing-no-tests ordinary-failure \
  missing-attestation empty-install-evidence invalid-install-evidence; do
  run_case "${scenario}" || exit 1
done
run_api36_scope_case || exit 1

echo 'Android emulator smoke retry gate self-test passed.'
