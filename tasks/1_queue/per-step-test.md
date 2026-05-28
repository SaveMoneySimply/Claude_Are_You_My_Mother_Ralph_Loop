# Task — per-step-test

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 10000 · **Attempts:** 0/3
**Test command:** bash -n ralph.sh && bash -n loop.sh && bash -n aymm-loop.sh && bash -n run_agent_task.sh && bash -n provider-config.sh

## Steps
- [ ] Step 1: Edit `run_agent_task.sh` — in `bundle_context()`, after setting `next_step`, write its value to `.ralph/last-step.txt` using `printf '%s\n' "$next_step" > "${SCRIPT_DIR}/.ralph/last-step.txt"` — done when: `bash -n run_agent_task.sh` passes and the file references `.ralph/last-step.txt` -- test: bash -n run_agent_task.sh
- [ ] Step 2: Edit `run_agent_task.sh` — in `run_test_command()`, after the global test passes (after the `if output=...` block succeeds), read `.ralph/last-step.txt` if it exists, extract the `-- test: <cmd>` suffix using `grep -oP '(?<=-- test: ).*'`, and if found run that command via `eval`; if it fails set outcome to `fail` and return 2 — done when: `bash -n run_agent_task.sh` passes and `run_test_command` references `last-step.txt` and `-- test:` -- test: bash -n run_agent_task.sh

## Smoke test
Queue a task with `-- test: <cmd>` on a step and confirm the step-level test runs and its pass/fail controls the outcome independently of the global test.
