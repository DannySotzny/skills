#!/bin/bash
# Test suite for the Dependency-Track skill
# Tests: argument validation, error messages, script structure
# RULE: Live tests are READ-ONLY. Never create, modify, or delete data in live systems.
# Read-only live tests run automatically when Dependency-Track is configured.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DT_DIR="${SCRIPT_DIR}/.."
DT_SCRIPTS="${DT_DIR}/scripts"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
PASS=0; FAIL=0; SKIP=0


pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${RESET}   %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${RESET} %s\n" "$1"; [ -n "$2" ] && printf "    ${DIM}%s${RESET}\n" "$2"; }
skip() { SKIP=$((SKIP + 1)); printf "  ${YELLOW}SKIP${RESET} %s ${DIM}(skipped)${RESET}\n" "$1"; }
header() { echo ""; printf "${BOLD}━━━ %s ━━━${RESET}\n" "$1"; }

run_expect_fail() {
    local tmp_err; tmp_err=$(mktemp)
    "$@" >/dev/null 2>"$tmp_err"; CAPTURED_RC=$?; CAPTURED_ERR=$(cat "$tmp_err"); rm -f "$tmp_err"
}

# ═══════════════════════════════════════════════════════════════════════════════
header "Dependency-Track: Script file checks"
# ═══════════════════════════════════════════════════════════════════════════════

