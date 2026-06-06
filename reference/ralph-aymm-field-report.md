# Ralph AYMM Engine — Changes, Open Bugs & Direction

This file is designed to be copied to the ralph-aymm project root as `HANDOFF.md` for a new
agent picking up engine work. It documents every fix applied to the SC copy of the engine, the
bugs still open, and the planned new direction.

The **source of truth for the engine** lives at:
`/home/matt/Documents/Matt/Code/Claude_Are_You_My_Mother_Ralph_Loop/`

The **patched copy** (where all fixes were discovered and applied) lives at:
`/home/matt/Documents/Matt/Code/Simply_Curious/iamsimplycuriousdotcom/ralph-aymm/`

All diffs between original and patched are described below. The intention is to port these
fixes back into the canonical engine project.

---

## Context: how we got here

The ralph-aymm engine was copied into the Simply Curious project as a subdirectory
(`ralph-aymm/`) so it could run inside Docker with the project workspace at `/workspace` and
the engine files mounted at `/engine`. The original engine assumed it lived at the project
root. That mismatch caused a cascade of bugs — most discovered by running the engine live on
the 83-task Simply Curious build queue.

Full discovery log with root causes: `planning/ralph-engine-feedback.md` in the SC project.

---

## FIXES APPLIED (port these to the canonical engine)

### FIX-1 — ralph.sh: `local` keyword outside a function
**File:** `ralph.sh` — `aymm)` case block
```bash
# Before:
local aymm_args=""
# After:
aymm_args=""
```
`local` is bash-function-only. The `aymm)` case block is at top level.

---

### FIX-2 — ralph.sh: Unbound variable `$1` in aymm mode
**File:** `ralph.sh`
```bash
# Before:
if [[ "$1" == "--only" ]]; then
# After:
if [[ "${1:-}" == "--only" ]]; then
```
After `case` consumes `aymm`, `$1` is unbound and `set -u` crashes.

---

### FIX-3 — ralph.sh: Missing Docker capabilities for iptables
**File:** `ralph.sh` — `_docker_run_ralph` function
```bash
# Add after: docker run --rm \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
```

---

### FIX-4 — ralph.sh: Engine mount path doubles the directory
**File:** `ralph.sh` — `_docker_run_ralph` function
```bash
# Before:
-v "$SCRIPT_DIR/ralph-aymm:/engine:ro" \
# After:
-v "$SCRIPT_DIR:/engine:ro" \
```
When `ralph.sh` lives inside `ralph-aymm/`, `SCRIPT_DIR` already points to the engine
directory. Appending `/ralph-aymm` creates a non-existent nested path, leaving `/engine` empty.

**Note for the canonical engine:** This fix is only needed for the subdirectory layout. In the
canonical project where the engine IS the project root, the original mount path is fine. The
right fix for the canonical engine may be to support both layouts — detect whether you're
running from inside a `ralph-aymm/` subdirectory or from the project root.

---

### FIX-5 — ralph.sh: Mount host auth + git identity into container
**File:** `ralph.sh` — `_docker_run_ralph` function
```bash
# Add after the workspace mount:
-v "$HOME/.claude:/home/claude/.claude:ro" \
-v "$HOME/.gitconfig:/home/claude/.gitconfig:ro" \
```
Without these: Claude Code inside the container sees "Not logged in" (subscription auth) and
git can't commit ("unable to auto-detect email"). Both discovered during live runs.

---

### FIX-6 — ralph.sh: Remove `-it` flag
**File:** `ralph.sh`
```bash
# Before:
-it ralph-aymm-agent \
# After:
ralph-aymm-agent \
```
`-it` requires an interactive TTY. Fails immediately when called from background processes or
monitoring scripts. The container doesn't need interactive input.

---

### FIX-7 — ralph.sh: Cache Docker image check
**File:** `ralph.sh` — `_build_image` function
```bash
# Add at the top of the function:
if docker image inspect ralph-aymm-agent > /dev/null 2>&1; then
    return 0  # Image exists, skip build
fi
```
Avoids rebuilding on every run when the image already exists.

---

