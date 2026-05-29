# Task — update-readme

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 8000 · **Attempts:** 0/3
**Allowed files:** README.md

> **Run interactively with Claude (not AYMM)** — README rewrite requires judgment about tone, structure, and what to include. Free providers produce technically passable but flat output for this kind of task. No prerequisites.

## Context
The current README describes an older version of Ralph (v1/v2). It uses wrong folder names (`tasks/active/`, `tasks/done/`), doesn't mention most of the engine scripts, and doesn't explain the AYMM multi-provider system in enough depth for someone to actually try it. Goal: someone new should be able to read the README, understand what Ralph + AYMM does, and get it running.

Matt's specific asks:
- Correct the task folder structure (0_backlog, 1_queue, 2_active, 3_done — not active/done)
- Explain what each script does (ralph.sh, loop.sh, aymm-loop.sh, run_agent_task.sh, apply_changes.sh, provider-config.sh, init-firewall.sh, prompt.md)
- Explain how to run each mode and what it does
- Explain the callouts: STOP file, ARCHITECTURE_REVIEW.md pattern, BLOCKED.md, phone notifications via ntfy
- Explain how to use Ralph on your own project: fork the repo, put your project in `project/`, point `ARCHITECTURE.md` at it — engine scripts stay at repo root, project lives in `project/`

## Steps
- [x] Step 1: Read `README.md`, `CLAUDE.md` (task format section), `ARCHITECTURE.md`, and `provider-config.sh` (provider list) to understand the current state of the system before writing anything — done when: you have read all four files -- test: true

- [x] Step 2: Rewrite `README.md` — keep the same high-level sections but update all outdated content. Required sections:
  - **What Ralph is** — autonomous loop that runs Claude Code against task files, one step at a time, in a Docker container
  - **What AYMM adds** — free provider layer (Gemini → Groq → Mistral → OpenRouter → Claude), escalation logic, near-zero cost for most tasks
  - **Scripts reference** — table or list explaining what each script does: `ralph.sh`, `loop.sh`, `aymm-loop.sh`, `run_agent_task.sh`, `apply_changes.sh`, `provider-config.sh`, `init-firewall.sh`, `prompt.md`
  - **Task folder structure** — correct names: `0_backlog/`, `1_queue/`, `2_active/`, `3_done/` with one-line description of each stage
  - **How to run** — setup steps, env vars (ANTHROPIC_API_KEY + 4 free provider keys), `bash ralph.sh` vs `bash ralph.sh aymm` vs `bash ralph.sh plan`
  - **Watching progress** — loop.log, last-task.txt, aymm-provider-state.json
  - **Stopping** — `touch STOP`, writing a reason, phone notifications via ntfy
  - **Callouts** — ARCHITECTURE_REVIEW.md pattern (read-only files + review flow), BLOCKED.md, per-task Allowed files field
  Done when: README.md covers all sections above -- test: grep -q 'aymm-loop.sh\|run_agent_task\|0_backlog\|1_queue' README.md

## Smoke test
Read through the updated README from top to bottom and confirm a developer who has never seen this repo could understand what it does and follow the setup steps to get Ralph running on their own project.
