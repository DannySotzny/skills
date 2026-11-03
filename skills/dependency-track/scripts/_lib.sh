#!/bin/bash
# Shared input helpers for the Dependency-Track scripts (sourced, not executed)

# URL-encode a string byte-wise (UTF-8 safe)
dt_urlencode() {
    local LC_ALL=C
    local string="$1" encoded="" pos c o
    for (( pos=0 ; pos<${#string} ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * ) printf -v o '%%%02X' "'$c" ;;
        esac
        encoded+="${o}"
    done
    printf '%s' "${encoded}"
}

# Exit unless $2 is a UUID. Usage: dt_require_uuid <label> <value>
dt_require_uuid() {
    if [[ ! "$2" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        echo "ERROR: ${1} must be a UUID (got: '${2}'). Find UUIDs with dtrack-projects.sh or dtrack-findings.sh." >&2
        exit 1
    fi
}

# Exit unless $2 is a positive integer. Usage: dt_require_int <label> <value>
dt_require_int() {
    if [[ ! "$2" =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: ${1} must be a positive integer (got: '${2}')." >&2
        exit 1
    fi
}

# Exit unless $3 is one of the space-separated words in $2. Usage: dt_require_enum <label> "<A B C>" <value>
dt_require_enum() {
    local v
    for v in $2; do [[ "$3" == "$v" ]] && return 0; done
    echo "ERROR: ${1} must be one of: ${2} (got: '${3}')." >&2
    exit 1
}
