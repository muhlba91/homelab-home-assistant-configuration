#!/bin/bash
set -euo pipefail

FILES=(
  "sites/vie/configuration/secrets.yaml"
)

COMMAND=${1}
SOURCE_PATH=${2:-.}

#region encryption and decryption
for file in ${FILES[@]}; do
  IFS='.' read -ra data <<< "${file}"
  
  if [[ "${COMMAND}" == "d" ]]; then
    echo "[sops] decrypting file ${file}"
    sops -d ${SOURCE_PATH}/${data[0]}.enc.${data[1]:-} > ${SOURCE_PATH}/${file}
  else
    echo "[sops] encrypting file ${file}"
    sops -e ${SOURCE_PATH}/${file} > ${SOURCE_PATH}/${data[0]}.enc.${data[1]:-}
  fi
done
#endregion
