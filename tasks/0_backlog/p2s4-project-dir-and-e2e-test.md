# Task — project-dir-and-e2e-test

**Model:** sonnet · **Effort:** medium · **Thinking:** on
**Run:** Interactively with Claude — involves running the loop and observing output to verify end-to-end.

## Context
Engine extraction was abandoned. The new model: fork this repo, put your project in `project/`, point `ARCHITECTURE.md` at it. This task creates a minimal example project in `project/` and validates Ralph can run against it end-to-end — proving the fork model works and the system is in a clean state before the README is written.

The example project should be simple enough that a single loop task can complete it quickly (a trivial shell script, a small file transformation, anything with a verifiable outcome), but realistic enough to exercise the full pipeline: task picked from queue → step executed → test gate → committed → moved to done.

## Steps
- [ ] Step 1: Create `project/` directory with a minimal `ARCHITECTURE.md` describing the example project — include stack, test command, key files, and `## Ralph settings\nautonomy: low` — done when: `project/ARCHITECTURE.md` exists and has a test command

- [ ] Step 2: Add a minimal example task file to `project/tasks/1_queue/` — one or two steps, trivial but verifiable (e.g. "create a hello.sh that echoes Hello Ralph") — done when: at least one task file exists in `project/tasks/1_queue/`

- [ ] Step 3: Run `bash ralph.sh` from the repo root (pointing at `project/` as workspace, or confirm the current workspace mount still works with the project/ structure) — verify the loop picks up the task, executes it, and moves it to done — done when: task appears in `project/tasks/3_done/` with a date prefix

- [ ] Step 4: Confirm `tasks/` at repo root (Ralph's own tasks) is unaffected — done when: `ls tasks/1_queue/` still shows only Ralph's own task files (not the example project's tasks)

## Smoke test
`ls project/tasks/3_done/` shows a completed task. `ls tasks/1_queue/` shows only Ralph's own tasks. The two pipelines don't interfere.
