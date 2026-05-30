# Ralph v4 — Ideas Backlog

Items deferred from v3. Not scheduled — collect here until there's enough to warrant a planning session.

---

## Open

**AYMM-all mode (`bash ralph.sh aymm --all`)**
Run the same task through every provider regardless of whether an earlier one passes. Two sub-modes:
- `--all --pick` — run all providers, Claude picks the best passing response
- `--all --show` — run all providers, display diffs side by side, human picks

Open design questions: sequential vs parallel? What does "best" mean for --pick? How to display diffs for --show?

**OpenRouter free model checker**
Utility that queries `https://openrouter.ai/api/v1/models`, filters for `:free` models, and compares against models currently configured in `provider-config.sh`. Alerts when our configured model changed or new free models appear (candidates for adding as direct APIs). Could be a standalone `check-free-models.sh` or added to `provider-status.sh --check-models`.

**Daily quota reset detection**
When a provider hits its daily limit (403 / quota-exhausted body), read the reset timestamp from response headers (`x-ratelimit-reset`, `Retry-After`) and sleep exactly that duration rather than writing STOP. Only worth building once we have real response examples from each provider hitting their daily limit — inspect `.ralph/http-error-log.jsonl` after a real quota hit.

**Timestamp done-task filenames** ✅ done in v3

**Rollback on test failure** ✅ already implemented in `run_agent_task.sh` (lines 445–462 — `git checkout HEAD` on failure). Bug found and fixed 2026-05-29: rollback was also reverting the task mv (1_queue → 2_active), causing the failure counter to reset every iteration. Fixed by excluding `tasks/` from the rollback scope.

**Pass AYMM failure history to Claude on escalation**
When all free providers exhaust and `loop.sh` is called as Claude fallback, inject the `previous-attempts` context from `.ralph/test-log.jsonl` into the prompt so Claude knows what was tried and broken. Currently `run_agent_task.sh` passes this context between free providers, but the handoff to `loop.sh` drops it. Claude succeeded without it in the p1s1 run, but for harder tasks it would help Claude avoid repeating the same broken approaches.

**close_task() gap when Claude handles final steps via loop.sh escalation**
When aymm-loop.sh escalates to Claude (`SINGLE_TASK=1 bash loop.sh`), loop.sh's own close logic runs — it moves the task file to `3_done/` via `prompt.md` instructions. But aymm-loop.sh's `close_task()` never fires, so the task branch is not merged to main, not deleted, and the `2_active/` file is left as a stale copy. Observed after p1s1: had to manually `git merge --ff-only`, `git branch -d`, and `rm tasks/2_active/...`. Fix: after `SINGLE_TASK=1 bash loop.sh` returns, check if the task has been closed (file no longer in `2_active/`) and if so, run the branch merge/delete portion of `close_task()` manually.

**Single-attempt-then-switch on task failure (consider alongside rollback)**
Currently retries the same provider up to 3× on task failure before switching. Once rollback is in place, a failed attempt is clean (no broken baseline), but retrying the same provider quickly can trigger 429s. Consider reducing to 1 attempt per provider for code-writing failures — log the result, pass it as context to the next provider, move on. Keep the retry count for rate-limit recovery (which is already handled separately).

**Host-only step marker + fast-fail for environmental constraints**
When a loop step requires a host command (e.g. `docker build`, writing outside `/workspace`), the loop currently burns the full escalation ladder before hitting BLOCKED — every model tries and fails, all charged. Two fixes needed:
1. Task file format: a step marked `HOST:` (or similar) gets skipped by the loop and written to a "run on host" note file instead of attempted. The task pauses at that step until the human runs it and resumes.
2. Fast-fail exit code: if the agent detects an environmental constraint (no `docker` binary, no network to a required host, etc.), return exit code 3 — loop skips escalation and goes straight to BLOCKED. Observed failure mode: p2s1 step 4 (`docker build`) exhausted the full escalation ladder inside the container, burning significant usage on a hard impossibility.

**STOP file responsiveness**
`touch STOP` didn't halt the loop quickly during the p2s1 incident — the loop was mid-escalation and the STOP check only runs at the top of the `while` loop. Options: check for STOP between escalation levels, or trap SIGTERM and write STOP on container kill. The `touch STOP` UX should be instant — currently it can take minutes to take effect if the escalation ladder is running.

