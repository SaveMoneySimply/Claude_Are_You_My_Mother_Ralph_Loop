# HANDOFF — Ralph Loop / AYMM — 2026-05-26

> **Delete this file after reading.** It exists only to bridge sessions.

## Where we are
ralph-v2 is fully complete and committed — 4-stage task pipeline in place, bash-side navigation in loop.sh, prompt.md shrunk to 11 lines. One task remains: **aymm-unify** (`tasks/1_queue/aymm-unify.md`), which folds `aymm.sh` into `ralph.sh` as a third mode.

## What was just done
- Migrated directory structure: `tasks/{done,active}` → `tasks/{0_backlog,1_queue,2_active,3_done}`
- Rewrote `loop.sh` navigation: bash picks task, extracts next step, builds focused prompt — Claude no longer reads PLAN.md or scans task directories
- Shrunk `prompt.md` from 45 lines to 11 (step executor only)
- Trimmed `CLAUDE.md` — navigation sections replaced with 4-stage pipeline description
- Updated `ARCHITECTURE.md` — directory map, key files, test command
- Added commented chmod block to `init-firewall.sh` for engine files
- Closed ralph-v2 task, updated CHANGELOG

## Current blocker / next step
**Implement aymm-unify** — 5 steps, full spec at `tasks/1_queue/aymm-unify.md`.

Summary: add `aymm)` case to `ralph.sh` (copy API key env vars from `aymm.sh`), update `aymm-loop.sh` for new directory paths (`tasks/active/` → `tasks/2_active/` etc.), delete `aymm.sh`, update `ARCHITECTURE.md`, verify.

## Key files changed this session
- `loop.sh` — full navigation rewrite; `pick_task()`, `build_step_prompt()`, all refs updated
- `prompt.md` — down to 11 lines; bash injects step below it
- `CLAUDE.md` — 4-stage pipeline throughout; navigation sections removed
- `ARCHITECTURE.md` — directory map added, key files and test command updated
- `init-firewall.sh` — commented chmod block for engine files added
- `tasks/3_done/ralph-v2.md` — completed task archived
- `tasks/0_backlog/` — old `plans/` files migrated here
- Old `tasks/done/` and `tasks/active/` dirs removed

## Open issues to keep in mind
- A `STOP` file exists from a previous loop run ("All tasks complete") — delete it before running ralph/aymm
- `aymm-loop.sh` still references `tasks/active/` and `tasks/done/` — fixing this is Step 2 of aymm-unify
- `prompt-aymm.md` also references old paths — check if it needs updating as part of aymm-unify
- `tasks/2_active/` is currently empty (correct — no task in progress)

## Commands to run to resume
```bash
# Delete stale STOP file
rm STOP

# Read the task before starting
cat tasks/1_queue/aymm-unify.md

# When ready, tell Claude:
# "Implement tasks/1_queue/aymm-unify.md one step at a time, committing after each step."
```
