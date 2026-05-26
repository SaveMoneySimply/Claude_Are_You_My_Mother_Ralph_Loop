# Task — Integration & README

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 30000 · **Attempts:** 0/3
**Test command:** bash -n aymm.sh

## Steps

- [x] Step 1: Write `aymm.sh` — mirror the structure of `ralph.sh` (preflight checks for Docker + ANTHROPIC_API_KEY, build image on first run, tee to log) but also pass GEMINI_API_KEY, GROQ_API_KEY, MISTRAL_API_KEY, OPENROUTER_API_KEY into the container, and invoke `aymm-loop.sh` instead of `loop.sh`; support `bash aymm.sh plan` to run breakdown mode — done when: `bash -n aymm.sh` exits 0 and the script structure mirrors ralph.sh

- [x] Step 2: Write `prompt-aymm.md` — a concise navigation wrapper (under 40 lines) for free AI agents; it must: read `PLAN.md` + `tasks/active/`, find the highest-priority unchecked task, write task name to `.ralph/last-task.txt`, identify the next unchecked step, list the files mentioned in that step, instruct the AI to respond using `<file path="...">...</file>` XML blocks for every modified file, and exit — done when: file exists and is under 40 lines

- [x] Step 3: Update `README.md` — add an AYMM section after the existing Ralph Loop content covering: required env vars (all 5), how to run (`bash aymm.sh`), escalation summary in plain language, when to use aymm.sh vs ralph.sh — done when: README.md has the AYMM section and reads clearly

- [x] Step 4 (final): Run test command (`bash -n aymm.sh`); also run `bash -n aymm-loop.sh && bash -n run_agent_task.sh && bash -n provider-config.sh` as a full system syntax check — on pass, commit and close task

## Smoke test
With ANTHROPIC_API_KEY set (free provider keys optional), run `bash aymm.sh plan` and confirm it generates task files the same way `bash ralph.sh plan` does. Then inspect `aymm.sh` to confirm all 5 env vars are forwarded into the container.
