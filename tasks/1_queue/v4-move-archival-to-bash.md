# Task — v4-move-archival-to-bash

**Model:** sonnet · **Effort:** high · **Tokens estimated:** 8000 · **Attempts:** 0/3
**Allowed files:** loop.sh, project/loop.sh, prompt.md

## Context
Currently the agent (via prompt.md step 3) moves the task file to `tasks/3_done/` and appends to
`CHANGELOG.md` when the final step passes. This is mechanical state management that belongs in
bash, not in the agent's judgment. Moving it to bash makes archival reliable regardless of whether
the agent follows prompt.md precisely.

After this change, `loop.sh` detects that all steps are `[x]` after a pass result and closes the
task itself. `prompt.md` drops step 3 entirely — the agent only marks steps done, commits, and
writes pass/fail.

This also resolves the aymm close_task() gap: when loop.sh handles archival uniformly, the
existing post-escalation check in aymm-loop.sh (lines 396-408) correctly handles branch
merge/delete regardless of which path closed the task.

## Steps
- [ ] Add bash-side task close to loop.sh and project/loop.sh: in the `RESULT=pass` handler (after the recovery file cleanup), if `$TASK_FILE` still exists and has no remaining unchecked steps (`! grep -q '^\- \[ \]' "$TASK_FILE"`), move it to `tasks/3_done/YYYY-MM-DD-name.md`, append to `CHANGELOG.md`, commit the admin files (`git add tasks/3_done/ CHANGELOG.md && git commit -m "${CURRENT_TASK}: close task"`), then run the iter/error cleanup. Also update the existing auto-close block (around line 267) to include the same git commit and cleanup. Make identical changes to project/loop.sh — done when: both files contain `close task` in a git commit message string — test: grep -q 'close task' loop.sh && grep -q 'close task' project/loop.sh -- files: loop.sh:260-275, loop.sh:355-370, project/loop.sh:260-275, project/loop.sh:355-370
- [ ] Update prompt.md: remove step 3 (the "if final step, move file + append CHANGELOG" block). Keep steps 1-2 (mark step done, commit) and the ARCHITECTURE_REVIEW instruction. Renumber so instructions stay clean — done when: prompt.md contains no reference to `tasks/3_done` — test: ! grep -q '3_done' prompt.md -- files: prompt.md

## Smoke test
Queue a test task with two steps. Run `bash ralph.sh` and verify: (1) agent marks both steps [x] and commits, (2) loop.sh moves the file to `tasks/3_done/` and appends CHANGELOG without agent instruction, (3) `bash ralph.sh stats` shows the attempt logged.
