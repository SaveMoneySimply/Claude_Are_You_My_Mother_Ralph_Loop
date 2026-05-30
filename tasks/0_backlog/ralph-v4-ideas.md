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

**1. STOP file responsiveness** — Easy, real UX pain point
`touch STOP` didn't halt the loop quickly during the p2s1 incident — the STOP check only
runs at the top of the `while` loop. If the escalation ladder is running it can take minutes
to take effect.
Fix: add a STOP file check between each escalation level inside the escalation block.
Alternatively trap SIGTERM and write STOP on container kill. The `touch STOP` UX should
be instant.

**2. Single-attempt-then-switch on task failure** — Medium, reduces 429s
Currently retries the same provider up to 3× on task failure before switching. Now that
rollback is in place and error feedback is injected, retrying the same provider quickly
burns attempts and can trigger 429s. Reduce to 1 attempt per provider for code-writing
failures — log the result, pass it as context to the next provider, move on. Keep the
3× retry only for rate-limit recovery (already handled separately).

**3. Host-only step marker + fast-fail** — Medium, prevents wasted escalation
When a step requires a host command (`docker build`, etc.), the loop burns the full
escalation ladder before hitting BLOCKED — every model tries and fails.
Fix:
1. Steps marked `HOST:` get skipped by the loop and written to a "run on host" note
   file. Task pauses until human runs it.
2. Agent exits with code 3 on environmental constraint — loop skips escalation and
   goes straight to BLOCKED.
Observed: p2s1 step 4 (`docker build`) exhausted the full ladder inside the container.

**4. OpenRouter free model checker** — Low difficulty, maintenance utility
Utility that queries `https://openrouter.ai/api/v1/models`, filters `:free` models, and
compares against what's configured in `provider-config.sh`. Alerts when a configured model
changes or new free models appear worth adding as direct APIs. Add to `provider-status.sh
--check-models` or standalone `check-free-models.sh`. Run this before starting any large
AYMM session.

---

## Optional / deferred

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
