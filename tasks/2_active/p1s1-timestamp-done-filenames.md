# Task — timestamp-done-filenames

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 6000 · **Attempts:** 0/3
**Allowed files:** aymm-loop.sh, loop.sh, prompt.md

## Context
`tasks/3_done/` accumulates files alphabetically — no way to tell completion order. Fix: prefix filenames with `YYYY-MM-DD-` at close time so `ls tasks/3_done/` reads as a timeline.

Three places to update:
1. `aymm-loop.sh` `close_task()` — builds the done filename and CHANGELOG link
2. Both scripts' stale-task guards — currently check for exact filename `tasks/3_done/${task}.md`; must change to glob since done files now have date prefix
3. `prompt.md` — instructs Claude (in loop.sh path) to `mv` the task to `3_done/`

## Steps
- [x] Step 1: Edit `aymm-loop.sh` `close_task()` (~line 249) — change `local done_file="tasks/3_done/${task}.md"` to `local done_file="tasks/3_done/$(date +%Y-%m-%d)-${task}.md"` and update the CHANGELOG append line (~line 261) to reference the same path `tasks/3_done/$(date +%Y-%m-%d)-${task}.md` — done when: `grep -q 'date +%Y-%m-%d' aymm-loop.sh` -- test: grep -q 'date +%Y-%m-%d' aymm-loop.sh && bash -n aymm-loop.sh

- [x] Step 2: Edit the stale-task guard in `aymm-loop.sh` (~line 305) — change `if [[ -f "tasks/3_done/${CURRENT_TASK}.md" ]]` to `if compgen -G "tasks/3_done/*-${CURRENT_TASK}.md" > /dev/null 2>&1` so it finds date-prefixed files — done when: guard uses compgen or glob instead of exact path -- test: grep -q 'compgen.*3_done.*CURRENT_TASK\|3_done/\*.*CURRENT_TASK' aymm-loop.sh

- [x] Step 3: Edit the stale-task guard in `loop.sh` (~line 139) — same change: `if [ -f "tasks/3_done/${task_name}.md" ]` → `if compgen -G "tasks/3_done/*-${task_name}.md" > /dev/null 2>&1` — done when: guard uses compgen or glob -- test: grep -q 'compgen.*3_done.*task_name\|3_done/\*.*task_name' loop.sh && bash -n loop.sh

- [x] Step 4: Edit `prompt.md` line 7 — change `mv tasks/2_active/<name>.md tasks/3_done/<name>.md` to `mv tasks/2_active/<name>.md "tasks/3_done/$(date +%Y-%m-%d)-<name>.md"` — done when: prompt.md references `date +%Y-%m-%d` -- test: grep -q 'date +%Y-%m-%d' prompt.md

## Smoke test
Run one loop iteration to completion. Confirm the done file in `tasks/3_done/` starts with today's date: `ls tasks/3_done/ | grep $(date +%Y-%m-%d)` should show at least one result.
