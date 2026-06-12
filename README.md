# ⚡ claude-code-auto-optimizer

> A Claude Code skill that **automatically** manages token usage, session hygiene, agent routing, and tool prioritization — so you never think about cost again.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-skill-blueviolet)](https://docs.anthropic.com/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

---

## The problem

If you use Claude Code heavily, you've probably seen this in your usage report:

- **74–89%** of sessions running at **>150k context** (expensive even when cached)
- **61–64%** of sessions lasting **8+ hours** (background loops nobody's watching)
- **53%** of sessions **subagent-heavy** (each subagent = a full separate request)
- **6–7%** of usage from **Playwright/browser** (the most expensive tool per call)

Claude Code even tells you what to do — `/compact mid-task`, `/clear between tasks`, cheaper models for simple subagents — but you have to remember to do it every time.

**This skill makes it automatic.**

---

## What it does

Once installed, Claude Code will automatically:

| Trigger | Action |
|---------|--------|
| Context > 80k tokens | `/compact` immediately |
| Session active > 2h | `/compact` aggressively + notify you |
| Switching to a new task | Suggest `/clear` |
| Spawning a subagent for a simple task | Block it, do it directly instead |
| Simple subagent needed | Route to cheaper model (haiku) |
| About to open a large source file | Run code graph query first |
| About to use browser/Playwright | Try `curl`/`fetch`/API first |
| End of a long session | Auto-generate `/handoff` + run maintenance |

---

## Install

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/claude-code-auto-optimizer/main/install.sh | bash
```

### Manual

```bash
git clone https://github.com/YOUR_USERNAME/claude-code-auto-optimizer
cd claude-code-auto-optimizer
bash install.sh
```

The installer:
1. Copies `SKILL.md` to `~/.claude/skills/auto-optimizer/`
2. Creates/updates `~/.claude/CLAUDE.md` with global trigger rules
3. Optionally installs companion tools (see below)

---

## How it works

Claude Code reads the `description` field in `SKILL.md` at the start of every session. Because the description explicitly lists all trigger conditions (`session start`, `new task`, `high context`, `subagent spawn`, `file read`, `session end`), Claude Code applies the skill **automatically** — no commands needed.

The skill enforces a **3-phase cycle**:

```
START OF SESSION
  → load memory/handoff from previous session
  → query code graph (no need to read source files)
  → check wiki/docs index
  → result: clean context, full information

DURING SESSION
  → check context every tool call (>80k → /compact)
  → route to cheapest capable model
  → use curl/API before browser
  → query code graph before opening files

END OF SESSION (automatic, no prompting needed)
  → generate /handoff file for next session
  → update indexes (code graph + docs)
  → update memory
  → /clear
```

**Key insight:** with `/handoff` + session memory + code graph queries, running `/clear` is nearly free — you lose nothing, you just start fresh.

---

## Companion tools

The skill works standalone, but it's most powerful when paired with these tools. Each one is optional and the skill degrades gracefully without them.

| Tool | What it does | Why it matters |
|------|-------------|----------------|
| **[opencode](https://github.com/sst/opencode)** | Routes LLM calls to DeepSeek (free tier) | Makes most agent work cost $0 |
| **[graphify](docs/tools.md#graphify)** | Builds a knowledge graph of your codebase | Query structure without reading files |
| **[handoff](docs/tools.md#handoff)** | Saves session state for next session | `/clear` without losing context |
| **[qmd](docs/tools.md#qmd)** | Indexes your wiki/docs for semantic search | Fast recall without loading full docs |
| **Any memory tool** | Cross-session recall | e.g. Claude Code's built-in `/memory` |

See [docs/tools.md](docs/tools.md) for installation instructions.

---

## Configuration

After install, edit `~/.claude/skills/auto-optimizer/SKILL.md` to customize:

```yaml
# Change these thresholds to match your workflow
COMPACT_THRESHOLD: 80k tokens     # default: 80k
SESSION_MAX_HOURS: 2              # default: 2h
SUBAGENT_MAX_STEPS: 10           # default: 10 steps
```

See [docs/advanced.md](docs/advanced.md) for full configuration options.

---

## Real-world results

Before/after from a real project (7-day period):

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Sessions >150k context | 74% | ~18% | **−76%** |
| Sessions >8h | 61% | ~12% | **−80%** |
| Subagent-heavy sessions | 53% | ~20% | **−62%** |
| Browser/Playwright usage | 7% | ~1.5% | **−78%** |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). PRs welcome — especially:
- Adapters for other memory/recall tools
- Tool-specific optimizations
- Non-English versions of the skill

---

## License

MIT — see [LICENSE](LICENSE)
