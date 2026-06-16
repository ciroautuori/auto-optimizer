#!/usr/bin/env bash
# auto-optimizer — SessionStart hook.
# Scans the project + previous handoffs + planning-with-files artifacts,
# builds/refreshes docs/.session/STATE.md, and prints a compact summary.
# stdout reaches Claude as context (SessionStart plain stdout is injected).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"
_parse_hook_stdin

is_git_repo "$PROJ_CWD" || exit 0
cd "$PROJ_CWD"

STATE_DIR="docs/.session"
STATE="$STATE_DIR/STATE.md"
TEMPLATE="$HERE/lib/state-template.md"
mkdir -p "$STATE_DIR"

PROJECT="$(basename "$PROJ_CWD")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'no-commits')"

# --- collect handoff index (newest first) ---
handoffs=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  first="$(grep -m1 -E '^#|^>' "$f" 2>/dev/null | sed -E 's/^[#>[:space:]]+//' | cut -c1-80)"
  d="$(echo "$f" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
  handoffs+="- ${d:-?} — $f — ${first:-handoff}"$'\n'
done < <(ls -1t docs/HANDOFF-*.md 2>/dev/null | head -20)
[ -n "$handoffs" ] || handoffs="- (none yet)"$'\n'

# --- collect open tasks from previous handoffs + planning-with-files ---
collect_tasks() {
  # unchecked checkboxes from handoffs + any progress.md / task_plan.md
  grep -hE '^\s*-\s*\[ \]' \
    docs/HANDOFF-*.md \
    $(find . -path ./.git -prune -o \( -name progress.md -o -name task_plan.md \) -print 2>/dev/null) \
    2>/dev/null | sed -E 's/^\s*//' | sort -u | head -30
}

if [ ! -f "$STATE" ]; then
  # INIT
  tasks="$(collect_tasks || true)"
  [ -n "$tasks" ] || tasks="- [ ] (no carried tasks found — add yours here)"
  sed \
    -e "s|__PROJECT__|$PROJECT|g" \
    -e "s|__TS__|$TS|g" \
    -e "s|__BRANCH__|$BRANCH|g" \
    -e "s|__COMMIT__|$COMMIT|g" \
    "$TEMPLATE" > "$STATE.tmp"
  # inject multiline blocks via awk (sed chokes on newlines)
  awk -v tasks="$tasks" -v hd="$handoffs" '
    /__TASKS__/   { print tasks; next }
    /__HANDOFFS__/{ printf "%s", hd; next }
    { print }
  ' "$STATE.tmp" > "$STATE"
  rm -f "$STATE.tmp"
  MODE="INIT"
else
  # RELOAD — refresh footer + handoff index block, keep user tasks/facts
  awk -v ts="$TS" -v br="$BRANCH" -v cm="$COMMIT" -v hd="$handoffs" '
    BEGIN { inhd=0 }
    /^## Handoff index/ { print; printf "%s", hd; inhd=1; next }
    inhd==1 && /^## / { inhd=0 }
    inhd==1 { next }
    /^_last refresh:/ { printf "_last refresh: %s · branch %s · %s_\n", ts, br, cm; next }
    { print }
  ' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
  MODE="RELOAD"
fi

# --- summary to Claude ---
open_count="$(grep -cE '^\s*-\s*\[ \]' "$STATE" 2>/dev/null || echo 0)"
latest_handoff="$(ls -1t docs/HANDOFF-*.md 2>/dev/null | head -1)"

echo "── auto-optimizer SESSION STATE ($MODE) ──"
echo "project: $PROJECT · branch: $BRANCH · $COMMIT"
echo "ledger: $STATE · open tasks: $open_count"
[ -n "$latest_handoff" ] && echo "latest handoff: $latest_handoff"
echo "top open tasks:"
grep -E '^\s*-\s*\[ \]' "$STATE" 2>/dev/null | head -5 || true
echo "→ read $STATE first to resume the thread. Keep it current; flush runs at SessionEnd."
