# Task — per-task-write-allowlist

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 8000 · **Attempts:** 0/3
**Test command:** bash -n ralph.sh && bash -n loop.sh && bash -n aymm-loop.sh && bash -n run_agent_task.sh && bash -n provider-config.sh && bash -n apply_changes.sh

## Context
Free providers were corrupting engine files by writing `<file>` or `<edit>` blocks targeting files beyond the scope of their task (e.g. a task scoped to `aymm-loop.sh` caused the provider to also overwrite `loop.sh`). This adds an opt-in `**Allowed files:**` field to task headers. When present, `apply_changes.sh` silently skips any block whose path is not listed. Absent = current behavior (backward compatible).

Example task header field:
```
**Allowed files:** aymm-loop.sh, tasks/2_active/my-task.md
```

Paths are relative to workspace root, comma-separated, spaces around commas are trimmed.

## Steps
- [ ] Step 1: Edit `apply_changes.sh` — add `ALLOWLIST="${3:-}"` on a new line after line 8 (`files_written=0`). Then, in each of the three parsing loops (`<file>`, `<edit>`, `<delete>`), immediately after `fpath` is extracted and the `[[ -z "$fpath" ]]` guard, add a block: if `ALLOWLIST` is non-empty, split by comma into an array, trim spaces from each entry, and `continue` (skip this block) if `fpath` is not matched — also log `"Skipped (not in allowlist): $fpath"` to stderr. The `files_written` counter should NOT be incremented for skipped blocks. — done when: apply_changes.sh contains ALLOWLIST logic in all three loops and passes `bash -n` -- test: grep -q 'ALLOWLIST' apply_changes.sh && bash -n apply_changes.sh

- [ ] Step 2: Edit `run_agent_task.sh` `parse_and_apply_response()` function (around line 321) — immediately before the `bash apply_changes.sh` call, add logic to read the allowlist from the current task file: get `task_name` from `.ralph/last-task.txt`, derive `task_file="tasks/2_active/${task_name}.md"`, grep for `\*\*Allowed files:\*\*` to extract the comma-separated list into a local `allowlist` variable (empty string if the field is absent or the file is not found). Then pass `"$allowlist"` as the third argument to the existing `apply_changes.sh` call. — done when: run_agent_task.sh contains 'Allowed files' grep and passes `bash -n` -- test: grep -q 'Allowed files' run_agent_task.sh && bash -n run_agent_task.sh

- [ ] Step 3: Write `ARCHITECTURE_REVIEW.md` proposing that ARCHITECTURE.md's `## Task File Format` section (the task header block) be updated to document the new optional field — include the field name, example value, and behavior (skip unlisted paths; absent = unrestricted). — done when: ARCHITECTURE_REVIEW.md exists -- test: test -f ARCHITECTURE_REVIEW.md

## Smoke test
1. `bash -n apply_changes.sh && bash -n run_agent_task.sh` — both pass
2. Manual allowlist test: `printf '<file path="loop.sh">bad</file>\n' > /tmp/t.txt && bash apply_changes.sh /tmp/t.txt . "aymm-loop.sh" 2>&1 | grep -q 'Skipped'` — should exit 0 (grep found "Skipped" in output)
