#!/usr/bin/env bash
set -euo pipefail
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
SYNC="$CODEX_HOME_DIR/bin/rulecodex-sync.sh"
if [[ -x "$SYNC" ]]; then "$SYNC" --mode sync || echo 'RuleCodex sync failed; continuing with the last installed policy only.' >&2; fi
command -v codex >/dev/null 2>&1 || { echo 'Codex executable was not found in PATH.' >&2; exit 1; }
if [[ -n "${CODEX_EXECUTABLE:-}" ]]; then exec "$CODEX_EXECUTABLE" "$@"; fi
old_ifs="$IFS"; IFS=:
for dir in $PATH; do
  [[ "$dir" == "$CODEX_HOME_DIR/bin" ]] && continue
  if [[ -x "$dir/codex" ]]; then IFS="$old_ifs"; exec "$dir/codex" "$@"; fi
done
IFS="$old_ifs"
echo 'Set CODEX_EXECUTABLE or keep the managed bin directory after the real Codex executable in PATH.' >&2
exit 1
