#!/bin/bash
set -euo pipefail

DATA_PATH=${1}
SOURCE_PATH=${2:-.}

#region custom components
echo "[custom_components] wiping all existing components..."
rm -rf ${DATA_PATH}/custom_components
mkdir -p ${DATA_PATH}/custom_components || true

while read -r component; do
  if [ ! ${component:0:1} = \# ]; then
    IFS='@' read -ra data <<< "${component}"
    echo "[custom_components] processing ${data[0]} at version ${data[1]}"
    git clone --quiet --depth 1 --branch ${data[1]} ${data[0]} /tmp/component &> /dev/null
    cp -rf /tmp/component/custom_components/* ${DATA_PATH}/custom_components/
    rm -rf /tmp/component
  fi
done < ${SOURCE_PATH}/common/components/custom_components.txt

rm ${DATA_PATH}/custom_components/__init__.py
#endregion

echo ""

#region www components
echo "[www_components] wiping all existing components..."
rm -rf ${DATA_PATH}/www
mkdir -p ${DATA_PATH}/www || true

while read -r component; do
  if [ ! ${component:0:1} = \# ]; then
    IFS='@' read -ra data <<< "${component}"
    echo "[www_components] processing ${data[0]}/${data[1]}/${data[2]} to ${data[3]}"
    mkdir -p ${DATA_PATH}/www/${data[3]} || true
    wget -P ${DATA_PATH}/www/${data[3]} ${data[0]}/${data[1]}/${data[2]} &> /dev/null
  fi
done < ${SOURCE_PATH}/common/components/www_components.txt
#endregion
