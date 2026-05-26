# HANDOFF — Ralph Loop / AYMM — 2026-05-26

> **Delete this file after reading.** It exists only to bridge sessions.

## Where we are
AYMM v1 is fully complete and committed. A v2 plan has been designed and approved, with two task files queued in `tasks/1_queue/` ready for implementation. The v2 plan document lives at `~/.claude/plans/ok-i-updated-geminiconvo2-md-valiant-pancake.md`.

## What was just done
- Completed AYMM loop (all 4 phases: provider-infrastructure, task-runner, aymm-orchestrator, integration)
- Fixed 4 bugs found in post-completion review: exit code 429→173 wrapping (now 100/101), double step-marking in aymm-loop.sh, missing `break` after STOP write in guard block, missing `perl` in Dockerfile
- Reviewed three Gemini conversations about AYMM design (Gemini-chat.md, GeminiConvo.md, GeminiConvo2.md)
- Planned and approved Ralph v2 + AYMM unification (two tasks, Claude-direct implementation recommended)
- Created task files in `tasks/1_queue/` and v3 ideas backlog in `plans/ralph-v3-ideas.md`
- Created new directory stubs: `tasks/0_backlog/`, `tasks/1_queue/`, `tasks/2_active/`, `tasks/3_done/`

## Current blocker / next step
**Implement Task 1: ralph-v2** — full task spec at `tasks/1_queue/ralph-v2.md`.

7 steps: migrate directory structure → rewrite loop.sh navigation (bash does the step-finding, not Claude) → shrink prompt.md to ~8 lines → trim CLAUDE.md → update init-firewall.sh (commented-out chmod block) → update ARCHITECTURE.md → verify.

This is the high-value change: Claude currently burns 30-40% of each iteration just navigating to find the next step. Token-stripping moves all navigation to bash.

**Then Task 2: aymm-unify** — full spec at `tasks/1_queue/aymm-unify.md`. Folds `aymm.sh` into `ralph.sh` as a third mode (`bash ralph.sh aymm`). Deletes `aymm.sh`.

## Key files changed this session
- `aymm-loop.sh` — fixed exit codes (100/101), removed double mark_step_done, added break after STOP write
- `run_agent_task.sh` — fixed exit 429→100, exit 403→101
- `Dockerfile` — added perl to apt-get install
- `tasks/1_queue/ralph-v2.md` — new task file for v2 implementation
- `tasks/1_queue/aymm-unify.md` — new task file for AYMM unification
- `plans/ralph-v3-ideas.md` — backlog: Phase Gate, Flight Recorder, sleep-retry, global tool

## Open issues to keep in mind
- A `STOP` file exists from the completed loop run — delete it before running ralph/aymm again
- `tasks/active/` still exists alongside the new `tasks/1_queue/` etc. — the migration of `tasks/done/` → `tasks/3_done/` and `plans/` → `tasks/0_backlog/` is part of ralph-v2 Step 1
- GeminiConvo2.md and GeminiConvo.md are in the repo root — they're reference docs, not actionable
- `prompt-aymm.md` still references `tasks/active/` and `PLAN.md` — will need updating as part of aymm-unify

## Commands to run to resume
```bash
# Clean up the STOP file from last loop run
rm STOP

# Read the approved v2 plan
cat ~/.claude/plans/ok-i-updated-geminiconvo2-md-valiant-pancake.md

# Check the task files before starting
cat tasks/1_queue/ralph-v2.md
cat tasks/1_queue/aymm-unify.md

# When ready to implement Task 1 (tell Claude):
# "Implement tasks/1_queue/ralph-v2.md — start with Step 1"
```
