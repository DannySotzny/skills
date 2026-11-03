#!/bin/bash
# List components (dependencies) for a project
# Usage: dtrack-components.sh <project-uuid> [--page N] [--search NAME]
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

PROJECT_UUID=""; PAGE="1"; SEARCH=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --page)   PAGE="${2:-}";   shift 2 ;;
        --search) SEARCH="${2:-}"; shift 2 ;;
        -*)       echo "Unknown option: $1" >&2; exit 1 ;;
        *)        [[ -z "$PROJECT_UUID" ]] && PROJECT_UUID="$1"; shift ;;
    esac
done

[[ -z "$PROJECT_UUID" ]] && { echo "Usage: $0 <project-uuid> [--page N] [--search NAME]" >&2; exit 1; }
dt_require_uuid "project-uuid" "$PROJECT_UUID"
dt_require_int "--page" "$PAGE"

ENDPOINT="/v1/component/project/${PROJECT_UUID}?pageNumber=${PAGE}&pageSize=100"
[[ -n "$SEARCH" ]] && ENDPOINT="${ENDPOINT}&searchText=$(dt_urlencode "$SEARCH")"

"$SCRIPT_DIR/dtrack-api.sh" GET "$ENDPOINT" | jq '[.[] | { uuid, group, name, version, purl, classifier, license, isInternal }]'
