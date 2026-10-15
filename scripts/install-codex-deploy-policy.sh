#!/usr/bin/env bash
set -euo pipefail

RULECODEX_ROOT="${1:-}"
if [[ -z "$RULECODEX_ROOT" || ! -d "$RULECODEX_ROOT" ]]; then
  echo "Usage: $0 /path/to/rulecodex" >&2
  exit 2
fi

CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
SOURCE_SKILL="$RULECODEX_ROOT/skills/local-vps-deploy"
SOURCE_POLICY="$RULECODEX_ROOT/GLOBAL_DEPLOY_POLICY.md"
TARGET_SKILL="$CODEX_HOME_DIR/skills/local-vps-deploy"
TARGET_POLICY="$CODEX_HOME_DIR/rules/GLOBAL_DEPLOY_POLICY.md"

[[ -f "$SOURCE_SKILL/SKILL.md" ]] || { echo "Missing $SOURCE_SKILL/SKILL.md" >&2; exit 1; }
[[ -f "$SOURCE_POLICY" ]] || { echo "Missing $SOURCE_POLICY" >&2; exit 1; }

mkdir -p "$CODEX_HOME_DIR/skills" "$CODEX_HOME_DIR/rules"
if [[ -e "$TARGET_SKILL" ]]; then
  mv "$TARGET_SKILL" "$TARGET_SKILL.backup-$(date +%Y%m%d-%H%M%S)"
fi
cp -R "$SOURCE_SKILL" "$TARGET_SKILL"
cp "$SOURCE_POLICY" "$TARGET_POLICY"
mkdir -p "$CODEX_HOME_DIR/bin"
cp "$RULECODEX_ROOT/scripts/rulecodex-sync.sh" "$CODEX_HOME_DIR/bin/rulecodex-sync.sh"
cp "$RULECODEX_ROOT/scripts/codex-managed.sh" "$CODEX_HOME_DIR/bin/codex-managed.sh"
cp "$RULECODEX_ROOT/scripts/rulecodex-status.sh" "$CODEX_HOME_DIR/bin/rulecodex-status.sh"
chmod 700 "$CODEX_HOME_DIR/bin/rulecodex-sync.sh" "$CODEX_HOME_DIR/bin/codex-managed.sh"
chmod 700 "$CODEX_HOME_DIR/bin/rulecodex-status.sh"
printf 'PASS: installed %s\nPOLICY: %s\n' "$TARGET_SKILL" "$TARGET_POLICY"
