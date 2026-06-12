---
name: auto-optimizer
description: Use when starting a session, switching to a new task, about to spawn a subagent, about to read a large file, about to fetch web content, or when the conversation has grown long. Also use when the user mentions "optimize tokens", "reduce cost", "context too big", "hitting usage limits", or asks for a clean session.
---

# Auto-Optimizer — Token & Cost Hygiene for Claude Code

> Goal: maximum information at minimum cost — not fewer tokens for their own
> sake. A short, well-fed context beats a long, noisy one.
>
> Everything in this skill uses built-in Claude Code features only.
> No external tools, no other AI providers, no dependencies.

## Know what you're optimizing

Check the user's plan once per session (ask if unknown) and optimize the
right metric:

| Plan | You pay with | Check via | Optimize for |
|------|--------------|-----------|--------------|
| Pro / Max subscription | Usage limits (5-hour and weekly windows) | `/usage` | Fewer tokens per task → more work before hitting limits |
| API / pay-as-you-go | Dollars per token | `/cost` | Smaller context, cheaper models |
| Team / Enterprise | Seat or usage policy | Org admin | Same as above |

The rules below are identical for every plan — only the metric differs.
Every message resends the whole conversation context, so context size is
the single biggest cost lever on any plan.

## Phase 1 — Session start

1. If `~/.claude/sessions/` contains a recent handoff file for this
   project, read it before touching anything else.
2. Get oriented with Glob and Grep — do not read whole source files just
   to "understand the project". CLAUDE.md and the handoff already carry
   the durable context.

## Phase 2 — During the session: context checks

Claude cannot run `/compact` or `/clear` itself — these are user commands.
The skill's job is to *recommend them at the right moment* and to keep the
context from growing in the first place.

| Signal | Action |
|--------|--------|
| Conversation getting long (many file reads, long tool outputs) | Recommend `/compact` to the user **now**, before loading more |
| About to load large files or spawn subagents in an already-long session | Recommend `/compact` first |
| User switches to an unrelated task | Write a handoff file, then recommend `/clear` |
| Session active for hours on the same thread | Recommend `/compact` and flag it to the user |

Don't wait for auto-compact to fire — by then the expensive tokens are
already spent. Compact early, compact deliberately.

## Phase 3 — Routing: cheapest capable option

**Subagent routing** (in order — first match wins):

```
Task < 10 steps or touches 1-2 files  → NO subagent. Do it directly.
Task is sequential (A then B then C)  → NO subagent. Sequence lives in the main thread.
Parallel + independent + simple       → subagent with model: haiku
Parallel + independent + complex      → subagent with model: sonnet
Opus subagents                        → only on explicit user request
```

Each subagent is a full separate request with its own context. Spawning
one for a two-file fix costs more than just doing the fix.

**Tool routing** (cheapest tool that answers the question):

```
"Where is X / what calls Y?"      → Grep / Glob — never read files to browse
File > 200 lines                  → Grep for the section, or Read with offset+limit
Web page content                  → WebFetch or curl FIRST
Browser automation (Playwright)   → LAST RESORT, only when the page needs JS
                                     or interaction; close the browser right after
```

## Phase 4 — Session end (before /clear, always)

A handoff makes `/clear` nearly free: the context resets, the knowledge
doesn't.

1. Write a handoff file to `~/.claude/sessions/YYYY-MM-DD-<task-slug>.md`:

   ```markdown
   # Handoff — <title>
   > Next session goal: <one precise line>

   ## Done this session        (with commit hashes)
   ## Decisions made           (one line each, with the why)
   ## Next steps               (numbered, actionable, commands ready)
   ## Quick references         (paths, key files, smoke-test commands)
   ```

2. Update project memory (CLAUDE.md or auto memory) only with facts that
   are non-obvious and durable — not things git history already records.
3. Recommend `/clear` so the next session starts fresh.

Cost: ~1–2k tokens. Saving: the tens of thousands the next session would
burn re-deriving the same state.

## Anti-patterns — stop if you catch yourself doing these

| Anti-pattern | Correction |
|--------------|-----------|
| "I'll read the file to see how it's structured" | Grep/Glob first; read only the lines you need |
| "I'll spawn a subagent for this 2-file fix" | Do it directly in the main thread |
| "Context is huge but I'm almost done" | Recommend `/compact` now, then finish |
| "Just /clear, I'll remember the state" | Handoff file FIRST, always |
| "I'll open the browser to check the page" | WebFetch/curl first; browser only if JS required |
| "Chain subagents: A, then B, then C" | Sequential work belongs in the main thread |

## Customization

Edit this file at `~/.claude/skills/auto-optimizer/SKILL.md` to tune the
heuristics (subagent step threshold, file-size threshold, handoff
location) to your workflow. The `description` field controls when Claude
Code loads the skill — keep the trigger phrases if you edit it.
