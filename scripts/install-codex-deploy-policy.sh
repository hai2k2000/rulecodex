#!/usr/bin/env bash
set -euo pipefail

RULECODEX_ROOT="${1:-}"
if [[ -z "$RULECODEX_ROOT" || ! -d "$RULECODEX_ROOT" ]]; then
  echo "Usage: $0 /path/to/rulecodex" >&2
  exit 2
fi

CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
SOURCE_POLICY="$RULECODEX_ROOT/GLOBAL_DEPLOY_POLICY.md"
SOURCE_MANIFEST="$RULECODEX_ROOT/RULECODEX_VERSION.json"
SOURCE_SKILL="$RULECODEX_ROOT/skills/local-vps-deploy/SKILL.md"
TARGET_POLICY="$CODEX_HOME_DIR/rules/GLOBAL_DEPLOY_POLICY.md"
TARGET_SKILL="$CODEX_HOME_DIR/skills/local-vps-deploy/SKILL.md"
MANAGED_START='<!-- BEGIN CODEX GLOBAL DEPLOY POLICY -->'
MANAGED_END='<!-- END CODEX GLOBAL DEPLOY POLICY -->'

[[ -f "$SOURCE_POLICY" ]] || { echo "Missing $SOURCE_POLICY" >&2; exit 1; }
[[ -f "$SOURCE_MANIFEST" ]] || { echo "Missing $SOURCE_MANIFEST" >&2; exit 1; }
[[ -f "$SOURCE_SKILL" ]] || { echo "Missing $SOURCE_SKILL" >&2; exit 1; }
for script in rulecodex-sync.sh codex-managed.sh rulecodex-status.sh rulecodex-migrate.sh; do
  [[ -f "$RULECODEX_ROOT/scripts/$script" ]] || { echo "Missing $RULECODEX_ROOT/scripts/$script" >&2; exit 1; }
done

python3 - "$SOURCE_MANIFEST" "$RULECODEX_ROOT" <<'PY'
import hashlib, json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
root = pathlib.Path(sys.argv[2])
assert manifest.get('schema_version') == 1
for item in manifest['managed_files']:
    path = pathlib.Path(item)
    assert not path.is_absolute() and '..' not in path.parts
    file = root / path
    assert file.is_file(), item
    normalized = file.read_text(encoding='utf-8').replace('\r\n', '\n').encode('utf-8')
    assert hashlib.sha256(normalized).hexdigest().upper() == manifest['managed_sha256'][item], item
PY

tmp="$(mktemp -d "${TMPDIR:-/tmp}/rulecodex-install.XXXXXX")"
backup_root="$CODEX_HOME_DIR/backups/rulecodex/$(date +%Y%m%d-%H%M%S)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
mkdir -p "$tmp/skills/local-vps-deploy" "$tmp/rules" "$tmp/bin"
cp "$SOURCE_SKILL" "$tmp/skills/local-vps-deploy/SKILL.md"
cp "$SOURCE_POLICY" "$tmp/rules/GLOBAL_DEPLOY_POLICY.md"
cp "$RULECODEX_ROOT/scripts/rulecodex-sync.sh" "$tmp/bin/rulecodex-sync.sh"
cp "$RULECODEX_ROOT/scripts/codex-managed.sh" "$tmp/bin/codex-managed.sh"
cp "$RULECODEX_ROOT/scripts/rulecodex-status.sh" "$tmp/bin/rulecodex-status.sh"
cp "$RULECODEX_ROOT/scripts/rulecodex-migrate.sh" "$tmp/bin/rulecodex-migrate.sh"

mkdir -p "$CODEX_HOME_DIR/skills/local-vps-deploy" "$CODEX_HOME_DIR/rules" "$CODEX_HOME_DIR/bin"
backup_if_changed() {
  local source="$1" destination="$2"
  [[ -e "$destination" ]] || return 0
  cmp -s "$source" "$destination" && return 0
  mkdir -p "$backup_root"
  cp -p "$destination" "$backup_root/$(basename "$destination")"
}
backup_if_changed "$tmp/skills/local-vps-deploy/SKILL.md" "$TARGET_SKILL"
backup_if_changed "$tmp/rules/GLOBAL_DEPLOY_POLICY.md" "$TARGET_POLICY"
backup_if_changed "$tmp/bin/rulecodex-sync.sh" "$CODEX_HOME_DIR/bin/rulecodex-sync.sh"
backup_if_changed "$tmp/bin/codex-managed.sh" "$CODEX_HOME_DIR/bin/codex-managed.sh"
backup_if_changed "$tmp/bin/rulecodex-status.sh" "$CODEX_HOME_DIR/bin/rulecodex-status.sh"
backup_if_changed "$tmp/bin/rulecodex-migrate.sh" "$CODEX_HOME_DIR/bin/rulecodex-migrate.sh"
cp "$tmp/skills/local-vps-deploy/SKILL.md" "$TARGET_SKILL"
cp "$tmp/rules/GLOBAL_DEPLOY_POLICY.md" "$TARGET_POLICY"
cp "$tmp/bin/rulecodex-sync.sh" "$CODEX_HOME_DIR/bin/rulecodex-sync.sh"
cp "$tmp/bin/codex-managed.sh" "$CODEX_HOME_DIR/bin/codex-managed.sh"
cp "$tmp/bin/rulecodex-status.sh" "$CODEX_HOME_DIR/bin/rulecodex-status.sh"
cp "$tmp/bin/rulecodex-migrate.sh" "$CODEX_HOME_DIR/bin/rulecodex-migrate.sh"
chmod 700 "$CODEX_HOME_DIR/bin/rulecodex-sync.sh" "$CODEX_HOME_DIR/bin/codex-managed.sh" "$CODEX_HOME_DIR/bin/rulecodex-status.sh" "$CODEX_HOME_DIR/bin/rulecodex-migrate.sh"

agents="$CODEX_HOME_DIR/AGENTS.md"
python3 - "$agents" "$MANAGED_START" "$MANAGED_END" <<'PY'
import pathlib, re, sys
agents, start, end = map(pathlib.Path, sys.argv[1:])
if not agents.exists():
    agents.parent.mkdir(parents=True, exist_ok=True)
    agents.write_text('', encoding='utf-8')
PY
python3 - "$agents" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
start = '<!-- BEGIN CODEX GLOBAL DEPLOY POLICY -->'
end = '<!-- END CODEX GLOBAL DEPLOY POLICY -->'
block = f'''{start}

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
9. Authenticated smoke is optional diagnostics only; missing cookies, bearer tokens, test accounts, waivers, or RBAC smoke evidence must never block build, verification, activation, or deployment. Preserve static/automated auth tests, migration safety, health, rollback, and disk guards.

Canonical repository: `hai2k2000/rulecodex`
Canonical policy: `GLOBAL_DEPLOY_POLICY.md`
Reusable skill: `skills/local-vps-deploy/SKILL.md`

{end}
'''
pattern = re.compile(re.escape(start) + r'.*?' + re.escape(end), re.S)
next_text = pattern.sub(block.rstrip(), text) if pattern.search(text) else text.rstrip() + '\n\n' + block
if next_text != text:
    backup = path.with_name(path.name + '.backup-' + __import__('datetime').datetime.now().strftime('%Y%m%d-%H%M%S'))
    if text: backup.write_text(text, encoding='utf-8')
    path.write_text(next_text, encoding='utf-8')
PY

printf 'PASS: installed RuleCodex policy %s\n' "$(python3 -c "import json; print(json.load(open('$SOURCE_MANIFEST'))['policy_version'])")"
