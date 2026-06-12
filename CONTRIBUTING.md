# Contributing

PRs welcome. Here's what's most useful:

## High-value contributions

- **Real-world stats** — before/after numbers from your own Claude Code
  usage data; the README's target metrics improve with more samples
- **Threshold tuning** — large monorepos and small scripts need different
  compact/read heuristics; document what worked for you
- **Translations** — non-English versions of SKILL.md (keep the English
  `description` trigger phrases so auto-loading still works)
- **Handoff format improvements** — better session-bridge templates

## Ground rules

- **Built-in Claude Code features only.** No external tools, no other AI
  providers, no required dependencies. The zero-dependency promise is the
  point of the project.
- **No invented commands or claims.** If Claude Code can't do it, the
  skill must not say it does. (`/compact` and `/clear` are user commands —
  the skill recommends them, it can't run them.)

## How to contribute

1. Fork the repo
2. Create a branch: `git checkout -b my-improvement`
3. Make your changes
4. Test: `bash install.sh`, open a fresh Claude Code session, verify the
   skill triggers and the behavior matches what your change claims
5. Open a PR with a short description of what changed and why

## Skill description field — important

The `description:` in `SKILL.md` is what tells Claude Code when to load
this skill. If you modify it:

- Keep it as "when to use" triggers — don't summarize the workflow in it
- Keep the trigger phrases (session start, task switch, subagent, large
  file, long conversation, "optimize tokens")
- Test that the skill still loads in a fresh session before opening a PR

## Reporting issues

Use GitHub Issues. Include:

- Claude Code version (`claude --version`)
- Your plan type (Pro / Max / API) — the optimization target differs
- Relevant usage stats (optional but helpful)
