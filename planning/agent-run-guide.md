# Agent Run Guide — Starting and Monitoring the AYMM Loop

This document is for a Claude agent taking over a session in a Ralph project. It covers updating the engine, starting the loop, and monitoring it autonomously.

---

## Step 1 — Update the engine

Pull the latest engine files from the Ralph source repo:

```bash
bash ralph-aymm/ralph.sh update
```

This copies all engine scripts (`aymm-loop.sh`, `loop.sh`, `run_agent_task.sh`, `provider-config.sh`, etc.) from the source repo into `ralph-aymm/` and updates `CLAUDE.md` at the project root. It commits the changes automatically.

If `ralph-aymm/ralph.sh update` says `.ralph-source not found`, check `.ralph-source` at project root — it should contain the path to the Ralph source repo on this machine.

---

## Step 2 — Check what's in the queue

```bash
ls tasks/1_queue/
ls tasks/2_active/
```

- `tasks/1_queue/` — tasks waiting to run (the loop picks these up in order)
- `tasks/2_active/` — a task currently being worked (if one exists from a previous run)

Read any active task file to understand what step the loop is on:

```bash
cat tasks/2_active/*.md
```

Check for a stale STOP file from a previous run — delete it if present:

```bash
ls STOP 2>/dev/null && echo "STOP exists — delete it before starting"
rm -f STOP
```

---

## Step 3 — Start the loop

Run in the background so you can monitor it:

```bash
bash ralph-aymm/ralph.sh aymm 2>&1 | tee -a .ralph/loop.log &
```

Or if you want free providers only (no Claude fallback):

```bash
bash ralph-aymm/ralph.sh aymm --only 2>&1 | tee -a .ralph/loop.log &
```

The loop writes all output to `.ralph/loop.log` automatically (tee is already built into `ralph.sh`), so you don't need to redirect manually — just `bash ralph-aymm/ralph.sh aymm` is enough. The `&` is only needed if you want to keep the terminal free.

---

## Step 4 — Monitor autonomously

Use the Monitor tool to watch `.ralph/loop.log` for key events. This pattern covers the signals you'll actually act on:

```
tail -f .ralph/loop.log | grep -E --line-buffered \
  "Provider order|Context override|Running provider:|succeeded|failed|Switched to provider|STOP|rate.limit|[Ee]rror|Picked task|Marked step|closed|Building Docker|aymm-loop.sh started|── aymm iteration|All tasks complete|blocked"
```

**What each signal means:**

| Log line | What it means |
|---|---|
| `── aymm iteration N` | New iteration starting |
| `Picked task from queue: <name>` | Loop moved a task to 2_active/ |
| `Provider order for '<task>' (effort=X): ...` | Groq chain selected for this task |
| `Running provider: groq_8b \| Task: ...` | Free provider attempt starting |
| `Provider groq_8b succeeded` | Step passed — check task file for `[x]` |
| `Provider groq_8b failed (count: 1/2)` | Failed attempt — will retry or escalate |
| `Switched to provider: groq_qwen3` | Escalating to next model in chain |
| `All free providers exhausted — escalating to Claude` | Claude fallback starting |
| `Task <name> closed` | Task complete, moved to 3_done/ |
| `All tasks complete` | Queue empty — loop will write STOP |
| `STOP` | Loop has stopped — check STOP file contents |
| `rate limit` / `429` | Provider rate-limited — loop will sleep and retry |
| `blocked` | Task hit 3 failures — check BLOCKED.md |
| `Context override: N lines` | Step has large file injection — scout (30K TPM) inserted |
| `Step marked mode:fast` | Step overriding to lightest model |
| `Step marked mode:reason` | Step overriding to groq_70b/120b |
| `Step marked mode:claude` | Step delegating directly to Claude |

---

## Step 5 — While the loop runs

**Check progress on a task:**
```bash
cat tasks/2_active/*.md
```

**Check the last test error (when a step fails):**
```bash
cat .ralph/last-test-error.txt
```

**Inspect the last failed provider attempt:**
```bash
ls .ralph/last-failed-attempt/
cat .ralph/last-failed-attempt/test-error.txt
```

**Check pass/fail rates:**
```bash
bash ralph-aymm/ralph.sh stats
```

**Check recent log:**
```bash
tail -50 .ralph/loop.log
```

---

## Stopping the loop

```bash
touch STOP
```

The loop checks for STOP at the top of each iteration. A running Claude call (2-5 min) will finish before the loop actually stops — this is a known limitation. To stop immediately, kill the Docker container:

```bash
docker ps | grep ralph-aymm-agent
docker kill <container-id>
```

---

## What to do when the loop stops

**STOP file present — read it:**
```bash
cat STOP
```

