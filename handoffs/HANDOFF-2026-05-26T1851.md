# HANDOFF — Ralph Loop / AYMM — 2026-05-26

> **Archive this file after reading.** It exists only to bridge sessions.

## Where we are
A large feature plan has been fully designed and approved but NOT yet implemented. The plan
lives at `~/.claude/plans/i-would-like-to-immutable-naur.md`. Repo is clean on `main`,
nothing staged. Ready to start a fresh implementation session.

## What was just done
- Designed and got approval for a 10-step feature set covering:
  - Bug fix: stale `tasks/active/` path in `run_agent_task.sh`
  - Richer prompt context: project overview, all phase tasks, previous phase review
  - Error feedback loop: capture test output, inject into next retry prompt
  - Retry count raised from 2 → 3 before switching provider
  - New `apply_changes.sh` script handling `<file>`, `<edit>`, `<delete>` XML blocks
  - Phase system: `phase<N>-<NN>-<description>.md` task naming, Claude phase review at completion, archive to `_archive/phase<N>/`
  - Structured test log: `.ralph/test-log.jsonl` (both pass and fail)
  - `## Phases` template added to `ARCHITECTURE.md`
  - `prompt-aymm.md` updated to document current format (it's currently dead code with stale paths)
- Archived the HANDOFF.md from previous session to `handoffs/`
- Updated handoff skill: incoming now archives instead of deletes

## Current blocker / next step
**Implement the approved plan** — 10 ordered steps, start from step 1:

1. Fix `tasks/active/` → `tasks/2_active/` in `run_agent_task.sh` `bundle_context()` line ~70
2. Add `## Phases` template to `ARCHITECTURE.md` (chmod temporarily, restore 0444)
3. Add project overview + phase tasks + previous review to `bundle_context()`
4. Add error capture + `.ralph/test-log.jsonl` to `run_test_command()`
5. Add error injection to `bundle_context()`
6. Create `apply_changes.sh`
7. Update `parse_and_apply_response()` to call `apply_changes.sh`
8. Update response format instructions in `bundle_context()`
9. Add phase detection + `run_phase_review()` + `archive_phase()` to `aymm-loop.sh`
10. Update `prompt-aymm.md`

Commit after each step. Create branch `task/aymm-prompt-phase` first.

## Key files to modify
- `run_agent_task.sh` — steps 1, 3, 4, 5, 7, 8
- `apply_changes.sh` (new) — step 6
- `aymm-loop.sh` — step 9 (retry threshold + phase system)
- `ARCHITECTURE.md` — step 2 (chmod, add Phases section, restore 0444)
- `prompt-aymm.md` — step 10

## Open issues to keep in mind
- `STOP` file exists ("All tasks complete") — `rm STOP` before any loop run
- `prompt-aymm.md` is currently UNUSED dead code — `run_agent_task.sh` builds context inline; updating it is documentation only
- The `<delete>` block format uses self-closing tag: `<delete path="..."/>` — Perl regex must match self-closing
- Phase archive strips two prefixes: `phase1-` then `01-`, leaving just the description + date
- `archive_phase()` must run AFTER `run_phase_review()` (review reads from `tasks/3_done/`)
- For the phase review Claude call, use `claude --model sonnet -p --dangerously-skip-permissions` (same as loop.sh uses)

## Commands to run to resume
```bash
# Read the full approved plan first
cat ~/.claude/plans/i-would-like-to-immutable-naur.md

# Create branch and start
git checkout -b task/aymm-prompt-phase

# Remove stale STOP file
rm STOP

# Tell Claude:
# "Implement the approved plan at ~/.claude/plans/i-would-like-to-immutable-naur.md
#  one step at a time, committing after each step. Start with step 1."
```
