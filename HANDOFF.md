# HANDOFF — Ralph Loop / AYMM — 2026-05-29

> **Delete this file after reading.** It exists only to bridge sessions.

## Where we are
The AYMM pipeline is in good shape after a productive bug-fixing session. Queue and active are empty, working tree is clean on main. The next session's job is v3 phase planning — read the backlog, group into phases, break into steps, queue tasks with phase/step naming.

## What was just done
- Fixed `apply_changes.sh` multi-line edit bug — awk `-v` was truncating multi-line content to first line; free providers were writing correct code that was never applied
- Fixed provider rotation on HTTP 503 (treat as rate-limit → immediate rotation)
- Fixed `*` wildcard case in aymm-loop.sh never calling `advance_provider` (loop stuck on one provider forever)
- Fixed failure counters not resetting between runs (stale counts from previous sessions caused "12/3 attempts")
- Fixed Claude escalation scope — `exec bash loop.sh` replaced the aymm process entirely; replaced with `SINGLE_TASK=1 bash loop.sh` so aymm resumes after Claude completes one task; added `SINGLE_TASK` mode to loop.sh
- Added `--only` flag: `bash ralph.sh aymm --only` stops instead of escalating to Claude when free providers exhaust
- Added stale task guard in both loop.sh and aymm-loop.sh — skips queue items already in `3_done/`
- Fixed `close_task()` CHANGELOG format (was writing `| date | name |`, now writes `date | name`)
- Fixed rollback on test failure in `run_agent_task.sh` — provider file changes are now reverted (git checkout + rm) if the test fails; previously corrupted files survived failed attempts
- Ran 01-fix-changelog-format and 02-skip-already-done-tasks through the loop; both completed (01 via gemini, 02 step 1 via gemini, step 2 manually due to escalation bug)
- Clarified v3 backlog: AYMM-only mode written up, AYMM-all mode split into `--pick` and `--show` sub-modes, timestamp-filenames idea captured

## Current blocker / next step
**No blockers — queue is empty, everything is clean.**

Next session goal: **v3 phase planning**
1. Read `tasks/0_backlog/ralph-v3-ideas.md`
2. Group items into coherent phases (suggest: provider reliability, engine portability, observability/tooling)
3. Break each phase into ordered task steps
4. Create task files in `tasks/1_queue/` using `<phase><step>-<name>.md` naming convention (e.g. `p1s1-openrouter-model-rotation.md`)
5. Archive `ralph-v3-ideas.md` to `_archive/` and create `ralph-v4-ideas.md` as new scratch space
6. Update the `## Phases` placeholder in `ARCHITECTURE.md` with the real phase names

## Key files changed this session
- `run_agent_task.sh` — 503 → exit 100; rollback on test failure (git checkout + rm untracked)
- `apply_changes.sh` — multi-line edit fix (awk -v → temp file + getline)
- `aymm-loop.sh` — provider rotation on unexpected exit; failure counter reset on task pick; SINGLE_TASK escalation; AYMM_ONLY flag; stale task guard; CHANGELOG format fix in close_task()
- `loop.sh` — SINGLE_TASK mode; stale task guard in pick_task()
- `ralph.sh` — `--only` flag wiring
- `provider-config.sh` — loop_version(), provider_count(), has_provider() functions added
- `CHANGELOG.md` — all entries now use consistent format (no leading/trailing pipes)
- `tasks/0_backlog/ralph-v3-ideas.md` — AYMM-only, AYMM-all, and timestamp-filenames ideas clarified

## Open issues to keep in mind
- `validate-apply-changes` task ran under Claude (not a free provider) because the escalation scope bug was present during that run — the apply_changes.sh multi-line fix has NOT been end-to-end validated with a real free provider yet. The next loop run will be the real test.
- OpenRouter iterations are slow (Poolside model); the user asked about going direct — needs Poolside's API docs to assess
- CHANGELOG still has inconsistent ordering (newer entries at top, older at bottom — no separator)
- Free providers (Groq/Mistral/OpenRouter) struggle with tasks that edit bash files with complex here-doc syntax; they tend to corrupt the file. Rollback now prevents lasting damage but the root cause is context/prompt quality.

## Commands to run to resume
```bash
# Verify clean state
git status && git log --oneline -5

# Check queue before planning
ls tasks/1_queue/ tasks/2_active/

# Read the v3 backlog before the planning session
cat tasks/0_backlog/ralph-v3-ideas.md

# After planning, run the loop
bash ralph.sh aymm
```