### FIX-8 — init-firewall.sh: Ignores CMD args, always runs loop.sh
**File:** `init-firewall.sh` — final exec block
```bash
# Before:
LOOP="${LOOP_SCRIPT:-loop.sh}"
exec su -s /bin/bash claude -c \
    "export PATH=... && bash /workspace/${LOOP:-loop.sh}"

# After:
if [[ $# -gt 0 ]]; then
    EXEC_CMD="$*"
else
    EXEC_CMD="bash /workspace/${LOOP_SCRIPT:-loop.sh}"
fi
exec su -s /bin/bash claude -c \
    "export PATH=... && ${EXEC_CMD}"
```
The Dockerfile uses `ENTRYPOINT ["/init-firewall.sh"]`. Docker passes the CMD (`bash
/engine/aymm-loop.sh`) as `$@`, but the script was ignoring it entirely and hardcoding
`loop.sh`. This meant aymm mode always ran the wrong script.

---

### FIX-9 — aymm-loop.sh + loop.sh: WORKDIR resolves to `/`
**Both files** — top of file
```bash
# Before (both):
WORKDIR=/workspace

# After (both):
WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$WORKDIR" == "/" ]] && [[ -d "/workspace" ]]; then
    WORKDIR="/workspace"
fi
```
When the engine is at `/engine`, `dirname /engine/aymm-loop.sh` = `/engine` and the parent
is `/`. Every file reference (`${WORKDIR}/provider-config.sh` etc) resolved to the filesystem
root and failed with "permission denied".

Also add `ENGINEDIR` detection after the WORKDIR block (in aymm-loop.sh):
```bash
if [[ -d "/engine" ]]; then
    ENGINEDIR="/engine"
elif [[ -d "${WORKDIR}/ralph-aymm" ]]; then
    ENGINEDIR="${WORKDIR}/ralph-aymm"
else
    ENGINEDIR="$WORKDIR"
fi
```
Then update all `${WORKDIR}/provider-config.sh`, `${WORKDIR}/loop.sh` references to use
`${ENGINEDIR}` instead.

---

### FIX-10 — run_agent_task.sh: Files written to engine directory instead of workspace
**File:** `run_agent_task.sh` — PROJECT_ROOT detection (lines 9-11) and apply_changes call
```bash
# Replace PROJECT_ROOT detection with:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "/workspace/tasks" ]]; then
    PROJECT_ROOT="/workspace"
elif [ -d "$(dirname "$SCRIPT_DIR")/tasks" ]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi

# Fix apply_changes.sh call:
# Before:
bash "${SCRIPT_DIR}/apply_changes.sh" "$tmp_text" "$SCRIPT_DIR" "$allowlist"
# After:
bash "${SCRIPT_DIR}/apply_changes.sh" "$tmp_text" "$PROJECT_ROOT" "$allowlist"
```
Also update all `${SCRIPT_DIR}/.ralph/`, `${SCRIPT_DIR}/tasks/`, `${SCRIPT_DIR}/ARCHITECTURE.md`
references to use `${PROJECT_ROOT}` instead. (The SC copy has ~20 such replacements.)

---

### FIX-11 — Dockerfile: Node.js 20 → 22
**File:** `Dockerfile`
```bash
# Before:
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
# After:
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
```
Astro 6 and other modern frameworks require Node.js 22+. With Node 20, every build test
fails with "Node.js v20 is not supported by Astro! Please upgrade to >=22". Looked like AI
failures but was pure infrastructure.

---

### FIX-12 — loop.sh: Escalation blocks aymm tasks even when Claude is the fallback
**File:** `loop.sh` — run-mode check
```bash
# Before:
if [ "$RUN_MODE" = "interactive" ] || [ "$RUN_MODE" = "aymm" ]; then

# After:
if [ "$RUN_MODE" = "interactive" ] || { [ "$RUN_MODE" = "aymm" ] && [ "${SINGLE_TASK:-0}" != "1" ]; }; then
```
When `loop.sh` is called via `SINGLE_TASK=1` (Claude escalation from `aymm-loop.sh`), blocking
`aymm` tasks defeats the entire escalation path. Only `interactive` tasks should always be
blocked; `aymm` tasks can run via Claude as a fallback.

---

