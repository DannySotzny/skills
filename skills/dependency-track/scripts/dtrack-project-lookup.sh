#!/bin/bash
# Lookup project by name (and optionally version)
# Usage: dtrack-project-lookup.sh <name> [version]
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

NAME="${1:-}"; VERSION="${2:-}"
[[ -z "$NAME" ]] && { echo "Usage: $0 <project-name> [version]" >&2; exit 1; }

ENDPOINT="/v1/project/lookup?name=$(dt_urlencode "$NAME")"
[[ -n "$VERSION" ]] && ENDPOINT="${ENDPOINT}&version=$(dt_urlencode "$VERSION")"

"$SCRIPT_DIR/dtrack-api.sh" GET "$ENDPOINT"
