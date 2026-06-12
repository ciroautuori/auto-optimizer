# Companion Tools

The skill works without any companion tools. But each tool you add
unlocks a new layer of automation. Here's what each one does and how
to install it.

---

## opencode — Free LLM routing

**What it does:** Routes Claude Code's LLM calls through DeepSeek and
other free-tier models. Most coding tasks work just as well at $0.

**Install:**
```bash
npm install -g opencode-ai
```

**Why it matters:** The skill routes all default tasks to opencode.
You only pay for Claude when you explicitly need it (`quality=high`).

→ [github.com/sst/opencode](https://github.com/sst/opencode)

---

## handoff — Session bridge

**What it does:** Saves a structured summary of your session state that
Claude Code loads at the start of the next session. Lets you `/clear`
without losing anything.

**How it works:**
At the end of a session, the skill runs:
```
/handoff <next session goal>
```
This saves a file to `~/.claude/sessions/YYYY-MM-DD-<slug>.md`
containing: running services state, open tasks, key decisions,
exact next steps.

Next session, Claude reads this file first — before touching any code.

**No install needed** — it's built into the skill. Just make sure
`~/.claude/sessions/` exists (the installer creates it).

---

## graphify — Codebase knowledge graph

**What it does:** Builds an AST-based knowledge graph of your project.
Instead of reading source files into context, you query the graph:

```bash
graphify query "how does authentication work"
graphify path "UserService" "DatabasePool"
graphify explain "caching layer"
```

Each query returns a small targeted subgraph — much cheaper than
loading the actual files.

**The skill uses it automatically:** Before opening any `.py`, `.ts`,
`.js`, or similar file, Claude will run `graphify query` first.

**Install:**
```bash
pip install graphify-cli   # if available on PyPI
# or: check the project repo for installation instructions
```

→ Adapt to your preferred code navigation tool:
  `ctags`, `ast-grep`, `tree-sitter`, `semgrep`, `sourcegraph/src-cli`

---

## qmd — Docs/wiki indexer

**What it does:** Indexes your markdown documentation and wiki for
fast semantic search. Keeps an embedding index so Claude can find
relevant docs without loading them all into context.

```bash
qmd update -c ops    # reindex after changes
qmd embed -c ops     # rebuild embeddings
qmd query "how does X work"
```

**The skill uses it:** After any wiki/doc changes, the skill runs
`qmd update` automatically.

→ Adapt to your preferred docs tool:
  `llama-index`, `chromadb`, `weaviate`, Obsidian Smart Search,
  `docs-as-code` pipelines

---

## Memory / recall tool

**What it does:** Stores key facts across sessions so Claude doesn't
need to re-discover them every time.

**Options:**

Built-in Claude Code memory:
```bash
# Claude Code has /memory built in
# The skill writes to ~/.claude/projects/<project>/MEMORY.md
```

Custom recall tool (advanced):
```bash
# Any tool that:
# 1. Accepts: jarvis-recall "query"
# 2. Returns: relevant past context
# 3. Accepts: jarvis-recall --used <uri>  (to signal a doc was useful)
```

→ Adapt to: Claude Code `/memory`, `mem0`, custom SQLite, Notion API

---

## Minimum setup (no tools installed)

Even without any companion tools, the skill provides:
- ✅ Auto `/compact` at 80k context
- ✅ Auto `/clear` suggestions between tasks  
- ✅ Subagent routing to cheaper models
- ✅ Playwright/browser minimization
- ✅ End-of-session handoff file generation
- ✅ File reading optimization (grep before cat)

Tools multiply the effect but aren't required.
