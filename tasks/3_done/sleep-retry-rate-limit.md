# Task — sleep-retry-rate-limit

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 20000 · **Attempts:** 0/3
**Test command:** bash -n aymm-loop.sh

## Steps
- [x] Step 1: In `aymm-loop.sh`, replace the STOP write in `advance_provider()` (when all providers are rate-limited) with a sleep-and-retry: sleep 3600 seconds, reset `PROVIDER_INDEX` to 0, reset `RATE_LIMIT_ADVANCES` to 0, and log "All providers rate-limited — sleeping 1hr then retrying". Add a `RATE_LIMIT_SLEEP_COUNT` counter; if it reaches 3, write STOP instead of sleeping again (prevents infinite loops). Send an ntfy notification on sleep with body "All free providers rate-limited — retrying in 1hr (attempt N/3)". — done when: `bash -n aymm-loop.sh` exits 0 and the logic is correct by inspection.

- [x] Step 2 (final): Run test command — on pass, commit and close task.

## Smoke test
Manually inspect the modified `advance_provider()` logic: confirm sleep path triggers only when `RATE_LIMIT_ADVANCES >= ${#PROVIDERS[@]}`, counter increments correctly, STOP is written on the 3rd sleep, and ntfy fires on each sleep.
