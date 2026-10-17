#!/usr/bin/env bash
set -euo pipefail

RULECODEX_ROOT="${1:-}"
if [[ -z "$RULECODEX_ROOT" || ! -d "$RULECODEX_ROOT" ]]; then
  echo "Usage: $0 /path/to/rulecodex" >&2
  exit 2
fi
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
MANIFEST="$RULECODEX_ROOT/RULECODEX_VERSION.json"
INSTALLER="$RULECODEX_ROOT/scripts/install-codex-deploy-policy.sh"
SYNC="$CODEX_HOME_DIR/bin/rulecodex-sync.sh"
LOG_DIR="$CODEX_HOME_DIR/logs"
LOG_FILE="$LOG_DIR/rulecodex-migration.log"
STATE_FILE="$CODEX_HOME_DIR/rules/rulecodex-migration.json"
mkdir -p "$LOG_DIR" "$CODEX_HOME_DIR/rules"
log() { printf '%s [%s] %s\n' "$(date --iso-8601=seconds)" "$1" "$2" | tee -a "$LOG_FILE"; }
[[ -f "$MANIFEST" && -f "$INSTALLER" ]] || { log ERROR 'Missing main manifest or installer'; exit 1; }
python3 - "$MANIFEST" "$RULECODEX_ROOT" <<'PY'
import hashlib, json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
root = pathlib.Path(sys.argv[2])
assert manifest.get('schema_version') == 1 and manifest.get('source_ref') == 'main'
for item in manifest['managed_files']:
    path = pathlib.Path(item)
    assert not path.is_absolute() and '..' not in path.parts
    file = root / path
    normalized = file.read_text(encoding='utf-8').replace('\r\n', '\n').encode('utf-8')
    assert hashlib.sha256(normalized).hexdigest().upper() == manifest['managed_sha256'][item], item
PY
old_pinned=0
if [[ -f "$SYNC" ]] && rg -q 'codex/don-dep-vps-phase1-external-artifacts' "$SYNC"; then old_pinned=1; fi
policy_version="$(python3 -c "import json; print(json.load(open('$MANIFEST'))['policy_version'])")"
log INFO "Validated RuleCodex main manifest policy=$policy_version old_branch_pinned=$old_pinned"
bash "$INSTALLER" "$RULECODEX_ROOT"
python3 - "$STATE_FILE" "$policy_version" "$old_pinned" <<'PY'
import json, pathlib, sys, datetime
path = pathlib.Path(sys.argv[1])
path.write_text(json.dumps({
    'schema_version': 1,
    'migrated_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'source_ref': 'main',
    'policy_version': sys.argv[2],
    'old_branch_pinned': bool(int(sys.argv[3])),
    'status': 'success',
}, indent=2) + '\n', encoding='utf-8')
PY
log INFO 'Migration completed; future managed sync defaults to main.'
