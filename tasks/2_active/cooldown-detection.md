# Task — cooldown-detection

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 20000 · **Attempts:** 0/3
**Test command:** bash -n aymm-loop.sh

## Steps
- [x] Step 1: In `aymm-loop.sh`, split the handling of exit code 100 (currently "rate limited — switch provider immediately") into two behaviors based on a new per-provider cooldown counter. On first 429 from a provider: sleep 60 seconds, retry the same provider (do not advance). On second consecutive 429 from the same provider: treat as quota exhausted, call `advance_provider` as before. Track the per-provider 429 count in a new associative array `COOLDOWN_COUNT` (same pattern as `TASKS_ATTEMPTED`). Reset the count for a provider when it succeeds. HTTP 403 (exit 101) continues to advance immediately — that is a hard quota exhaustion, not a temporary limit. — done when: `bash -n aymm-loop.sh` exits 0 and logic is correct by inspection.

- [x] Step 2 (final): Run test command — on pass, commit and close task.

## Smoke test
Inspect the modified exit code 100 handler: confirm first 429 sleeps 60s and retries same provider, second consecutive 429 advances to next provider, and 403 still advances immediately.
