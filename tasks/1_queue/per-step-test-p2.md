# Task — per-step-test-p2

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 10000 · **Attempts:** 0/3

## Steps
- [ ] Step 1: Edit `run_agent_task.sh` — in `run_test_command()`, after the global test passes (inside the `if output=...` success branch, before setting `outcome="pass"`), read `.ralph/last-step.txt` if it exists, extract the `-- test: <cmd>` suffix using `grep -oP '(?<=-- test: ).*'`, and if a command is found run it via `eval`; if it fails override `outcome` to `"fail"` and write the error to `$error_log` — done when: `bash -n run_agent_task.sh` passes and `run_test_command` references both `last-step.txt` and `-- test:` -- test: grep -q '\-\- test:' run_agent_task.sh

## Smoke test
Queue a task with `-- test: false` on a step and confirm the step fails even though the global test passes.