### FIX-13 — loop.sh: SINGLE_STEP mode — return after one step
**File:** `loop.sh` — end of main `while` loop body
```bash
# Add at the end of each loop iteration, before the `done`:
if [ "${SINGLE_STEP:-0}" = "1" ]; then
    break
fi
```
Without this, `loop.sh` in SINGLE_TASK mode drains all remaining steps of the active task.
When AYMM delegates a single `-- mode: claude` step, `loop.sh` must execute exactly one
step and return control so AYMM can handle the next (possibly free-provider) step.

---

### FIX-14 — aymm-loop.sh: ENH-001 — per-step `-- mode: claude` delegation
**File:** `aymm-loop.sh` — before the inner provider execution loop

New helper function:
```bash
read_step_mode() {
    local task_file="$1" step val
    step=$(grep -m1 -- '^- \[ \]' "$task_file" 2>/dev/null)
    val=$(printf '%s' "$step" | grep -oiP -- '-- mode:\s*\K[a-z]+' | head -1 | tr '[:upper:]' '[:lower:]')
    echo "${val:-any}"
}
```

Delegation block (insert before provider execution loop):
```bash
STEP_MODE="$(read_step_mode "tasks/2_active/${CURRENT_TASK}.md")"
if [[ "$STEP_MODE" == "claude" ]]; then
    if [[ "${AYMM_ONLY:-}" == "1" ]]; then
        echo "Step is mode:claude but AYMM_ONLY=1 — stopping." > STOP
        break
    fi
    SINGLE_STEP=1 SINGLE_TASK=1 bash "${ENGINEDIR}/loop.sh"
    # If task is now complete (all steps done), run branch cleanup
    if [[ ! -f "tasks/2_active/${CURRENT_TASK}.md" ]] || ! grep -q '^- \[ \]' "tasks/2_active/${CURRENT_TASK}.md" 2>/dev/null; then
        post_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
        if [[ "$post_branch" == "task/${CURRENT_TASK}" ]]; then
            git checkout main && git merge --ff-only "task/${CURRENT_TASK}" && git branch -D "task/${CURRENT_TASK}" || true
        fi
    fi
    PROVIDER_INDEX=0; RATE_LIMIT_ADVANCES=0
    continue
fi
```

This lets a single task mix free-provider steps (new self-contained files) with Claude-only
steps (edits to existing TypeScript). Free providers reliably corrupt existing typed files —
this annotation routes just those steps to Claude while the cheaper steps go to AYMM.

**Usage in task files:**
```
- [ ] Step N: Create new utility file — test: ... -- files: ... -- mode: aymm  (default, can omit)
- [ ] Step N+1: Add import to existing schema.ts — test: ... -- files: ... -- mode: claude
```

---

### FIX-15 — aymm-loop.sh: BUG-020 — empty STOP when all steps are mode:claude
**File:** `aymm-loop.sh` — before provider execution loop, after mode:claude delegation

```bash
if ! has_remaining_steps "$CURRENT_TASK"; then
    echo "No unchecked steps remain — delegating task close to loop.sh"
    SINGLE_TASK=1 bash "${ENGINEDIR}/loop.sh"
    PROVIDER_INDEX=0; RATE_LIMIT_ADVANCES=0
    continue
fi
```

Without this: when all steps are `mode:claude` and the last one completes, `read_step_mode`
returns `any` (no unchecked steps found), the delegation block doesn't fire, and control falls
to `run_agent_task.sh` which exits 1 ("no unchecked steps"). All providers exhaust. The
escalation path triggers loop.sh, which closes the task but the container's exit path writes
an empty STOP — killing the loop prematurely.

---

