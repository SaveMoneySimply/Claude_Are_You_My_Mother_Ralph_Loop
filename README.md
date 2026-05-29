# Ralph Loop

An autonomous Claude Code agent that works through task files one step at a time inside a Docker container with a firewall, token budgets, escalation logic, and phone notifications. **AYMM** (Are You My Mother) extends it to route tasks through free AI providers first — Gemini, Groq, Mistral, and OpenRouter — before falling back to Claude.

Fork this repo to use Ralph on your own project.

---

## Scripts reference

| Script | Purpose |
|---|---|
| `ralph.sh` | Host wrapper — builds the Docker image on first run, selects the execution mode, starts the container |
| `loop.sh` | Container loop for Claude mode — picks the next task, extracts the next step, runs Claude, escalates on failure, sends a stop notification |
| `aymm-loop.sh` | AYMM orchestrator — tries free providers in order before invoking `loop.sh` as the Claude fallback |
| `run_agent_task.sh` | Per-provider task runner — bundles context, calls the provider API, parses XML file-change blocks from the response, runs the per-step test |
| `apply_changes.sh` | Applies `<file>` / `<edit>` / `<delete>` XML blocks from free-AI responses to disk |
| `provider-config.sh` | Per-provider API config: endpoint URL, model name, API key env var name, max consecutive failures, request format |
| `init-firewall.sh` | Container entrypoint (runs as root) — sets up iptables egress allowlist, marks read-only files, drops to the `claude` non-root user |
| `prompt.md` | Step executor for Claude mode (~12 lines); bash injects the current step before passing to Claude. Not used by free AI providers. |
| `prompt-aymm.md` | XML response format reference; `run_agent_task.sh` appends this to free-AI prompts so providers know to return `<file>` / `<edit>` / `<delete>` blocks |

---

## Task pipeline

Four stages. Bash auto-pulls from `1_queue/` and moves to `2_active/`. Moving from backlog to queue is a human step. The agent archives to `3_done/` after the final step passes.

| Folder | Stage | Who moves files here |
|---|---|---|
| `tasks/0_backlog/` | Ideas and area plans not yet broken into task files | You |
| `tasks/1_queue/` | Task files ready to run | You (promote from backlog) |
| `tasks/2_active/` | The task currently being worked | Bash — auto-pulls from `1_queue/` in alphabetical order |
| `tasks/3_done/` | Archived completed tasks (`YYYY-MM-DD-name.md`) | Agent — on final step pass, per `prompt.md` instructions |

Name tasks with a phase/step prefix (`p2s3-foo.md`, `p2s4-bar.md`) to control execution order without manual sorting.

---

## Using Ralph on your own project

**1. Fork the repo**

```bash
git clone https://github.com/your-fork/ralph-loop my-project
cd my-project
```

**2. Write `ARCHITECTURE.md`**

This is the project spec Ralph reads every iteration. Keep it short and factual.

```markdown
# Architecture — My Project

## Stack
- Node 20, TypeScript

## Test command
npm run build && npm test

## Key files
- src/index.ts — entry point

## Firewall additions
# Extra egress domains beyond the defaults (one per line)
# api.example.com

## Ralph Settings
autonomy: low
```

**3. Put project code in `project/`**

Engine scripts stay at the repo root. Your project's source code lives in `project/`. Task files still live in `tasks/1_queue/` at the repo root — steps reference paths like `project/src/foo.ts`.

**4. Write task files**

Add one file per task to `tasks/1_queue/`. Bash picks them up automatically in filename order.

```markdown
# Task — add-greeting-endpoint

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 20000 · **Attempts:** 0/3
**Allowed files:** project/src/routes.ts, tasks/2_active/add-greeting-endpoint.md
**Run:** ralph

## Steps
- [ ] Step 1: Add GET /hello route that returns "Hello, world" — done when: endpoint exists and returns 200 — test: grep -q '/hello' project/src/routes.ts

## Smoke test
curl http://localhost:3000/hello returns "Hello, world"
```

**Header fields:**

| Field | Values | Effect |
|---|---|---|
| `Model` | `haiku` / `sonnet` / `opus` | Which Claude model; also the Claude fallback for AYMM |
| `Effort` | `low` / `medium` / `high` / `max` | Passed to `claude --effort` |
| `Tokens estimated` | integer | Loop writes STOP if actual output tokens exceed 2× this |
| `Allowed files` | comma-separated paths | `apply_changes.sh` skips any XML block targeting an unlisted path — prevents free AI from writing out-of-scope files |
| `Run` | `interactive` / `ralph` / `aymm` / `any` | Which loop mode can pick up this task — loop writes STOP with a clear error if the mode doesn't match |

**Step format:** Each step ends with `-- done when: <criterion>` and `-- test: <shell command>`. The test should be the cheapest check that would catch plausible-but-wrong output — `grep -q 'key-string' file.sh` rather than a full test suite run.

**5. Set environment variables**

