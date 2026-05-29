# HANDOFF — Ralph Loop / AYMM — 2026-05-29

> **Delete this file after reading.** It exists only to bridge sessions.

## Where we are
v3 phase planning is complete and two task files are queued. Queue is clean, working tree is clean on main. A STOP file exists on disk (written by the loop finding no tasks earlier) but will be auto-cleared at next startup.

## What was just done
- Fixed `apply_changes.sh` — added `ALLOWLIST` arg: free providers now blocked from writing files not listed in `**Allowed files:**` task header field
- Fixed `run_agent_task.sh` — parses `**Allowed files:**` and passes to apply_changes.sh
- Documented `**Allowed files:**` field in CLAUDE.md; closed ARCHITECTURE_REVIEW.md
- Fixed `ralph.sh` — was missing the `AUTH_MOUNT` branch for subscription auth (container was getting "Not logged in"); now mounts `~/.claude:/home/claude/.claude`
- Fixed `loop.sh` — added `rm -f STOP` at startup (matching aymm-loop.sh); previously a leftover STOP from a prior run caused immediate exit
- Rebuilt Docker image to pick up loop.sh and init-firewall.sh changes
- Completed v3 phase planning: archived ralph-v3-ideas.md, created ralph-v4-ideas.md, queued two task files, wrote ARCHITECTURE_REVIEW.md for phases section update

## Current blocker / next step
**No blockers.** One task in the queue, two in backlog waiting for manual promotion:

1. **p1s1-timestamp-done-filenames** (in `1_queue/`) — adds `YYYY-MM-DD-` prefix to done filenames. Run: `bash ralph.sh aymm`
2. **p2s1-engine-dir-and-mounts** (in `0_backlog/`) — moved to backlog because there's no way to tell the loop to run one task via aymm and the next via ralph.sh only. After p1s1 completes, manually move to `1_queue/` and run `bash ralph.sh` (not aymm) — step 1 does `mkdir + cp` outside the workspace.
3. After p2s1, do **p2s2 interactively** (Claude directly, not via loop): promote `tasks/0_backlog/p2s2-script-dir-workspace-split.md` to context and implement — adds `ENGINE_DIR=/engine` to loop.sh + aymm-loop.sh, adds `WORKSPACE=/workspace` to run_agent_task.sh, fixes all cross-script path references. Full step-by-step is in the backlog task file.
4. After p2s2, promote `tasks/0_backlog/p2s3-update-readme.md` to `tasks/1_queue/` and run via AYMM — rewrites README to document current system (correct folder names, all scripts, callouts, AYMM setup).

## Key files changed this session
- `apply_changes.sh` — added ALLOWLIST filtering in all three parsing loops
- `run_agent_task.sh` — parses Allowed files field, passes to apply_changes.sh
- `ralph.sh` — AUTH_MOUNT fix for subscription auth; /engine:ro mount (p2s1 will add this)
- `loop.sh` — `rm -f STOP` at startup
- `CLAUDE.md` — documents Allowed files task header field
- `tasks/1_queue/p1s1-timestamp-done-filenames.md` — new task file
- `tasks/1_queue/p2s1-engine-dir-and-mounts.md` — new task file
- `tasks/0_backlog/ralph-v4-ideas.md` — new v4 backlog
- `_archive/ralph-v3-ideas.md` — archived v3 backlog
- `ARCHITECTURE_REVIEW.md` — proposes phases section update for ARCHITECTURE.md

## Open issues to keep in mind
- ARCHITECTURE_REVIEW.md still needs a human to apply it to ARCHITECTURE.md and delete the review file
- p2s2 (SCRIPT_DIR/WORKSPACE split) is NOT a loop task — do it interactively with Claude because free providers tend to miss path substitutions that pass `bash -n` but fail at runtime
- After p2s1 + p2s2 complete, rebuild Docker image and verify: `docker run --rm -v ~/tools/ralph:/engine:ro -v $(pwd):/workspace ralph:latest bash -c "touch /engine/loop.sh"` → should fail (permission denied)
- Docker image was rebuilt today but `~/tools/ralph/` doesn't exist yet — the `/engine:ro` mount isn't in ralph.sh yet either (that's what p2s1 adds)

## Commands to run to resume
```bash
# Verify clean state
git status && git log --oneline -5

# Check queue
ls tasks/1_queue/ tasks/2_active/

# Run p1s1 (timestamp filenames) — only task in queue, safe for AYMM
bash ralph.sh aymm

# After p1s1 completes, manually promote p2s1 then run via ralph.sh (not aymm)
mv tasks/0_backlog/p2s1-engine-dir-and-mounts.md tasks/1_queue/
bash ralph.sh

# After both complete, do p2s2 interactively with Claude
# Then rebuild image and test external project
```
