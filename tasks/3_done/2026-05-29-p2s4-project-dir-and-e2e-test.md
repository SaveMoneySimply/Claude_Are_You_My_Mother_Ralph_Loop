# Task — project-dir-and-e2e-test

**Model:** sonnet · **Effort:** medium · **Thinking:** on
**Run:** Interactively with Claude — involves running the loop and observing output to verify end-to-end.

## Context
Engine extraction was abandoned. The new model: fork this repo, put your project in `project/`, point `ARCHITECTURE.md` at it. This task creates a minimal example project in `project/` and validates Ralph can run against it end-to-end — proving the fork model works and the system is in a clean state before the README is written.

The example project should be simple enough that a single loop task can complete it quickly (a trivial shell script, a small file transformation, anything with a verifiable outcome), but realistic enough to exercise the full pipeline: task picked from queue → step executed → test gate → committed → moved to done.

## Steps
- [x] Step 1: Create `project/` directory with a minimal `ARCHITECTURE.md` describing the example project — include stack, test command, key files, and `## Ralph settings\nautonomy: low` — done when: `project/ARCHITECTURE.md` exists and has a test command

- [x] Step 2: Add example task to `tasks/1_queue/hello-world.md` (tasks stay at repo root; `project/` holds code only) — done when: task file exists in `tasks/1_queue/`

- [x] Step 3: Ran `bash ralph.sh` — loop picked up hello-world, created `project/hello.sh`, passed test, committed, moved to `tasks/3_done/2026-05-29-hello-world.md`

- [x] Step 4: Confirmed `tasks/1_queue/` is empty (hello-world moved to done, p2s3/ralph-v4-ideas untouched in backlog)

## Smoke test
`ls project/tasks/3_done/` shows a completed task. `ls tasks/1_queue/` shows only Ralph's own tasks. The two pipelines don't interfere.
