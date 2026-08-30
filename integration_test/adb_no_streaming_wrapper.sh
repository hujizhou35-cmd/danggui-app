#!/usr/bin/env bash
set -euo pipefail

readonly wrapper_path="$(realpath -- "$0")"
readonly real_adb="${DANGGUI_REAL_ADB:-${wrapper_path}.danggui-real}"
if [[ "${real_adb}" != /* || ! -x "${real_adb}" ]]; then
  echo "Danggui ADB wrapper cannot execute the real client: ${real_adb}" >&2
  exit 69
fi
readonly real_adb_path="$(realpath -- "${real_adb}")"
if [[ "${wrapper_path}" == "${real_adb_path}" ]]; then
  echo 'Danggui ADB wrapper refuses to invoke itself recursively.' >&2
  exit 69
fi

if [[ "${DANGGUI_ADB_FORCE_NO_STREAMING:-0}" != 1 ]]; then
  exec "${real_adb_path}" "$@"
fi

args=("$@")
command_index=-1
index=0

# ADB accepts transport/server switches before its top-level command. Locate
# that command without mistaking a value (for example the device serial) for
# an install operation. All non-install commands are passed through unchanged.
while (( index < ${#args[@]} )); do
  case "${args[index]}" in
    -s|-t|-H|-P|-L|--one-device)
      if (( index + 1 >= ${#args[@]} )); then
        echo "Danggui ADB wrapper found a global option without a value: ${args[index]}" >&2
        exit 64
      fi
      index=$((index + 2))
      ;;
    -d|-e|-a|--exit-on-write-error)
      index=$((index + 1))
      ;;
    --)
      index=$((index + 1))
      command_index=${index}
      break
      ;;
    *)
      command_index=${index}
      break
      ;;
  esac
done

if (( command_index >= 0 && command_index < ${#args[@]} )); then
  case "${args[command_index]}" in
    install|install-multiple|install-multi-package)
      has_no_streaming=false
      has_streaming=false
      has_incremental=false
      for ((index = command_index + 1; index < ${#args[@]}; index++)); do
        case "${args[index]}" in
          --no-streaming) has_no_streaming=true ;;
          --streaming) has_streaming=true ;;
          --incremental|--incr) has_incremental=true ;;
        esac
      done
      if [[ "${has_streaming}" == true || "${has_incremental}" == true ]]; then
        echo 'Danggui emulator acceptance forbids explicit streamed or incremental ADB installs.' >&2
        exit 64
      fi
      if [[ "${has_no_streaming}" == false ]]; then
        args=(
          "${args[@]:0:command_index + 1}"
          --no-streaming
          "${args[@]:command_index + 1}"
        )
      fi
      if [[ -n "${DANGGUI_ADB_MODE_EVIDENCE:-}" ]]; then
        printf 'top_level_command=%s mode=no-streaming\n' \
          "${args[command_index]}" >> "${DANGGUI_ADB_MODE_EVIDENCE}"
      fi
      ;;
  esac
fi

exec "${real_adb_path}" "${args[@]}"
