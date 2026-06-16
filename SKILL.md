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

## Phase 0 — The automatic loop (installed hooks)

`install.sh` wires three Claude Code lifecycle hooks into `~/.claude/settings.json`
so session hygiene happens **without anyone asking**. The loop, per project:

```
SessionStart → scripts/session-init.sh
   scans the repo + previous docs/HANDOFF-*.md + planning-with-files artifacts,
   builds/refreshes docs/.session/STATE.md (open tasks · handoff index · facts),
   injects a state summary so the thread is never lost. (startup=INIT, resume/clear=RELOAD)

Stop → scripts/stop-nudge.sh
   ONCE per session (marker-guarded, non-blocking): reminds Claude to run the
   `handoff` skill, tick the roadmap, add a MEMORY line, update STATE — before /clear.

SessionEnd → scripts/session-flush.sh   ← the hard guarantee ($0, no LLM)
   qmd update+embed -c <coll> · graphify update . · snapshot docs/HANDOFF-latest.md
   · git add docs/ && commit (only if changed). SessionEnd is observability-only and
   cannot inject — so the mechanical flush lives here and always fires (clear/logout/exit).
        └──► next SessionStart resumes from STATE.md
```

**Reused, not reinvented:** the `planning-with-files` skill (file-based task ledger +
auto-recovery after /clear) feeds STATE.md; the `handoff` skill writes the narrative.
**Hard deps for the flush layer:** `qmd`, `graphify` (fail loud if absent).
`docs/.session/STATE.md` is the single "don't lose the thread" ledger — read it first.

## Phase 1 — Session start

1. If `~/.claude/sessions/` contains a recent handoff file for this
   project, read it before touching anything else.
2. Get oriented with Glob and Grep — do not read whole source files just
   to "understand the project". CLAUDE.md and the handoff already carry
   the durable context.

## Phase 2 — During the session: keep context lean automatically

Claude Code **auto-compacts on its own** near the context limit, and the
`PreCompact` hook auto-preserves the task state in the summary. Do **not**
stop work to tell the user to run `/compact` — that is noise, not
optimization. Your job is to stop context from bloating in the first
place, silently, on every action you take:

| Signal | Automatic action — no user prompt |
|--------|-----------------------------------|
| About to read a large file | Grep, or Read with offset+limit — never the whole file to "understand it" |
| About to spawn a subagent | Apply Phase 3 routing; a subagent's context never returns, so isolate cost there |
| About to fetch a web page | WebFetch / curl first; Playwright only if the page needs JS, close it immediately |
| Context already large | Tighten routing further and keep working; let built-in auto-compact fire when it must |
| User switches to an unrelated task | Write the handoff file (Phase 4) **automatically**, then carry on |

The only time you surface context cost to the user: they are about to hit
a hard usage or billing limit they would want to decide about (check
`/usage` or `/cost`). Otherwise optimize silently — never hand a
`/compact` or `/clear` decision back to the user as a substitute for
doing the cheap thing yourself.

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

> Most of this is now **automatic** via the Phase 0 hooks: the mechanical flush
> (qmd/graphify/snapshot/commit) runs itself at `SessionEnd`, and the `Stop`
> nudge reminds Claude to do the narrative parts. The steps below are what that
> nudge asks for — do them when prompted; don't hand the decision back to the user.

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
3. **GOLDEN RULE — always print the restart prompt before `/clear`.** Never
   let the user `/clear` without first giving them a ready-to-paste kickoff
   prompt for the next session. Output it in a fenced block so they can copy
   it verbatim. It must:
   - point to the handoff file(s) + key memories to load FIRST;
   - state the next concrete task in one line (the "next session goal");
   - carry the hard constraints (deploy gates, prod-safety, token discipline);
   - tell them what NOT to redo (already-done work).
   Template:
   ```
   Sessione: <next goal>. Carica stato PRIMA di agire:
   1. <handoff path(s)>
   2. memorie: <slugs>
   GIÀ FATTO (non rifare): <bullets>
   TASK: <one precise line + acceptance/verifier>
   VINCOLI: <deploy gate / prod-safety / token discipline>
   ```
4. `/clear` is terminal (it ends the thread) so it stays the user's call,
   but the handoff file + the restart prompt above are produced
   *automatically* first — so whenever they clear, nothing is lost. Don't
   nag; just keep the handoff current and always hand over the kickoff prompt.

Cost: ~1–2k tokens. Saving: the tens of thousands the next session would
burn re-deriving the same state.

## Anti-patterns — stop if you catch yourself doing these

| Anti-pattern | Correction |
|--------------|-----------|
| "I'll read the file to see how it's structured" | Grep/Glob first; read only the lines you need |
| "I'll spawn a subagent for this 2-file fix" | Do it directly in the main thread |
| "Context is huge but I'm almost done" | Tighten reads/routing and finish; auto-compact handles the rest — don't stop to ask |
| "I'll tell the user to /compact" | Optimize silently instead; only flag a real usage/billing limit |
| "Just /clear, I'll remember the state" | Handoff file FIRST, always |
| "I'll open the browser to check the page" | WebFetch/curl first; browser only if JS required |
| "Chain subagents: A, then B, then C" | Sequential work belongs in the main thread |

## Customization

Edit this file at `~/.claude/skills/auto-optimizer/SKILL.md` to tune the
heuristics (subagent step threshold, file-size threshold, handoff
location) to your workflow. The `description` field controls when Claude
Code loads the skill — keep the trigger phrases if you edit it.
