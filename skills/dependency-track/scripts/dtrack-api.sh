#!/bin/bash
# Raw Dependency-Track API access (only ever talks to the configured DTRACK_URL)
# Usage: dtrack-api.sh <METHOD> <endpoint> [-d JSON | --data-file FILE]
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

_usage() {
    cat >&2 <<EOF
Usage: $0 <METHOD> <endpoint> [-d JSON | --data-file FILE]
  $0 GET /v1/project
  $0 PUT /v1/analysis -d '{...}'
METHOD: GET, POST, PUT, PATCH, DELETE. Endpoint: path below /api, starting with /v1/.
EOF
    exit 1
}

METHOD="${1:-}"; ENDPOINT="${2:-}"; shift 2 2>/dev/null || true
[[ -z "$METHOD" || -z "$ENDPOINT" ]] && _usage

case "$METHOD" in
    GET|POST|PUT|PATCH|DELETE) ;;
    *) echo "ERROR: unsupported HTTP method '${METHOD}'." >&2; _usage ;;
esac

# The endpoint is appended to the configured server URL, so it must be a plain path:
# no scheme, no second host, no whitespace or control characters.
_bad_endpoint=false
[[ "$ENDPOINT" =~ ^/v[0-9]+/ ]] || _bad_endpoint=true
case "$ENDPOINT" in *"://"*|*[[:space:][:cntrl:]]*|*'@'*|*'\'*) _bad_endpoint=true ;; esac
if [[ "$_bad_endpoint" == "true" ]]; then
    echo "ERROR: endpoint must be an API path like /v1/project (got: '${ENDPOINT}')." >&2
    exit 1
fi

# Only a request body is accepted as extra input; arbitrary curl options are refused
# so no other host, output file or upload can be smuggled in.
BODY=""; BODY_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--data)   [[ $# -ge 2 ]] || _usage; BODY="$2"; shift 2 ;;
        --data-file) [[ $# -ge 2 && -f "$2" ]] || { echo "ERROR: --data-file needs an existing file." >&2; exit 1; }
                     BODY_FILE="$2"; shift 2 ;;
        *) echo "ERROR: unsupported argument '$1'. Only -d JSON or --data-file FILE are allowed." >&2; exit 1 ;;
    esac
done

source "$SCRIPT_DIR/_config.sh"

_CURL_CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-10}"
_CURL_MAX_TIME="${CURL_MAX_TIME:-30}"
_CURL_RETRIES="${CURL_RETRIES:-2}"

# Retry curl on transient transport failures (connection refused, timeout, empty reply, recv failure).
_retry_curl() {
    local _attempt=0 _max=$((_CURL_RETRIES + 1)) _wait=1 _rc=0
    while [ $_attempt -lt $_max ]; do
        _attempt=$((_attempt + 1))
        curl "$@" && return 0
        _rc=$?
        case $_rc in
            7|28|52|56)
                if [ $_attempt -lt $_max ]; then
                    echo "RETRY: curl failed (exit ${_rc}), attempt ${_attempt}/${_max}. Waiting ${_wait}s..." >&2
                    sleep $_wait
                    _wait=$((_wait * 2))
                    continue
                fi ;;
        esac
        return $_rc
    done
    return $_rc
}

# Temp files: response body, request headers (API key stays off the command line), request body
_tmpdir=$(mktemp -d)
chmod 700 "$_tmpdir" 2>/dev/null || true
trap 'rm -rf "$_tmpdir"' EXIT
( umask 077; printf 'X-Api-Key: %s\n' "$DTRACK_API_KEY" > "$_tmpdir/headers" )

_data_args=()
if [[ -n "$BODY_FILE" ]]; then
    _data_args=(--data-binary "@${BODY_FILE}")
elif [[ -n "$BODY" ]]; then
    ( umask 077; printf '%s' "$BODY" > "$_tmpdir/body" )
    _data_args=(--data-binary "@${_tmpdir}/body")
fi

_URL="${DTRACK_URL}/api${ENDPOINT}"
# No -L: redirects are never followed, so the API key header cannot be forwarded to another host.
_code=$(_retry_curl -s --proto '=http,https' --max-redirs 0 \
    --connect-timeout "$_CURL_CONNECT_TIMEOUT" --max-time "$_CURL_MAX_TIME" \
    -w "%{http_code}" -o "$_tmpdir/response" \
    -X "$METHOD" \
    -H "@${_tmpdir}/headers" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    "${_data_args[@]}" \
    "$_URL") || _code="000"
_body=$(cat "$_tmpdir/response" 2>/dev/null || true)

if [[ "$_code" -ge 200 && "$_code" -lt 300 ]]; then
    printf '%s' "$_body"
else
    cat >&2 <<EOF
ERROR: Dependency-Track API returned HTTP ${_code}.

Context: ${METHOD} ${_URL}
Response: $(printf '%.500s' "$_body")

Common causes:
  - HTTP 3xx: server redirected; redirects are not followed for safety. Fix the URL (e.g. http -> https, trailing path)
  - HTTP 401: API key invalid or expired. Regenerate in Dependency-Track > Administration > Access Management
  - HTTP 403: API key lacks required permission (e.g., VIEW_PORTFOLIO, VULNERABILITY_ANALYSIS)
  - HTTP 404: project UUID or endpoint does not exist. Verify with dtrack-projects.sh
  - HTTP 000: network unreachable or DNS failure. Check DTRACK_URL in ${_DTRACK_CONFIG_DIR}/url

Recovery: verify connectivity with: dtrack-setup.sh --check
EOF
    exit 1
fi
