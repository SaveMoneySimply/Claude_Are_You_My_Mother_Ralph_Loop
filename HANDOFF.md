# HANDOFF — Ralph Loop / AYMM — 2026-05-26

> **Archive this file after reading.** It exists only to bridge sessions.

## Where we are
All planned tasks are complete. `aymm-unify` is done — `aymm.sh` is deleted, `bash ralph.sh aymm` is the entry point, `aymm-loop.sh` uses the new 4-stage directory paths. README is updated. One unstaged change (README.md) not yet committed.

## What was just done
- Implemented `aymm-unify`: added `aymm)` case to `ralph.sh`, set `LOOP_ENV`, updated usage comment
- Updated `aymm-loop.sh`: `tasks/active/` → `tasks/2_active/`, `tasks/done/` → `tasks/3_done/`, removed PLAN.md updates from `close_task()`, fixed stale `aymm.sh` references in STOP messages
- Deleted `aymm.sh`
- Updated `ARCHITECTURE.md`: removed `aymm.sh` from Key Files, updated entry points and test command
- Smoke tested: `bash ralph.sh aymm` launched container, configured firewall, ran correctly
- Deleted remote branch `origin/task/aymm-orchestrator` (was dangling on GitHub as default branch — had to change GitHub default to `main` first)
- Updated handoff skill: HANDOFF.md is now archived to `handoffs/HANDOFF-<timestamp>.md` instead of deleted on incoming
- Updated README.md: replaced all `aymm.sh` references with `bash ralph.sh aymm`

## Current blocker / next step
**README.md has one unstaged change** — needs to be committed. Then the project is ready for API credential setup and first real run.

Next: get free provider API keys (Gemini, Mistral, Groq, OpenRouter) and do a live test with `bash ralph.sh aymm` against a real task.

## Key files changed this session
- `ralph.sh` — added `aymm)` case with `LOOP_ENV`, switched if/else to case statement
- `aymm-loop.sh` — updated all directory paths, removed PLAN.md plan-link updates, fixed stale refs
- `aymm.sh` — deleted
- `ARCHITECTURE.md` — entry points and Key Files updated
- `README.md` — all `aymm.sh` references replaced (unstaged)
- `~/.claude/skills/handoff/SKILL.md` — archive behavior on incoming

## Open issues to keep in mind
- A `STOP` file exists ("All tasks complete") — delete before running the loop: `rm STOP`
- `handoffs/` folder doesn't exist yet — the updated skill will create it on next incoming handoff
- `tasks/0_backlog/` has a duplicate `integration.md` (same as `tasks/3_done/integration.md`) — low priority cleanup
- Ralph v3 ideas are in `tasks/0_backlog/ralph-v3-ideas.md` if there's future work

## Commands to run to resume
```bash
# Commit the README change
git add README.md
git commit -m "readme: update aymm.sh references to bash ralph.sh aymm"

# Delete stale STOP file before running
rm STOP

# Set API keys (add to shell profile)
export ANTHROPIC_API_KEY=sk-ant-...
export GEMINI_API_KEY=...
export MISTRAL_API_KEY=...
export GROQ_API_KEY=...
export OPENROUTER_API_KEY=...

# Run AYMM
bash ralph.sh aymm
```
