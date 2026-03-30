#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

require_env SCW_ACCESS_KEY
require_env SCW_SECRET_KEY
require_env SCW_DEFAULT_ORGANIZATION_ID
require_env SCW_DEFAULT_PROJECT_ID
require_env SCW_DEFAULT_REGION
require_env SCW_DEFAULT_ZONE
require_env VOLUME_ID
require_env BUCKET_NAME

PREFIX="${PREFIX:-volume-backups}"
SNAPSHOT_PREFIX="${SNAPSHOT_PREFIX:-daily}"
DELETE_SNAPSHOT_AFTER_EXPORT="${DELETE_SNAPSHOT_AFTER_EXPORT:-true}"

DATE_UTC="$(date -u +%F-%H%M%S)"
SNAPSHOT_NAME="${SNAPSHOT_PREFIX}-${DATE_UTC}"
OBJECT_KEY="${PREFIX}/${SNAPSHOT_NAME}.qcow2"

log "Starting backup for volume ${VOLUME_ID}"
log "Region=${SCW_DEFAULT_REGION} Zone=${SCW_DEFAULT_ZONE} Bucket=${BUCKET_NAME} Key=${OBJECT_KEY}"

log "Creating snapshot"
SNAPSHOT_JSON="$(scw block snapshot create \
  zone="${SCW_DEFAULT_ZONE}" \
  volume-id="${VOLUME_ID}" \
  name="${SNAPSHOT_NAME}" \
  -o json)"
SNAPSHOT_ID="$(echo "${SNAPSHOT_JSON}" | jq -r '.id')"

if [[ -z "${SNAPSHOT_ID}" || "${SNAPSHOT_ID}" == "null" ]]; then
  echo "Failed to get snapshot id" >&2
  exit 1
fi

log "Snapshot created: ${SNAPSHOT_ID}"

log "Waiting for snapshot to be available"
scw block snapshot wait "${SNAPSHOT_ID}" \
  zone="${SCW_DEFAULT_ZONE}" \
  terminal-status=available \
  timeout=30m

log "Starting export to object storage"
scw block snapshot export-to-object-storage \
  zone="${SCW_DEFAULT_ZONE}" \
  snapshot-id="${SNAPSHOT_ID}" \
  bucket="${BUCKET_NAME}" \
  key="${OBJECT_KEY}"

log "Waiting for export to complete"
scw block snapshot wait "${SNAPSHOT_ID}" \
  zone="${SCW_DEFAULT_ZONE}" \
  terminal-status=available \
  timeout=1h

FINAL_STATUS="$(scw block snapshot get "${SNAPSHOT_ID}" zone="${SCW_DEFAULT_ZONE}" -o json | jq -r '.status')"
if [[ "${FINAL_STATUS}" != "available" ]]; then
  echo "Snapshot export did not complete successfully. Final status: ${FINAL_STATUS}" >&2
  exit 1
fi

log "Export complete: s3://${BUCKET_NAME}/${OBJECT_KEY}"

if [[ "${DELETE_SNAPSHOT_AFTER_EXPORT}" == "true" ]]; then
  log "Deleting temporary snapshot ${SNAPSHOT_ID}"
  scw block snapshot delete "${SNAPSHOT_ID}" zone="${SCW_DEFAULT_ZONE}"
fi

log "Backup job completed successfully"