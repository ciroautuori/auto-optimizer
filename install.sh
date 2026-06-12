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
