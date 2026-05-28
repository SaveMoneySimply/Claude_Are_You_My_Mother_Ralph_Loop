# HANDOFF — Ralph Loop / AYMM — 2026-05-27

> **Delete this file after reading.** It exists only to bridge sessions.

## Where we are
The AYMM free-AI pipeline is working end-to-end: groq completed the `aymm-test` smoke test (wrote `hello.txt`, step marked done, task closed and merged to main). The loop is idle with a STOP file present and an empty queue.

## What was just done
- Fixed `run_agent_task.sh` exit 1 after passing test — root cause was `local tmp_response` going out of scope under `set -u` when the EXIT trap fired
- Fixed `mark_step_done` never running — it was added to the wrong version of the file; also moved it before `git_commit_step` so the [x] marking is in the commit and doesn't dirty the tree during `close_task`
- Fixed jq logging aborting the script — captured output in a variable with `|| true` inside `$()`
- Fixed rate limiting — 429 now immediately advances to next provider instead of sleeping 60s
- Wrapped all context sections in `<context name="...">` XML tags and added explicit instruction not to write context sections as files (groq was writing `task.md` and `project_overview.md` as garbage)
- `aymm-test` and `fix-rate-limit-advance` both now in `tasks/3_done/`

## Current blocker / next step
**Cleanup needed before next run:**
- `STOP` file exists — must be cleared (the loop clears it at startup, but worth knowing)
- `hello.txt` committed to main — smoke test artifact, delete it
- `task.md` committed to main — garbage written by groq, delete it

**Before trusting with overnight work:**
- Queue is empty — need a real multi-step task queued
- Run a watched 3-4 step task to verify multi-step and provider-switching work under real conditions
- Gemini and Mistral have not successfully completed any task yet — only groq has been validated

## Key files changed this session
- `aymm-loop.sh` — mark_step_done before git_commit_step; immediate 429 advance
- `run_agent_task.sh` — tmp_response global; jq logging safe; context XML tags; task-file test command; rate-limit advance

## Open issues to keep in mind
- Groq still occasionally writes `task.md` despite context XML fix — the instruction helps but smaller models are inconsistent
- `apply_changes.sh` exits 1 if no file blocks found — this is intentional but worth watching for provider responses that don't include any `<file>` blocks
- The Claude escalation path (all free providers exhausted → loop.sh) is completely untested
- Only groq has been validated end-to-end; gemini was hitting per-minute rate limits during testing

## Commands to run to resume
```bash
# Check state
git status && git branch --show-current

# Clean up smoke test artifacts
rm hello.txt task.md
git add -A && git commit -m "chore: remove aymm smoke test artifacts from main"

# Clear STOP (loop does this at startup, but clean manually to be safe)
rm -f STOP

# Queue a real task, then run
# (create tasks/1_queue/<task-name>.md first)
bash ralph.sh aymm
```