for script in "$DT_SCRIPTS"/*.sh; do
    name=$(basename "$script")
    case "$name" in _*.sh) continue ;; esac

    if [ -x "$script" ]; then pass "${name}: is executable"; else fail "${name}: not executable"; fi
    if bash -n "$script" 2>/dev/null; then pass "${name}: bash syntax OK"; else fail "${name}: bash syntax error"; fi
    if grep -q 'set -e' "$script"; then pass "${name}: has set -e"; else fail "${name}: missing set -e"; fi
done

# ═══════════════════════════════════════════════════════════════════════════════
header "Dependency-Track: _config.sh"
# ═══════════════════════════════════════════════════════════════════════════════

for lib in _config.sh _lib.sh; do
    if bash -n "${DT_SCRIPTS}/${lib}" 2>/dev/null; then pass "${lib}: bash syntax OK"; else fail "${lib}: bash syntax error"; fi
done

# ═══════════════════════════════════════════════════════════════════════════════
header "Dependency-Track: Security hardening"
# ═══════════════════════════════════════════════════════════════════════════════

API="${DT_SCRIPTS}/dtrack-api.sh"
if grep -qE 'curl[^#]*[[:space:]]-[a-zA-Z]*L' "$API" || grep -q -- '--location' "$API"; then
    fail "dtrack-api.sh: follows redirects (-L)"
else
    pass "dtrack-api.sh: does not follow redirects"
fi
if grep -q 'X-Api-Key: ${DTRACK_API_KEY}"' "$API"; then
    fail "dtrack-api.sh: API key passed on the curl command line"
else
    pass "dtrack-api.sh: API key not on the curl command line"
fi

SEC_KEY=$(mktemp); echo "fake" > "$SEC_KEY"
sec_env() { env DTRACK_URL="https://dtrack.invalid" DTRACK_API_KEY_FILE="$SEC_KEY" CURL_RETRIES=0 "$@"; }

run_expect_fail sec_env bash "$API" GET /v1/project https://evil.invalid/
if [ $CAPTURED_RC -ne 0 ] && echo "$CAPTURED_ERR" | grep -q 'unsupported argument'; then
    pass "dtrack-api.sh: rejects extra URL / curl arguments"
else
    fail "dtrack-api.sh: accepted extra curl argument" "$CAPTURED_ERR"
fi

for bad in "https://evil.invalid/v1/x" "/v1/x@evil.invalid" "/v1/a b" "v1/project" "//evil.invalid/v1/"; do
    run_expect_fail sec_env bash "$API" GET "$bad"
    if [ $CAPTURED_RC -ne 0 ] && echo "$CAPTURED_ERR" | grep -q 'endpoint must be'; then
        pass "dtrack-api.sh: rejects endpoint '${bad}'"
    else
        fail "dtrack-api.sh: accepted endpoint '${bad}'" "$CAPTURED_ERR"
    fi
done

run_expect_fail sec_env bash "$API" TRACE /v1/project
if [ $CAPTURED_RC -ne 0 ]; then pass "dtrack-api.sh: rejects unsupported method"; else fail "dtrack-api.sh: accepted TRACE"; fi

run_expect_fail env DTRACK_URL="https://user:pw@evil.invalid" DTRACK_API_KEY_FILE="$SEC_KEY" bash "$API" GET /v1/project
if [ $CAPTURED_RC -ne 0 ] && echo "$CAPTURED_ERR" | grep -q 'not a valid server URL'; then
    pass "_config.sh: rejects URL with credentials"
else
    fail "_config.sh: accepted URL with credentials" "$CAPTURED_ERR"
fi

run_expect_fail env DTRACK_URL="http://dtrack.invalid" DTRACK_API_KEY_FILE="$SEC_KEY" CURL_RETRIES=0 CURL_CONNECT_TIMEOUT=1 bash "$API" GET /v1/project
if echo "$CAPTURED_ERR" | grep -q 'WARNING: .*plain HTTP'; then pass "_config.sh: warns on plain HTTP"; else fail "_config.sh: no plain-HTTP warning"; fi

for script in dtrack-findings dtrack-project-status dtrack-components dtrack-services dtrack-violations; do
    run_expect_fail sec_env bash "$DT_SCRIPTS/${script}.sh" "../../v1/user"
    if [ $CAPTURED_RC -ne 0 ] && echo "$CAPTURED_ERR" | grep -q 'must be a UUID'; then
        pass "${script}.sh: rejects non-UUID project id"
    else
        fail "${script}.sh: accepted non-UUID project id" "$CAPTURED_ERR"
    fi
done

U=00000000-0000-0000-0000-000000000000
run_expect_fail sec_env bash "$DT_SCRIPTS/dtrack-audit.sh" $U $U $U --state 'NOT_SET"}'
if [ $CAPTURED_RC -ne 0 ] && echo "$CAPTURED_ERR" | grep -q 'must be one of'; then
    pass "dtrack-audit.sh: rejects invalid --state"
else
    fail "dtrack-audit.sh: accepted invalid --state" "$CAPTURED_ERR"
fi

run_expect_fail sec_env bash "$DT_SCRIPTS/dtrack-findings.sh" $U --severity 'HIGH") | env'
if [ $CAPTURED_RC -ne 0 ] && echo "$CAPTURED_ERR" | grep -q 'must be one of'; then
    pass "dtrack-findings.sh: rejects invalid --severity"
else
    fail "dtrack-findings.sh: accepted invalid --severity" "$CAPTURED_ERR"
fi

NOT_BOM=$(mktemp); echo "secret data" > "$NOT_BOM"
run_expect_fail sec_env bash "$DT_SCRIPTS/dtrack-bom-upload.sh" $U "$NOT_BOM"
if [ $CAPTURED_RC -ne 0 ] && echo "$CAPTURED_ERR" | grep -q 'does not look like'; then
    pass "dtrack-bom-upload.sh: refuses non-BOM files"
else
    fail "dtrack-bom-upload.sh: accepted a non-BOM file" "$CAPTURED_ERR"
fi
rm -f "$NOT_BOM"

ENC=$(bash -c 'source "$1"; dt_urlencode "a b&c=ü/"' _ "${DT_SCRIPTS}/_lib.sh")
if [ "$ENC" = "a%20b%26c%3D%C3%BC%2F" ]; then pass "_lib.sh: URL-encodes UTF-8 correctly"; else fail "_lib.sh: wrong encoding: ${ENC}"; fi
rm -f "$SEC_KEY"

# ═══════════════════════════════════════════════════════════════════════════════
header "Dependency-Track: Setup modes"
# ═══════════════════════════════════════════════════════════════════════════════

SETUP="${DT_SCRIPTS}/dtrack-setup.sh"
CFG_TMP=$(mktemp -d)
run_expect_fail env DTRACK_CONFIG_DIR="$CFG_TMP" bash "$SETUP" --status
if [ $CAPTURED_RC -ne 0 ]; then pass "dtrack-setup.sh --status: non-zero when unconfigured"; else fail "dtrack-setup.sh --status: exit 0 without config"; fi

env DTRACK_CONFIG_DIR="$CFG_TMP" bash "$SETUP" --url "dtrack.example.com/" >/dev/null 2>&1
if [ "$(cat "$CFG_TMP/url" 2>/dev/null)" = "https://dtrack.example.com" ]; then
    pass "dtrack-setup.sh --url: saves normalized URL"
else
    fail "dtrack-setup.sh --url: wrong URL saved: $(cat "$CFG_TMP/url" 2>/dev/null)"
fi

run_expect_fail env DTRACK_CONFIG_DIR="$CFG_TMP" bash "$SETUP" --url "https://x@evil.invalid"
if [ $CAPTURED_RC -ne 0 ]; then pass "dtrack-setup.sh --url: rejects URL with credentials"; else fail "dtrack-setup.sh --url: accepted URL with credentials"; fi

run_expect_fail env DTRACK_CONFIG_DIR="$CFG_TMP" bash "$SETUP" --key </dev/null
if [ $CAPTURED_RC -ne 0 ] && echo "$CAPTURED_ERR" | grep -q 'needs a terminal'; then
    pass "dtrack-setup.sh --key: refuses to run without a terminal"
else
    fail "dtrack-setup.sh --key: did not refuse non-interactive run" "$CAPTURED_ERR"
fi
rm -rf "$CFG_TMP"

# ═══════════════════════════════════════════════════════════════════════════════
header "Dependency-Track: Argument validation"
# ═══════════════════════════════════════════════════════════════════════════════

MOCK_TOKEN=$(mktemp); echo "fake" > "$MOCK_TOKEN"

for script in dtrack-api dtrack-findings dtrack-audit dtrack-audit-get dtrack-components dtrack-services dtrack-violations dtrack-project-status dtrack-projects dtrack-project-lookup dtrack-vulnerability dtrack-bom-upload; do
    SCRIPT_FILE="$DT_SCRIPTS/${script}.sh"
    [ -f "$SCRIPT_FILE" ] || continue

    run_expect_fail env DTRACK_URL="http://fake" DTRACK_API_KEY_FILE="$MOCK_TOKEN" \
        bash "$SCRIPT_FILE"
    if [ $CAPTURED_RC -ne 0 ]; then
        pass "${script}.sh: exits non-zero without required args"
    else
        fail "${script}.sh: exits 0 without required args"
    fi

    if [ -n "$CAPTURED_ERR" ] && echo "$CAPTURED_ERR" | grep -qi 'usage\|error\|required'; then
        pass "${script}.sh: provides usage/error message"
    else
        fail "${script}.sh: no error message on missing args"
    fi
done

# dtrack-metrics-refresh.sh: valid no-arg behavior (refreshes portfolio metrics).
# It should NOT be in the "must fail" loop — calling without args triggers a portfolio
# refresh, which is its intended default mode.
run_expect_fail env DTRACK_URL="http://fake" DTRACK_API_KEY_FILE="$MOCK_TOKEN" \
    bash "$DT_SCRIPTS/dtrack-metrics-refresh.sh"
if [ $CAPTURED_RC -eq 0 ]; then
    pass "dtrack-metrics-refresh.sh: exits 0 without args (portfolio refresh mode)"
else
    fail "dtrack-metrics-refresh.sh: unexpected failure without args (rc=${CAPTURED_RC})"
fi
if echo "$CAPTURED_ERR" | grep -qi "portfolio.*refresh\|refresh.*portfolio"; then
    pass "dtrack-metrics-refresh.sh: outputs portfolio refresh message"
else
    fail "dtrack-metrics-refresh.sh: missing portfolio refresh message"
fi

# dtrack-setup.sh: interactive; without a TTY it must refuse and print recovery steps.
run_expect_fail env DTRACK_CONFIG_DIR="$(mktemp -d)" bash "$DT_SCRIPTS/dtrack-setup.sh" </dev/null
if [ $CAPTURED_RC -ne 0 ] && echo "$CAPTURED_ERR" | grep -qi 'error\|missing'; then
    pass "dtrack-setup.sh: refuses to run without a terminal"
else
    fail "dtrack-setup.sh: did not refuse non-interactive run (rc=${CAPTURED_RC})"
fi

rm -f "$MOCK_TOKEN"

# ═══════════════════════════════════════════════════════════════════════════════
# Live tests
# ═══════════════════════════════════════════════════════════════════════════════

if [ -f "$HOME/.boring/dependency-track/url" ] && [ -f "$HOME/.boring/dependency-track/apikey" ]; then
    header "Dependency-Track: LIVE — Connectivity (read-only)"

    RESULT=$("$DT_SCRIPTS/dtrack-api.sh" GET /v1/project?pageSize=1 2>&1)
    if echo "$RESULT" | jq -e '.[0].name' >/dev/null 2>&1; then
        pass "Dependency-Track API reachable"
    else
        fail "Dependency-Track API failed: $(echo "$RESULT" | head -3)"
    fi

    header "Dependency-Track: LIVE — Project listing (read-only)"

    PROJECTS=$("$DT_SCRIPTS/dtrack-projects.sh" 2>&1)
    if echo "$PROJECTS" | jq -e '.[0].name' >/dev/null 2>&1; then
        COUNT=$(echo "$PROJECTS" | jq 'length')
        pass "dtrack-projects.sh: listed ${COUNT} projects"
    else
        fail "dtrack-projects.sh: failed: $(echo "$PROJECTS" | head -3)"
    fi
else
    header "Dependency-Track: LIVE tests (read-only)"
    skip "Dependency-Track not configured (missing ~/.boring/dependency-track/ files)"
fi

# ═══════════════════════════════════════════════════════════════════════════════
header "Results: Dependency-Track"
# ═══════════════════════════════════════════════════════════════════════════════

printf "  ${GREEN}%d passed${RESET}  ${RED}%d failed${RESET}  ${YELLOW}%d skipped${RESET}\n" "$PASS" "$FAIL" "$SKIP"
echo ""
if [ "$FAIL" -gt 0 ]; then printf "  ${RED}${BOLD}FAILED${RESET}\n"; exit 1
else printf "  ${GREEN}${BOLD}ALL TESTS PASSED${RESET}\n"; exit 0; fi
