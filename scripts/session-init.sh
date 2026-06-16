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

# --- analyze ALL accumulated docs (handoffs/prompts/roadmap over time) ---
# Pulls real carried work, not just a filename index:
#  1) unchecked checkboxes from every doc + planning-with-files artifacts
#  2) actionable residue lines from handoffs/prompts (NEXT/TODO/residuo/OUTWARD/manca/...)
collect_tasks() {
  local planning
  planning="$(find . -path ./.git -prune -o \( -name progress.md -o -name task_plan.md \) -print 2>/dev/null)"
  {
    # unchecked checkboxes anywhere under docs/ + planning files
    grep -rhE '^\s*-\s*\[ \]' docs/ $planning 2>/dev/null \
      | sed -E 's/^\s*-\s*\[ \]\s*/- [ ] /'
    # actionable residue lines from handoffs / prompts (analyze their prose)
    grep -rhiE '^\s*(\*\*)?(NEXT|TODO|residuo|outward|manca|prossim|da fare|next step|gate residuo)' \
      docs/HANDOFF-*.md docs/PROMPT-*.md docs/ROADMAP-*.md 2>/dev/null \
      | sed -E 's/^\s*//; s/\*\*//g; s/^/- [ ] /' | cut -c1-160
  } 2>/dev/null | sort -u | head -40
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
