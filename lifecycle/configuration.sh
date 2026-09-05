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
  local files
  files=$(find "${source_path}/common/configuration" -maxdepth 1 -exec basename -a {} +)
  for file in ${files}; do
    rm -rf "${data_path:?}/${file}"
  done
  files=$(find "${source_path}/sites/${site}/configuration" -maxdepth 1 -exec basename -a {} +)
  for file in ${files}; do
    rm -rf "${data_path:?}/${file}"
  done

  echo "[configuration] copying configuration..."
  cp -rf "${source_path}/common/configuration/"* "${data_path}/"
  cp -rf "${source_path}/sites/${site}/configuration/"* "${data_path}/"
}
#endregion

# exit codes: 0=unchanged  1=changed+applied  2=error
_common_hash=$(_sha256_dir "${SOURCE_PATH}/common/configuration")
_site_hash=$(_sha256_dir "${SOURCE_PATH}/sites/${SITE}/configuration")
_combined_hash=$(printf '%s%s' "${_common_hash}" "${_site_hash}" | sha256sum | awk '{print $1}')

#region configuration check
if ! _has_changed "${STATE_PATH}" "configuration" "${_combined_hash}"; then
  echo "[configuration] configuration unchanged — skipping."
  exit 0
fi
#endregion

#region apply configuration
copy_configuration "${DATA_PATH}" "${SOURCE_PATH}" "${SITE}" \
  || { echo "[configuration] WARNING: copy failed."; [[ "${IGNORE_RETURN_VALUES}" == "true" ]] && exit 0 || exit 2; }

_save_hash "${STATE_PATH}" "configuration" "${_combined_hash}"
echo "[configuration] done."
if [[ "${IGNORE_RETURN_VALUES}" == "true" ]]; then
  exit 0
fi
exit 1
#endregion
