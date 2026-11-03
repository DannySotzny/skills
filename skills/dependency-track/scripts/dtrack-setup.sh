#!/bin/bash
# Setup for the Dependency-Track skill: writes ~/.boring/dependency-track/{url,apikey}
# Usage: dtrack-setup.sh [--check | --status | --url URL | --key]
#   (no option)  Interactive: prompt for URL and API key (needs a terminal)
#   --status     Print what is configured (never prints the key); exit 0 if complete
#   --check      Verify the configuration against the server
#   --url URL    Save the server URL (non-interactive; safe for an agent to run)
#   --key        Prompt for the API key with hidden input (run this yourself, in a terminal)
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CFG_DIR="${DTRACK_CONFIG_DIR:-$HOME/.boring/dependency-track}"
SELF="${SCRIPT_DIR}/dtrack-setup.sh"

MODE="interactive"; URL_ARG=""
case "${1:-}" in
    "")       ;;
    --check)  MODE="check" ;;
    --status) MODE="status" ;;
    --key)    MODE="key" ;;
    --url)    MODE="url"; URL_ARG="${2:-}"
              [[ -z "$URL_ARG" ]] && { echo "Usage: $0 --url https://dtrack.example.com" >&2; exit 1; } ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; echo "Usage: $0 [--check | --status | --url URL | --key]" >&2; exit 1 ;;
esac

check_deps() {
    local missing=""
    for cmd in curl jq base64; do
        command -v "$cmd" >/dev/null 2>&1 || missing="${missing} ${cmd}"
    done
    if [[ -n "$missing" ]]; then
        cat >&2 <<EOF
ERROR: Missing required tools:${missing}

Context: The Dependency-Track scripts need curl, jq and base64 on PATH.

Recovery:
  macOS:          brew install curl jq
  Debian/Ubuntu:  sudo apt-get install curl jq coreutils
  Windows:        winget install jqlang.jq   (curl and base64 ship with Git Bash; restart Claude afterwards)
EOF
        exit 1
    fi
}

require_tty() {
    if [[ ! -t 0 ]]; then
        cat >&2 <<EOF
ERROR: This step is interactive and needs a terminal.

Context: stdin is not a TTY, so nothing can be prompted for.

Recovery: open a terminal (Git Bash on Windows) and run:
  ${SELF} $1
EOF
        exit 1
    fi
}

write_secure() {
    local file="$1" value="$2"
    mkdir -p "$CFG_DIR"
    chmod 700 "$CFG_DIR" 2>/dev/null || true
    ( umask 077; printf '%s\n' "$value" > "$file" )
    chmod 600 "$file" 2>/dev/null || true
}

normalize_url() {
    local url
    url="$(printf '%s' "$1" | tr -d '[:space:]')"
    [[ "$url" =~ ^https?:// ]] || url="https://${url}"
    url="${url%/}"
    url="${url%/api}"
    printf '%s' "$url"
}

save_url() {
    local url; url="$(normalize_url "$1")"
    if [[ ! "$url" =~ ^https?://[A-Za-z0-9.-]+(:[0-9]+)?(/[A-Za-z0-9._~/-]*)?$ ]]; then
        echo "ERROR: not a valid server URL: ${url} (expected https://host[:port][/path])" >&2
        exit 1
    fi
    write_secure "${CFG_DIR}/url" "$url"
    echo "Saved server URL ${url} to ${CFG_DIR}/url" >&2
    [[ "$url" == http://* ]] && echo "WARNING: plain HTTP sends the API key unencrypted. Prefer https." >&2
    return 0
}

print_key_help() {
    local url; url="$(cat "${CFG_DIR}/url" 2>/dev/null || echo '<your server>')"
    cat >&2 <<EOF

How to get an API key:
  1. Open ${url} in your browser
  2. Go to Administration -> Access Management -> Teams
  3. Select (or create) a team with these permissions:
       VIEW_PORTFOLIO, VIEW_VULNERABILITY,
       VULNERABILITY_ANALYSIS, VIEW_POLICY_VIOLATION
  4. Under "API Keys" click "+ Generate" and copy the key

EOF
}

prompt_key() {
    local key=""
    print_key_help
    while [[ -z "$key" ]]; do
        read -r -s -p "API key (input hidden): " key
        echo "" >&2
        key="$(printf '%s' "$key" | tr -d '[:space:]')"
    done
    write_secure "${CFG_DIR}/apikey" "$key"
    echo "Saved API key to ${CFG_DIR}/apikey (mode 600)" >&2
}

status() {
    local ok=0
    if [[ -n "${DTRACK_URL:-}" ]]; then echo "url:    ${DTRACK_URL} (from DTRACK_URL)"
    elif [[ -s "${CFG_DIR}/url" ]]; then echo "url:    $(cat "${CFG_DIR}/url")"
    else echo "url:    MISSING -> ${SELF} --url https://your-dtrack.example.com"; ok=1; fi
    local keyfile="${DTRACK_API_KEY_FILE:-${CFG_DIR}/apikey}"
    if [[ -s "$keyfile" ]]; then echo "apikey: present (${keyfile})"
    else echo "apikey: MISSING -> the user runs in their own terminal: ${SELF} --key"; ok=1; fi
    if command -v jq >/dev/null 2>&1; then echo "jq:     ok"
    else echo "jq:     MISSING -> winget install jqlang.jq (Windows) / brew install jq / apt-get install jq"; ok=1; fi
    return $ok
}

verify() {
    check_deps
    echo "Verifying connection..." >&2
    if "$SCRIPT_DIR/dtrack-api.sh" GET "/v1/project?pageSize=1" >/dev/null; then
        echo "OK: Dependency-Track API reachable and API key accepted." >&2
    else
        echo "Connectivity check failed (see error above). Config: ${CFG_DIR}/" >&2
        exit 1
    fi
}

case "$MODE" in
    status) status ;;
    check)  verify ;;
    url)    save_url "$URL_ARG"
            [[ -s "${CFG_DIR}/apikey" ]] || echo "Next: the user stores the API key in their own terminal: ${SELF} --key" >&2 ;;
    key)    require_tty "--key"
            [[ -s "${CFG_DIR}/url" ]] || { echo "ERROR: set the URL first: ${SELF} --url https://..." >&2; exit 1; }
            prompt_key
            verify ;;
    interactive)
        check_deps
        require_tty ""
        echo "Dependency-Track skill setup"
        echo "Config directory: ${CFG_DIR}"
        echo ""
        if [[ -s "${CFG_DIR}/url" && -s "${CFG_DIR}/apikey" ]]; then
            read -r -p "Existing config found. Reconfigure? [y/N] " reconf
            if [[ ! "$reconf" =~ ^[Yy] ]]; then verify; exit 0; fi
        fi
        url=""
        while [[ -z "$url" ]]; do
            read -r -p "Server URL (e.g. https://dtrack.example.com): " url
        done
        save_url "$url"
        prompt_key
        verify ;;
esac
