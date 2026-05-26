# Ralph v3 — Ideas Backlog

Items deferred from the v2 plan. Not scheduled — collect here until there's enough to warrant a v3 planning session.

## Global Engine Install (Dual-Volume Mount)

From GeminiConvo2.md. Engine lives at `~/tools/ralph`, mounted read-only as `/engine` into any project's container. Project workspace mounted separately as `/workspace`.

**When to do it:** After v2 is stable and ralph is being pointed at real external projects. Extracting a stable v2 is much cleaner than extracting a half-finished v1.

**What changes:**
- `ralph.sh` moves to `~/tools/ralph/ralph.sh` (installed globally, run from any project dir)
- Container gets two mounts: `-v ~/tools/ralph:/engine:ro -v $(pwd):/workspace:rw`
- Engine scripts reference `/engine/` not `/workspace/`
- Project repos become clean: just `ARCHITECTURE.md` + `tasks/` + project source

## Phase Gate Reviews (Claude at Task Boundaries)

From GeminiConvo.md. After all steps in a task complete, pause and do one constrained single-turn Claude review before closing the task. Free providers can run all steps; Claude only reviews at the boundary.

**The prompt constraint:** "Reply EXACTLY with PHASE_PASSED or provide an error block. Do not refactor."

**Tradeoff:** Free providers may build on a broken step 2 for steps 3-4. Phase gate catches it but the repair may be larger. Worth testing once we have real free-provider execution data.

## Flight Recorder Logging

From GeminiConvo.md. Log each step's file touches and test errors to `.ralph/aymm-flight-recorder.log`. Gives Claude a diagnostic map when it escalates — instead of starting blind, it sees exactly what was tried, what files changed, and what the errors were.

**Low effort, high value.** Changes to `run_agent_task.sh` and `aymm-loop.sh` only.

## Sleep-and-Retry on Rate Limit Exhaustion

Currently when all 4 free providers are rate-limited, `aymm-loop.sh` writes STOP and exits. The original Gemini proposal had `sleep 3600` + reset provider index and retry.

**Addition:** Instead of STOP, sleep 1hr and restart the provider cycle. Keeps AYMM running overnight without manual intervention. Add a max-retry count to prevent infinite sleep loops.

## Cooldown Detection (Distinguish 429 from Quota Blown)

HTTP 429 = temporary rate limit (resets in minutes). HTTP 403/quota = daily limit (resets in hours). Currently both advance the provider. Could instead: on 429, sleep 60s and retry the same provider before advancing. Only advance on quota exhaustion.
