#!/bin/bash
# Dependency-Track configuration loader
set -e

_DTRACK_CONFIG_DIR="${DTRACK_CONFIG_DIR:-$HOME/.boring/dependency-track}"
_DTRACK_SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dtrack-setup.sh"

# Read URL from file
if [ -z "$DTRACK_URL" ] && [ -f "${_DTRACK_CONFIG_DIR}/url" ]; then
    DTRACK_URL=$(tr -d '[:space:]' < "${_DTRACK_CONFIG_DIR}/url")
fi

DTRACK_URL="${DTRACK_URL:-}"
DTRACK_URL="${DTRACK_URL%/}"
DTRACK_API_KEY_FILE="${DTRACK_API_KEY_FILE:-${_DTRACK_CONFIG_DIR}/apikey}"

if [ -z "$DTRACK_URL" ]; then
    cat >&2 <<EOF
ERROR: DTRACK_URL not set.

Context: Loading Dependency-Track configuration from ${_DTRACK_CONFIG_DIR}/

The Dependency-Track server URL must be configured before any operations can run.

Recovery:
  ${_DTRACK_SETUP} --url https://your-dtrack.example.com
  then, in your own terminal: ${_DTRACK_SETUP} --key
EOF
    exit 1
fi

# Only scheme://host[:port][/path] - no credentials, query or fragment in the base URL
if [[ ! "$DTRACK_URL" =~ ^https?://[A-Za-z0-9.-]+(:[0-9]+)?(/[A-Za-z0-9._~/-]*)?$ ]]; then
    cat >&2 <<EOF
ERROR: DTRACK_URL is not a valid server URL: ${DTRACK_URL}

Context: Expected scheme://host[:port][/path], e.g. https://dtrack.example.com

Recovery: ${_DTRACK_SETUP} --url https://your-dtrack.example.com
EOF
    exit 1
fi

if [[ "$DTRACK_URL" == http://* && "${DTRACK_ALLOW_HTTP:-}" != "1" ]]; then
    echo "WARNING: ${DTRACK_URL} uses plain HTTP - the API key is sent unencrypted. Use https, or set DTRACK_ALLOW_HTTP=1 to silence this warning." >&2
fi

if [ ! -f "$DTRACK_API_KEY_FILE" ]; then
    cat >&2 <<EOF
ERROR: API key file not found at ${DTRACK_API_KEY_FILE}

Context: Loading Dependency-Track API key for ${DTRACK_URL}

Recovery (run in your own terminal - never paste the key into a chat):
  ${_DTRACK_SETUP} --key

Generate an API key at: ${DTRACK_URL} > Administration > Access Management > Teams
EOF
    exit 1
fi

DTRACK_API_KEY=$(tr -d '[:space:]' < "$DTRACK_API_KEY_FILE")
if [ -z "$DTRACK_API_KEY" ]; then
    cat >&2 <<EOF
ERROR: API key file is empty at ${DTRACK_API_KEY_FILE}

Context: Loading Dependency-Track API key for ${DTRACK_URL}

The file exists but contains no API key value.

Recovery (run in your own terminal - never paste the key into a chat):
  ${_DTRACK_SETUP} --key

Generate an API key at: ${DTRACK_URL} > Administration > Access Management > Teams
EOF
    exit 1
fi
