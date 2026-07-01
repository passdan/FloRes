#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source Workbench environment configuration
CONFIG_FILE="${SCRIPT_DIR}/config/wb.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    echo "Create it from the template: cp ${SCRIPT_DIR}/config/wb.env.template ${CONFIG_FILE}"
    exit 1
fi

source "$CONFIG_FILE"

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
    1>&2 echo "Error: Not authenticated with gcloud. Run: gcloud auth login"
    exit 1
fi

if [[ -z "${GOOGLE_CLOUD_PROJECT:-}" ]]; then
    1>&2 echo "Error: GOOGLE_CLOUD_PROJECT not set. Check your wb.env configuration."
    exit 1
fi

echo "Project: ${GOOGLE_CLOUD_PROJECT}"
echo ""

# Create GCS bucket via Workbench
WB_BUCKET_ID="${WB_BUCKET_RESOURCE_ID:-}"
if [[ -z "$WB_BUCKET_ID" ]]; then
    1>&2 echo "Error: WB_BUCKET_RESOURCE_ID not set. Check your wb.env configuration."
    exit 1
fi

if wb resource describe --id="${WB_BUCKET_ID}" &>/dev/null; then
    echo "GCS bucket resource already exists: ${WB_BUCKET_ID}"
else
    echo "Creating GCS bucket via Workbench: ${WB_BUCKET_ID}"
    wb resource create gcs-bucket --id="${WB_BUCKET_ID}"
fi

export GCS_BUCKET=$(wb resource describe --id="${WB_BUCKET_ID}" 2>/dev/null | grep "GCS bucket name" | awk -F': ' '{print $2}' | xargs)
echo "Resolved GCS bucket: ${GCS_BUCKET}"

# Create Artifact Registry repository
ARTIFACT_LOCATION="${GCS_BUCKET_LOCATION:-us-central1}"

if gcloud artifacts repositories describe "${GOOGLE_ARTIFACT_REPO}" --location="${ARTIFACT_LOCATION}" --project="${GOOGLE_CLOUD_PROJECT}" &>/dev/null; then
    echo "Artifact repository already exists: ${GOOGLE_ARTIFACT_REPO}"
else
    echo "Creating artifact repository: ${GOOGLE_ARTIFACT_REPO}"
    gcloud artifacts repositories create "${GOOGLE_ARTIFACT_REPO}" \
        --repository-format=docker \
        --location="${ARTIFACT_LOCATION}" \
        --project="${GOOGLE_CLOUD_PROJECT}"
fi

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Build and push container:  ./wb/build.sh --env wb --push"
echo "  2. Upload reference data:     ./wb/upload_data.sh wb"
echo "  3. Upload pipeline source:    ./wb/upload_pipeline.sh"
