#!/bin/bash
# List services for a project
# Usage: dtrack-services.sh <project-uuid> [page]
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
PROJECT_UUID="${1:-}"; PAGE="${2:-1}"

[[ -z "$PROJECT_UUID" ]] && { echo "Usage: $0 <project-uuid> [page]" >&2; exit 1; }
dt_require_uuid "project-uuid" "$PROJECT_UUID"
dt_require_int "page" "$PAGE"

"$SCRIPT_DIR/dtrack-api.sh" GET "/v1/service/project/${PROJECT_UUID}?pageNumber=${PAGE}&pageSize=100" | \
    jq '[.[] | { uuid, name, version, group, description, authenticated, crossesTrustBoundary, endpoints }]'
