# Ralph v4 — Roadmap

---

## Next milestone — test on external project

Ralph has been built on itself long enough. The engine is stable, tested, and has real
pass-rate data. The next milestone is running AYMM on Matt's web project once the blueprint
and style guide are ready. That real-world run will generate meaningful stats to compare
against the current baseline (gemini 72%, groq 84%) and reveal failure modes we haven't seen.

Everything below is secondary to that milestone.

---

## Confirmed next (in this order after external project)

**1. Diagnose Mistral/OpenRouter + add more free providers** — High priority
Current stats: Mistral 0% (15 attempts, 0 passes), OpenRouter 0% (1 attempt, 0 passes).
We're effectively running on 2 providers, not 4. Before adding new providers, diagnose
why Mistral and OpenRouter fail completely — likely a model config issue or API format
mismatch, not a fundamental limitation. Then add 2-3 new direct APIs to get to 5-6
working providers. Candidates: DeepSeek (strong coder, free API), Cerebras (fast
inference), additional Groq models (Llama variants), and more OpenRouter `:free` models.
More working providers = more daily quota before Claude escalation = lower cost per task.
The OpenRouter free model checker (see optional below) would help surface candidates.

**2. STOP file responsiveness** — Easy, real UX pain point
`touch STOP` currently only takes effect at the top of the `while` loop — between Claude
calls, not during one. A single Claude call can run 2-5 minutes, so STOP can take that
long to register.
Fix: run Claude in the background and poll for STOP every 2 seconds, killing the process
if STOP appears:
```bash
claude ... > "$ITER_JSON" 2>"$ITER_ERR" &
CLAUDE_PID=$!
while kill -0 $CLAUDE_PID 2>/dev/null; do
    [ -f STOP ] && kill $CLAUDE_PID && break
    sleep 2
done
wait $CLAUDE_PID
```
Needs care to preserve exit codes and clean up correctly. Same change in both `loop.sh`
and `aymm-loop.sh`.

**3. Cap at 2 attempts per provider, not 3** — Replaces "single-attempt-then-switch"
Original idea was 1 attempt then rotate to reduce 429s. But with error feedback now
injected, a second attempt is genuinely valuable — the provider sees what it broke and
can self-correct. 3 attempts before switching is too many though: if it hasn't fixed it
in 2 tries with full error context, a fresh provider will do better. Cap at 2: first
attempt (blind), second attempt (with error feedback), then rotate.
Note: `loop.sh` already uses "Step 0 gets 2 attempts" — this applies the same logic to
AYMM's per-provider retry count.

**4. OpenRouter free model checker** — Low difficulty, maintenance utility
Utility that queries `https://openrouter.ai/api/v1/models`, filters `:free` models, and
compares against what's configured in `provider-config.sh`. Alerts when a configured model
changes or new free models appear worth adding. Add to `provider-status.sh --check-models`
or standalone `check-free-models.sh`. Run before any large AYMM session.

---

## Optional / deferred

**Host-only step marker + fast-fail** — mostly solved by existing `**Run:**` header
The `**Run:** interactive` header already prevents Ralph from picking up tasks that require
host commands. The HOST: step marker would let you mix container and host steps in one task
file (e.g. steps 1-3 inside, step 4 `docker build` on host) — but in practice it's easier
to just split those into two tasks. Only worth building if mixed-step tasks come up
repeatedly on the external project. Observed failure mode (p2s1 docker build) is avoided
simply by marking those tasks `**Run:** interactive`.

**Daily quota reset detection** — defer until we hit a real quota
When a provider hits daily limit (403), read `x-ratelimit-reset` / `Retry-After` header
and sleep exactly that duration instead of writing STOP. Not worth building until we have
real response examples from each provider — inspect `.ralph/http-error-log.jsonl` after
a real quota hit.

**Progress-sensitive rollback (Idea 3)** — defer, no data showing it's needed
Before applying provider changes, snapshot the pass count. On failure, if count went up,
skip rollback and let the next provider build on partial state. Tradeoff: partial state
accumulates. Stats show our problem is complete failures, not near-misses — revisit if
that changes.

**Surgical rollback (Idea 4)** — defer, too slow for current failure profile
Revert modified files one at a time and re-run the test. Keep changes for files whose
revert doesn't fix the failure. Runs the full test suite N extra times per failure.
Only useful when providers partially succeed — same data gap as Idea 3.

**AYMM-all mode (`bash ralph.sh aymm --all`)** — defer, design questions unresolved
Run the same task through every provider regardless of whether an earlier one passes.
Sub-modes: `--pick` (Claude picks best passing response) or `--show` (human picks from
diffs). Open design questions: sequential vs parallel? What does "best" mean? How to
display diffs? Revisit when there's a concrete use case.

**Plan-task linkage and auto-archiving** — defer, low priority
Plans and tasks are unconnected. True automation would need a `**Plan:**` header field
in each task, `close_task()` marking plan checklist items `[x]`, and auto-archiving plans
when all items complete. Complex. Only matters at scale — revisit when running multi-phase
projects.

**Plan mode — update or remove** — defer, low priority
`ralph.sh plan` / `prompt-plan.md` references old folder structure. Interactive planning
has proven better in practice. Leave it until there's a clear reason to keep or remove it.

---

## Task-writing practices (in CLAUDE.md — not engine changes)

These reduce free provider failure rates. All documented in CLAUDE.md already.

- **One independent assertion per step** — split when assertion A could pass while B fails
- **`bash -n <file> &&` prefix** on every step test that edits a bash script
- **Full test suite in `-- test:`** for bash function edits, not just `bash -n`
- **Full function in `-- files:`** — include lines past closing `}` / `fi`
- **Exact old→new text** for bash edits, not high-level descriptions
- **`-- test:` and `-- files:` stripped from agent prompt** ✅ implemented — agent sees
  only the spec; bash runs the test and feeds errors back via `last-test-error.txt`

---

## Done

**Timestamp done-task filenames** ✅ v3

**Rollback on test failure** ✅ `run_agent_task.sh` — excludes `tasks/` from rollback
scope; task file snapshot/restore prevents false-completion on rollback.

**Error feedback in retry prompt** ✅ 2026-05-30 — `last-test-error.txt` injected after
the step; `previous-attempts` trimmed to provider + error (no code blobs → avoids Groq 413).

**One assertion per step** ✅ 2026-05-30 — documented in CLAUDE.md.

**`|| echo` fallback defaults** ✅ 2026-05-30 — 7 dead fallbacks replaced with
`local val; ${val:-default}` in `loop.sh` and `aymm-loop.sh`.

**`.ralph/` folder maintenance** ✅ 2026-05-30 — `loop.log` rotates on startup; iter
files deleted on task close; failure counter entries pruned on task close.

**`ralph.sh stats`** ✅ 2026-05-30 — all-time + last-7-days pass rates per provider;
per-task attempt counts.

**Move task archival from agent to bash** ✅ 2026-05-30 — `loop.sh` detects all steps
`[x]` after pass and closes the task; `prompt.md` no longer instructs file moves.

**close_task() gap on Claude escalation** ✅ 2026-05-30 — branch merge/delete now guards
with `git branch --list` existence check; post-escalation block in `aymm-loop.sh` handles
all cases correctly.

**Pass AYMM failure history to Claude on escalation** ✅ 2026-05-30 — `aymm-loop.sh`
writes `.ralph/escalation-context.md` before calling `loop.sh`; both prompt builders
inject it when present.

**Strip `-- test:` and `-- files:` from agent prompt** ✅ 2026-05-30 — implemented in
`bundle_context()`, `build_step_prompt()`, `build_context_prompt()`.
