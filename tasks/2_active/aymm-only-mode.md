# Task — aymm-only-mode

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 8000 · **Attempts:** 0/3

Add an `--only` flag to `bash ralph.sh aymm --only` that prevents escalation to Claude when all free providers are exhausted. The loop stops with a clear STOP message instead of handing off to loop.sh.

## Steps
- [x] Step 1: Edit `ralph.sh` — in the `aymm)` case block, detect a second argument `--only` (check `"${2:-}"`) and if present append `-e AYMM_ONLY=1` to `LOOP_ENV`; also update the echo message to say "(--only: no Claude fallback)" when the flag is set — done when: `bash -n ralph.sh` passes -- test: grep -q 'AYMM_ONLY' ralph.sh
- [x] Step 2: Edit `aymm-loop.sh` — in the escalation block that checks `[[ -f ".ralph/aymm-escalate.txt" ]]`, before the `exec bash loop.sh` line add a check: if `"${AYMM_ONLY:-}" == "1"` then write `"All free providers exhausted — stopping (aymm-only mode)"` to STOP and break; also handle the "no tasks in queue" branch similarly: if AYMM_ONLY is set, write `"All tasks complete (aymm-only mode)"` to STOP and break instead of delegating to loop.sh — done when: `bash -n aymm-loop.sh` passes -- test: grep -q 'AYMM_ONLY' aymm-loop.sh

## Smoke test
Run `bash ralph.sh aymm --only` and confirm the log shows "(--only: no Claude fallback)" in the startup message.
If all free providers exhaust on a task, confirm STOP is written with the aymm-only message rather than escalating to Claude.
