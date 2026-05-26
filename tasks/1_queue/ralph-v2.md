# Task — ralph-v2

**Model:** sonnet · **Effort:** high · **Tokens estimated:** 25000 · **Attempts:** 0/3
**Test command:** bash -n loop.sh && bash -n prompt.md || true

## Context
Move all task navigation out of Claude's context window and into bash. Claude currently burns
~30-40% of each iteration reading PLAN.md and scanning task files just to find what to do next.
Replace with bash-side navigation + directory-driven state machine.

## Steps

- [ ] Step 1: Create directory pipeline — `mkdir -p tasks/{0_backlog,1_queue,2_active,3_done}` (already done as prep); migrate existing `tasks/done/` files to `tasks/3_done/`; migrate `plans/` content to `tasks/0_backlog/` — done when: new dirs exist and old content is relocated

- [ ] Step 2: Rewrite `loop.sh` navigation — replace PLAN.md+tasks/active/ scanning with bash-side directory navigation: pull from `1_queue/` → `2_active/` when active is empty; extract NEXT_STEP with `grep -m1 '^- \[ \]'`; inject NEXT_STEP + referenced files into prompt; remove PLAN.md reads entirely — done when: `bash -n loop.sh` exits 0; logic reviewed for correctness

- [ ] Step 3: Shrink `prompt.md` to ~8 lines — remove all navigation instructions (bash handles it now); keep only: execute this step, write pass/fail, handle final-step closure (commit, move to 3_done/, append CHANGELOG.md) — done when: file is ≤15 lines and covers pass/fail/final-step

- [ ] Step 4: Trim `CLAUDE.md` — remove navigation sections (PLAN.md references, tasks/active/ references, per-task workflow steps that bash now handles); update directory map to show 0_backlog/1_queue/2_active/3_done; keep: operating principles, escalation ladder, git rules — done when: CLAUDE.md references new directory structure throughout

- [ ] Step 5: Update `init-firewall.sh` — add commented-out chmod block for engine files (loop.sh, prompt.md, provider-config.sh, run_agent_task.sh) with instruction to uncomment once development stabilizes — done when: `bash -n init-firewall.sh` exits 0

- [ ] Step 6: Update `ARCHITECTURE.md` — update Key Files list, directory map, and test command to reflect new structure — done when: ARCHITECTURE.md matches new layout

- [ ] Step 7 (final): Run test command; verify `bash ralph.sh` launches and navigates via new directories — done when: syntax checks pass and one loop iteration correctly reads from `tasks/2_active/`

## Smoke test
Place a simple 2-step test task in `tasks/1_queue/`. Run `bash ralph.sh`. Confirm:
- Iteration 1: task moves from `1_queue/` to `2_active/`; Claude receives only the step text, not the full task file
- Iteration 2: step 2 executed, task moves to `3_done/`, CHANGELOG.md updated
- `.ralph/loop.log` shows short Claude output (step-scoped, not full-file navigation)
