# Task — run-mode-failsafe

**Model:** sonnet · **Effort:** low · **Tokens estimated:** 4000 · **Attempts:** 0/3
**Test command:** bash -n loop.sh && bash -n aymm-loop.sh
**Allowed files:** loop.sh, aymm-loop.sh

## Context
Task files can be marked with a `**Run:**` field to specify which execution mode they support. Without a failsafe, running the wrong mode silently picks up the task and burns usage — e.g. a task marked `interactive` sitting in `1_queue/` will be picked up by `bash ralph.sh` and attempted autonomously.

Valid run mode values:
- `interactive` — must be run with Claude directly; neither `ralph.sh` nor `ralph.sh aymm` should touch it
- `ralph` — run via `bash ralph.sh` only; `ralph.sh aymm` should refuse
- `aymm` — run via `bash ralph.sh aymm` only; `bash ralph.sh` (Claude-only) should refuse
- `any` or absent — no restriction, either mode can run it

## Steps
- [ ] Step 1: Add a `read_run_mode()` helper to `loop.sh` — reads the `**Run:**` field from the active task file using grep/sed (same pattern as existing `read_model()`/`read_effort()` helpers), returns the value lowercased, defaults to `any` if absent — done when: function exists in loop.sh -- test: grep -q 'read_run_mode' loop.sh && bash -n loop.sh

- [ ] Step 2: In `loop.sh` main loop, after `CURRENT_TASK` is set and `TASK_FILE` is defined, call `read_run_mode` and check: if value is `interactive` or `aymm`, write `"Task ${CURRENT_TASK} is marked run:${RUN_MODE} — cannot run via ralph.sh. Use Claude directly or bash ralph.sh aymm."` to STOP and break — done when: check exists after task is picked -- test: grep -q 'run.*interactive\|interactive.*run' loop.sh && bash -n loop.sh

- [ ] Step 3: Add the same `read_run_mode()` helper to `aymm-loop.sh` and add the equivalent check after task pick: if value is `interactive` or `ralph`, write `"Task ${CURRENT_TASK} is marked run:${RUN_MODE} — cannot run via ralph.sh aymm. Use Claude directly or bash ralph.sh."` to STOP and break — done when: check exists in aymm-loop.sh -- test: grep -q 'read_run_mode' aymm-loop.sh && bash -n aymm-loop.sh

## Smoke test
Add `**Run:** interactive` to a test task file in `tasks/1_queue/`, run `bash ralph.sh`, confirm the loop writes STOP with the correct message and exits without executing any steps. Repeat with `bash ralph.sh aymm`. Remove the test file after.
