#!/usr/bin/env bash
set -e

REPO="https://raw.githubusercontent.com/YOUR_USERNAME/claude-code-auto-optimizer/main"
SKILL_DIR="$HOME/.claude/skills/auto-optimizer"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}⚡ claude-code-auto-optimizer installer${NC}"
echo "======================================="
echo ""

# 1 — Create skills directory
echo -e "${YELLOW}→ Installing skill...${NC}"
mkdir -p "$SKILL_DIR"

if [ -f "./SKILL.md" ]; then
  cp ./SKILL.md "$SKILL_DIR/SKILL.md"
else
  curl -fsSL "$REPO/SKILL.md" -o "$SKILL_DIR/SKILL.md"
fi
echo -e "${GREEN}✓ Skill installed: $SKILL_DIR/SKILL.md${NC}"

# 2 — Create/update global CLAUDE.md
echo ""
echo -e "${YELLOW}→ Updating ~/.claude/CLAUDE.md...${NC}"
mkdir -p "$HOME/.claude"

OPTIMIZER_BLOCK='
## ⚡ AUTO-OPTIMIZER (claude-code-auto-optimizer)
# github.com/YOUR_USERNAME/claude-code-auto-optimizer

# These rules apply to EVERY session automatically.

# Context management
- Context > 80k tokens → run /compact immediately, do not wait
- Context > 120k tokens → /compact required, warn user
- Before loading large files or spawning subagents at 40-80k → /compact first

# Session hygiene  
- Session active > 2h → run /compact aggressively
- Switching to a new unrelated task → suggest /clear
- Background loop with no output > 30 min → pause and check

# Agent routing (cheapest capable model)
- Simple tasks < 10 steps → do directly, no subagent
- Parallel independent tasks → subagent with haiku/flash
- Sequential tasks → no subagent, do in order
- Default model → free tier (opencode/DeepSeek/Gemini)

# Tool routing (cheapest capable tool)
- Codebase questions → code graph query before opening files
- Web fetch → curl/API before Playwright
- Large files > 200 lines → grep/head/tail before cat
- Remote dispatch → only for tasks > 15 min

# End of every long session (automatic)
- Generate /handoff → save to ~/.claude/sessions/YYYY-MM-DD-<slug>.md
- Update code graph and docs indexes
- Update memory/recall tool
- Suggest /clear for next session
'

if [ -f "$CLAUDE_MD" ]; then
  if grep -q "AUTO-OPTIMIZER" "$CLAUDE_MD"; then
    echo -e "${YELLOW}  (AUTO-OPTIMIZER block already present, skipping)${NC}"
  else
    echo "" >> "$CLAUDE_MD"
    echo "$OPTIMIZER_BLOCK" >> "$CLAUDE_MD"
    echo -e "${GREEN}✓ Rules appended to existing $CLAUDE_MD${NC}"
  fi
else
  echo "# Claude Code Global Configuration" > "$CLAUDE_MD"
  echo "$OPTIMIZER_BLOCK" >> "$CLAUDE_MD"
  echo -e "${GREEN}✓ Created $CLAUDE_MD${NC}"
fi

# 3 — Create sessions directory for handoffs
mkdir -p "$HOME/.claude/sessions"
echo -e "${GREEN}✓ Created ~/.claude/sessions/ for handoff files${NC}"

# 4 — Optional: companion tools
echo ""
echo -e "${YELLOW}→ Companion tools (optional, press Enter to skip each):${NC}"
echo ""

read -p "  Install opencode (free LLM routing via DeepSeek)? [y/N] " install_opencode
if [[ "$install_opencode" =~ ^[Yy]$ ]]; then
  if command -v npm &>/dev/null; then
    npm install -g opencode-ai
    echo -e "${GREEN}  ✓ opencode installed${NC}"
  else
    echo -e "${YELLOW}  ⚠ npm not found — install manually: https://opencode.ai${NC}"
  fi
fi

# 5 — Done
echo ""
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
echo "  Skill location:  $SKILL_DIR/SKILL.md"
echo "  Global config:   $CLAUDE_MD"
echo "  Session files:   ~/.claude/sessions/"
echo ""
echo "  The skill is now active in every Claude Code session."
echo "  No commands needed — it runs automatically."
echo ""
echo -e "${BLUE}  Customize thresholds: $SKILL_DIR/SKILL.md${NC}"
echo -e "${BLUE}  Read the docs:        https://github.com/YOUR_USERNAME/claude-code-auto-optimizer${NC}"
echo ""
