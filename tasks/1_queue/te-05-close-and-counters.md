# Task — te-05-close-and-counters

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 5000 · **Attempts:** 0/3
**Test command:** (cd project && bash test-engine.sh)
**Allowed files:** project/test-engine.sh, tasks/2_active/te-05-close-and-counters.md

## Context
Adds two test groups to `project/test-engine.sh`:

**Group A — close_task** (from aymm-loop.sh):
Tests the file-manipulation parts of close_task: moving task file to 3_done/ with a date prefix
and appending a CHANGELOG entry. The phase-completion check in close_task fires only when the task
name matches `^phase[0-9]+` — use a plain name like "my-task" to skip it in tests.

Since close_task sources provider-config.sh and uses git, run it by initializing a real temp git
repo in TESTDIR (`git init`, `git add -A`, `git commit -m init`). The branch check inside
close_task (`current_branch == "task/${task}"`) won't match "main" so the merge/delete block is
skipped, leaving only the file-move and CHANGELOG logic to test. Source aymm-loop.sh into the
test subshell after setting WORKDIR="$TESTDIR" to pick up close_task and its helpers.

**Group B — AYMM provider failure counters** (from aymm-loop.sh):
Pure jq operations on `.ralph/aymm-failure-counters.json`. Can be sourced from aymm-loop.sh using
the same WORKDIR override. No git or API calls involved.

## Steps
- [ ] Add close_task file-move tests: in a subshell, initialize a temp git repo in TESTDIR, set WORKDIR=TESTDIR, source aymm-loop.sh (which starts its while loop — create STOP first to let it exit immediately, then source; or source only the functions section), call `close_task "my-task" "test-provider"` with a fake task file in tasks/2_active/, verify (a) the file no longer exists in 2_active/ and (b) a file matching `tasks/3_done/*-my-task.md` exists — done when: 2 assertions pass -- test: (cd project && bash test-engine.sh) | grep -q 'close_task_move'
- [ ] Add close_task CHANGELOG test: continuing from the setup above, verify that CHANGELOG.md contains a line with "my-task" and today's date after close_task runs — done when: 1 assertion passes -- test: (cd project && bash test-engine.sh) | grep -q 'close_task_changelog'
- [ ] Add provider failure counter tests: using the same WORKDIR subshell setup with aymm-loop.sh sourced, call `init_failure_counters`, then: (a) assert `get_failure_count gemini my-task` returns 0; (b) call `increment_failure_count gemini my-task` twice, assert count is 2; (c) call `reset_failure_count gemini my-task`, assert count returns to 0; (d) add counts for two providers, call `reset_all_failure_counts my-task`, assert both return 0 — done when: 4 assertions pass -- test: (cd project && bash test-engine.sh) | grep -q 'failure_counters'

## Smoke test
Run `(cd project && bash test-engine.sh)` and confirm all tests pass. Final SUMMARY should show >= 23 passed across all 5 tasks, 0 failed.
