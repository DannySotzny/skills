#!/bin/bash
# List vulnerability findings for a project
# Usage: dtrack-findings.sh <project-uuid> [--suppressed] [--source SRC] [--cve ID] [--severity SEV]
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
PROJECT_UUID="${1:-}"; shift 2>/dev/null || true

SUPPRESSED="false"; SOURCE=""; CVE_FILTER=""; SEVERITY_FILTER=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --suppressed) SUPPRESSED="true"; shift ;;
        --source)   SOURCE="${2:-}"; shift 2 ;;
        --cve)      CVE_FILTER="${2:-}"; shift 2 ;;
        --severity) SEVERITY_FILTER="${2:-}"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$PROJECT_UUID" ]]; then
    echo "Usage: $0 <project-uuid> [--suppressed] [--source SRC] [--cve ID] [--severity SEV]" >&2
    echo "Sources: NVD, NPM, GITHUB, VULNDB, OSSINDEX, OSV, SNYK, TRIVY" >&2
    exit 1
fi
dt_require_uuid "project-uuid" "$PROJECT_UUID"
[[ -n "$SEVERITY_FILTER" ]] && dt_require_enum "--severity" "CRITICAL HIGH MEDIUM LOW INFO UNASSIGNED" "$SEVERITY_FILTER"

ENDPOINT="/v1/finding/project/${PROJECT_UUID}?suppressed=${SUPPRESSED}"
[[ -n "$SOURCE" ]] && ENDPOINT="${ENDPOINT}&source=$(dt_urlencode "$SOURCE")"

"$SCRIPT_DIR/dtrack-api.sh" GET "$ENDPOINT" | jq --arg cve "$CVE_FILTER" --arg sev "$SEVERITY_FILTER" '[.[]
    | select($cve == "" or .vulnerability.vulnId == $cve)
    | select($sev == "" or .vulnerability.severity == $sev)
    | {
    component: { uuid: .component.uuid, name: .component.name, version: .component.version, group: .component.group, purl: .component.purl },
    vulnerability: {
        uuid: .vulnerability.uuid, vulnId: .vulnerability.vulnId,
        source: .vulnerability.source, severity: .vulnerability.severity,
        severityRank: .vulnerability.severityRank,
        title: .vulnerability.title,
        description: (.vulnerability.description // "" | if length > 200 then .[0:200] + "..." else . end),
        cvssV3BaseScore: .vulnerability.cvssV3BaseScore,
        epssScore: .vulnerability.epssScore, epssPercentile: .vulnerability.epssPercentile,
        cwes: .vulnerability.cwes
    },
    analysis: { state: .analysis.analysisState, isSuppressed: .analysis.isSuppressed },
    attribution: { analyzerIdentity: .attribution.analyzerIdentity, attributedOn: .attribution.attributedOn }
}] | sort_by(.vulnerability.severityRank)'
