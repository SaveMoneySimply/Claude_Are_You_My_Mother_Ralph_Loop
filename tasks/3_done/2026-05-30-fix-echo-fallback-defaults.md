# Task — fix-echo-fallback-defaults

**Model:** sonnet · **Effort:** low · **Tokens estimated:** 3000 · **Attempts:** 0/3
**Test command:** (cd project && bash test-engine.sh)
**Allowed files:** loop.sh, aymm-loop.sh, project/loop.sh, project/aymm-loop.sh

## Context
Seven `|| echo default` fallbacks in the header-reading functions silently never fire.
When a pipeline ends with `tr '[:upper:]' '[:lower:]'` or `head -1`, those commands
exit 0 on empty input, so `|| echo default` is never reached — the variable is set to
empty string instead of the intended default.

The pattern that works: capture to a local var first, then apply `${val:-default}`.

The test-engine.sh header_parsing tests already verify the correct behavior using this
pattern and currently pass. These fixes bring loop.sh/aymm-loop.sh into alignment.

**Functions to fix (same lines in root and project/ copies):**

loop.sh + project/loop.sh:
- `read_autonomy` (L17-21): `|| echo "low"` → `${val:-low}`
- `read_run_mode` (L23-28): `|| echo "any"` → `${val:-any}`
- `load_recovery` RECOVERY_SPLIT_DEPTH (L91-92): `| head -1 || echo 0` → `${val:-0}`
- `load_recovery` RECOVERY_DECL_MODEL (L95-96): `| tr ... || echo "sonnet"` → `${val:-sonnet}`
- `load_recovery` RECOVERY_DECL_EFFORT (L97-98): `| tr ... || echo "high"` → `${val:-high}`
- `RESULT` (L336): `| tr ... || echo "unknown"` → `${val:-unknown}`
- `ESTIMATE` (L374): `| head -1 || echo 0` → `${val:-0}`

aymm-loop.sh + project/aymm-loop.sh:
- `read_autonomy` (L24-28): same fix
- `read_run_mode` (L30-35): same fix

## Steps
- [ ] Fix `read_autonomy` and `read_run_mode` in loop.sh and project/loop.sh — replace the `|| echo` fallback with local-var + `${val:-default}` pattern matching the working examples in test-engine.sh — done when: both functions use `${val:-...}` — test: grep -q 'val:-low' loop.sh && grep -q 'val:-any' loop.sh -- files: loop.sh:17-28, project/loop.sh:17-28
- [ ] Fix `read_autonomy` and `read_run_mode` in aymm-loop.sh and project/aymm-loop.sh — same pattern — done when: both functions updated in both files — test: grep -q 'val:-low' aymm-loop.sh && grep -q 'val:-any' aymm-loop.sh -- files: aymm-loop.sh:24-35, project/aymm-loop.sh:24-35
- [ ] Fix `load_recovery` RECOVERY_SPLIT_DEPTH, RECOVERY_DECL_MODEL, RECOVERY_DECL_EFFORT in loop.sh and project/loop.sh; fix RESULT and ESTIMATE assignments in the same files — done when: all five use `${val:-...}` — test: grep -c 'val:-' loop.sh | grep -qP '^[5-9]' -- files: loop.sh:88-100, loop.sh:333-337, loop.sh:370-376, project/loop.sh:88-100, project/loop.sh:333-337, project/loop.sh:370-376

## Smoke test
Run `(cd project && bash test-engine.sh)` — all 27 tests should still pass. Run `bash -n loop.sh aymm-loop.sh project/loop.sh project/aymm-loop.sh` — no syntax errors.
