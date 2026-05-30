# Task — v4-pass-failure-history-to-claude

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 5000 · **Attempts:** 0/3
**Allowed files:** aymm-loop.sh, project/aymm-loop.sh, loop.sh, project/loop.sh

## Context
When free providers exhaust and aymm-loop.sh escalates to Claude (`SINGLE_TASK=1 bash loop.sh`),
Claude has no knowledge of what the free providers tried and broke. The failure history lives in
`.ralph/test-log.jsonl` but isn't passed through to loop.sh's prompt.

Fix: before calling `SINGLE_TASK=1 bash loop.sh`, write `.ralph/escalation-context.md` with a
compact summary of free provider failures for the current task (provider, timestamp, test error —
no code blobs). In `build_step_prompt()` and `build_context_prompt()` in loop.sh, inject this
file into the prompt if it exists. Clean it up after loop.sh returns.

This keeps Claude from repeating approaches that already failed.

## Steps
- [x] In aymm-loop.sh and project/aymm-loop.sh: before `SINGLE_TASK=1 bash loop.sh` (line 392), generate `.ralph/escalation-context.md` from test-log.jsonl using jq — one line per failed attempt for the current task: `[ts] provider — test error`. After `SINGLE_TASK=1 bash loop.sh` returns, delete the file — done when: aymm-loop.sh writes escalation-context.md before the loop.sh call — test: bash -n aymm-loop.sh && bash -n project/aymm-loop.sh && grep -q 'escalation-context' aymm-loop.sh && grep -q 'escalation-context' project/aymm-loop.sh -- files: aymm-loop.sh:384-415, project/aymm-loop.sh:384-415
- [x] In loop.sh and project/loop.sh: in `build_step_prompt()` (line 165) and `build_context_prompt()` (line 185), after `cat prompt.md`, if `.ralph/escalation-context.md` exists append it under a `## Free provider attempts (failed)` header — done when: loop.sh injects escalation-context.md in both prompt builders — test: bash -n loop.sh && bash -n project/loop.sh && grep -q 'escalation-context' loop.sh && grep -q 'escalation-context' project/loop.sh -- files: loop.sh:165-220, project/loop.sh:165-220

## Smoke test
Run `bash ralph.sh aymm` on a task that requires Claude escalation. Check `.ralph/loop.log` — Claude's iteration should show "Free provider attempts" in the injected context.
