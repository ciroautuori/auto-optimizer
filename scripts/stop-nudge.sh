#!/usr/bin/env bash
# auto-optimizer — Stop hook.
# Once per session (marker-guarded) emits a NON-blocking reminder so Claude
# keeps the handoff / roadmap / memory / STATE current before the user clears.
# Lightweight: no LLM, just static JSON. Never blocks (no decision:block).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"
_parse_hook_stdin

MARKER="$MARKER_DIR/nudged-$SESSION_ID"
if [ -f "$MARKER" ]; then
  echo '{}'
  exit 0
fi
: > "$MARKER"

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"auto-optimizer (igiene sessione attiva): prima che l'utente faccia /clear — (1) invoca la skill `handoff` per il handoff narrativo, (2) ticka i checkbox completati in ROADMAP-MASTER, (3) aggiungi 1 riga a MEMORY.md se c'e' un fatto durevole, (4) aggiorna docs/.session/STATE.md (task done/nuovi). Il flush meccanico (qmd update+embed, graphify update, snapshot HANDOFF-latest, git commit) parte DA SOLO a SessionEnd — non rifarlo a mano."}}
JSON
