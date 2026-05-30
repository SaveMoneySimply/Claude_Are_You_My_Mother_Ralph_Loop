# Ralph v4 — Free Provider Improvement Ideas

Ideas for helping free AI providers (groq, gemini, mistral, openrouter) succeed more often
when tests partially pass. Ranked by impact vs effort.

---

## Idea 1 — Error feedback in retry prompt ⭐ highest priority

**Problem:** When a provider fails, the next attempt gets the same prompt with no knowledge of
what went wrong. Groq got 5/7 pick_task tests right but had no idea which 2 were wrong.

**What changes:** `bundle_context()` in `run_agent_task.sh`. The file `.ralph/last-test-error.txt`
is written on failure and deleted on success — its presence already signals "this is a retry".

```bash
# Near end of bundle_context(), after injecting the step
if [[ -f "${SCRIPT_DIR}/.ralph/last-test-error.txt" ]]; then
    printf '\n## Previous attempt failed\n\n'
    printf 'Tests that ran:\n```\n%s\n```\n' \
        "$(cat "${SCRIPT_DIR}/.ralph/last-test-error.txt")"
    printf '\nFix what failed. Do not remove passing tests.\n'
fi
```

**Tradeoff:** Longer prompts — a concern for free providers with tight context windows
(Groq 413 was already triggered). May need to truncate or summarise the error output if
it's large. Both `run_agent_task.sh` and `project/run_agent_task.sh` need the change.

---

## Idea 2 — One assertion per step

**Problem:** A step that adds 3 tests rolls back ALL 3 when any one fails. The provider can't
partially succeed.

**What changes:** Task authoring practice, not engine code. Each step writes and validates
exactly one test assertion.

```markdown
- [ ] pick_task test (a): moves file from 1_queue to 2_active when active/ is empty
      -- test: (cd project && bash test-engine.sh) | grep -q 'pick_task_a'
- [ ] pick_task test (b): returns existing active task untouched
      -- test: (cd project && bash test-engine.sh) | grep -q 'pick_task_b'
- [ ] pick_task test (c): skips and removes queue file when task already in 3_done/
      -- test: (cd project && bash test-engine.sh) | grep -q 'pick_task_c'
```

On failure only one assertion rolls back. The provider can't half-pass a step.

**Tradeoff:** 3× more steps = 3× more iterations. Worth it for complex multi-assertion steps,
overkill for trivial ones.

---

## Idea 3 — Progress-sensitive rollback

**Problem:** A provider that gets 5/7 tests right gets fully rolled back and the next provider
starts over. Progress is lost.

**What changes:** `run_test_command()` in `run_agent_task.sh`. Snapshot pass count before
applying changes. On failure, if the count went up, skip the rollback and let the next provider
build on the partial state.

```bash
# Before parse_and_apply_response
baseline_passes=$(cd project && bash test-engine.sh 2>&1 \
    | grep -oP '^\d+(?= passed)' || echo 0)

# Inside the rollback block — replace unconditional rollback
current_passes=$(grep -oP '^\d+(?= passed)' \
    "${SCRIPT_DIR}/.ralph/last-test-error.txt" || echo 0)
if [[ "$current_passes" -gt "$baseline_passes" ]]; then
    echo "Progress: $baseline_passes → $current_passes passes — keeping changes"
    exit 2   # still counts as failure for provider rotation
    # no rollback
fi
# else: full rollback as normal
```

**Tradeoff:** Partial state accumulates across providers. If provider A makes progress but
breaks something unrelated, provider B inherits a messy starting point. Pairs well with
Idea 1 — pass the error output to the next attempt so it knows the current state.

---

## Idea 4 — Surgical rollback

**Problem:** When multiple files are changed, the entire changeset gets reverted even if only
one file's changes caused the failure.

**What changes:** The rollback block in `run_agent_task.sh`. Instead of reverting all modified
files at once, try reverting them one at a time and re-running the test. Keep changes for any
file whose revert doesn't fix the failure.

```bash
# Replace the monolithic git checkout block
for f in $modified_files; do
    git -C "$SCRIPT_DIR" checkout HEAD -- "$f" 2>/dev/null
    if (cd project && bash test-engine.sh > /dev/null 2>&1); then
        echo "Reverted $f — tests pass without it"
        break
    else
        # Reverting this file didn't fix things — restore the change
        git -C "$SCRIPT_DIR" checkout ORIG_HEAD -- "$f" 2>/dev/null || true
    fi
done
```

**Tradeoff:** Runs the full test suite N extra times per failure (one per modified file) —
slow. File-level attribution can be wrong when changes interact. Most useful when providers
touch both a code file and the task file (common), and the task file change is fine but the
code file change is wrong.

---

## Ranking

| # | Idea | Effort | Impact | Try first? |
|---|------|--------|--------|------------|
| 1 | Error feedback in retry | Low | High | ✓ yes |
| 2 | One assertion per step | None (authoring) | Medium | ✓ yes (new tasks) |
| 3 | Progress-sensitive rollback | Medium | Medium | after 1 |
| 4 | Surgical rollback | High | Low-Medium | last |
