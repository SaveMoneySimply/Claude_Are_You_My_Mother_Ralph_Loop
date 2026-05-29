# Architecture Review — Document `**Allowed files:**` task header field

**Triggered by task:** `per-task-write-allowlist`
**Date:** 2026-05-29

## What needs to change

The `## Task File Format` section in `CLAUDE.md` (the task header block) should be updated to document the new optional `**Allowed files:**` field.

> Note: The Task File Format section lives in `CLAUDE.md`, not `ARCHITECTURE.md`. This review follows the same pattern — a human should update `CLAUDE.md` directly and delete this file when done.

## Proposed addition to the task header block in CLAUDE.md

In the Task File Format section, add one line to the example task header:

```markdown
**Model:** sonnet · **Effort:** high · **Tokens estimated:** 50000 · **Attempts:** 0/3
**Allowed files:** aymm-loop.sh, tasks/2_active/my-task.md
**Test command:** <only include if different from ARCHITECTURE.md default — omit to use the default>
```

And add a paragraph below the header block explaining the field:

---

**`**Allowed files:**` (optional)** — A comma-separated list of paths (relative to workspace root) that `apply_changes.sh` is permitted to write. Any `<file>`, `<edit>`, or `<delete>` block targeting a path not in this list is silently skipped and logged to stderr as `Skipped (not in allowlist): <path>`. When the field is absent, all paths are permitted (current behavior — fully backward compatible).

Use this field for tasks scoped to a specific file when running free-tier AI providers, which have been observed to emit out-of-scope file blocks that overwrite unrelated engine files.

Example:
```
**Allowed files:** aymm-loop.sh, tasks/2_active/my-task.md
```

---

## Why this change is needed

Free AI providers (Gemini, Groq, Mistral, OpenRouter) occasionally emit `<file>` blocks for paths outside the task's intended scope — for example, a task scoped to `aymm-loop.sh` caused an overwrite of `loop.sh`. The `**Allowed files:**` field gives task authors a simple opt-in containment mechanism without changing the default behavior for existing tasks.

## Implementation already in place

- `apply_changes.sh` — reads `ALLOWLIST` as third positional argument; skips and logs any block whose path is not listed
- `run_agent_task.sh` — reads `**Allowed files:**` from the active task file and passes it as `$3` to `apply_changes.sh`
