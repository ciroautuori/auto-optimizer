#!/usr/bin/env bash
set -e

REPO="https://raw.githubusercontent.com/ciroautuori/auto-optimizer/main"
SKILL_DIR="$HOME/.claude/skills/auto-optimizer"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}⚡ auto-optimizer installer${NC}"
echo "==========================="
echo ""

# 1 — Install the skill
echo -e "${YELLOW}→ Installing skill...${NC}"
mkdir -p "$SKILL_DIR"

if [ -f "./SKILL.md" ]; then
  cp ./SKILL.md "$SKILL_DIR/SKILL.md"
else
  curl -fsSL "$REPO/SKILL.md" -o "$SKILL_DIR/SKILL.md"
fi
echo -e "${GREEN}✓ Skill installed: $SKILL_DIR/SKILL.md${NC}"

# 2 — Sessions directory for handoff files
mkdir -p "$HOME/.claude/sessions"
echo -e "${GREEN}✓ Created ~/.claude/sessions/ for handoff files${NC}"

# 2b — Install hook scripts (the automatic session-hygiene loop)
echo -e "${YELLOW}→ Installing hook scripts...${NC}"
if [ -d "./scripts" ]; then
  cp -r ./scripts "$SKILL_DIR/scripts"
else
  mkdir -p "$SKILL_DIR/scripts/lib"
  for f in session-init.sh stop-nudge.sh session-flush.sh lib/common.sh lib/state-template.md; do
    curl -fsSL "$REPO/scripts/$f" -o "$SKILL_DIR/scripts/$f"
  done
fi
chmod +x "$SKILL_DIR"/scripts/*.sh "$SKILL_DIR"/scripts/lib/*.sh 2>/dev/null || true
echo -e "${GREEN}✓ Hook scripts installed: $SKILL_DIR/scripts/${NC}"

# 2c — Hard-dep check (the flush layer needs these; fail loud, don't abort)
for dep in qmd graphify; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ HARD DEP MISSING: '$dep' not on PATH — SessionEnd flush will skip it loudly until installed${NC}"
  fi
done

# 2d — Merge the 3 lifecycle hooks into ~/.claude/settings.json (backup + merge, never overwrite)
SETTINGS="$HOME/.claude/settings.json"
echo -e "${YELLOW}→ Merging SessionStart / Stop / SessionEnd hooks into settings.json...${NC}"
SKILL_DIR="$SKILL_DIR" python3 - <<'PY'
import json, os, sys, shutil

settings = os.path.expanduser("~/.claude/settings.json")
skill = os.environ["SKILL_DIR"]
scripts = os.path.join(skill, "scripts")

want = {
    "SessionStart": f"bash {scripts}/session-init.sh",
    "Stop":         f"bash {scripts}/stop-nudge.sh",
    "SessionEnd":   f"bash {scripts}/session-flush.sh",
}

data = {}
if os.path.exists(settings):
    try:
        with open(settings) as f:
            data = json.load(f)
    except Exception as e:
        print(f"  ! settings.json unreadable ({e}); leaving it untouched", file=sys.stderr)
        sys.exit(0)
    shutil.copy2(settings, settings + ".bak")
    print("  ✓ backed up settings.json → settings.json.bak")

hooks = data.setdefault("hooks", {})
changed = False
for event, cmd in want.items():
    entries = hooks.setdefault(event, [])
    present = any(
        h.get("command") == cmd
        for entry in entries
        for h in entry.get("hooks", [])
    )
    if present:
        continue
    entries.append({"hooks": [{"type": "command", "command": cmd}]})
    changed = True
    print(f"  ✓ added {event} hook")

if changed:
    os.makedirs(os.path.dirname(settings), exist_ok=True)
    with open(settings, "w") as f:
        json.dump(data, f, indent=2)
    print("  ✓ settings.json updated (existing hooks preserved)")
else:
    print("  (hooks already present — nothing to do)")
PY
echo -e "${GREEN}✓ Hooks merged${NC}"

# 3 — Optional: global CLAUDE.md rules block
OPTIMIZER_BLOCK='
## ⚡ AUTO-OPTIMIZER rules
<!-- github.com/ciroautuori/auto-optimizer — remove this block to uninstall the rules -->

### Context hygiene
- Conversation getting long → recommend /compact to the user NOW, before loading more
- Task switch → write handoff file to ~/.claude/sessions/, then recommend /clear
- Never recommend /clear without a handoff file written first

### Subagent routing (cheapest capable model)
- Task < 10 steps or 1-2 files → NO subagent, do it directly
- Sequential tasks → NO subagent, keep them in the main thread
- Parallel + independent + simple → subagent with model: haiku
- Most expensive models → only on explicit user request

### Tool routing (cheapest capable tool)
- Codebase questions → Grep/Glob before reading files
- Files > 200 lines → Grep or Read with offset+limit, never whole-file
- Web content → WebFetch/curl before any browser tool; close browser right after use
'

echo ""
if [ -t 0 ]; then
  read -r -p "Append auto-optimizer rules to ~/.claude/CLAUDE.md? [y/N] " append_rules
else
  append_rules="n"
  echo -e "${YELLOW}  (non-interactive install — skipping CLAUDE.md changes;${NC}"
  echo -e "${YELLOW}   re-run install.sh from a terminal to add the rules block)${NC}"
fi

if [[ "$append_rules" =~ ^[Yy]$ ]]; then
  mkdir -p "$HOME/.claude"
  if [ -f "$CLAUDE_MD" ] && grep -q "AUTO-OPTIMIZER" "$CLAUDE_MD"; then
    echo -e "${YELLOW}  (AUTO-OPTIMIZER block already present, skipping)${NC}"
  else
    [ -f "$CLAUDE_MD" ] || echo "# Claude Code Global Configuration" > "$CLAUDE_MD"
    printf '%s\n' "$OPTIMIZER_BLOCK" >> "$CLAUDE_MD"
    echo -e "${GREEN}✓ Rules appended to $CLAUDE_MD${NC}"
  fi
fi

# 4 — Done
echo ""
echo -e "${GREEN}===========================${NC}"
echo -e "${GREEN}✓ Installation complete${NC}"
echo ""
echo "  Skill:          $SKILL_DIR/SKILL.md"
echo "  Session files:  ~/.claude/sessions/"
echo ""
echo "  The skill triggers automatically on session starts, task switches,"
echo "  subagent spawns, large file reads, and long conversations."
echo ""
echo -e "${BLUE}  Customize thresholds: $SKILL_DIR/SKILL.md${NC}"
echo -e "${BLUE}  Docs:                 https://github.com/ciroautuori/auto-optimizer${NC}"
echo ""