**Plan mode — update or remove**
`ralph.sh plan` / `prompt-plan.md` is not wired into the current folder structure — it references `plans/*.md` and `tasks/active/` which no longer exist. Interactive planning with Claude has proven better in practice (back-and-forth produces better task files, scope can be adjusted in real-time). Options: update `prompt-plan.md` to use the current `tasks/0_backlog/` structure and `tasks/1_queue/`, or remove plan mode entirely and document that planning is done interactively. Don't touch until there's a clear reason to keep it.

**Plan-task linkage and auto-archiving**
Plans and tasks are currently unconnected — `close_task()` infers a phase from the task name prefix but has no awareness of plan files. True automation needs:
1. `**Plan:** p2-plan.md` header field in each task pointing to its plan file
2. `close_task()` reads that field, opens the plan file, finds the matching checklist item, marks it `[x]`
3. When all items in the plan are `[x]`, move the plan file to `_archive/plans/`

Also needs a decision on folder structure: currently plans, tasks, and ideas are all mixed in `tasks/0_backlog/`. Clean separation would be `plans/` (phases with completion criteria), `tasks/` pipeline (unchanged), and `ideas/` (long-running files like `ralph-v4-ideas.md` that never complete). The ideas file is a different kind of thing from a plan — it accumulates rather than completes and shouldn't be in the task pipeline at all.

**Move task archival from agent to bash**
Currently the agent moves `tasks/2_active/<name>.md` to `tasks/3_done/YYYY-MM-DD-<name>.md` and appends to `CHANGELOG.md` as part of executing the final step — instructed by `prompt.md`. This is mechanical state management that belongs in the loop, not a judgment call that needs the agent. Moving it to bash (`loop.sh` / `aymm-loop.sh`) on a pass result would: make the agent's job simpler (fewer things to get wrong on the final step), make archival more reliable (not dependent on the agent following instructions precisely), and keep `prompt.md` focused on just executing the step. Would require loop.sh to detect when a task file has been closed by checking whether `2_active/<name>.md` still exists after a pass.

---

## Free provider success rate ideas (sketched 2026-05-30)

Four ideas for helping free providers succeed when tests partially pass, ranked by impact vs effort.

**Idea 1 — Error feedback in retry prompt** ⭐ highest priority

`bundle_context()` in `run_agent_task.sh` already reads `.ralph/last-step.txt`. Add a section that injects `.ralph/last-test-error.txt` when it exists (written on failure, deleted on success — its presence already signals "this is a retry").

```bash
# Near end of bundle_context(), after injecting the step
if [[ -f "${SCRIPT_DIR}/.ralph/last-test-error.txt" ]]; then
    printf '\n## Previous attempt failed\n\n'
    printf 'Tests that ran:\n```\n%s\n```\n' \
        "$(cat "${SCRIPT_DIR}/.ralph/last-test-error.txt")"
    printf '\nFix what failed. Do not remove passing tests.\n'
fi
```

Tradeoff: longer prompts — Groq 413 was already triggered. May need to truncate. Both `run_agent_task.sh` and `project/run_agent_task.sh` need the change.

**Idea 2 — One assertion per step**

Task authoring practice, not engine code. Each step writes and validates exactly one test assertion. On failure only one assertion rolls back. Worth it for complex multi-assertion steps, overkill for trivial ones.

**Idea 3 — Progress-sensitive rollback**

Before applying provider changes, snapshot the pass count. On failure, if count went up, skip the rollback and let the next provider build on partial state.

```bash
baseline_passes=$(cd project && bash test-engine.sh 2>&1 \
    | grep -oP '^\d+(?= passed)' || echo 0)

# Inside rollback block
current_passes=$(grep -oP '^\d+(?= passed)' \
    "${SCRIPT_DIR}/.ralph/last-test-error.txt" || echo 0)
if [[ "$current_passes" -gt "$baseline_passes" ]]; then
    echo "Progress: $baseline_passes → $current_passes passes — keeping changes"
    exit 2   # still counts as failure for provider rotation
fi
# else: full rollback as normal
```

Tradeoff: partial state accumulates. Pairs well with Idea 1.

**Idea 4 — Surgical rollback**

On failure, try reverting modified files one at a time and re-running the test. Keep changes for any file whose revert doesn't fix the failure. Runs the full test suite N extra times per failure — slow. Most useful when providers touch both code and task file.

---

## Matt's Thoughts

- I need to understand what ralph.sh plan mode does and try to use it for the next planing session
