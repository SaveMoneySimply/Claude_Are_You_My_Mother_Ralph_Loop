# HANDOFF — Ralph Loop — 2026-06-06

> **Delete this file after reading.** It exists only to bridge sessions.

## Where we are
Engine is stable and has real field data from an 83-task run on the Simply Curious project.
`ralph.sh init <path>` now works and bootstraps new projects with the `ralph-aymm/` subfolder
structure. The field report at `reference/ralph-aymm-field-report.md` is the primary body of
work for the next milestone.

## What was just done
- Fixed `|| echo` dead fallbacks (7 spots) in `loop.sh` and `aymm-loop.sh`
- Implemented v4 Idea 1: error feedback injection — `last-test-error.txt` injected into retry prompts
- Added `.ralph/` folder maintenance: log rotation, iter file cleanup on task close, failure counter pruning
- Added `ralph.sh stats` subcommand (all-time + per-provider pass rates)
- Ran three v4 tasks via AYMM (archival-to-bash, close_task gap, failure history) — all passed
- Stripped `-- test:` and `-- files:` from agent prompt (annotation stripping) so agents can't game tests
- Built `ralph.sh init <path>` and `ralph.sh update` commands to bootstrap new projects with `ralph-aymm/` subfolder
- Fixed heredoc quoting in `ralph_init()` (`<< 'EOF'`) to prevent backtick expansion
- Moved field report from `ralph-aymm-handoff.md` → `reference/ralph-aymm-field-report.md`

## Current blocker / next step
**Port bugs from the field report.** `reference/ralph-aymm-field-report.md` documents 16 fixes
and 3 open bugs discovered running the engine on a real 83-task project. Priority order:

1. **FIX-1**: `local` keyword outside function in `ralph.sh` aymm case block
2. **FIX-2**: Unbound `$1` in aymm mode (`set -u` crash)
3. **FIX-3**: Missing Docker capabilities (`--cap-add=NET_ADMIN --cap-add=NET_RAW`)
4. **FIX-5**: Mount host auth + git identity into container (Claude "not logged in" + git identity missing)
5. **FIX-6**: Remove `-it` flag from docker run (breaks background/monitored runs)
6. **FIX-8**: `init-firewall.sh` ignores CMD args, hardcodes loop.sh
7. **FIX-9**: WORKDIR resolves to `/` when engine mounted at `/engine` + ENGINEDIR detection
8. **FIX-11**: Node.js 20 → 22 in Dockerfile (Astro 6 requires >=22)
9. **FIX-12**: Escalation blocks aymm tasks even when Claude is the fallback
10. **FIX-13**: SINGLE_STEP mode — return after one step
11. **FIX-14**: Per-step `-- mode: claude` delegation in aymm-loop.sh
12. **FIX-4**: Engine mount path (`-v "$SCRIPT_DIR/ralph-aymm:/engine:ro"` → `$SCRIPT_DIR` only) — only needed for subdirectory layout
13. **FIX-7**: Cache Docker image check (skip rebuild if image exists)
14. **FIX-10**: `run_agent_task.sh` PROJECT_ROOT + apply_changes workspace arg

Also from the field report: **ENH-003 Groq multi-model routing** (see field report section) —
expands free capacity from ~1,000 to ~72,000+ requests/day by adding all Groq model variants.

## Key files
- `reference/ralph-aymm-field-report.md` — full bug list, lessons, Groq routing plan
- `ralph.sh` — init/update commands added this session
- `tasks/0_backlog/ralph-v4-ideas.md` — v4 roadmap (updated this session)
- `CHANGELOG.md` — staged, needs commit

## Open issues to keep in mind
- Remote `task/aymm-test` branch still on origin — delete once GitHub creds sorted: `git push origin --delete task/aymm-test`
- FIX-4 (mount path) is layout-dependent — canonical engine needs detection logic, not a blind replacement
- Failure counters survive infrastructure fixes (SUGGESTION-006) — workaround: `echo '{}' > .ralph/aymm-failure-counters.json`

## Commands to run to resume
```bash
cd /home/matt/Documents/Matt/Code/Claude_Are_You_My_Mother_Ralph_Loop
git status

# Read the field report to triage which fixes to tackle first
cat reference/ralph-aymm-field-report.md

# Start creating task files for the fix batch
# Recommend: FIX-1,2,3,5,6 first (ralph.sh fixes) — all in one file, low risk
```
