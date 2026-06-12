---
name: auto-optimizer
description: >
  Automatic token and cost optimization skill for Claude Code.
  Activates automatically on EVERY session — no manual invocation needed.
  Handles: /compact at 80k context, /clear between tasks, agent routing
  (free models default, haiku for simple subagents), session cap at 2h,
  browser/Playwright as last resort, code graph queries before reading
  source files, session memory and handoff at end of session.
  Triggers: session start, new task, high context, subagent spawn,
  browser use, source file read, session end. ALWAYS ON.
---

# AUTO-OPTIMIZER — Claude Code Token & Cost Control

> Runs automatically. No commands needed. Adapts to your tool stack.

---

## PHASE 0 — START OF SESSION

Before doing anything else:

```
1. Load previous session state
   → read ~/.claude/sessions/latest-handoff.md  (if exists)
   → load memory / recall tool output           (if configured)
   → run code graph query for project state     (if graphify/similar available)
   → result: clean context, full information

2. Check current context size
   → if any context already loaded > 40k: consider /compact before starting
```

---

## PHASE 1 — CONTEXT CHECK (before every tool call)

```
context < 40k   → proceed normally
context 40-80k  → /compact before loading large files or spawning subagents
context > 80k   → /compact IMMEDIATELY, then proceed
context > 120k  → /compact REQUIRED + warn user
```

---

## PHASE 2 — SESSION CHECK (ongoing)

```
New task, different from previous?  → suggest /clear before starting
Session active > 2 hours?           → run /compact aggressively, warn user
Background loop with no output?     → pause and ask if it should continue
```

---

## PHASE 3 — ROUTING (before every LLM or tool call)

**Agent routing — cheapest capable model:**
```
Task is simple (< 10 steps, touches 1 file)  → do it DIRECTLY, no subagent
Task is parallelizable + independent         → subagent with cheap model (haiku/flash)
Task is sequential                           → do in sequence, NO subagent
Task requires max quality                    → full model only if explicitly requested
DEFAULT always                               → free tier model (opencode/DeepSeek/Gemini)
```

**Tool routing — cheapest capable tool:**
```
Question about codebase structure  → code graph query BEFORE opening files
  (graphify, ctags, tree-sitter, ast-grep, or similar)
Cross-session recall               → memory tool BEFORE raw file search
Web scraping / data fetch          → curl / fetch / official API FIRST
  → Playwright / browser           → LAST RESORT only, close immediately after
Reading a file > 200 lines         → grep / head / tail / ripgrep FIRST
Fleet / remote dispatch            → only for tasks that take > 15 min
```

---

## PHASE 4 — END OF SESSION (automatic, no prompting needed)

Run this after every significant work block, unprompted:

```
1. /handoff — generate session handoff
   save to: ~/.claude/sessions/YYYY-MM-DD-<task-slug>.md
   include:
     - current state of running services
     - tasks completed this session
     - tasks still open (with context)
     - key decisions made
     - exact next steps for next session

2. Update indexes
   → code graph:  graphify update .  (or equivalent)
   → docs/wiki:   update your indexing tool
   → memory:      add session summary to memory file

3. Update task tracking
   → mark completed tasks as done
   → update README.md if architecture changed

4. /clear  ← start next session fresh with zero context cost
```

---

## NUMERIC THRESHOLDS — reference

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Context → /compact | > 80k tokens | immediate /compact |
| Session → /compact | > 2h active | aggressive /compact |
| Session → /clear | task switch | suggest /clear |
| Subagent model | simple task | cheap model (haiku/flash) |
| Subagent spawn | < 10 steps | NO subagent, do directly |
| Browser use | API available | use API instead |
| File read | > 200 lines | grep/head first |
| Remote dispatch | < 15 min task | do locally |

---

## TOOL PRIORITY STACK

Adapt this to your actual installed tools:

```
RECALL / SEARCH
  Priority 1: your memory/recall tool     (cross-session, hot docs)
  Priority 2: code graph tool             (structure queries, no file reads)
  Priority 3: docs/wiki index             (after updates only)
  Avoid:      raw file reads              (expensive, loads context fast)

BROWSER / FETCH
  Priority 1: curl / wget / fetch         (free, fast)
  Priority 2: official API               (if available)
  Priority 3: Playwright / browser        (last resort, close after use)

LLM ROUTING
  Priority 1: free tier model             (DeepSeek, Gemini Flash, etc.)
  Priority 2: cheap fast model            (haiku, flash) for subagents
  Priority 3: standard model             (sonnet) for complex tasks
  Priority 4: max model                  (opus) only on explicit request

SESSION HYGIENE
  /compact     when context > 80k or session > 2h
  /handoff     at end of every long session
  /clear       when switching to a new unrelated task
```

---

## TARGET METRICS

Use your Claude Code usage report to track improvement:

| Metric | Typical before | Target |
|--------|---------------|--------|
| Sessions > 150k context | ~75% | < 20% |
| Sessions > 8h | ~60% | < 15% |
| Subagent-heavy sessions | ~50% | < 25% |
| Browser tool % of total | ~7% | < 2% |

---

## CUSTOMIZATION

Edit the thresholds in this file to match your workflow.
The description field controls when this skill auto-activates —
keep the trigger keywords to ensure it fires on every session.
