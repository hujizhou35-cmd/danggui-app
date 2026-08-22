#!/usr/bin/env bash
set -euo pipefail

if (( $# < 1 || $# > 3 )); then
  echo "Usage: $0 <apk> [aab] [expected-version-code]" >&2
  exit 64
fi

apk="$1"
aab="${2:-}"
expected_version_code="${3:-1}"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"

if [[ ! -f "${apk}" ]]; then
  echo "APK not found: ${apk}" >&2
  exit 66
fi
if [[ -z "${sdk_root}" || ! -d "${sdk_root}" ]]; then
  echo "ANDROID_SDK_ROOT or ANDROID_HOME must point to an installed Android SDK." >&2
  exit 69
fi

apkanalyzer="$(command -v apkanalyzer || true)"
if [[ -z "${apkanalyzer}" ]]; then
  apkanalyzer="$(find "${sdk_root}/cmdline-tools" -type f -name apkanalyzer 2>/dev/null | sort -V | tail -n 1)"
fi
apksigner="$(find "${sdk_root}/build-tools" -type f -name apksigner 2>/dev/null | sort -V | tail -n 1)"

if [[ -z "${apkanalyzer}" || -z "${apksigner}" ]]; then
  echo "apkanalyzer and apksigner are required to verify the release." >&2
  exit 69
fi

permissions="$(${apkanalyzer} manifest permissions "${apk}")"
printf '%s\n' "${permissions}"

mapfile -t permission_names < <(
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"${permissions}" |
    sed '/^$/d' |
    sort -u
)
required_permissions=(
  android.permission.POST_NOTIFICATIONS
  android.permission.RECEIVE_BOOT_COMPLETED
  android.permission.VIBRATE
)
for required in "${required_permissions[@]}"; do
  if ! printf '%s\n' "${permission_names[@]}" | grep -Fxq "${required}"; then
    echo "APK is missing required local-reminder permission ${required}." >&2
    exit 1
  fi
done
for permission in "${permission_names[@]}"; do
  case "${permission}" in
    android.permission.POST_NOTIFICATIONS|\
    android.permission.RECEIVE_BOOT_COMPLETED|\
    android.permission.VIBRATE|\
    com.danggui.memo.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION)
      ;;
    *)
      echo "APK contains an unapproved permission: ${permission}" >&2
      exit 1
      ;;
  esac
done

declare -A expected_manifest_values=(
  [application-id]=com.danggui.memo
  [version-name]=1.0.0
  [version-code]="${expected_version_code}"
  [min-sdk]=24
  [target-sdk]=36
  [debuggable]=false
)
for field in application-id version-name version-code min-sdk target-sdk debuggable; do
  actual="$(${apkanalyzer} manifest "${field}" "${apk}")"
  if [[ "${actual}" != "${expected_manifest_values[${field}]}" ]]; then
    echo "Unexpected APK ${field}: ${actual} (expected ${expected_manifest_values[${field}]})." >&2
    exit 1
  fi
done

merged_manifest_file="$(mktemp)"
trap 'rm -f "${merged_manifest_file}"' EXIT
"${apkanalyzer}" manifest print "${apk}" > "${merged_manifest_file}"
python3 - "${merged_manifest_file}" <<'PY'
import sys
import xml.etree.ElementTree as ET

android = "{http://schemas.android.com/apk/res/android}"
root = ET.parse(sys.argv[1]).getroot()
application = root.find("application")
if application is None:
    raise SystemExit("Merged APK manifest has no application element.")

for attribute in ("allowBackup", "usesCleartextTraffic"):
    if application.get(android + attribute) != "false":
        raise SystemExit(
            f'Merged APK application must set android:{attribute}="false".'
        )

main_activity = next(
    (
        activity
        for activity in application.findall("activity")
        if (activity.get(android + "name") or "").endswith(".MainActivity")
    ),
    None,
)
if main_activity is None:
    raise SystemExit("Merged APK manifest has no MainActivity.")
orientation = main_activity.get(android + "screenOrientation")
if orientation not in {"portrait", "1"}:
    raise SystemExit(
        "Merged APK MainActivity must remain portrait-only; "
        f"apkanalyzer reported {orientation!r}."
    )

required_receivers = {
    "ScheduledNotificationReceiver",
    "ScheduledNotificationBootReceiver",
    "ActionBroadcastReceiver",
}
receivers = {
    (receiver.get(android + "name") or "").rsplit(".", 1)[-1]: receiver
    for receiver in application.findall("receiver")
}
for receiver_name in required_receivers:
    receiver = receivers.get(receiver_name)
    if receiver is None or receiver.get(android + "exported") != "false":
        raise SystemExit(
            f"Merged APK receiver {receiver_name} must exist and remain non-exported."
        )
PY

signature_report="$(${apksigner} verify --verbose --print-certs "${apk}")"
printf '%s\n' "${signature_report}"

normalize_digest() { tr '[:lower:]' '[:upper:]' | tr -d ':[:space:]'; }

if [[ -n "${DANGGUI_EXPECTED_CERT_SHA256:-}" ]]; then
  actual="$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' <<<"${signature_report}" | head -n 1)"
  if [[ "$(printf '%s' "${actual}" | normalize_digest)" != "$(printf '%s' "${DANGGUI_EXPECTED_CERT_SHA256}" | normalize_digest)" ]]; then
    echo "APK certificate SHA-256 does not match DANGGUI_EXPECTED_CERT_SHA256." >&2
    exit 1
  fi
fi

if [[ -n "${aab}" ]]; then
  if [[ ! -f "${aab}" ]]; then
    echo "AAB not found: ${aab}" >&2
    exit 66
  fi
  signature_entries="$(jar tf "${aab}" | tr -d '\r')"
  if ! grep -Eiq '^META-INF/[^/]+\.SF$' <<<"${signature_entries}" ||
     ! grep -Eiq '^META-INF/[^/]+\.(RSA|DSA|EC)$' <<<"${signature_entries}"; then
    echo "AAB does not contain a complete JAR signature block." >&2
    exit 1
  fi
  jarsigner -verify "${aab}"
  certificate_report="$(keytool -printcert -jarfile "${aab}")"
  if [[ -n "${DANGGUI_EXPECTED_CERT_SHA256:-}" ]]; then
    actual_aab="$(sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' <<<"${certificate_report}" | head -n 1)"
    if [[ -z "${actual_aab}" ]]; then
      echo "keytool did not report an AAB certificate SHA-256 fingerprint." >&2
      exit 1
    fi
    if [[ "$(printf '%s' "${actual_aab}" | normalize_digest)" != "$(printf '%s' "${DANGGUI_EXPECTED_CERT_SHA256}" | normalize_digest)" ]]; then
      echo "AAB certificate SHA-256 does not match DANGGUI_EXPECTED_CERT_SHA256." >&2
      exit 1
    fi
  fi
fi
