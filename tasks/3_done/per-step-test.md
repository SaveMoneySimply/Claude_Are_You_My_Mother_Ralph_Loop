# Task — per-step-test

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 10000 · **Attempts:** 0/3

## Steps
- [x] Step 1: Edit `run_agent_task.sh` — in `bundle_context()`, after setting `next_step`, write its value to `.ralph/last-step.txt` using `printf '%s\n' "$next_step" > "${SCRIPT_DIR}/.ralph/last-step.txt"` — done when: `bash -n run_agent_task.sh` passes and the file references `.ralph/last-step.txt` -- test: grep -q 'last-step.txt' run_agent_task.sh
- [x] Step 1: Edit `run_agent_task.sh` — in `bundle_context()`, after setting `next_step`, write its value to `.ralph/last-step.txt` using `printf '%s
' "$next_step" > "${SCRIPT_DIR}/.ralph/last-step.txt"` — done when: `bash -n run_agent_task.sh` passes and the file references `.ralph/last-step.txt` -- test: grep -q 'last-step.txt' run_agent_task.sh

## Smoke test
Queue a task with `-- test: <cmd>` on a step and confirm the step-level test runs and its pass/fail controls the outcome independently of the global test.
