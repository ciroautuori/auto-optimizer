# ⚡ auto-optimizer

> A Claude Code skill that keeps your sessions cheap and clean — context
> hygiene, smart subagent routing, and session handoffs, using **only
> built-in Claude Code features**. Zero dependencies.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-skill-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

---

## The problem

Claude Code resends the entire conversation context with every message.
If you work in long sessions, that means:

- Sessions running at **150k+ context** burn tokens on every single turn
- A subagent spawned for a trivial fix costs **a full separate request**
- Browser automation (Playwright MCP) is one of the most expensive tools
  per call — screenshots and page snapshots are thousands of tokens each
- `/clear` feels risky, so nobody runs it — and context never resets

Claude Code's docs already tell you the fixes: `/compact` mid-task,
`/clear` between tasks, `haiku` for simple subagents. But you have to
remember to do it every time, on every session.

**This skill makes Claude remember for you.**

---

## What it does

Once installed, in every session where it triggers, Claude will:

| Situation | Behavior |
|-----------|----------|
| Conversation grows long | Recommends `/compact` *before* loading more files |
| You switch to a new task | Writes a handoff file, recommends `/clear` |
| Simple task (< 10 steps) | Refuses to spawn a subagent — does it directly |
| Parallel simple subtasks | Routes subagents to `haiku` instead of your main model |
| Codebase questions | Uses Grep/Glob instead of reading whole files |
| Web content needed | Tries WebFetch/curl before opening a browser |
| End of session | Writes a structured handoff to `~/.claude/sessions/` |

**Honest note:** `/compact` and `/clear` are user commands — Claude cannot
run them for you. The skill makes Claude *recommend them at the right
moment* and, more importantly, changes Claude's own behavior so context
grows slower in the first place.

---

## Automatic session hygiene (hooks)

Beyond the skill's in-session behavior, `install.sh` wires three Claude Code
lifecycle hooks so the full session loop runs **without you asking**:

| Hook | Script | Does |
|------|--------|------|
| `SessionStart` | `scripts/session-init.sh` | Scans the repo + previous handoffs + planning files, (re)builds `docs/.session/STATE.md`, injects a state summary so you never lose the thread |
| `Stop` | `scripts/stop-nudge.sh` | Once per session (non-blocking): reminds Claude to run the `handoff` skill, tick the roadmap, add a memory line, update STATE — before you `/clear` |
| `SessionEnd` | `scripts/session-flush.sh` | The hard guarantee, $0, no LLM: `qmd update+embed`, `graphify update .`, snapshot `docs/HANDOFF-latest.md`, `git commit` |

```
SessionStart (init/scan) → STATE.md ──► work ──► Stop (nudge handoff) ──► SessionEnd (flush+commit)
        ▲                                                                          │
        └──────────────────────── loop: next session resumes from STATE ◄──────────┘
```

It **reuses** the `planning-with-files` skill (task ledger + auto-recovery after
`/clear`) and the `handoff` skill (narrative) instead of reinventing them.

> **Heads up — the flush layer is no longer zero-dependency.** `session-flush.sh`
> requires `qmd` and `graphify` on your `PATH` and fails loud if they're missing.
> The skill + the SessionStart/Stop layers stay dependency-free; only the
> mechanical flush needs them. `install.sh` warns you if either is absent.

The hooks are merged into `~/.claude/settings.json` (backed up first, existing
hooks preserved). Run `bash tests/smoke.sh` to see the whole loop exercised
against a throwaway repo.

## Works with your plan

The skill optimizes whichever metric your plan actually bills:

| Plan | What you're saving | Where to check |
|------|-------------------|----------------|
| **Pro / Max** | Usage limits (5-hour + weekly windows) — fewer tokens per task means more work before you hit them | `/usage` |
| **API (pay-as-you-go)** | Dollars — smaller context and cheaper subagent models directly cut spend | `/cost` |
| **Team / Enterprise** | Same levers, policy set by your org | admin console |

---

## Install

### Manual (recommended — read what you run)

```bash
git clone https://github.com/ciroautuori/auto-optimizer
cd auto-optimizer
bash install.sh
```

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/ciroautuori/auto-optimizer/main/install.sh | bash
```

The installer:

1. Copies `SKILL.md` to `~/.claude/skills/auto-optimizer/`
2. Optionally appends a compact rules block to `~/.claude/CLAUDE.md`
   (asks first — your file, your call)
3. Creates `~/.claude/sessions/` for handoff files

Uninstall: delete `~/.claude/skills/auto-optimizer/` and remove the
`AUTO-OPTIMIZER` block from `~/.claude/CLAUDE.md`.

---

## How it works

Two layers, both plain markdown:

1. **The skill** (`~/.claude/skills/auto-optimizer/SKILL.md`) — Claude
   Code loads skills on demand by matching their `description` field.
   This one triggers on session starts, task switches, subagent spawns,
   large file reads, web fetches, and long conversations.
2. **The CLAUDE.md block** (optional) — global memory is loaded into
   *every* session, so the core rules apply even when the skill isn't
   explicitly triggered.

The core idea is a three-phase cycle:

```
SESSION START   → read previous handoff → orient with Grep/Glob, not file dumps
DURING          → recommend /compact early · cheapest capable model/tool
SESSION END     → write handoff → update memory → recommend /clear
```

**Key insight:** a handoff file costs ~1–2k tokens and makes `/clear`
nearly free. The context resets; the knowledge doesn't.

See [tools.md](tools.md) for the built-in Claude Code commands the skill
leans on (`/compact`, `/clear`, `/usage`, `/cost`, `/model`, subagents).

---

## Target metrics

Pull your numbers from Claude Code's usage data, then track:

| Metric | Common in heavy use | Target |
|--------|--------------------:|-------:|
| Sessions exceeding 150k context | most | < 20% |
| Subagent-heavy sessions | ~half | < 25% |
| Browser/Playwright share of tool calls | varies | < 2% |

Your numbers will vary — the point is the direction, not the exact figure.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). PRs welcome — especially
real-world before/after usage stats, threshold tuning for different
codebase sizes, and translations.

---

## License

MIT — see [LICENSE](LICENSE)
