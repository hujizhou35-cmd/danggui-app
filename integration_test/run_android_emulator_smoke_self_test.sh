#!/usr/bin/env bash
set -uo pipefail
set +e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "${script_dir}/.." && pwd)"

run_case() {
  local scenario="$1"
  local case_root output status retry_log event_log events expected_events
  local expected_status=124 failed=0
  case_root="$(mktemp -d "${TMPDIR:-/tmp}/danggui-smoke-gate.XXXXXX")" || return 1
  retry_log="${case_root}/danggui-emulator-api-24/retry-after-adb-recovery.log"
  event_log="${case_root}/events.log"
  : > "${event_log}"

  output="$(
    cd "${repository_root}" || exit 98
    SCENARIO="${scenario}" RUNNER_TEMP="${case_root}" \
      EVENT_LOG="${event_log}" bash -c '
      timeout() {
        case " $* " in
          *" flutter test "*)
            printf "%s\n" "flutter-test" >> "${EVENT_LOG}"
            flutter_invocations="$(grep -c "^flutter-test$" "${EVENT_LOG}")"
            if [[ "${SCENARIO}" == "clean" ]] &&
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
            printf "%s\n" "target-package-query" >> "${EVENT_LOG}"
            case "${SCENARIO}" in
              clean|retry-failure)
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
      source integration_test/run_android_emulator_smoke.sh 24
    ' 2>&1
  )"
  status=$?
  events="$(<"${event_log}")"

  case "${scenario}" in
    clean) expected_status=0 ;;
    ordinary-failure|retry-failure) expected_status=1 ;;
  esac
  if (( status != expected_status )); then
    failed=1
  fi
  case "${scenario}" in
    clean)
      expected_events=$'flutter-test\nkill-server\nstart-server\nwait-for-device\nboot-query\nsystem-package-query\ntarget-package-query\nuninstall\ntarget-package-query\nflutter-test'
      [[ -f "${retry_log}" ]] || failed=1
      [[ "${output}" == *'performing one bounded ADB recovery'* ]] || failed=1
      [[ "${output}" != *'refusing to retry'* ]] || failed=1
      [[ "${output}" == *'All tests passed!'* ]] || failed=1
      [[ "${events}" == "${expected_events}" ]] || failed=1
      [[ "$(grep -c '^target-package-query$' "${event_log}")" == '2' ]] ||
        failed=1
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
  esac

  rm -rf -- "${case_root}"
  if (( failed != 0 )); then
    printf 'Smoke retry gate self-test failed for %s (status %s).\nEvents:\n%s\nOutput:\n%s\n' \
      "${scenario}" "${status}" "${events}" "${output}" >&2
    return 1
  fi
}

for scenario in \
  clean retry-failure installed unknown system-pm-failure non-install-timeout \
  missing-built missing-installing missing-no-tests ordinary-failure; do
  run_case "${scenario}" || exit 1
done

echo 'Android emulator smoke retry gate self-test passed.'
