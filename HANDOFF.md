# HANDOFF — Ralph Loop / AYMM — 2026-05-29

> **Delete this file after reading.** It exists only to bridge sessions.

## Where we are
Queue is empty, working tree clean on main, STOP file present (cleared automatically at loop startup). Two backlog tasks are ready to promote: p2s3 (README rewrite, interactive) and p2s4 (project/ dir + e2e test, interactive). Both must be run interactively with Claude — the run-mode failsafe built this session will block any accidental loop run.

## What was just done
- Fixed `aymm-loop.sh` unbound `next_task` variable — rewrote task-pick block to mirror `loop.sh` pattern
- Fixed `run_agent_task.sh` rollback — was reverting the task mv (1_queue → 2_active), resetting failure counter every iteration; fixed by excluding `tasks/` from rollback scope
- Abandoned engine extraction (p2s1/p2s2) — reverted ralph.sh and init-firewall.sh changes; new approach is `project/` subdirectory within the repo
- Built run-mode failsafe (p2s5) — `loop.sh` and `aymm-loop.sh` check `**Run:**` field and write STOP if wrong mode attempted
- Updated `CLAUDE.md` — added `**Run:**` field docs, AYMM task-writing guidance, done-file naming note
- Archived stale `PLAN.md` (all v3 phases done)
- Added several v4 backlog items: host-only step marker, STOP responsiveness, plan-task linkage, folder structure cleanup (plans/ ideas/ tasks/)

## Current blocker / next step
No blockers. Two tasks to do interactively, in order:

1. **p2s4 first** — create `project/` subdirectory with a minimal example project, verify Ralph runs end-to-end against it. This validates the fork model before writing the README about it.
2. **p2s3 second** — rewrite README once p2s4 proves the system works. Read `README.md`, `CLAUDE.md`, `ARCHITECTURE.md`, and `provider-config.sh` first, then rewrite. Sections needed: what Ralph is, what AYMM adds, scripts reference, task folder structure, how to run, watching progress, stopping, callouts (ARCHITECTURE_REVIEW, BLOCKED, Allowed files, Run: field), how to use on your own project (fork + project/ dir).

## Key files changed this session
- `aymm-loop.sh` — task-pick block rewrite, run-mode failsafe, read_run_mode() helper
- `loop.sh` — run-mode failsafe, read_run_mode() helper
- `run_agent_task.sh` — rollback fix (exclude tasks/ from git checkout)
- `ralph.sh` + `init-firewall.sh` — reverted engine extraction changes (back to /workspace paths)
- `CLAUDE.md` — Run: field, AYMM guidance, done-file naming
- `tasks/0_backlog/ralph-v4-ideas.md` — rollback marked done, 5 new items added
- `tasks/3_done/2026-05-29-p2s5-run-mode-failsafe.md` — completed this session

## Open issues to keep in mind
- p2s4 is interactive — the `project/` dir approach means forking the repo and putting your project in `project/`. The minimal example just needs one testable task so Ralph can run end-to-end.
- p2s3 README should NOT mention engine extraction (abandoned) or `~/tools/ralph/`. Document the `project/` subdirectory approach instead.
- v4 backlog has a cluster of related items (plan-task linkage, folder structure, host-only steps, STOP responsiveness) — good candidates for a planning session when v3 wraps up.
- `ralph.sh plan` mode is broken (references old folder structure) — noted in v4 backlog, leave it for now.

## Commands to run to resume
```bash
# Verify clean state
git status && git log --oneline -5

# Check backlog
ls tasks/0_backlog/

# p2s4 first — promote to queue, then work interactively
# (failsafe will block loop runs, so safe to queue)
mv tasks/0_backlog/p2s4-project-dir-and-e2e-test.md tasks/1_queue/

# p2s3 — promote after p2s4 is done
mv tasks/0_backlog/p2s3-update-readme.md tasks/1_queue/
```
