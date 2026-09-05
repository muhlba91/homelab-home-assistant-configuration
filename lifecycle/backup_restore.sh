#!/bin/bash
set -euo pipefail

DATA_PATH=${1}

#region global configuration
S3_ASSETS_BUCKET_BACKUP_PATH="${S3_ASSETS_BUCKET}/${S3_ASSETS_BUCKET_PATH}/home-assistant"
#endregion

#region functions
# Check whether an existing HA data installation is present.
# Returns: 0 if secrets.yaml exists in DATA_PATH; 1 otherwise
function data_exists() {
  test -f "${DATA_PATH}/secrets.yaml"
}

# Upload the current .storage directory to S3.
function backup() {
  echo "[backup_restore] backing up..."

  echo "[backup_restore] uploading storage..."
  s3cmd --access_key="${SCW_ACCESS_KEY}" --secret_key="${SCW_SECRET_KEY}" --host="https://s3.${SCW_DEFAULT_REGION}.scw.cloud" --host-bucket="https://%(bucket)s.s3.${SCW_DEFAULT_REGION}.scw.cloud" --recursive --delete-removed --force --exclude-from .s3ignore sync "${DATA_PATH}/.storage/" "s3://${S3_ASSETS_BUCKET_BACKUP_PATH}/"
}

# Wipe DATA_PATH and restore .storage from S3.
function restore() {
  echo "[backup_restore] restoring..."

  echo "[backup_restore] wiping data..."
  rm -rf "${DATA_PATH:?}/"*
  mkdir -p "${DATA_PATH}/.storage"

  echo "[backup_restore] downloading and restoring storage..."
  s3cmd --access_key="${SCW_ACCESS_KEY}" --secret_key="${SCW_SECRET_KEY}" --host="https://s3.${SCW_DEFAULT_REGION}.scw.cloud" --host-bucket="https://%(bucket)s.s3.${SCW_DEFAULT_REGION}.scw.cloud" --recursive --force sync "s3://${S3_ASSETS_BUCKET_BACKUP_PATH}/" "${DATA_PATH}/.storage/"
}
#endregion

#region log configuration
echo "[backup_restore] using S3 bucket and path: ${S3_ASSETS_BUCKET_BACKUP_PATH}"
#endregion

#region backup or restore
# if data exists we perform a backup; otherwise restore to a fresh setup
if data_exists; then
  backup
else
  restore
fi
#endregion
