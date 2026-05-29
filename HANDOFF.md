# HANDOFF — Ralph Loop — 2026-05-29

> **Delete this file after reading.** It exists only to bridge sessions.

## Where we are
Working tree is clean (after this commit), queue is empty, backlog has only `ralph-v4-ideas.md`. p2s3 (README rewrite) and p2s4 (project/ e2e test) are both done. The next planned task is agreed on but not started.

## What was just done
- **p2s4** — Validated the fork model: `project/` holds code only, tasks stay at repo root, ralph.sh needs no changes. Ran the loop end-to-end against a hello-world task that created `project/hello.sh`.
- **p2s3** — Full README rewrite: scripts reference table (9 files), correct 4-stage task pipeline, fork-and-use walkthrough with task file format, AYMM escalation with correct provider order (gemini→groq→mistral→openrouter), callouts (read-only files, BLOCKED.md, Run:/Allowed files: fields), file layout tree.
- Added "move task archival from agent to bash" idea to `tasks/0_backlog/ralph-v4-ideas.md`.
- Corrected the AYMM provider order (README had mistral before groq — fixed to match provider-config.sh).

## Current blocker / next step
No blockers. Agreed-on next task: **set up `project/` for self-hosting** — copy Ralph's engine files into `project/` so Ralph can work on Ralph itself.

Files to copy into `project/`:
- Engine scripts: `loop.sh`, `aymm-loop.sh`, `ralph.sh`, `run_agent_task.sh`, `apply_changes.sh`, `provider-config.sh`, `init-firewall.sh`, `test-providers.sh`
- Prompt files: `prompt.md`, `prompt-aymm.md`, `prompt-split.md`, `prompt-plan.md`
- `Dockerfile`

Files to create:
- `project/ARCHITECTURE.md` — describes Ralph (stack: bash, test command: bash -n *.sh syntax check, key files, autonomy: low)

Files NOT to copy: `tasks/`, `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `.gitignore`, `handoffs/`

Deploy-back model: simple directory copy (not a nested git). When Ralph improves a file in `project/`, copy it back to repo root (`cp project/loop.sh loop.sh`). Outer git tracks everything.

## Key files changed this session
- `README.md` — full rewrite (see p2s3)
- `project/ARCHITECTURE.md` — created for hello-world e2e test
- `project/hello.sh` — created by the loop as the p2s4 validation artifact
- `tasks/0_backlog/ralph-v4-ideas.md` — added task-archival-to-bash idea
- `CHANGELOG.md` — two new entries (p2s4, p2s3)
- `tasks/3_done/2026-05-29-p2s3-update-readme.md` — archived
- `tasks/3_done/2026-05-29-p2s4-project-dir-and-e2e-test.md` — archived

## Open issues to keep in mind
- `ralph.sh plan` is broken (references old folder structure `plans/` / `tasks/active/`). Documented in README as a caveat. Tracked in ralph-v4-ideas.md under "Plan mode — update or remove."
- `project/` is currently just `ARCHITECTURE.md` + `hello.sh` from the e2e test. The self-hosting setup (next task) will populate it with Ralph's own engine files.
- The hello-world task in `tasks/3_done/` is a test artifact — can be ignored or deleted.

## Commands to run to resume
```bash
# Verify clean state
git status && git log --oneline -5

# Check what's in project/ currently
ls project/

# Start self-hosting setup: copy engine files into project/
cp loop.sh aymm-loop.sh ralph.sh run_agent_task.sh apply_changes.sh \
   provider-config.sh init-firewall.sh test-providers.sh \
   prompt.md prompt-aymm.md prompt-split.md prompt-plan.md \
   Dockerfile \
   project/

# Then create project/ARCHITECTURE.md (describe Ralph, bash stack, syntax-check test command)
# Then write a task file to tasks/1_queue/ for whatever improvement you want Ralph to make
```
