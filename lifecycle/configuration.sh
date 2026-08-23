#!/bin/bash
set -euo pipefail

DATA_PATH=${1}
SOURCE_PATH=${2:-.}
SITE=${3:-vie}
STATE_PATH=${4:-$(mktemp -d)}
IGNORE_RETURN_VALUES=${5:-false}

mkdir -p "${STATE_PATH}"

# shellcheck source=./util.sh
source "$(dirname "${BASH_SOURCE[0]}")/util.sh"

#region functions
# Copy common and site-specific configuration into the data directory.
# Removes previously applied files from those source trees first.
# Args:    $1 data_path   — destination directory (HA data path)
#          $2 source_path — root of the source repository
#          $3 site        — site name (e.g. vie)
function copy_configuration() {
  local data_path="${1}"
  local source_path="${2}"
  local site="${3}"

  echo "[configuration] wiping current configuration data..."
  while IFS= read -rd '' entry; do
    rm -rf "${data_path:?}/$(basename -- "${entry}")" || return 1
  done < <(find "${source_path}/common/configuration" -mindepth 1 -maxdepth 1 -print0)
  while IFS= read -rd '' entry; do
    rm -rf "${data_path:?}/$(basename -- "${entry}")" || return 1
  done < <(find "${source_path}/sites/${site}/configuration" -mindepth 1 -maxdepth 1 -print0)

  echo "[configuration] copying configuration..."
  mkdir -p "${data_path}" || return 1
  cp -rf "${source_path}/common/configuration/." "${data_path}/" || return 1
  cp -rf "${source_path}/sites/${site}/configuration/." "${data_path}/" || return 1
}
#endregion

# exit codes: 0=unchanged  1=changed+applied  2=error
_common_hash=$(_sha256_dir "${SOURCE_PATH}/common/configuration") \
  || { echo "[configuration] ERROR: failed to hash common configuration"; exit 2; }
_site_hash=$(_sha256_dir "${SOURCE_PATH}/sites/${SITE}/configuration") \
  || { echo "[configuration] ERROR: failed to hash site configuration"; exit 2; }
_combined_hash=$(printf '%s%s' "${_common_hash}" "${_site_hash}" | sha256sum | awk '{print $1}') \
  || { echo "[configuration] ERROR: failed to compute combined hash"; exit 2; }

#region configuration check
if ! _has_changed "${STATE_PATH}" "configuration" "${_combined_hash}"; then
  echo "[configuration] configuration unchanged — skipping."
  exit 0
fi
#endregion

#region apply configuration
copy_configuration "${DATA_PATH}" "${SOURCE_PATH}" "${SITE}" \
  || { echo "[configuration] WARNING: copy failed."; [[ "${IGNORE_RETURN_VALUES}" == "true" ]] && exit 0 || exit 2; }

_save_hash "${STATE_PATH}" "configuration" "${_combined_hash}" \
  || { echo "[configuration] ERROR: failed to save state hash"; [[ "${IGNORE_RETURN_VALUES}" == "true" ]] && exit 0 || exit 2; }
echo "[configuration] done."
if [[ "${IGNORE_RETURN_VALUES}" == "true" ]]; then
  exit 0
fi
exit 1
#endregion