Common causes:
- `All tasks complete` — queue is empty, normal exit
- Rate limit exhaustion — all providers hit daily limit; wait or run `bash ralph-aymm/ralph.sh` (Claude only)
- Task design issue — look at BLOCKED.md

**BLOCKED.md present:**
Read BLOCKED.md, inspect the failing task in `tasks/2_active/` or `tasks/3_done/`, fix the task file or the code, delete BLOCKED.md, then restart.

**All tasks complete:**
Check `tasks/3_done/` to confirm expected tasks landed there. Run the project's smoke tests. Update `CHANGELOG.md` if needed.

---

## Capturing a field report (for Ralph improvement)

After a run — or when something breaks interestingly — generate a field report to bring back to the Ralph source repo. This is how the engine gets improved: real failure data beats guessing.

### Generate the stats summary

```bash
bash ralph-aymm/ralph.sh stats
```

Paste the full JSON output into your field report. It shows per-provider pass rates and total attempts — the primary signal for routing decisions.

### Capture failures

For each task that failed or blocked, capture:

```bash
# The blocked task record
cat BLOCKED.md

# The last test error
cat .ralph/last-test-error.txt

# The broken output from the last failing provider
ls .ralph/last-failed-attempt/
cat .ralph/last-failed-attempt/test-error.txt
# + any .sh or .ts files in that folder
```

### Capture the HTTP error log

Rate limit hits, 403s, and unexpected API responses are logged here:

```bash
cat .ralph/http-error-log.jsonl
```

### Capture the full test log

Per-step pass/fail with provider and task context:

```bash
cat .ralph/test-log.jsonl
```

### Capture the loop log around a failure

Find the iteration where a task went wrong and grab the surrounding context:

```bash
grep -n "Task: <task-name>" .ralph/loop.log | tail -5
# Use the line numbers to extract the relevant section
sed -n '200,280p' .ralph/loop.log   # adjust range
```

### Write a field-report.md

Create a file `handoffs/field-report-YYYY-MM-DD.md` with this structure:

```markdown
# Field Report — YYYY-MM-DD

## Run summary
- Tasks completed: N
- Tasks blocked: N
- Total iterations: N
- Provider stats: [paste ralph.sh stats output]

## What worked well
- [e.g. groq_qwen3 handled all bash edits cleanly]

## What failed and why
For each blocked or repeatedly-failing task:
- **Task:** <name>
- **Step:** <step description>
- **Providers tried:** groq_8b (2x), groq_qwen3 (2x), ...
- **Error:** [paste last-test-error.txt]
- **Failed output:** [paste .ralph/last-failed-attempt/ file contents]
- **Hypothesis:** [what you think went wrong — truncation? wrong nesting? bad model for this type?]

## Patterns noticed
- [e.g. "8b consistently drops closing fi on multi-branch if statements"]
- [e.g. "qwen3 rewrites full files instead of targeted edits when the file is >200 lines"]
- [e.g. "120b always adds a comment block at the top of bash files"]

## Task design issues
- [e.g. "step had two assertions, one could pass while other failed — should have been split"]
- [e.g. "-- files: range was too narrow, model couldn't see the surrounding function"]

## Suggested engine changes
- [concrete ideas: new -- mode: annotation, routing tweak, prompt wording, etc.]
```

### What to bring back to the Ralph source repo

Open a new session in the Ralph source repo and paste (or attach) the field report. The most actionable items are:

1. **Provider stats JSON** — informs routing decisions (which models to move up/down the chain)
2. **Failed output + error pairs** — shows exactly what models produce wrong and why
3. **Patterns** — recurring failure modes that suggest prompt changes, step-splitting rules, or new `-- mode:` annotations
4. **Task design issues** — improvements to the task-writing guidance in CLAUDE.md

The Ralph source session can then make targeted engine changes and you run `ralph.sh update` in the project to pull them in.

---

## Key files at a glance

| File | Purpose |
|---|---|
| `tasks/1_queue/` | Tasks waiting to run |
| `tasks/2_active/` | Currently active task |
| `tasks/3_done/` | Completed tasks (date-prefixed) |
| `.ralph/loop.log` | Full loop output, appended across runs |
| `.ralph/last-test-error.txt` | Most recent step test failure output |
| `.ralph/last-failed-attempt/` | Broken files from last provider failure |
| `.ralph/aymm-failure-counters.json` | Per-provider failure counts (reset with `echo '{}' > .ralph/aymm-failure-counters.json`) |
| `STOP` | Loop exit sentinel — delete to allow restart |
| `BLOCKED.md` | Tasks the loop couldn't complete |
| `ARCHITECTURE.md` | Project facts, test command, Ralph settings |
| `CLAUDE.md` | Loop operating manual (read-only to the loop) |
