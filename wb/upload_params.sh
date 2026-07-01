#!/bin/bash
echo "NOTE: upload_params.sh is deprecated."
echo "Pipeline params are now uploaded by upload_pipeline.sh along with all other pipeline files."
echo ""
echo "Running upload_pipeline.sh instead..."
exec "$(dirname "$0")/upload_pipeline.sh"
