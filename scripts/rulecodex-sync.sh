#!/usr/bin/env bash
set -euo pipefail

MODE="check"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
REPOSITORY_URL="https://github.com/hai2k2000/rulecodex.git"
REF="codex/don-dep-vps-phase1-external-artifacts"
OFFLINE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -Mode|--mode) MODE="${2,,}"; shift 2 ;;
    -CodexHome|--codex-home) CODEX_HOME_DIR="$2"; shift 2 ;;
    -RepositoryUrl|--repository-url) REPOSITORY_URL="$2"; shift 2 ;;
    -Ref|--ref) REF="$2"; shift 2 ;;
    -Offline|--offline) OFFLINE=1; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

LOG_DIR="$CODEX_HOME_DIR/logs"
LOG_FILE="$LOG_DIR/rulecodex-sync.log"
STATE_FILE="$CODEX_HOME_DIR/rules/rulecodex-state.json"
mkdir -p "$LOG_DIR" "$CODEX_HOME_DIR/rules"
log() { printf '%s [%s] %s\n' "$(date --iso-8601=seconds)" "$1" "$2" | tee -a "$LOG_FILE"; }
if [[ "$OFFLINE" == 1 ]]; then log WARN 'OFFLINE: using the last installed RuleCodex policy; remote version was not verified.'; exit 0; fi

tmp="$(mktemp -d -t rulecodex-sync-XXXXXX)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
if ! git clone --depth 1 --branch "$REF" --filter=blob:none --no-checkout "$REPOSITORY_URL" "$tmp/repo" >>"$LOG_FILE" 2>&1; then
  log ERROR "Unable to retrieve RuleCodex from $REPOSITORY_URL ref $REF"; exit 1
fi
git -C "$tmp/repo" checkout --quiet "$REF"
python3 - "$tmp/repo/RULECODEX_VERSION.json" <<'PY'
import hashlib, json, pathlib, sys
p = pathlib.Path(sys.argv[1])
data = json.loads(p.read_text(encoding='utf-8'))
assert data.get('schema_version') == 1
for item in data.get('managed_files', []):
    path = pathlib.Path(item)
    assert not path.is_absolute() and '..' not in path.parts
    file = p.parent / item
    assert file.is_file(), item
    normalized = file.read_text(encoding='utf-8').replace('\r\n', '\n').encode('utf-8')
    assert data['managed_sha256'][item].lower() == hashlib.sha256(normalized).hexdigest(), item
PY
commit="$(git -C "$tmp/repo" rev-parse HEAD)"
policy_hash="$(python3 - "$tmp/repo/GLOBAL_DEPLOY_POLICY.md" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8').replace('\r\n','\n').encode('utf-8')).hexdigest().upper())
PY
)"
log INFO "Verified RuleCodex ref=$REF commit=$commit policy_hash=$policy_hash"
if [[ "$MODE" != "sync" ]]; then exit 0; fi
mkdir -p "$CODEX_HOME_DIR/skills/local-vps-deploy"
backup_root="$CODEX_HOME_DIR/backups/rulecodex/$(date +%Y%m%d-%H%M%S)"
backup_if_changed() {
  local source="$1" destination="$2"
  [[ -e "$destination" ]] || return 0
  cmp -s "$source" "$destination" && return 0
  mkdir -p "$backup_root"
  cp -p "$destination" "$backup_root/$(basename "$destination")"
}
backup_if_changed "$tmp/repo/GLOBAL_DEPLOY_POLICY.md" "$CODEX_HOME_DIR/rules/GLOBAL_DEPLOY_POLICY.md"
backup_if_changed "$tmp/repo/skills/local-vps-deploy/SKILL.md" "$CODEX_HOME_DIR/skills/local-vps-deploy/SKILL.md"
cp "$tmp/repo/GLOBAL_DEPLOY_POLICY.md" "$CODEX_HOME_DIR/rules/GLOBAL_DEPLOY_POLICY.md"
cp "$tmp/repo/skills/local-vps-deploy/SKILL.md" "$CODEX_HOME_DIR/skills/local-vps-deploy/SKILL.md"
agents="$CODEX_HOME_DIR/AGENTS.md"
if [[ ! -f "$agents" ]]; then
  mkdir -p "$(dirname "$agents")"
  : > "$agents"
fi
if [[ -f "$agents" ]]; then
  python3 - "$agents" "$tmp/repo/GLOBAL_DEPLOY_POLICY.md" <<'PY'
import pathlib, re, sys
agents = pathlib.Path(sys.argv[1]); policy = pathlib.Path(sys.argv[2])
text = agents.read_text(encoding='utf-8')
block = """<!-- BEGIN CODEX GLOBAL DEPLOY POLICY -->

# GLOBAL DEPLOY POLICY

For build, packaging, staging, deploy, release, rollback, migration, service activation, or deployment cleanup:

1. Read the canonical `GLOBAL_DEPLOY_POLICY.md` from the configured RuleCodex checkout or local policy cache, then read the target repository's `AGENTS.md` and deployment documentation. Do not assume a shared HOME or CODEX_HOME.
2. Use `LOCAL DEVELOPMENT -> LOCAL BUILD -> SSH/RSYNC (or the documented target transfer) -> TARGET VERIFY -> PRODUCTION ACTIVATION -> GITHUB ARCHIVE`.
3. Prefer local build and direct artifact transfer. GitHub Actions is optional and is not a fallback that may be selected silently.
4. Identify the target platform before acting. Never expose credentials, private keys, tokens, secrets, or `.env` contents.
5. Default to build/verify only. Production activation, restart, migration, rollback, destructive retention, and cleanup APPLY require explicit owner approval for the exact project, target, release, and operation.
6. Require source commit/version, checksum, provenance, compatible runtime, disk budget, health check, backup/rollback target, and retention evidence. Missing or conflicting configuration is a blocker.
7. New projects must link to the canonical policy and declare application type, build command, target, staging/release roots, service, health check, migration/backup/rollback gates, disk budget, retention, and approver.
8. Report GitHub synchronization failures as unsynchronized; do not hide them.

Canonical repository: `hai2k2000/rulecodex`
Canonical policy: `GLOBAL_DEPLOY_POLICY.md`
Reusable skill: `skills/local-vps-deploy/SKILL.md`

<!-- END CODEX GLOBAL DEPLOY POLICY -->"""
pattern = re.compile(r'<!-- BEGIN CODEX GLOBAL DEPLOY POLICY -->.*?<!-- END CODEX GLOBAL DEPLOY POLICY -->', re.S)
next_text = pattern.sub(block, text) if pattern.search(text) else text.rstrip() + "\n\n" + block + "\n"
if next_text != text:
    backup = agents.with_name(agents.name + '.backup-' + __import__('datetime').datetime.now().strftime('%Y%m%d-%H%M%S'))
    if text: backup.write_text(text, encoding='utf-8')
    agents.write_text(next_text, encoding='utf-8')
PY
else
  log WARN "Global AGENTS.md not found; policy cache updated without creating it"
fi
policy_version="$(python3 -c "import json; print(json.load(open('$tmp/repo/RULECODEX_VERSION.json'))['policy_version'])")"
printf '{"schema_version":1,"machine":"%s","policy_version":"%s","source_repository":"%s","source_ref":"%s","source_commit":"%s","policy_sha256":"%s","last_sync_status":"success","last_verified_utc":"%s"}\n' "$(hostname)" "$policy_version" "$REPOSITORY_URL" "$REF" "$commit" "$policy_hash" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STATE_FILE"
log INFO 'RuleCodex sync completed successfully'
