#!/usr/bin/env bash
# auto-optimizer — shared hook helpers.
# Sourced by session-init.sh / stop-nudge.sh / session-flush.sh.
# Reads the Claude Code hook JSON from stdin ONCE and exports the fields.

# --- marker dir (per-session idempotency) ---
MARKER_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/auto-optimizer"
mkdir -p "$MARKER_DIR" 2>/dev/null || true

log() { printf 'auto-optimizer: %s\n' "$*" >&2; }

# Parse hook stdin JSON into SESSION_ID / PROJ_CWD / SOURCE.
# Falls back to env/$PWD when no stdin is given (manual runs / tests).
_parse_hook_stdin() {
  local raw=""
  if [ ! -t 0 ]; then
    raw="$(cat 2>/dev/null || true)"
  fi
  if [ -n "$raw" ] && command -v python3 >/dev/null 2>&1; then
    eval "$(printf '%s' "$raw" | python3 -c '
import json, sys, shlex
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
sid = d.get("session_id", "")
cwd = d.get("cwd", "")
src = d.get("source") or d.get("matcher") or d.get("reason") or ""
print("SESSION_ID=%s" % shlex.quote(str(sid)))
print("PROJ_CWD=%s"   % shlex.quote(str(cwd)))
print("SOURCE=%s"     % shlex.quote(str(src)))
')"
  fi
  [ -n "${SESSION_ID:-}" ] || SESSION_ID="manual-$$"
  [ -n "${PROJ_CWD:-}" ]   || PROJ_CWD="$PWD"
  [ -n "${SOURCE:-}" ]     || SOURCE="manual"
  export SESSION_ID PROJ_CWD SOURCE
}

is_git_repo() {
  git -C "${1:-$PROJ_CWD}" rev-parse --is-inside-work-tree >/dev/null 2>&1
}
