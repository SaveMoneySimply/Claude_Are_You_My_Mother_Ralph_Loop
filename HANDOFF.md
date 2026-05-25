# HANDOFF — Ralph Loop / AYMM — 2026-05-25

> **Delete this file after reading.** It exists only to bridge sessions.

## Where we are
We built the full AYMM scaffolding (ARCHITECTURE.md, PLAN.md, 4 sub-plans) and fixed ralph.sh to use Claude subscription auth instead of a paid API key. The loop is failing to authenticate inside Docker — one more small fix needed before it can run.

## What was just done
- Created ARCHITECTURE.md, PLAN.md, plans/provider-infrastructure.md, plans/task-runner.md, plans/aymm-orchestrator.md, plans/integration.md
- Deleted failed-plan.md and cleaned up .gitignore
- Modified ralph.sh to mount ~/.claude credentials instead of requiring ANTHROPIC_API_KEY
- Fixed mount to include both ~/.claude/ directory AND ~/.claude.json config file
- Created /handoff skill at ~/.claude/skills/handoff.md

## Current blocker / next step
**Auth almost working — one missing mount.**

The loop fails with:
```
Claude configuration file not found at: /home/claude/.claude.json
```

The fix was already applied (mounting `~/.claude.json` to `/home/claude/.claude.json`), but ralph.sh has **not been committed yet** and the loop hasn't been retried. The next step is:

1. Clean up the stray `STOPtouch` file in the project root (leftover from `touch STOP` being mistyped)
2. Run the loop in plan mode to generate task files

## Key files changed this session
- `ralph.sh` — subscription auth via credential mounts (uncommitted change)
- `ARCHITECTURE.md` — new, describes AYMM system
- `PLAN.md` — new, 4-phase index
- `plans/provider-infrastructure.md` — new
- `plans/task-runner.md` — new
- `plans/aymm-orchestrator.md` — new
- `plans/integration.md` — new
- `.gitignore` — added .env, *.env
- `~/.claude/skills/handoff.md` — new skill (global, not in this repo)

## Open issues to keep in mind
- `tasks/active/` is empty — ralph.sh plan hasn't successfully run yet, no task files generated
- The `Attempts: 0/3` field in sub-plan files is template noise — loop.sh doesn't read it from plan files. Fine to leave as-is.
- AYMM independence (ralph doesn't touch ralph) is a future v2 project — noted in README section Matt will add to the main ralph repo
- ralph.sh now supports both auth modes: credentials file (subscription) takes priority, API key still works as fallback

## Commands to run to resume
```bash
cd ~/Documents/Matt/Code/Claude_Are_You_My_Mother_Ralph_Loop

# Clean up stray file from mistyped stop command
rm -f STOPtouch

# Verify the auth fix is in ralph.sh (should show .claude.json mount)
grep "claude.json" ralph.sh

# Run breakdown mode to generate task files
bash ralph.sh plan

# If that works, run the loop
bash ralph.sh
```
