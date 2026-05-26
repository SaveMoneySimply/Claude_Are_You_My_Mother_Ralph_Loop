# Claude_Ralph_Loop
Ralph Loop — A template repo for running autonomous Claude Code agents. Fork it to start a new project. The agent works through task files one step at a time in a Docker container, with a firewall, escalation logic, and phone notifications when it stops.

# Ralph Loop — Project Scaffold

A base template for autonomous Claude coding sessions. Fork this repo to start a new project, then let Ralph work through your task list while you do other things.

## What's in the box

| File | Purpose |
|---|---|
| `CLAUDE.md` | Working standards Claude reads every session (interactive and loop mode) |
| `Dockerfile` | Container Claude runs inside — isolated from your host |
| `init-firewall.sh` | Locks down egress to an allowlist, marks read-only files, drops to non-root |
| `loop.sh` | The loop — pipes `prompt.md` to Claude, tracks token budgets, sends stop notifications |
| `ralph.sh` | One command to build the image and start the loop |

## Starting a new project

**1. Fork or clone this repo**

```bash
git clone https://github.com/SaveMoneySimply/Claude_Ralph_Loop my-project
cd my-project
git remote set-url origin https://github.com/SaveMoneySimply/Claude_Ralph_Loop
```

**2. Create `ARCHITECTURE.md`**

This is the one file you write before Ralph touches anything. It tells Claude what the project is.

```md
# Architecture — My Project

## Stack
- ...

## Key folders
- ...

## Test command
npm run build && npm test

## Firewall additions
# List any extra domains the container needs egress to (beyond the defaults)
```

**3. `prompt.md` is already included**

It works for most projects out of the box. Edit it only if your project needs custom navigation logic (different task selection order, extra state checks, etc.).

**4. Add tasks**

```
tasks/active/your-first-task.md
```

See `CLAUDE.md → .md File Architecture` for the task file format, including the required `Tokens estimated` header field.

**5. Set environment variables**

```bash
export ANTHROPIC_API_KEY=sk-ant-...        # required
export NTFY_TOPIC=ralph-yourname-xxxx      # optional — phone notifications via ntfy.sh
```

Add both to your shell profile so they persist.

**6. Install Docker**

[docs.docker.com/get-docker](https://docs.docker.com/get-docker/)

After installing, add yourself to the docker group so you can run Docker without sudo:

```bash
sudo usermod -aG docker $USER
# Log out and back in (or run: newgrp docker)
```

**7. Start Ralph**

`PLAN.md`, `CHANGELOG.md`, and `plans/example.md` ship as stubs in the template — edit them to match your project before running. If you want Ralph to generate task files from your plans automatically, run breakdown mode:

```bash
# Breakdown mode: reads plans/*.md and creates task files in tasks/active/
bash ralph.sh plan

# Then run execution mode (or skip breakdown and write task files yourself)
bash ralph.sh
```

If you prefer to write task files directly, skip `bash ralph.sh plan` and just run `bash ralph.sh`.

First run builds the Docker image (a few minutes). Subsequent runs start immediately.

If you modify `Dockerfile` or `init-firewall.sh`, force a rebuild: `docker rmi ralph:latest` then `bash ralph.sh`.

## Watching progress

`.ralph/` is created on the first container run — these commands require at least one run to have completed.

```bash
tail -f .ralph/loop.log          # full log
ls .ralph/iter-*.json            # per-iteration output
cat .ralph/last-task.txt         # which task Ralph is working on right now
```

## Stopping Ralph

From any terminal in the project directory:

```bash
touch STOP
```

Ralph finishes the current iteration, sends a phone notification (if `NTFY_TOPIC` is set), and exits. You can also write a reason:

```bash
echo "Pausing for review" > STOP
```

## Phone notifications

Install the [ntfy app](https://ntfy.sh), subscribe to your topic name, and you'll get a push notification whenever Ralph stops — with the stop reason in the message body.

## What Ralph will never touch

- `CLAUDE.md` — chmod 0444 inside the container
- `ARCHITECTURE.md` — chmod 0444 inside the container

If Ralph thinks either needs to change, it writes a proposal to `ARCHITECTURE_REVIEW.md` or `CLAUDE_REVIEW.md` and stops for your review.

## File layout for your project

```
my-project/
├── ARCHITECTURE.md       ← you write and own this
├── CLAUDE.md             ← working standards (edit rarely)
├── PLAN.md               ← index of sub-plans
├── CHANGELOG.md          ← append-only log of completed tasks
├── TEST.md               ← post-deploy and recurring verifications
├── BLOCKED.md            ← tasks Ralph got stuck on (auto-created)
├── prompt.md             ← what Ralph reads each iteration
├── plans/                ← one .md per work area
├── tasks/
│   ├── active/           ← in-progress task files
│   └── done/             ← archived completed tasks
└── .ralph/               ← iteration logs (gitignored)
```

See `CLAUDE.md → .md File Architecture` for the full doc conventions.

---

## AYMM — Are You My Mother (Multi-Provider Mode)

AYMM extends Ralph to use free AI providers (Gemini, Mistral, Groq, OpenRouter) before falling back to Claude. Same workflow, lower API cost.

### Required environment variables

```bash
export ANTHROPIC_API_KEY=sk-ant-...       # required — Claude fallback and plan mode
export GEMINI_API_KEY=...                 # optional free provider
export MISTRAL_API_KEY=...                # optional free provider
export GROQ_API_KEY=...                   # optional free provider
export OPENROUTER_API_KEY=...             # optional free provider
```

At least one free provider key is recommended; without them AYMM behaves identically to Ralph.

### Running AYMM

```bash
# Breakdown mode: generate task files from plans (uses Claude)
bash aymm.sh plan

# Execution mode: work through tasks using free providers first
bash aymm.sh
```

All other controls (watching progress, stopping) are identical to Ralph — use `.ralph/loop.log`, `cat .ralph/last-task.txt`, and `touch STOP`.

### Escalation — how AYMM picks a provider

Each iteration, AYMM tries providers in priority order: **gemini → mistral → groq → openrouter → Claude**.

| Event | Action |
|---|---|
| Step passes | Reset failure counter, stay on current provider |
| 2 consecutive failures on one provider | Switch to next free provider |
| Rate-limited (429) or forbidden (403) | Switch to next free provider immediately |
| All free providers exhausted (non-rate-limit) | Escalate to Claude via `loop.sh` |
| All free providers rate-limited | Write STOP — wait ~1hr or run `bash ralph.sh` to use Claude now |

Current provider and failure counts are written to `.ralph/aymm-provider-state.json` each iteration.

### When to use `aymm.sh` vs `ralph.sh`

| | `ralph.sh` | `aymm.sh` |
|---|---|---|
| Provider | Claude only | Free providers first, Claude as fallback |
| Cost | Claude API credits | Near-zero for most tasks |
| Speed | Consistent | Depends on free-tier rate limits |
| Best for | Deadline-sensitive work, complex tasks | Long-running autonomous work, cost reduction |

Use `ralph.sh` when you need reliability and speed. Use `aymm.sh` when you have time and want to reduce API spend.
