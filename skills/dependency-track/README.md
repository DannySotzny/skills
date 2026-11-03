# Dependency-Track Skill

Give your AI agent access to your software composition analysis — know what vulnerabilities are in your dependencies and audit them.

## Why

Dependency-Track tells you which of your 500 dependencies have known CVEs. This skill lets your agent query that data, filter by severity, audit findings as false positives or not affected, and check if a project's dependency health is getting better or worse. Useful during PR reviews, security audits, or when someone asks "are we affected by CVE-2024-XXXX?"

## What it can do

- **List projects** — with pagination, search, tag filtering, and inactive project support
- **Look up projects** — by exact name and version
- **View project status** — vulnerability counts, risk scores, component totals
- **List findings** — vulnerabilities with severity, CVSS, EPSS, CWE, and audit state
- **Vulnerability details** — full CVE/GHSA/OSV record by source and ID
- **Audit findings** — mark as NOT_AFFECTED, FALSE_POSITIVE, EXPLOITABLE, etc.
- **Get audit history** — see who audited what and when
- **List components** — project dependencies with license and version info
- **Check policy violations** — license or security policy failures
- **View services** — external service dependencies
- **Upload SBOMs** — CycloneDX/SPDX BOM upload to a project
- **Refresh metrics** — per project or portfolio-wide
- **Raw API access** — for anything the wrappers don't cover

## Scripts

| Script | Purpose |
|--------|---------|
| `dtrack-setup.sh` | Interactive configuration (`--check` to verify only) |
| `dtrack-projects.sh` | List/search projects with pagination |
| `dtrack-project-lookup.sh` | Look up project by name and version |
| `dtrack-project-status.sh` | Vulnerability summary for a project |
| `dtrack-findings.sh` | List vulnerability findings |
| `dtrack-vulnerability.sh` | Vulnerability details by source and ID |
| `dtrack-audit.sh` | Set audit status on a finding |
| `dtrack-audit-get.sh` | Get audit trail for a finding |
| `dtrack-components.sh` | List project dependencies |
| `dtrack-violations.sh` | Policy violations |
| `dtrack-services.sh` | External service dependencies |
| `dtrack-bom-upload.sh` | Upload an SBOM to a project |
| `dtrack-metrics-refresh.sh` | Trigger a metrics refresh |
| `dtrack-api.sh` | HTTP helper and raw API access |
| `_config.sh` | Configuration loader |

## Installation

```bash
npx skills add DannySotzny/skills --skill dependency-track
```

Or install manually: copy (or symlink) `skills/dependency-track/` into your agent's skills directory, e.g. `~/.claude/skills/dependency-track/`.

## Setup

Requirements: `bash`, `curl`, `jq`, `base64` (on Windows: Git Bash plus `jq`).

```bash
skills/dependency-track/scripts/dtrack-setup.sh          # interactive
skills/dependency-track/scripts/dtrack-setup.sh --check  # verify existing config
```

This writes `~/.boring/dependency-track/url` and `~/.boring/dependency-track/apikey` (mode 600). The environment variables `DTRACK_URL`, `DTRACK_API_KEY_FILE` and `DTRACK_CONFIG_DIR` take precedence over the files. See [SKILL.md](SKILL.md) for manual setup.

Needs a Dependency-Track API key with `VIEW_PORTFOLIO`, `VIEW_VULNERABILITY`, `VULNERABILITY_ANALYSIS`, and `VIEW_POLICY_VIOLATION` permissions.

## Tests

```bash
bash skills/dependency-track/tests/test-dependency-track.sh
```

Offline checks (syntax, `set -e`, argument validation) always run. Read-only live checks run only when `~/.boring/dependency-track/` is configured — tests never write to the server.

## Origin and license

Copied from [rezkam/boring-but-good](https://github.com/rezkam/boring-but-good/tree/main/skills/dependency-track) and licensed under the Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
