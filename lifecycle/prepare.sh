#!/bin/bash
set -uo pipefail

DATA_PATH=${1}
SOURCE_PATH=${2:-.}

#region functions
function install_custom_components() {
  set -euo pipefail
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
        || { echo "[custom_components] ERROR: git clone failed for ${data[0]}: ${clone_err}"; return 1; }
      cp -rf "${tmp}/component/custom_components/"* "${tmp}/"
      rm -rf "${tmp}/component"
      echo "[custom_components] cloned: ${data[0]}"
    fi
  done < "${SOURCE_PATH}/common/components/custom_components.txt"

  rm -f "${tmp}/__init__.py"

  echo "[custom_components] all downloads succeeded — installing into ${DATA_PATH}/custom_components..."
  rm -rf "${DATA_PATH}/custom_components"
  mkdir -p "${DATA_PATH}/custom_components"
  cp -rf "${tmp}/"* "${DATA_PATH}/custom_components/"
  echo "[custom_components] done."
}

function install_www_components() {
  set -euo pipefail
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
          || { echo "[www_components] ERROR: download failed for ${data[2]}: ${dl_err}"; return 1; }
      elif [ "${data[4]:-}" = "zip" ]; then
        dl_err=$(wget -qO- "${data[0]}/${data[1]}/${data[2]}" 2>&1 | bsdtar -xf- -C "${tmp}/${data[3]}") \
          || { echo "[www_components] ERROR: download/extract failed for ${data[2]}: ${dl_err}"; return 1; }
      else
        dl_err=$(wget -qO- "${data[0]}/${data[1]}/${data[2]}" 2>&1 | tar xz -C "${tmp}/${data[3]}") \
          || { echo "[www_components] ERROR: download/extract failed for ${data[2]}: ${dl_err}"; return 1; }
      fi
      echo "[www_components] done: ${data[3]}"
    fi
  done < "${SOURCE_PATH}/common/components/www_components.txt"

  echo "[www_components] all downloads succeeded — installing into ${DATA_PATH}/www..."
  rm -rf "${DATA_PATH}/www"
  mkdir -p "${DATA_PATH}/www"
  cp -rf "${tmp}/"* "${DATA_PATH}/www/"
  echo "[www_components] done."
}
#endregion

#region custom components
install_custom_components \
  || echo "[custom_components] WARNING: installation failed, skipping custom components."
#endregion

echo ""

#region www components
install_www_components \
  || echo "[www_components] WARNING: installation failed, skipping www components."
#endregion
