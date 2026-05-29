# Task — te-01-skeleton

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 4000 · **Attempts:** 0/3
**Allowed files:** project/test-engine.sh, tasks/2_active/te-01-skeleton.md

## Context
First task of the Test Engine phase. `test-engine.sh` does not exist yet — this task creates it.
All subsequent te-* tasks add test functions to this file and use it as their gate.

This task uses `bash -n project/test-engine.sh` as its own gate (bootstrap — can't use the file as its own gate before it exists).

## Steps
- [x] Create `project/test-engine.sh`: shebang line, SCRIPT_DIR detection (`$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`), `cd "$SCRIPT_DIR"` so all subsequent paths are relative to `project/`, initialize `PASS_COUNT=0` and `FAIL_COUNT=0`, create `TESTDIR=$(mktemp -d)`, register `trap "rm -rf $TESTDIR" EXIT — done when: bash -n project/test-engine.sh passes -- test: bash -n project/test-engine.sh
- [ ] Add helper functions: `pass NAME` prints "  PASS: $NAME" and increments PASS_COUNT; `fail NAME MSG` prints "  FAIL: $NAME — $MSG" and increments FAIL_COUNT; `assert_eq NAME EXPECTED ACTUAL` calls pass/fail comparing the two values; `assert_contains NAME NEEDLE HAYSTACK` calls pass/fail if NEEDLE is a substring of HAYSTACK; `assert_file_exists NAME PATH` calls pass/fail if PATH exists — done when: all five helpers present -- test: grep -q 'assert_file_exists' project/test-engine.sh
- [ ] Add syntax-check tests: for each engine script in `project/` (loop.sh, aymm-loop.sh, ralph.sh, run_agent_task.sh, apply_changes.sh, provider-config.sh, provider-status.sh, init-firewall.sh, test-providers.sh), run `bash -n <script>` and call pass/fail accordingly — done when: all 9 scripts checked -- test: grep -c 'bash -n' project/test-engine.sh | grep -qE '^[9-9][0-9]*$|^[1-9][0-9]+$'
- [x] Create `project/test-engine.sh`: shebang line, SCRIPT_DIR detection (`$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`), `cd "$SCRIPT_DIR"` so all subsequent paths are relative to `project/`, initialize `PASS_COUNT=0` and `FAIL_COUNT=0`, create `TESTDIR=$(mktemp -d)`, register `trap "rm -rf $TESTDIR" EXIT — done when: bash -n project/test-engine.sh passes -- test: bash -n project/test-engine.sh

## Smoke test
Run `(cd project && bash test-engine.sh)` and confirm all 9 syntax checks pass with "SUMMARY: 9 passed, 0 failed".
