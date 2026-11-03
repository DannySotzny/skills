#!/bin/bash
# Retrieve existing analysis trail for a finding
# Usage: dtrack-audit-get.sh <project-uuid> <component-uuid> <vulnerability-uuid>
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
PROJECT_UUID="${1:-}"; COMPONENT_UUID="${2:-}"; VULNERABILITY_UUID="${3:-}"

if [[ -z "$PROJECT_UUID" || -z "$COMPONENT_UUID" || -z "$VULNERABILITY_UUID" ]]; then
    echo "Usage: $0 <project-uuid> <component-uuid> <vulnerability-uuid>" >&2; exit 1
fi
dt_require_uuid "project-uuid" "$PROJECT_UUID"
dt_require_uuid "component-uuid" "$COMPONENT_UUID"
dt_require_uuid "vulnerability-uuid" "$VULNERABILITY_UUID"

"$SCRIPT_DIR/dtrack-api.sh" GET \
    "/v1/analysis?project=${PROJECT_UUID}&component=${COMPONENT_UUID}&vulnerability=${VULNERABILITY_UUID}" | \
    jq '{ analysisState, analysisJustification, analysisResponse, analysisDetails, isSuppressed,
          comments: [.analysisComments[]? | { timestamp, commenter, comment }] }'
