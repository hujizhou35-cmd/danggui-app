#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != 'Darwin' ]]; then
  echo 'Verified iOS native-asset prefetch requires macOS.' >&2
  exit 69
fi

# sqlite3 3.5.2 uses Dart native-asset hooks. The hook verifies these hashes,
# but an interrupted GitHub release download used to make iOS builds fail
# before the verifier could reuse a complete cache entry. Prefetching through
# curl gives the transient network path bounded retries while retaining the
# upstream package's exact immutable digest contract.
readonly sqlite_package_version='3.5.2'
readonly sqlite_release_tag="sqlite3-${sqlite_package_version}"
readonly sqlite_release_base="https://github.com/simolus3/sqlite3.dart/releases/download/${sqlite_release_tag}"

locked_version="$(
  awk '
    $1 == "sqlite3:" { in_sqlite = 1; next }
    in_sqlite && $1 == "version:" { gsub(/\"/, "", $2); print $2; exit }
  ' pubspec.lock
)"
if [[ "${locked_version}" != "${sqlite_package_version}" ]]; then
  echo "sqlite3 lock drift: expected ${sqlite_package_version}, got ${locked_version:-missing}." >&2
  exit 1
fi

prefetch_asset() {
  local asset_name="$1"
  local expected_sha256="$2"
  local cache_dir=".dart_tool/hooks_runner/shared/sqlite3/build/download-${expected_sha256:0:8}"
  local destination="${cache_dir}/libsqlite3.dylib"
  local temporary="${destination}.partial"

  mkdir -p "${cache_dir}"
  if [[ -f "${destination}" ]] &&
    [[ "$(shasum -a 256 "${destination}" | awk '{print $1}')" == "${expected_sha256}" ]]; then
    printf 'sqlite3 native asset already verified: %s\n' "${asset_name}"
    return
  fi

  rm -f "${temporary}"
  curl --fail --location \
    --retry 10 \
    --retry-delay 3 \
    --retry-all-errors \
    --connect-timeout 30 \
    --max-time 900 \
    --output "${temporary}" \
    "${sqlite_release_base}/${asset_name}"

  actual_sha256="$(shasum -a 256 "${temporary}" | awk '{print $1}')"
  if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
    rm -f "${temporary}"
    echo "sqlite3 digest mismatch for ${asset_name}: ${actual_sha256}" >&2
    exit 1
  fi
  mv -f "${temporary}" "${destination}"
  printf 'sqlite3 native asset downloaded and verified: %s\n' "${asset_name}"
}

# Every unsigned device build targets arm64.
prefetch_asset \
  'libsqlite3.arm64.ios.dylib' \
  'f1bc69a4304a21e472c15f849c34ae46539483cfa7ce901f54175c6d6cc17991'

case "$(uname -m)" in
  arm64)
    prefetch_asset \
      'libsqlite3.arm64.macos.dylib' \
      '6d80ba56cff1fa44f62bebc3e6b6b71513cc628862a9745c223c7bea8bf813f3'
    prefetch_asset \
      'libsqlite3.arm64.ios_sim.dylib' \
      '1ce8ac8ebbb3f61fd6282c45a4da15b9c6c6ec169eff40a918520357a502510b'
    ;;
  x86_64)
    prefetch_asset \
      'libsqlite3.x64.macos.dylib' \
      '4ee3335ce95e17c36e4002bfeede2a3b2f77d9ac8434d0b7ed421d3e2205b216'
    prefetch_asset \
      'libsqlite3.x64.ios_sim.dylib' \
      '7bf9c4262f4a95e0d3f58f9b31d825ec6cb6b2f7b2031f00dfe496fff2fcfbd7'
    ;;
  *)
    echo "Unsupported macOS runner architecture: $(uname -m)" >&2
    exit 1
    ;;
esac
