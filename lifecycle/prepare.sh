#!/bin/bash
set -euo pipefail

DATA_PATH=${1}
SOURCE_PATH=${2:-.}
STATE_PATH=${3:-$(mktemp -d)}
IGNORE_RETURN_VALUES=${4:-false}

mkdir -p "${STATE_PATH}"

# shellcheck source=./util.sh
source "$(dirname "${BASH_SOURCE[0]}")/util.sh"

#region functions
# Clone and install all custom components listed in custom_components.txt.
# Args:    (none) — reads SOURCE_PATH, DATA_PATH, STATE_PATH from scope
# Returns: 0 if unchanged; 1 if changed and applied; 2 on error
function install_custom_components() {
  local manifest="${SOURCE_PATH}/common/components/custom_components.txt"
  local current_hash
  current_hash=$(_sha256 "${manifest}")

  if ! _has_changed "${STATE_PATH}" "custom_components" "${current_hash}"; then
    echo "[custom_components] manifest unchanged — skipping."
    return 0
  fi

  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "${tmp}"' RETURN

  echo "[custom_components] downloading into temporary directory ${tmp}..."

  while read -r component; do
    if [ ! "${component:0:1}" = \# ]; then
      IFS='@' read -ra data <<< "${component}"
      echo "[custom_components] cloning ${data[0]} at version ${data[1]}..."
      local clone_err
      clone_err=$(git clone --quiet --depth 1 --branch "${data[1]}" "${data[0]}" "${tmp}/component" 2>&1) \
        || { echo "[custom_components] ERROR: git clone failed for ${data[0]}: ${clone_err}"; return 2; }
      cp -rf "${tmp}/component/custom_components/"* "${tmp}/"
      rm -rf "${tmp}/component"
      echo "[custom_components] cloned: ${data[0]}"
    fi
  done < "${manifest}"

  rm -f "${tmp}/__init__.py"

  echo "[custom_components] all downloads succeeded — installing into ${DATA_PATH}/custom_components..."
  rm -rf "${DATA_PATH}/custom_components"
  mkdir -p "${DATA_PATH}/custom_components"
  cp -rf "${tmp}/"* "${DATA_PATH}/custom_components/"

  _save_hash "${STATE_PATH}" "custom_components" "${current_hash}"
  echo "[custom_components] done."
  return 1
}

# Download and install all www (Lovelace) components listed in www_components.txt.
# Args:    (none) — reads SOURCE_PATH, DATA_PATH, STATE_PATH from scope
# Returns: 0 if unchanged; 1 if changed and applied; 2 on error
function install_www_components() {
  local manifest="${SOURCE_PATH}/common/components/www_components.txt"
  local current_hash
  current_hash=$(_sha256 "${manifest}")

  if ! _has_changed "${STATE_PATH}" "www_components" "${current_hash}"; then
    echo "[www_components] manifest unchanged — skipping."
    return 0
  fi

  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "${tmp}"' RETURN

  echo "[www_components] downloading into temporary directory ${tmp}..."

  while read -r component; do
    if [ ! "${component:0:1}" = \# ]; then
      IFS='@' read -ra data <<< "${component}"
      echo "[www_components] processing ${data[0]}/${data[1]}/${data[2]} → ${data[3]}..."
      mkdir -p "${tmp}/${data[3]}"
      local dl_err
      if [ "${data[4]:-}" = "file" ]; then
        dl_err=$(wget -q -P "${tmp}/${data[3]}" "${data[0]}/${data[1]}/${data[2]}" 2>&1) \
          || { echo "[www_components] ERROR: download failed for ${data[2]}: ${dl_err}"; return 2; }
      elif [ "${data[4]:-}" = "zip" ]; then
        dl_err=$(wget -qO- "${data[0]}/${data[1]}/${data[2]}" 2>&1 | bsdtar -xf- -C "${tmp}/${data[3]}") \
          || { echo "[www_components] ERROR: download/extract failed for ${data[2]}: ${dl_err}"; return 2; }
      else
        dl_err=$(wget -qO- "${data[0]}/${data[1]}/${data[2]}" 2>&1 | tar xz -C "${tmp}/${data[3]}") \
          || { echo "[www_components] ERROR: download/extract failed for ${data[2]}: ${dl_err}"; return 2; }
      fi
      echo "[www_components] done: ${data[3]}"
    fi
  done < "${manifest}"

  echo "[www_components] all downloads succeeded — installing into ${DATA_PATH}/www..."
  rm -rf "${DATA_PATH}/www"
  mkdir -p "${DATA_PATH}/www"
  cp -rf "${tmp}/"* "${DATA_PATH}/www/"

  _save_hash "${STATE_PATH}" "www_components" "${current_hash}"
  echo "[www_components] done."
  return 1
}
#endregion

# exit codes: 0=unchanged  1=changed+applied  2=error
_exit=0
_rc=0

#region custom components
install_custom_components || _rc=$?
case ${_rc} in
  2) echo "[custom_components] WARNING: installation failed."; [ ${_exit} -lt 2 ] && _exit=2 ;;
  1) [ ${_exit} -lt 1 ] && _exit=1 ;;
esac
#endregion

#region www components
_rc=0
install_www_components || _rc=$?
case ${_rc} in
  2) echo "[www_components] WARNING: installation failed."; [ ${_exit} -lt 2 ] && _exit=2 ;;
  1) [ ${_exit} -lt 1 ] && _exit=1 ;;
esac
#endregion

#region result
echo "[prepare] exit code: ${_exit} (0=unchanged, 1=changed, 2=error)"
if [[ "${IGNORE_RETURN_VALUES}" == "true" ]]; then
  exit 0
fi
exit ${_exit}
#endregion
