# Architecture Review — Update Phases section

**Triggered by:** v3 phase planning session (2026-05-29)

## What needs to change

The `## Phases` section in `ARCHITECTURE.md` currently has a placeholder. Replace it with the actual v3 phase structure.

## Proposed replacement for `## Phases`

```markdown
## Phases

**Phase 1 — Polish**
- p1s1: Timestamp filenames in tasks/3_done/ (YYYY-MM-DD-<name>.md for chronological ordering)

**Phase 2 — Engine Extraction**
- p2s1: Create ~/tools/ralph/, mount as /engine:ro in container, update init-firewall.sh exec path
- p2s2: SCRIPT_DIR/WORKSPACE split in engine scripts (loop.sh, aymm-loop.sh, run_agent_task.sh)

**After Phase 2:** Point Ralph at an external project to validate end-to-end.

**Deferred to v4:** AYMM-all mode, OpenRouter model checker, daily quota reset detection.
```
