#!/bin/bash
# Interactive setup for the Dependency-Track skill
# Writes ~/.boring/dependency-track/{url,apikey} and verifies connectivity.
# Usage: dtrack-setup.sh [--check]
#   --check   Only verify the existing configuration (no prompts, no writes)
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CFG_DIR="${DTRACK_CONFIG_DIR:-$HOME/.boring/dependency-track}"

CHECK_ONLY="false"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) CHECK_ONLY="true"; shift ;;
        -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; echo "Usage: $0 [--check]" >&2; exit 1 ;;
    esac
done

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
  Windows:        winget install jqlang.jq   (curl and base64 ship with Git Bash)
EOF
        exit 1
    fi
}

verify() {
    echo "Verifying connection to $(cat "${CFG_DIR}/url" 2>/dev/null || echo "${DTRACK_URL:-<unset>}")..." >&2
    if "$SCRIPT_DIR/dtrack-api.sh" GET "/v1/project?pageSize=1" >/dev/null; then
        echo "OK: Dependency-Track API reachable and API key accepted." >&2
    else
        echo "Connectivity check failed (see error above). Config: ${CFG_DIR}/" >&2
        exit 1
    fi
}

write_secure() {
    local file="$1" value="$2"
    ( umask 077; printf '%s\n' "$value" > "$file" )
    chmod 600 "$file" 2>/dev/null || true
}

check_deps

if [[ "$CHECK_ONLY" == "true" ]]; then
    verify
    exit 0
fi

if [[ ! -t 0 ]]; then
    cat >&2 <<EOF
ERROR: dtrack-setup.sh is interactive and needs a terminal.

Context: stdin is not a TTY, so the URL and API key cannot be prompted for.

Recovery (non-interactive):
  mkdir -p ${CFG_DIR}
  echo 'https://your-dtrack.example.com' > ${CFG_DIR}/url
  echo 'your-api-key' > ${CFG_DIR}/apikey
  chmod 600 ${CFG_DIR}/apikey
  $0 --check
EOF
    exit 1
fi

echo "Dependency-Track skill setup"
echo "Config directory: ${CFG_DIR}"
echo ""

if [[ -f "${CFG_DIR}/url" && -f "${CFG_DIR}/apikey" ]]; then
    read -r -p "Existing config found. Reconfigure? [y/N] " reconf
    if [[ ! "$reconf" =~ ^[Yy] ]]; then
        verify
        exit 0
    fi
fi

mkdir -p "$CFG_DIR"
chmod 700 "$CFG_DIR" 2>/dev/null || true

url=""
while [[ -z "$url" ]]; do
    read -r -p "Server URL (e.g. https://dtrack.example.com): " url
    url="$(printf '%s' "$url" | tr -d '[:space:]')"
done
[[ "$url" =~ ^https?:// ]] || url="https://${url}"
url="${url%/}"
url="${url%/api}"

cat <<EOF

How to get an API key:
  1. Open ${url} in your browser
  2. Go to Administration -> Access Management -> Teams
  3. Select (or create) a team with these permissions:
       VIEW_PORTFOLIO, VIEW_VULNERABILITY,
       VULNERABILITY_ANALYSIS, VIEW_POLICY_VIOLATION
  4. Under "API Keys" click "+ Generate" and copy the key

EOF

key=""
while [[ -z "$key" ]]; do
    read -r -s -p "API key (input hidden): " key
    echo ""
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
done

write_secure "${CFG_DIR}/url" "$url"
write_secure "${CFG_DIR}/apikey" "$key"
echo "Saved ${CFG_DIR}/url and ${CFG_DIR}/apikey"
echo ""

verify
