#!/usr/bin/env bash
# auto-optimizer — smoke test. Runs the 3 hook scripts against a throwaway
# git repo with stubbed qmd/graphify, asserts the loop behaves.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ROOT/scripts"
fail=0
ok()   { printf '  ok  — %s\n' "$1"; }
bad()  { printf '  BAD — %s\n' "$1"; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# stub hard deps on PATH so flush exercises the happy path
STUB="$TMP/bin"; mkdir -p "$STUB"
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/qmd";      chmod +x "$STUB/qmd"
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/graphify"; chmod +x "$STUB/graphify"
export PATH="$STUB:$PATH"
export XDG_CACHE_HOME="$TMP/cache"

# throwaway project repo
PROJ="$TMP/proj"; mkdir -p "$PROJ"
git -C "$PROJ" init -q
git -C "$PROJ" config user.email t@t; git -C "$PROJ" config user.name t
mkdir -p "$PROJ/docs"
cat > "$PROJ/docs/HANDOFF-2026-06-15-thing.md" <<'EOF'
# Handoff thing
## Next steps
- [ ] wire the widget
- [ ] ship it
EOF
git -C "$PROJ" add -A; git -C "$PROJ" commit -qm init

SID="smoke-$$"
J() { printf '{"session_id":"%s","cwd":"%s","source":"%s"}' "$SID" "$PROJ" "$1"; }

echo "[1] SessionStart INIT"
out="$(J startup | bash "$SCRIPTS/session-init.sh" 2>/dev/null)"
[ -f "$PROJ/docs/.session/STATE.md" ] && ok "STATE.md created" || bad "STATE.md missing"
echo "$out" | grep -q "SESSION STATE (INIT)" && ok "INIT summary printed" || bad "no INIT summary"
grep -q "wire the widget" "$PROJ/docs/.session/STATE.md" && ok "carried task parsed from handoff" || bad "task not carried"

echo "[2] SessionStart RELOAD (idempotent)"
out2="$(J resume | bash "$SCRIPTS/session-init.sh" 2>/dev/null)"
echo "$out2" | grep -q "SESSION STATE (RELOAD)" && ok "RELOAD mode" || bad "expected RELOAD"

echo "[3] Stop nudge — first fires, second silent"
n1="$(J '' | bash "$SCRIPTS/stop-nudge.sh" 2>/dev/null)"
echo "$n1" | grep -q "additionalContext" && ok "first Stop emits reminder" || bad "first Stop empty"
n2="$(J '' | bash "$SCRIPTS/stop-nudge.sh" 2>/dev/null)"
[ "$(echo "$n2" | tr -d '[:space:]')" = "{}" ] && ok "second Stop silent (marker)" || bad "marker not idempotent"

echo "[4] SessionEnd flush"
J clear | bash "$SCRIPTS/session-flush.sh" --collection smoke >/dev/null 2>&1
[ -f "$PROJ/docs/HANDOFF-latest.md" ] && ok "HANDOFF-latest.md written" || bad "no HANDOFF-latest.md"
git -C "$PROJ" log --oneline | grep -q "auto-flush" && ok "auto-flush commit made" || bad "no auto-flush commit"

echo
[ "$fail" = 0 ] && { echo "ALL GREEN"; exit 0; } || { echo "FAILURES"; exit 1; }
