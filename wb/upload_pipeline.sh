#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."

CONFIG_FILE="${SCRIPT_DIR}/config/wb.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    echo "Create it from the template: cp ${SCRIPT_DIR}/config/wb.env.template ${CONFIG_FILE}"
    exit 1
fi

source "$CONFIG_FILE"
export GOOGLE_CLOUD_PROJECT GOOGLE_SERVICE_ACCOUNT_EMAIL GCS_BUCKET GCS_REF_BUCKET GCS_BUCKET_LOCATION GOOGLE_ARTIFACT_REPO REGISTRY_PATH

if [[ -z "${GCS_BUCKET:-}" ]]; then
    echo "Error: GCS_BUCKET is not set. Check your wb.env configuration."
    exit 1
fi

STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

ENVSUBST_VARS='${GOOGLE_CLOUD_PROJECT} ${GOOGLE_SERVICE_ACCOUNT_EMAIL} ${GCS_BUCKET} ${GCS_REF_BUCKET} ${GCS_BUCKET_LOCATION} ${GOOGLE_ARTIFACT_REPO} ${REGISTRY_PATH}'

echo "Resolving nextflow.config..."
envsubst "$ENVSUBST_VARS" < "${REPO_ROOT}/nextflow.config" > "${STAGING_DIR}/nextflow.config"

echo "Resolving params_google_batch.yaml..."
envsubst "$ENVSUBST_VARS" < "${REPO_ROOT}/params_google_batch.yaml" > "${STAGING_DIR}/params_google_batch.yaml"

DEST="gs://${GCS_BUCKET}/pipeline"

echo "Uploading pipeline to ${DEST}/..."

gcloud storage cp "${STAGING_DIR}/nextflow.config" "${DEST}/"
gcloud storage cp "${STAGING_DIR}/params_google_batch.yaml" "${DEST}/"

gcloud storage cp "${REPO_ROOT}/main_AMRplusplus.nf" "${DEST}/"
gcloud storage cp "${REPO_ROOT}/params.config" "${DEST}/"
gcloud storage cp "${REPO_ROOT}/params_google_batch.config" "${DEST}/"

gcloud storage cp -r "${REPO_ROOT}/modules" "${DEST}/"
gcloud storage cp -r "${REPO_ROOT}/subworkflows" "${DEST}/"
gcloud storage cp -r "${REPO_ROOT}/config" "${DEST}/"
gcloud storage cp -r "${REPO_ROOT}/bin" "${DEST}/"

echo ""
echo "Upload complete!"
echo "Pipeline uploaded to: ${DEST}/"
echo ""
echo "In the Workbench UI, add a workflow from workspace bucket"
echo "with bucket '${GCS_BUCKET}' and prefix 'pipeline/'."
