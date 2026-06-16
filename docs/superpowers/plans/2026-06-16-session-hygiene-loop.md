# Session-Hygiene Loop — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Make session hygiene (init/scan → STATE ledger → handoff → roadmap → qmd/graphify → memory → commit) happen automatically via Claude Code hooks, no manual asking.

**Architecture:** Three hooks installed into user `settings.json` by `install.sh` (merge, not overwrite). `SessionStart`→`session-init.sh` scans repo + previous handoffs + planning-with-files artifacts, builds/refreshes `docs/.session/STATE.md`, injects a state summary via `additionalContext`. `Stop`→`stop-nudge.sh` emits a once-per-session non-blocking reminder (marker-guarded) to run the `handoff` skill, tick the roadmap, add a MEMORY line, update STATE. `SessionEnd`→`session-flush.sh` runs the mechanical flush ($0, no LLM): `qmd update+embed`, `graphify update .`, snapshot `docs/HANDOFF-latest.md`, `git add docs/ && commit`. All scripts read the hook JSON on stdin (session_id, cwd, source) and are parametric on cwd + `--collection`. Reuses existing `planning-with-files` and `handoff` skills instead of reinventing.

**Tech Stack:** Bash, python3 (stdin JSON parse + settings.json merge), git, qmd, graphify. Test bed = auto-optimizer repo itself.

**Hard deps (fail loud):** `qmd`, `graphify`. **Reused skills:** `planning-with-files` (task ledger / auto-recovery), `handoff` (narrative).

---

## File structure

- `scripts/lib/common.sh` — shared: parse stdin JSON → SESSION_ID/PROJ_CWD/SOURCE; MARKER_DIR; `is_git_repo`; `log`.
- `scripts/session-init.sh` — SessionStart. Scan + build/refresh STATE.md; print summary (stdout reaches Claude).
- `scripts/stop-nudge.sh` — Stop. Marker-guarded once/session; emit JSON `hookSpecificOutput.additionalContext`.
- `scripts/session-flush.sh` — SessionEnd. Mechanical flush, hard-dep qmd+graphify, commit.
- `scripts/lib/state-template.md` — STATE.md seed.
- `tests/smoke.sh` — bash smoke test, runnable in this repo.
- `install.sh` — patched: copy scripts/, merge 3 hooks into settings.json (backup), check hard deps.
- `SKILL.md`, `README.md` — document the loop.

## STATE.md shape (`docs/.session/STATE.md`, committed)

```markdown
# SESSION STATE — <project>
> auto-maintained by auto-optimizer. Loaded each SessionStart. Don't lose the thread.

## Open tasks (carried across sessions)
- [ ] <task>

## Handoff index (newest first)
- <date> — <file> — <one-line>

## Durable project facts
- <fact>

_last refresh: <ISO> · branch <b> · <commit>_
```

---

### Task 1: common lib + STATE template

**Files:** Create `scripts/lib/common.sh`, `scripts/lib/state-template.md`

- [ ] Write `common.sh`: read stdin JSON once via python3 → export `SESSION_ID`, `PROJ_CWD`, `SOURCE`; set `MARKER_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/auto-optimizer"`; `is_git_repo()`; `log()` to stderr.
- [ ] Write `state-template.md` seed.
- [ ] Commit.

### Task 2: session-init.sh (SessionStart)

**Files:** Create `scripts/session-init.sh`

- [ ] Resolve project dir (PROJ_CWD or `$PWD`). If not git → emit nothing, exit 0.
- [ ] Ensure `docs/.session/`. If STATE.md missing → INIT: seed from template, fill project name, scan `git log --oneline -8`, parse `docs/HANDOFF-*.md` (grep `Next steps`/`- [ ]` lines) into Open tasks, build Handoff index from filenames. If exists → RELOAD: refresh `_last refresh_` line + append any new HANDOFF-*.md to index.
- [ ] Also fold in `planning-with-files` artifacts if present (`docs/**/progress.md`, `task_plan.md`): append their open `- [ ]` to Open tasks (dedup).
- [ ] Print to stdout a compact summary (state path + open task count + top 5 tasks + latest handoff) — reaches Claude as context.
- [ ] Commit.

