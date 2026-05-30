# Task — v4-close-task-gap

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 4000 · **Attempts:** 0/3
**Allowed files:** aymm-loop.sh, project/aymm-loop.sh

## Context
When aymm-loop.sh escalates to Claude (`SINGLE_TASK=1 bash loop.sh`), the post-escalation block
(lines 396-408) already handles branch merge/delete if the task was closed. After
`v4-move-archival-to-bash` is done, loop.sh closes tasks from bash, so the task file will be
gone from `2_active/` when control returns to aymm-loop.sh.

This task verifies the existing post-escalation logic handles that correctly and fixes any gaps:
- `! -f task_active_file` → TRUE after bash close → branch merge/delete runs ✓
- `if [[ -f "$task_active_file" ]]` → FALSE → close_task() not double-called ✓

One real gap that may remain: if the escalation block calls `close_task()` when the file still
exists (edge case where loop.sh passed but didn't close — e.g. more steps remain), close_task()
does `git checkout main` before the merge. If we're already on main, this is a no-op. But if
the task branch was never created (no-branch workflow), `close_task()` should skip the merge
gracefully rather than error. Check and tighten this.

## Steps
- [x] In aymm-loop.sh and project/aymm-loop.sh: in `close_task()`, guard the branch merge/delete so it only runs when `task/${task}` actually exists as a branch (`git branch --list "task/${task}"` returns non-empty). Currently if the branch doesn't exist, `git merge --ff-only` fails silently with `|| true` — make it skip entirely instead of attempting. Also verify the post-escalation block (lines 396-408) reads correctly after v4-move-archival-to-bash: task file gone → branch cleanup runs, close_task() skipped — done when: close_task() contains a branch-existence check — test: grep -q 'git branch --list' aymm-loop.sh && grep -q 'git branch --list' project/aymm-loop.sh -- files: aymm-loop.sh:253-285, project/aymm-loop.sh:253-285

## Smoke test
Run `bash ralph.sh aymm` on a simple task. Verify after completion: no stale `tasks/2_active/` file, task branch merged and deleted, CHANGELOG entry present.
