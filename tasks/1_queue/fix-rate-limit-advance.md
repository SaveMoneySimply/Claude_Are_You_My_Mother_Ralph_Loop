# Task — fix-rate-limit-advance

**Model:** sonnet · **Effort:** low · **Tokens estimated:** 3000 · **Attempts:** 0/3
**Test command:** bash -n aymm-loop.sh && echo "pass" || echo "fail"

## Steps
- [ ] Step 1: In `aymm-loop.sh`, change the `100)` case so that a 429 rate-limit immediately advances to the next provider instead of sleeping 60s on the first occurrence. Remove the COOLDOWN_COUNT logic for the 100 case entirely. The updated case should just call `advance_provider "$CURRENT_TASK" "rate_limit"` directly. — done when: the `100)` case in `aymm-loop.sh` no longer contains `sleep 60` and `bash -n aymm-loop.sh` exits 0.

## Smoke test
Inspect the `100)` case in `aymm-loop.sh` and confirm there is no `sleep` call.