### Task 3: stop-nudge.sh (Stop)

**Files:** Create `scripts/stop-nudge.sh`

- [ ] Marker `"$MARKER_DIR/nudged-$SESSION_ID"`. If exists → print `{}` exit 0 (no repeat).
- [ ] Else create marker, emit JSON:
```json
{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"auto-optimizer: prima che l'utente faccia /clear — invoca skill `handoff`, ticka i checkbox in ROADMAP-MASTER, aggiungi 1 riga a MEMORY.md, e aggiorna docs/.session/STATE.md (task done/nuovi). Il flush meccanico (qmd+graphify+commit) parte da solo a SessionEnd."}}
```
- [ ] Non-blocking (no `decision:block`). Exit 0.
- [ ] Commit.

### Task 4: session-flush.sh (SessionEnd)

**Files:** Create `scripts/session-flush.sh`

- [ ] Args: `--collection <coll>` default `eros`. Resolve project dir. Not git → exit 0.
- [ ] Hard-dep check: `command -v qmd` and `command -v graphify` → if missing, `log` loud error + exit 1.
- [ ] `qmd update -c "$COLL" && qmd embed -c "$COLL"` (best-effort, log on fail, don't abort commit).
- [ ] `graphify update .` (best-effort, log on fail).
- [ ] Snapshot `docs/HANDOFF-latest.md`: date, branch, `git status -s`, `git log --oneline -8`.
- [ ] `git add docs/ && git commit -m "chore(session): auto-flush"` only if staged changes exist.
- [ ] Commit the script.

### Task 5: install.sh merge 3 hooks + deps check

**Files:** Modify `install.sh`

- [ ] Copy `scripts/` → `~/.claude/skills/auto-optimizer/scripts/` (chmod +x).
- [ ] Hard-dep check: warn loud if `qmd`/`graphify` absent (pipeline degraded).
- [ ] python3 merge into `~/.claude/settings.json`: backup `.bak` first; add SessionStart/Stop/SessionEnd command hooks pointing at installed scripts; idempotent (skip if our command already present); never overwrite existing hooks.
- [ ] Commit.

### Task 6: smoke test + run in this repo

**Files:** Create `tests/smoke.sh`

- [ ] Simulate SessionStart: pipe fake JSON `{"session_id":"smoke1","cwd":"<repo>","source":"startup"}` to session-init.sh → assert STATE.md created, summary printed.
- [ ] Simulate Stop twice with same session_id → assert first emits additionalContext, second emits `{}` (marker idempotent).
- [ ] Simulate SessionEnd → assert HANDOFF-latest.md written (qmd/graphify may be stubbed via PATH shim in test).
- [ ] Run `bash tests/smoke.sh` → all assertions pass.
- [ ] Commit.

### Task 7: SKILL.md + README + push

- [ ] SKILL.md: replace manual Phase-4 steps with "automatic via hooks" + describe the loop + reused skills.
- [ ] README: add "Automatic session hygiene" section + note hard deps qmd+graphify (no longer zero-dep for the flush layer).
- [ ] Commit + `git push origin main`.

## Self-review notes
- Spec coverage: init/scan ✓(T2), STATE ledger ✓(T1/T2), Stop nudge ✓(T3), flush qmd+graphify+commit ✓(T4), install merge+backup+deps ✓(T5), test bed ✓(T6), docs+push ✓(T7).
- Reuse: planning-with-files folded in T2; handoff invoked by T3 nudge.
- Honesty: SessionEnd can't inject (observability-only) → mechanical flush only; LLM handoff is the Stop nudge (best-effort timing).
