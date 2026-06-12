# Built-in Claude Code features the skill uses

Everything here ships with Claude Code. Nothing to install.

---

## Context management

| Command | What it does | When the skill recommends it |
|---------|--------------|-------------------------------|
| `/compact` | Summarizes the conversation and frees context | Conversation grown long, before loading big files, long-running sessions |
| `/clear` | Wipes the conversation, fresh start | Task switch — *after* a handoff file is written |
| `/context` | Shows what's occupying your context window | Diagnosing why context is large |

Claude Code also auto-compacts when the context window fills up, but by
then the expensive tokens are already spent. Compacting early and
deliberately is the whole point.

---

## Cost & usage visibility

| Command | Shows | For |
|---------|-------|-----|
| `/usage` | Position in your 5-hour and weekly usage windows | Pro / Max subscribers |
| `/cost` | Dollar cost of the current session | API (pay-as-you-go) users |

Check one of these at the start of a heavy work day so you know your
budget before committing to a long session.

---

## Model selection

| Mechanism | What it does |
|-----------|--------------|
| `/model` | Switches the main conversation model |
| Subagent `model` field | Pins a subagent to a specific model — set `model: haiku` in the agent's frontmatter, or pass the model when dispatching |

Rule of thumb the skill enforces: the main thread runs your chosen model;
simple parallel subagents run `haiku`; the most expensive models are for
explicit requests only.

---

## Subagents

Custom subagents live in `.claude/agents/` (project) or
`~/.claude/agents/` (global). Each spawn is a separate request with its
own context window — that's why the skill blocks subagents for trivial
tasks: the spawn overhead exceeds the work.

Good subagent use: parallel, independent, well-scoped tasks.
Bad subagent use: sequential chains, single-file fixes, "just to be thorough".

---

## Memory

| Mechanism | Scope | Use for |
|-----------|-------|---------|
| `~/.claude/CLAUDE.md` | All projects | Global working rules (the installer's optional block goes here) |
| `./CLAUDE.md` | One project | Project conventions, commands, architecture notes |
| `# <note>` shortcut / `/memory` | Quick capture | Adding a memory mid-session |

The skill writes durable, non-obvious facts to memory at session end —
never things git history already records.

---

## Handoff files (skill convention, not a built-in command)

There is no `/handoff` command in Claude Code. "Handoff" is this skill's
convention: at session end, Claude writes a structured markdown file to
`~/.claude/sessions/YYYY-MM-DD-<slug>.md` with what was done, decisions
made, and exact next steps. The next session reads it first.

That file is what makes `/clear` nearly free.
