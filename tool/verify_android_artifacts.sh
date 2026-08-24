#!/usr/bin/env bash
set -euo pipefail

normalize_digest() { tr '[:lower:]' '[:upper:]' | tr -d ':[:space:]'; }

verify_apksigner_certificate_report() {
  local signature_report="$1"
  local expected_digest="$2"
  local expected_normalized actual_normalized
  local -a signer_counts actual_digests

  mapfile -t signer_counts < <(
    sed -n -E 's/^Number of signers:[[:space:]]*([[:digit:]]+)[[:space:]]*$/\1/p' \
      <<<"${signature_report}"
  )
  if (( ${#signer_counts[@]} != 1 )) || [[ "${signer_counts[0]:-}" != '1' ]]; then
    echo "apksigner must report exactly one APK signer." >&2
    return 1
  fi

  # Build Tools 35 and earlier commonly prefix this line with "Signer #1";
  # Build Tools 36 reports the verified scheme, for example "V2 Signer:".
  mapfile -t actual_digests < <(
    sed -n -E \
      's/^(Signer #[[:digit:]]+|V[[:digit:].]+ Signer:)[[:space:]]+certificate SHA-256 digest:[[:space:]]*//p' \
      <<<"${signature_report}"
  )
  if (( ${#actual_digests[@]} == 0 )); then
    echo "apksigner did not report a certificate SHA-256 digest." >&2
    return 1
  fi

  expected_normalized="$(printf '%s' "${expected_digest}" | normalize_digest)"
  if [[ ! "${expected_normalized}" =~ ^[[:xdigit:]]{64}$ ]]; then
    echo "DANGGUI_EXPECTED_CERT_SHA256 must contain exactly 64 hexadecimal digits." >&2
    return 1
  fi
  for actual in "${actual_digests[@]}"; do
    actual_normalized="$(printf '%s' "${actual}" | normalize_digest)"
    if [[ "${actual_normalized}" != "${expected_normalized}" ]]; then
      echo "APK certificate SHA-256 does not match DANGGUI_EXPECTED_CERT_SHA256." >&2
      return 1
    fi
  done
}

run_certificate_parser_self_test() {
  local expected='a893a375c3cfb71e582ca4b99f9691173d969333c375e2c32fd08572960e0888'
  local other='0000000000000000000000000000000000000000000000000000000000000000'
  local old_report new_report missing_report multiple_report inconsistent_report

  old_report="$(printf 'Number of signers: 1\nSigner #1 certificate SHA-256 digest: %s\n' "${expected}")"
  new_report="$(printf 'Number of signers: 1\nV2 Signer: certificate SHA-256 digest: %s\n' "${expected}")"
  missing_report='Number of signers: 1'
  multiple_report="$(printf 'Number of signers: 2\nSigner #1 certificate SHA-256 digest: %s\nSigner #2 certificate SHA-256 digest: %s\n' "${expected}" "${other}")"
  inconsistent_report="$(printf 'Number of signers: 1\nV2 Signer: certificate SHA-256 digest: %s\nV3 Signer: certificate SHA-256 digest: %s\n' "${expected}" "${other}")"

  verify_apksigner_certificate_report "${old_report}" "${expected}" >/dev/null
  verify_apksigner_certificate_report "${new_report}" "${expected}" >/dev/null
  if verify_apksigner_certificate_report "${missing_report}" "${expected}" >/dev/null 2>&1; then
    echo "Certificate parser self-test accepted a missing digest." >&2
    return 1
  fi
  if verify_apksigner_certificate_report "${multiple_report}" "${expected}" >/dev/null 2>&1; then
    echo "Certificate parser self-test accepted multiple APK signers." >&2
    return 1
  fi
  if verify_apksigner_certificate_report "${inconsistent_report}" "${expected}" >/dev/null 2>&1; then
    echo "Certificate parser self-test accepted inconsistent certificate digests." >&2
    return 1
  fi
  echo "Android certificate report parser self-test passed."
}

if [[ "${1:-}" == '--self-test' ]]; then
  if (( $# != 1 )); then
    echo "Usage: $0 --self-test" >&2
    exit 64
  fi
  run_certificate_parser_self_test
  exit 0
fi

if (( $# < 1 || $# > 3 )); then
  echo "Usage: $0 <apk> [aab] [expected-version-code]" >&2
  exit 64
fi

apk="$1"
aab="${2:-}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
technical_version="$(sed -n -E 's/^version:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' "${repo_root}/pubspec.yaml" | head -n 1)"
if [[ "${technical_version}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([1-9][0-9]*)$ ]]; then
  expected_version_name="${BASH_REMATCH[1]}"
  pubspec_version_code="${BASH_REMATCH[2]}"
else
  echo "pubspec.yaml version must use semantic-name+positive-build-number: ${technical_version}" >&2
  exit 65
fi
expected_version_code="${3:-${pubspec_version_code}}"
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
  [version-name]="${expected_version_name}"
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
aab_manifest_file=""
trap 'rm -f "${merged_manifest_file}" "${aab_manifest_file:-}"' EXIT
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

if [[ -n "${DANGGUI_EXPECTED_CERT_SHA256:-}" ]]; then
  verify_apksigner_certificate_report \
    "${signature_report}" "${DANGGUI_EXPECTED_CERT_SHA256}"
fi

if [[ -n "${aab}" ]]; then
  if [[ ! -f "${aab}" ]]; then
    echo "AAB not found: ${aab}" >&2
    exit 66
  fi
  bundletool_jar="${BUNDLETOOL_JAR:-}"
  if [[ -z "${bundletool_jar}" || ! -f "${bundletool_jar}" ]]; then
    echo "BUNDLETOOL_JAR must point to the pinned bundletool-all JAR for AAB metadata verification." >&2
    exit 69
  fi
  if ! command -v java >/dev/null 2>&1; then
    echo "Java is required for AAB metadata verification with bundletool." >&2
    exit 69
  fi
  java -jar "${bundletool_jar}" validate --bundle="${aab}" >/dev/null
  aab_manifest_file="$(mktemp)"
  java -jar "${bundletool_jar}" dump manifest \
    --bundle="${aab}" --module=base > "${aab_manifest_file}"
  python3 - "${aab_manifest_file}" "${expected_version_name}" \
    "${expected_version_code}" <<'PY'
import sys
import xml.etree.ElementTree as ET

manifest_path, expected_version_name, expected_version_code_text = sys.argv[1:]
android = "{http://schemas.android.com/apk/res/android}"
root = ET.parse(manifest_path).getroot()


def integer_attribute(element, name):
    value = element.get(android + name)
    if value is None:
        raise SystemExit(f"AAB manifest is missing android:{name}.")
    try:
        return int(value[2:], 16) if value.lower().startswith("0x") else int(value, 10)
    except ValueError as error:
        raise SystemExit(
            f"AAB manifest android:{name} is not an integer: {value!r}."
        ) from error


expected_identity = {
    "package": "com.danggui.memo",
    "version-name": expected_version_name,
    "version-code": int(expected_version_code_text),
    "min-sdk": 24,
    "target-sdk": 36,
}
uses_sdk = root.find("uses-sdk")
if uses_sdk is None:
    raise SystemExit("AAB manifest has no uses-sdk element.")
actual_identity = {
    "package": root.get("package"),
    "version-name": root.get(android + "versionName"),
    "version-code": integer_attribute(root, "versionCode"),
    "min-sdk": integer_attribute(uses_sdk, "minSdkVersion"),
    "target-sdk": integer_attribute(uses_sdk, "targetSdkVersion"),
}
for field, expected in expected_identity.items():
    actual = actual_identity[field]
    if actual != expected:
        raise SystemExit(
            f"Unexpected AAB {field}: {actual!r} (expected {expected!r})."
        )

permission_elements = list(root.findall("uses-permission")) + list(
    root.findall("uses-permission-sdk-23")
)
permissions = {
    element.get(android + "name")
    for element in permission_elements
    if element.get(android + "name")
}
required_permissions = {
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.VIBRATE",
}
allowed_permissions = required_permissions | {
    "com.danggui.memo.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
}
missing = sorted(required_permissions - permissions)
unexpected = sorted(permissions - allowed_permissions)
if missing:
    raise SystemExit(f"AAB is missing required permission(s): {', '.join(missing)}.")
if unexpected:
    raise SystemExit(f"AAB contains unapproved permission(s): {', '.join(unexpected)}.")
PY
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
