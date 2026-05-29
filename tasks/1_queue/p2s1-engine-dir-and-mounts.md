# Task — engine-dir-and-mounts

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 8000 · **Attempts:** 0/3
**Test command:** bash -n ralph.sh && bash -n init-firewall.sh
**Allowed files:** ralph.sh, init-firewall.sh
**Note:** Run via `bash ralph.sh` (not aymm) — step 1 creates a directory outside /workspace which free providers cannot do via XML blocks.

## Context
Engine scripts need to live in `~/tools/ralph/` and be mounted read-only as `/engine` in the container. This separates engine files from the project workspace so external projects stay clean. The container's `init-firewall.sh` currently executes `bash /workspace/${LOOP}` — this must change to `bash /engine/${LOOP:-loop.sh}` after the mount is in place.

After this task, SCRIPT_DIR in engine scripts still points to /workspace (scripts run from workspace mount, not /engine). The SCRIPT_DIR/WORKSPACE split is a separate task (p2s2, done interactively).

## Steps
- [ ] Step 1: Run shell command: `mkdir -p ~/tools/ralph && cp /workspace/loop.sh /workspace/aymm-loop.sh /workspace/run_agent_task.sh /workspace/apply_changes.sh /workspace/provider-config.sh /workspace/provider-status.sh /workspace/test-providers.sh /workspace/prompt.md /workspace/prompt-aymm.md /workspace/prompt-plan.md /workspace/prompt-split.md ~/tools/ralph/` — done when: all engine scripts exist in ~/tools/ralph/ -- test: test -f ~/tools/ralph/loop.sh && test -f ~/tools/ralph/aymm-loop.sh && test -f ~/tools/ralph/run_agent_task.sh

- [ ] Step 2: Edit `ralph.sh` docker run block — add `-v "${HOME}/tools/ralph:/engine:ro" \` as a new line immediately after the `-v "$(pwd):/workspace" \` line — done when: ralph.sh contains `/engine:ro` -- test: grep -q '/engine:ro' ralph.sh

- [ ] Step 3: Edit `init-firewall.sh` line 78 — change `bash /workspace/${LOOP}` to `bash /engine/${LOOP:-loop.sh}` — done when: init-firewall.sh references /engine/ -- test: grep -q '/engine/' init-firewall.sh

- [ ] Step 4: Rebuild Docker image so the updated init-firewall.sh is baked in: run `docker build -t ralph:latest /workspace` — done when: image rebuilds without error -- test: docker image inspect ralph:latest --format '{{.Created}}' | grep -q '2026'

## Smoke test
Run `bash ralph.sh` — confirm the loop starts and logs show it is executing from /engine (loop.sh will still reference SCRIPT_DIR=/workspace for now, that is expected and correct until p2s2).
