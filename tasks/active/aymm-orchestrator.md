# Task — aymm-orchestrator

**Model:** sonnet · **Effort:** high · **Tokens estimated:** 60000 · **Attempts:** 0/3
**Test command:** bash -n aymm-loop.sh

## Steps

- [x] Step 1: Write `aymm-loop.sh` skeleton — source `provider-config.sh`, read `autonomy` setting from `ARCHITECTURE.md`, initialize provider index at 0, initialize per-task failure counters, define main loop structure — done when: `bash -n aymm-loop.sh` exits 0

- [x] Step 2: Implement inner execution loop — call `run_agent_task.sh --provider=$CURRENT_PROVIDER`, read exit code, handle exit 0 (pass: reset failure counter, git commit, mark step done), handle exit 2 (fail: increment counter), handle exit 429 (rate limit: break to provider switcher) — done when: `bash -n aymm-loop.sh` exits 0; logic reviewed for correctness

- [x] Step 3: Implement provider switching — on 2× consecutive failures or exit 429, advance the provider index; if all 4 providers have been tried for the current task, write `.ralph/aymm-escalate.txt` and break to Claude escalation — done when: `bash -n aymm-loop.sh` exits 0

- [x] Step 4: Implement exhaustion STOP — when all providers return 429 or 403 (rate-limited, not task failure) in the same cycle, write `STOP` with message: "All free providers exhausted. Run \`bash ralph.sh\` to continue with Claude now, or wait ~1hr and run \`bash aymm.sh\` again." and send ntfy notification if `NTFY_TOPIC` is set — done when: `bash -n aymm-loop.sh` exits 0

- [ ] Step 5: Implement Claude escalation — when `.ralph/aymm-escalate.txt` exists, remove it and exec `bash /workspace/loop.sh`; loop.sh handles Claude invocation, testing, and BLOCKED if Claude also fails — done when: `bash -n aymm-loop.sh` exits 0

- [ ] Step 6: Implement recovery state tracking — write `.ralph/aymm-provider-state.json` after each iteration containing: current provider name, provider index, consecutive failure count, tasks attempted per provider — done when: `bash -n aymm-loop.sh` exits 0; JSON structure is valid (checked with `jq`)

- [ ] Step 7 (final): Run test command — on pass, commit and close task

## Smoke test
Run `aymm-loop.sh` with all provider keys set to invalid strings. Confirm: Gemini is tried first, fails twice, Mistral is tried next, fails twice, and so on through all four providers; finally `.ralph/aymm-escalate.txt` is written and loop.sh is invoked.
