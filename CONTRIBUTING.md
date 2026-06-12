# Contributing

PRs welcome. Here's what's most useful:

## High-value contributions

- **Tool adapters** — if you use a different memory/recall/code-graph tool,
  add a section to `docs/tools.md` with install + config instructions
- **Workflow examples** — real before/after usage stats in `examples/`
- **Language-specific thresholds** — some codebases need different compact
  triggers (e.g. large monorepos vs small scripts)
- **Non-English skill versions** — the description field in SKILL.md
  determines auto-activation; translations help non-English users

## How to contribute

1. Fork the repo
2. Create a branch: `git checkout -b my-improvement`
3. Make your changes
4. Test: install locally with `bash install.sh` and verify in Claude Code
5. Open a PR with a short description of what changed and why

## Skill description field — important

The `description:` in `SKILL.md` is what tells Claude Code when to
auto-activate this skill. If you modify it:
- Keep all the trigger keywords (`session start`, `high context`, etc.)
- Keep `ALWAYS ON` and `Not needed to invoke explicitly`
- Test that the skill still auto-fires in a fresh Claude Code session

## Reporting issues

Use GitHub Issues. Include:
- Claude Code version (`claude --version`)
- Which companion tools you have installed
- Your usage report stats (optional but helpful)
