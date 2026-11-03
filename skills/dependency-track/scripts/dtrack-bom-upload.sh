#!/bin/bash
# Upload a BOM (SBOM) to a project
# Usage: dtrack-bom-upload.sh <project-uuid> <bom-file> [--auto-create]
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

PROJECT_UUID="${1:-}"; BOM_FILE="${2:-}"; AUTO_CREATE="false"
shift 2 2>/dev/null || true
[[ "${1:-}" == "--auto-create" ]] && AUTO_CREATE="true"

if [[ -z "$PROJECT_UUID" || -z "$BOM_FILE" ]]; then
    echo "Usage: $0 <project-uuid> <bom-file> [--auto-create]" >&2; exit 1
fi
dt_require_uuid "project-uuid" "$PROJECT_UUID"
[[ ! -f "$BOM_FILE" ]] && { echo "Error: File not found: $BOM_FILE" >&2; exit 1; }

# Only CycloneDX / SPDX documents are uploaded - never arbitrary files
if ! head -c 4096 "$BOM_FILE" | grep -qiE 'bomFormat|CycloneDX|spdxVersion|SPDXID'; then
    echo "Error: ${BOM_FILE} does not look like a CycloneDX or SPDX BOM. Refusing to upload." >&2
    exit 1
fi

# Build the payload in temp files: large BOMs exceed command-line length limits (notably on Windows)
_tmpdir=$(mktemp -d)
trap 'rm -rf "$_tmpdir"' EXIT
base64 < "$BOM_FILE" | tr -d '\r\n' > "$_tmpdir/bom.b64"
jq -n --arg p "$PROJECT_UUID" --rawfile b "$_tmpdir/bom.b64" --arg a "$AUTO_CREATE" \
    '{ project: $p, bom: $b, autoCreate: ($a == "true") }' > "$_tmpdir/payload.json"

echo "Uploading BOM..." >&2
"$SCRIPT_DIR/dtrack-api.sh" PUT "/v1/bom" --data-file "$_tmpdir/payload.json" | jq '.'
echo "BOM uploaded. Metrics will update after processing." >&2
