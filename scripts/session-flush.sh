#!/usr/bin/env bash
# auto-optimizer — SessionEnd hook (also runnable manually).
# Mechanical flush, $0, no LLM: qmd index + graphify + handoff snapshot + commit.
# SessionEnd cannot inject context — this layer is the hard guarantee.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

COLL="eros"
while [ $# -gt 0 ]; do
  case "$1" in
    --collection) COLL="$2"; shift 2 ;;
    --collection=*) COLL="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

_parse_hook_stdin
is_git_repo "$PROJ_CWD" || exit 0
cd "$PROJ_CWD"

# --- hard deps: fail loud (but still snapshot+commit so work is never lost) ---
have_qmd=1; have_graphify=1
command -v qmd      >/dev/null 2>&1 || { have_qmd=0;      log "HARD DEP MISSING: qmd — knowledge index NOT updated"; }
command -v graphify >/dev/null 2>&1 || { have_graphify=0; log "HARD DEP MISSING: graphify — graph NOT updated"; }

if [ "$have_qmd" = 1 ]; then
  qmd update -c "$COLL" >/dev/null 2>&1 && qmd embed -c "$COLL" >/dev/null 2>&1 \
    && log "qmd indexed collection '$COLL'" || log "qmd step failed (non-fatal)"
fi
if [ "$have_graphify" = 1 ]; then
  graphify update . >/dev/null 2>&1 && log "graphify updated" || log "graphify step failed (non-fatal)"
fi

# --- mechanical handoff snapshot ---
mkdir -p docs
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
{
  echo "# HANDOFF (auto) — $(basename "$PROJ_CWD")"
  echo "> mechanical snapshot by auto-optimizer SessionEnd flush. $TS · branch $BRANCH"
  echo
  echo "## git status"
  echo '```'
  git status -s
  echo '```'
  echo "## recent commits"
  echo '```'
  git log --oneline -8
  echo '```'
} > docs/HANDOFF-latest.md

# --- commit only if there is something staged under docs/ ---
git add docs/ 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "chore(session): auto-flush" >/dev/null 2>&1 \
    && log "committed session flush" || log "commit failed (non-fatal)"
else
  log "no docs changes to commit"
fi
exit 0
