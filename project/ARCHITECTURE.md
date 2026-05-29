# Ralph Loop — Engine

## What This Is
The Ralph Loop engine: a bash-driven autonomous coding agent that runs Claude Code (and free AI providers via AYMM mode) against a queue of task files, one step at a time.

Ralph works on itself. Files in this directory are copies of the live engine scripts. When Ralph improves a file here, copy it back to repo root: `cp project/<file> <file>`.

## Stack
- Shell: bash
- HTTP client: curl
- JSON parsing: jq
- Container: Docker

## Key Files
- `loop.sh` — bash-side navigator: picks task from 4-stage pipeline, extracts next step, injects into prompt; Claude fallback
- `aymm-loop.sh` — AYMM mode orchestrator: outer provider loop + inner execution loop
- `ralph.sh` — host CLI wrapper; modes: `execute` (default), `plan`, `aymm`
- `run_agent_task.sh` — per-provider task runner: context bundle → API → XML parse → apply → test
- `apply_changes.sh` — parses XML output from free AI and writes file changes to disk
- `provider-config.sh` — API configuration and model selection per provider
- `provider-status.sh` — tracks per-session provider exhaustion state
- `init-firewall.sh` — iptables allowlist; runs at container startup
- `test-providers.sh` — live connectivity test for all 4 free providers
- `prompt.md` — step executor; bash injects the current step before passing to Claude
- `prompt-aymm.md` — free AI context wrapper
- `prompt-plan.md` — breakdown mode; generates task files from backlog plans
- `prompt-split.md` — task splitter; breaks a failed task into smaller sub-tasks
- `Dockerfile` — container definition

## Task Pipeline
Tasks flow through four directories at repo root (not inside project/):
- `tasks/0_backlog/` — area plans not yet broken into task files
- `tasks/1_queue/` — task files waiting to run
- `tasks/2_active/` — the single task currently being worked (loop.sh moves it here)
- `tasks/3_done/` — archived completed tasks

## Test Command
```bash
bash -n loop.sh && bash -n aymm-loop.sh && bash -n ralph.sh && bash -n run_agent_task.sh && bash -n apply_changes.sh && bash -n provider-config.sh && bash -n provider-status.sh && bash -n init-firewall.sh && bash -n test-providers.sh
```
Bash syntax check — zero API calls, no quota burned during build.

## Deploy-Back Model
This directory is not a nested git repo — the outer repo tracks everything. Workflow:
1. Write a task file in `tasks/1_queue/` describing the change to make to a file in `project/`
2. Run `bash ralph.sh` — the loop works on files inside `project/`
3. When the task passes, copy the improved file back: `cp project/<file> <file>`
4. Commit from repo root — one git history for everything

## Ralph Settings
autonomy: low
