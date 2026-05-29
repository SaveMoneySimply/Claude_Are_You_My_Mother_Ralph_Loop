# Task — te-02-task-pipeline

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 4000 · **Attempts:** 0/3
**Test command:** (cd project && bash test-engine.sh)
**Allowed files:** project/test-engine.sh, tasks/2_active/te-02-task-pipeline.md

## Context
Adds tests for the core task pipeline operations to `project/test-engine.sh`.

These are tested by replicating the exact bash one-liners used in loop.sh and aymm-loop.sh
against a controlled temp workspace — no sourcing of the full scripts needed.

The functions under test and their implementations:
- Task picking: `ls tasks/2_active/*.md 2>/dev/null | head -1` and `ls tasks/1_queue/*.md 2>/dev/null | head -1`
- Already-done detection: `compgen -G "tasks/3_done/*-${task_name}.md"`
- has_remaining_steps: `grep -q '^- \[ \]' taskfile`
- mark_step_done: `sed -i '0,/^- \[ \]/{s/^- \[ \]/- [x]/}' taskfile`
- STOP detection: `[ -f STOP ]`

## Steps
- [ ] Add a `setup_workspace` helper to test-engine.sh that creates the 4-stage task pipeline directories (`tasks/0_backlog`, `tasks/1_queue`, `tasks/2_active`, `tasks/3_done`) inside `$TESTDIR` and initializes a minimal fake task file with two unchecked steps; add a `teardown_workspace` that removes those dirs (TESTDIR cleanup on EXIT already handles the root, but individual tests may recreate state) — done when: helper functions present -- test: grep -q 'setup_workspace' project/test-engine.sh -- files: project/test-engine.sh
- [ ] Add pick_task tests: using a subshell with TESTDIR as working directory, verify (a) when 2_active/ is empty and 1_queue/ has a file, the file is moved to 2_active/; (b) when 2_active/ already has a file, that file is returned without touching 1_queue/; (c) when a task name matches an existing 3_done/*-<name>.md entry, the queue file is removed and pick returns empty — done when: 3 pick_task tests pass -- test: (cd project && bash test-engine.sh) | grep -q 'pick_task' -- files: project/test-engine.sh, project/loop.sh:131-156
- [ ] Add step-management tests: verify (a) `has_remaining_steps` returns true (exit 0) when a task file contains `- [ ]` lines; (b) returns false (exit 1) when all steps are `- [x]`; (c) `mark_step_done` changes the first `- [ ]` to `- [x]` and leaves subsequent `- [ ]` lines untouched — done when: 3 step-management tests pass -- test: (cd project && bash test-engine.sh) | grep -q 'mark_step_done' -- files: project/test-engine.sh, project/aymm-loop.sh:167-182
- [ ] Add STOP detection test: verify that a loop iteration that checks `[ -f STOP ]` exits when STOP exists in TESTDIR; use a small inline while loop in a subshell to confirm it reads the file correctly — done when: 1 STOP test passes -- test: (cd project && bash test-engine.sh) | grep -q 'STOP' -- files: project/test-engine.sh

## Smoke test
Run `(cd project && bash test-engine.sh)` and confirm all new tests pass (SUMMARY shows >= 7 passed including the 9 syntax checks from te-01).