```bash
export ANTHROPIC_API_KEY=sk-ant-...        # required (Claude and Claude fallback)
export NTFY_TOPIC=ralph-yourname-xxxx      # optional — phone push notifications

# Optional — free providers for AYMM mode
export GEMINI_API_KEY=...
export GROQ_API_KEY=...
export MISTRAL_API_KEY=...
export OPENROUTER_API_KEY=...
```

Add to your shell profile so they persist.

**6. Install Docker**

[docs.docker.com/get-docker](https://docs.docker.com/get-docker/)

Add yourself to the docker group so you can run Docker without sudo:

```bash
sudo usermod -aG docker $USER
# Log out and back in (or run: newgrp docker)
```

**7. Run**

```bash
bash ralph.sh
```

First run builds the Docker image (~a few minutes). Subsequent runs start immediately. If you modify `Dockerfile` or `init-firewall.sh`, rebuild with `docker rmi ralph:latest && bash ralph.sh`.

---

## Running Ralph

```bash
bash ralph.sh              # Claude only — works through tasks/1_queue/ using Claude
bash ralph.sh aymm         # AYMM — free providers first, Claude as fallback
bash ralph.sh aymm --only  # AYMM — free providers only, no Claude fallback
```

> **Plan mode** (`bash ralph.sh plan`) is currently broken and may be removed in a future version. Write task files directly to `tasks/1_queue/` instead.

---

## AYMM — free-provider escalation

AYMM tries providers in this order before falling back to Claude:

**gemini → groq → mistral → openrouter → Claude**

| Event | Action |
|---|---|
| Step passes | Reset failure counter; stay on current provider |
| Consecutive failures ≥ provider limit (gemini/groq: 3, mistral: 2, openrouter: 1) | Switch to next provider |
| HTTP 429 (rate-limited) | Switch to next provider immediately; pause if all providers rate-limited |
| HTTP 403 (forbidden) | Mark provider exhausted for this session; skip it |
| All free providers exhausted (non-rate-limit) | Escalate to Claude via `loop.sh` |
| All providers rate-limited | Write STOP — run `bash ralph.sh` to use Claude now, or wait ~1hr |

Current provider and failure counts: `.ralph/aymm-provider-state.json`

---

## Watching progress

```bash
tail -f .ralph/loop.log                  # full loop output
ls tasks/2_active/                        # what Ralph is working on right now
cat .ralph/aymm-provider-state.json      # current provider + failure counts (AYMM mode)
```

`.ralph/` is created on the first container run.

---

## Stopping

```bash
touch STOP                             # stop after the current iteration finishes
echo "Pausing for review" > STOP      # stop with a reason (shown in phone notification)
```

Ralph finishes the current iteration, then exits. The STOP file is cleared automatically at the start of the next run.

---

## Phone notifications

Set `NTFY_TOPIC` to any unique string (e.g. `ralph-matt-7a3k`), install the [ntfy app](https://ntfy.sh), and subscribe to your topic. You'll get a push notification whenever Ralph stops, with the stop reason in the message body.

---

## Callouts

### Read-only files and the review pattern

`CLAUDE.md` and `ARCHITECTURE.md` are chmod 0444 inside the container — the agent cannot write to them. If the agent determines either needs an update, it writes a proposal to `ARCHITECTURE_REVIEW.md` (or `CLAUDE_REVIEW.md`) and writes STOP. You review, edit the file manually, delete the review file, and resume.

### BLOCKED.md

Auto-created when a task exhausts the full escalation ladder (all providers + all Claude escalation levels). Contains the task name, what was tried, and the failing output. Review it, fix the underlying issue or split the task into smaller steps, re-queue, and resume.

### `Run:` and `Allowed files:` task fields

- `Run: interactive` — loop refuses to pick up this task; it must be run with Claude directly (use for tasks requiring human judgment, UI review, or host-only commands)
- `Run: aymm` — only `bash ralph.sh aymm` can run this task; `bash ralph.sh` will refuse
- `Allowed files: path1, path2` — `apply_changes.sh` skips any XML block targeting a path not on this list; strongly recommended for AYMM tasks to prevent free providers from writing to unrelated files

---

## File layout

```
my-project/
├── ARCHITECTURE.md        ← you write this; describes your project for Ralph
├── CLAUDE.md              ← Ralph's operating manual (read-only to agent)
├── CHANGELOG.md           ← append-only log of completed tasks
├── ralph.sh               ← host wrapper
├── loop.sh                ← container loop (Claude mode)
├── aymm-loop.sh           ← container loop (AYMM mode)
├── run_agent_task.sh      ← per-provider task runner
├── apply_changes.sh       ← XML block applicator
├── provider-config.sh     ← free provider config
├── init-firewall.sh       ← container entrypoint
├── prompt.md              ← step executor prompt (Claude mode)
├── prompt-aymm.md         ← XML response format reference (free AI)
├── project/               ← your project code lives here
├── tasks/
│   ├── 0_backlog/         ← plans and ideas not yet broken into tasks
│   ├── 1_queue/           ← task files waiting to run
│   ├── 2_active/          ← the task currently being worked
│   └── 3_done/            ← archived completed tasks
└── .ralph/                ← iteration logs (gitignored)
```
