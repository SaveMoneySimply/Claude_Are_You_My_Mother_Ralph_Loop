# Task — fix-bug022-local-keyword

**Model:** sonnet · **Effort:** low · **Tokens estimated:** 8000 · **Attempts:** 0/3
**Run:** aymm
**Allowed files:** loop.sh

## Steps

- [ ] Remove the `local` keyword from the `_est` variable declaration inside the main while-loop body in loop.sh around line 416. The `local` keyword is only valid inside functions — using it in the main loop body is a bash error. Change the two lines:
  ```
  local _est
  _est=$(grep 'Tokens estimated' "$TASK_FILE" | grep -oP '\d+' | head -1)
  ```
  to a single line:
  ```
  _est=$(grep 'Tokens estimated' "$TASK_FILE" | grep -oP '\d+' | head -1)
  ```
  Done when: bash -n passes on loop.sh and the `local _est` line no longer exists. -- test: bash -n loop.sh && ! grep -q 'local _est' loop.sh -- files: loop.sh:412-420 -- mode: aymm

## Smoke test
Run `bash -n loop.sh` — should exit 0 with no output.
