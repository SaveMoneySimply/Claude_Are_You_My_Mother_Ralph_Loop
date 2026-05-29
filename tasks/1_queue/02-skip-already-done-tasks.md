# Task — skip-already-done-tasks

**Model:** sonnet · **Effort:** low · **Tokens estimated:** 5000 · **Attempts:** 0/3

Guard against stale task files appearing in `1_queue/` or `2_active/` after a git merge resurrects them. Before running a task, check if a same-named file already exists in `3_done/`. If so, remove the stale copy and skip it.

## Steps
- [ ] Step 1: Edit `aymm-loop.sh` — in the queue-pick block (after `CURRENT_TASK` is set from `1_queue/`), add a check: if `tasks/3_done/${CURRENT_TASK}.md` exists, log a warning, remove the stale queue file, and `continue` to the next iteration — done when: `bash -n aymm-loop.sh` passes -- test: grep -q '3_done.*CURRENT_TASK' aymm-loop.sh
- [ ] Step 2: Edit `loop.sh` — in `pick_task()`, after moving a file from `1_queue/` to `2_active/`, add the same check: if `tasks/3_done/${task_name}.md` exists, log a warning, remove the stale active file, and return `""` so the caller skips it — done when: `bash -n loop.sh` passes -- test: grep -q '3_done.*task_name\|3_done.*CURRENT_TASK' loop.sh

## Smoke test
Manually place a copy of any `tasks/3_done/*.md` file into `tasks/1_queue/` and run one iteration — confirm the loop logs "Warning: already in 3_done — skipping" and does not execute the task.
