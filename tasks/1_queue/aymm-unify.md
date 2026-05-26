# Task — aymm-unify

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 10000 · **Attempts:** 0/3
**Test command:** bash -n ralph.sh && bash -n aymm-loop.sh
**Depends on:** ralph-v2 (must be complete first — requires new directory structure)

## Context
Absorb `aymm.sh` into `ralph.sh` as a third mode so there is one entry point and one project to
manage. `aymm-loop.sh` stays as the container-side script; only the host-side wrapper changes.
Also update `aymm-loop.sh` for the new directory paths from ralph-v2.

## Steps

- [ ] Step 1: Add `aymm` mode to `ralph.sh` — copy the provider API key env var forwarding from `aymm.sh` into a new `aymm)` case; set `LOOP_ENV="-e LOOP_SCRIPT=aymm-loop.sh"`; update the usage/help text — done when: `bash -n ralph.sh` exits 0 and `bash ralph.sh aymm` (dry-run) shows correct docker invocation

- [ ] Step 2: Update `aymm-loop.sh` for new directory paths — replace `tasks/active/` → `tasks/2_active/`, `tasks/done/` → `tasks/3_done/` throughout; update `close_task()` to skip PLAN.md updates (directory IS the state now) — done when: `bash -n aymm-loop.sh` exits 0

- [ ] Step 3: Delete `aymm.sh` — done when: file is removed and `ralph.sh aymm` is the documented entry point

- [ ] Step 4: Update `ARCHITECTURE.md` — remove `aymm.sh` from Key Files; update usage section to show `bash ralph.sh aymm`; update description of entry points — done when: ARCHITECTURE.md no longer references aymm.sh

- [ ] Step 5 (final): Run test command; verify `bash ralph.sh aymm` launches correctly — done when: syntax checks pass

## Smoke test
Run `bash ralph.sh aymm` with no provider keys set. Confirm it fails gracefully with a helpful
error (same behavior as the old `bash aymm.sh`). Check that `ralph.sh` `plan` and `execute` modes
still work unchanged.
