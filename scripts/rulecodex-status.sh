#!/usr/bin/env bash
set -euo pipefail
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
PROJECT_ROOT="${1:-$PWD}"
STATE_FILE="$CODEX_HOME_DIR/rules/rulecodex-state.json"
if [[ -f "$STATE_FILE" ]]; then
  python3 - "$STATE_FILE" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
for key in ('policy_version','source_ref','source_commit','policy_sha256','last_verified_utc','last_sync_status','last_error_utc'):
    if key in data: print(f'{key}: {data[key]}')
PY
else
  echo 'RuleCodex state: NOT_INSTALLED'
fi
if [[ -f "$PROJECT_ROOT/AGENTS.md" ]] && rg -n -i '(github actions.*(required|must)|must.*push.*before.*deploy|build.*on.*vps|build.*on.*production)' "$PROJECT_ROOT/AGENTS.md"; then
  echo 'PROJECT POLICY CONFLICTS: REVIEW_REQUIRED'
else
  echo 'PROJECT POLICY CONFLICTS: none detected by baseline checks'
fi
