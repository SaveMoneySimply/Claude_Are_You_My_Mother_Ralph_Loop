# Task — script-dir-workspace-split

**Model:** sonnet · **Effort:** high · **Tokens estimated:** 12000 · **Attempts:** 0/3
**Test command:** bash -n loop.sh && bash -n aymm-loop.sh && bash -n run_agent_task.sh && bash -n apply_changes.sh && bash -n provider-config.sh && bash -n ralph.sh

> **Do this interactively (Claude directly) — do NOT run through the loop or AYMM.**
> Free providers miss path substitutions that pass `bash -n` but fail at runtime. This is a coordinated refactor across 3 files.
> Prerequisite: p2s1-engine-dir-and-mounts must be complete (~/tools/ralph/ exists, ralph.sh has /engine:ro mount, init-firewall.sh runs bash /engine/loop.sh).

## Context
After p2s1, the container mounts `~/tools/ralph → /engine:ro` and `$(pwd) → /workspace`. But engine scripts still hardcode paths relative to their old location (everything was in the same dir before). Two kinds of paths must be split:

- **Engine paths** (scripts calling other scripts): `loop.sh`, `aymm-loop.sh`, `apply_changes.sh`, `prompt*.md`, `provider-config.sh` — these live at `/engine/` and are referenced via `${SCRIPT_DIR}` or `${ENGINE_DIR}`
- **Workspace paths** (project state files): `tasks/`, `.ralph/`, `ARCHITECTURE.md`, `CHANGELOG.md`, `BLOCKED.md`, `STOP` — these live at `/workspace/` and must use `${WORKSPACE}` or remain as relative paths (scripts `cd /workspace` at startup, so relative paths already work for loop.sh and aymm-loop.sh)

`run_agent_task.sh` is the main problem — it uses `SCRIPT_DIR` for BOTH, but after extraction `SCRIPT_DIR=/engine` and workspace is `/workspace`.

## Steps

- [ ] Step 1: Edit `loop.sh` — add `ENGINE_DIR=/engine` on a new line after `WORKDIR=/workspace` (line 6). Then change the 3 engine-file references:
  - Both occurrences of `cat prompt.md` → `cat "${ENGINE_DIR}/prompt.md"`
  - `PROMPT_FILE=prompt-split.md` → `PROMPT_FILE="${ENGINE_DIR}/prompt-split.md"`
  Done when: `grep -q 'ENGINE_DIR=/engine' loop.sh` -- test: grep -q 'ENGINE_DIR=/engine' loop.sh && bash -n loop.sh

- [ ] Step 2: Edit `aymm-loop.sh` — add `ENGINE_DIR=/engine` after `WORKDIR=/workspace` (line 6). Then change the 4 engine-file references:
  - `source "${WORKDIR}/provider-config.sh"` → `source "${ENGINE_DIR}/provider-config.sh"`
  - Both `bash "${WORKDIR}/loop.sh"` → `bash "${ENGINE_DIR}/loop.sh"`
  - `bash "${WORKDIR}/run_agent_task.sh"` → `bash "${ENGINE_DIR}/run_agent_task.sh"`
  Done when: `grep -q 'ENGINE_DIR=/engine' aymm-loop.sh` -- test: grep -q 'ENGINE_DIR=/engine' aymm-loop.sh && bash -n aymm-loop.sh

- [ ] Step 3: Edit `run_agent_task.sh` — add `WORKSPACE=/workspace` immediately after the `SCRIPT_DIR=` line (line 8). Then replace every `${SCRIPT_DIR}/tasks/`, `${SCRIPT_DIR}/.ralph/`, `${SCRIPT_DIR}/ARCHITECTURE.md`, `${SCRIPT_DIR}/CHANGELOG.md`, `${SCRIPT_DIR}/BLOCKED.md` with `${WORKSPACE}/tasks/`, `${WORKSPACE}/.ralph/`, `${WORKSPACE}/ARCHITECTURE.md`, `${WORKSPACE}/CHANGELOG.md`, `${WORKSPACE}/BLOCKED.md`. Also update the `apply_changes.sh` call: change the second argument from `"$SCRIPT_DIR"` to `"$WORKSPACE"`. Engine paths (`${SCRIPT_DIR}/apply_changes.sh`, `${SCRIPT_DIR}/provider-config.sh`) stay unchanged.
  Done when: `grep -q 'WORKSPACE=/workspace' run_agent_task.sh` -- test: grep -q 'WORKSPACE=/workspace' run_agent_task.sh && bash -n run_agent_task.sh

- [ ] Step 4: Sync updated scripts to `~/tools/ralph/` and rebuild Docker image:
  ```bash
  cp loop.sh aymm-loop.sh run_agent_task.sh ~/tools/ralph/
  docker build -t ralph:latest .
  ```
  Done when: Docker image rebuilds without error -- test: docker image inspect ralph:latest --format '{{.Created}}' | grep -q '2026'

## Smoke test
Run `bash ralph.sh` from the project root. Confirm the loop starts, picks up a task, and executes correctly. The log should show loop.sh running from /engine/loop.sh (init-firewall.sh output). Then verify engine is truly read-only: `docker run --rm -v ~/tools/ralph:/engine:ro -v $(pwd):/workspace ralph:latest bash -c "touch /engine/loop.sh" 2>&1 | grep -qi 'permission\|read-only'`