### FIX-16 — aymm-loop.sh: git branch -d → -D
**File:** `aymm-loop.sh` — all branch delete call sites
```bash
# Before:
git branch -d "task/${CURRENT_TASK}"
# After:
git branch -D "task/${CURRENT_TASK}"
```
`-d` requires the branch to be merged into its remote tracking branch, which task branches
never have (they're local-only). `-D` forces deletion unconditionally. With `-d`, stale task
branches accumulate and confuse subsequent runs.

---

## OPEN BUGS (not yet fixed in either project)

### BUG-007 — aymm-loop stops entirely on interactive tasks instead of skipping
**File:** `aymm-loop.sh` — run-mode check for task pickup
**Symptom:** Loop picks up a completed `interactive` task, writes STOP, exits — leaving all
subsequent aymm tasks unstarted.
**Proposed fix:** When running in aymm mode and an interactive task is encountered, skip it
(move to 3_done with a note) and continue. Only STOP if there are NO remaining non-interactive
tasks.
**Workaround:** Manually move completed interactive tasks to `tasks/3_done/` before starting.

---

### BUG-022 — `local` keyword outside function in loop.sh escalation path
**File:** `loop.sh` around line 361
**Symptom:** 41 instances of `loop.sh: line 361: local: can only be used in a function`
during escalation ladder recovery functions. Doesn't block task completion (caught by `|| true`)
but means recovery variables have undefined scope.
**Status:** Needs investigation of escalation recovery functions around lines 361 and 417.

---

### SUGGESTION-006 — Failure counters survive infrastructure fixes
When a task fails due to an infrastructure bug (e.g. wrong Node version), failure counters
accumulate. After the fix, ralph escalates directly to Claude because counters are high — even
though free providers would now succeed.
**Proposed:** Reset counters when a task is moved back to `1_queue/`, or add `--reset-counters`
flag, or detect when the Docker image was rebuilt.
**Workaround:** Write `{}` to `.ralph/aymm-failure-counters.json` manually before restarting.

---

## NEW DIRECTION — Groq Multi-Model Routing (ENH-003)

Full plan: `planning/ralph-groq-routing-plan.md` in the SC project.

**The problem:** The engine currently uses one Groq model (`llama-3.3-70b-versatile`, 1,000 RPD)
for everything. Meanwhile Groq's free tier offers multiple models with separate RPD buckets:

| Model | RPD | Role |
|---|---|---|
| `llama-3.1-8b-instant` | 14,400 | Fast workhorse — mechanical steps |
| `meta-llama/llama-4-scout-17b-16e-instruct` | 14,400 | Balanced — good quality + high TPM |
| `qwen-qwq-32b` | 14,400 | Reasoning — best coding quality on free tier |
| `deepseek-r1-distill-llama-70b` | 14,400 | Reasoning specialist — math, logic, hard debugging |
| `kimi-k2-instruct` | 14,400 | Long context — 262K, for large file injection |
| `llama-3.3-70b-versatile` | 1,000 | Quality reserve — complex multi-file |
| `gpt-oss-120b` | 1,000 | Quality reserve — fallback when 70b fails |
| `compound-beta` | 250 | Director — tool use, code execution, web search |

**Implementation phases (in order):**

**Phase 1 — Expand provider-config.sh** (do first, ~1 hour)
Add all Groq model variants as separate named providers. No changes to loop logic needed —
the existing `advance_provider()` escalation handles rotation automatically. This alone
expands free capacity from ~1,000 to ~72,000+ requests/day.

**Phase 2 — Effort-aware ordering** (~30 min)
Add `build_provider_order()` to `aymm-loop.sh` that reorders providers based on the task's
declared effort level before the loop starts:
- `low` → start at `groq_8b`
- `medium` → start at `groq_qwen32b`
- `high` → start at `groq_70b`

**Phase 3 — Context-aware override** (~45 min)
Add token estimator that checks `-- files:` line ranges. If estimated tokens > 8000, prepend
`groq_kimi` to the front (only 14,400 RPD model with enough TPM headroom for large injections).

**Phase 4 — Director using Groq Compound** (~2 hours)
Post-step diff review using `compound-beta` (tool use + code execution). Fires only on
suspicion triggers (diff 2× larger than expected, files outside `-- files:` list, empty diff
with passing test). Not after every step — 250 RPD is scarce.

Full implementation code for all four phases is in `planning/ralph-groq-routing-plan.md`.

---

## IDEA-001 — Director Role: Post-Step Diff Review

**Proposed flow:**
```
aymm-loop → provider/Claude → apply_changes → test → Director reviews diff → pass/fail
```
Director sees: step spec + `git diff HEAD -- <files>` + test result.
Director catches: full-file rewrites masquerading as edits (BUG-023), tests gamed by comments,
correct grep with wrong implementation, scope creep (files outside `-- files:` list).

**Two trigger options:**
1. After every step (thorough, expensive — one extra Groq Compound call per step)
2. Suspicion-triggered: bash heuristics first (diff size, deletion count, out-of-scope files).
   Director only called when something looks suspicious. Much cheaper on the 250 RPD budget.

Option 2 is recommended. Shell script is the supervisor; Director is the quality gate.

Full `director.sh` implementation sketch is in `planning/ralph-groq-routing-plan.md` (Phase 4).

---

## KEY LESSONS FROM THE SC BUILD (83 tasks)

### On task-writing

- **grep tests verify presence, not correctness** — `grep -q 'functionName' lib.ts` passes even
  if the function is never called from anywhere. Add a second assertion checking the call site.
- **Sequential tasks on the same file need cumulative tests** — if p13-t03, t04, t05 all write
  to `calibration.ts`, t05's test must also assert t03's and t04's additions still exist.
- **Exact grep strings must appear verbatim in step description** — `-- test:` is stripped from
  the agent prompt. If the test does `grep -q 'exact phrase'`, that phrase must appear literally
  in the step description or providers will paraphrase and fail.
- **"Create" steps on existing files get rewritten from scratch** — use "Ensure X contains..."
  instead of "Create X with..." when the file may already exist.
- **Functional test strict, cosmetic test loose** — route wiring, schema fields, HTTP status
  → strict grep. UI copy, headings, inline notes → loose `grep -qi` or skip entirely.
- **All-claude-mode tasks should use `Run: ralph`** — routing every step through the AYMM loop
  adds 2 iterations per step with zero benefit when there are no free-provider-eligible steps.

### On providers

- **Mistral (codestral) returns prose instead of file blocks** on new files >100 lines.
  Consider removing from default rotation or marking as last-resort.
- **Gemini times out (`exit 28`) on large-context steps** — any step injecting >500 tokens of
  context files is unreliable on Gemini.
- **Free providers corrupt existing TypeScript** — `schema.ts`, `auth.ts`, `index.ts`, any
  Drizzle query. Always mark edits to these `-- mode: claude`.

### On infrastructure

- **Worker boot is the cheapest, highest-value gate** — add a `curl /api/health` smoke step
  after any task that touches the Worker entry point. Would have caught P0 bugs instantly.
- **Dependency installs can downgrade framework versions** — `npm install hono` can pull in an
  older Astro. Add post-install version check: `grep '"astro"' package.json`.
- **Node version in Dockerfile must track project requirements** — pin to current LTS minimum,
  not a specific old version.

---

## FILE MAP (SC patched engine)

| File | Key changes vs original |
|---|---|
| `ralph-aymm/ralph.sh` | FIX-1,2,3,4,5,6,7 — capabilities, mounts, path, `local` bug |
| `ralph-aymm/init-firewall.sh` | FIX-8 — passes CMD args instead of hardcoding loop.sh |
| `ralph-aymm/aymm-loop.sh` | FIX-9,14,15,16 — WORKDIR, mode:claude delegation, BUG-020, branch -D |
| `ralph-aymm/loop.sh` | FIX-9,12,13 — WORKDIR, escalation run-mode fix, SINGLE_STEP break |
| `ralph-aymm/run_agent_task.sh` | FIX-10 — PROJECT_ROOT detection, apply_changes workspace arg |
| `ralph-aymm/Dockerfile` | FIX-11 — Node 20 → 22 |
| `ralph-aymm/provider-config.sh` | No changes yet — Groq multi-model routing is Phase 1 of ENH-003 |

---

## COMMANDS TO START

```bash
# Run with AYMM free providers + Claude fallback
bash ralph-aymm/ralph.sh aymm

# Run Claude-only mode (for all-claude-mode task queues)
bash ralph-aymm/ralph.sh

# Run AYMM only — no Claude fallback (burn-free-credits mode)
bash ralph-aymm/ralph.sh aymm --only

# Check provider pass/fail stats
bash ralph-aymm/ralph.sh stats

# Stop the loop
touch STOP

# Reset failure counters before re-running a previously-failing queue
echo '{}' > .ralph/aymm-failure-counters.json

# Watch live output
tail -f .ralph/loop.log
```
