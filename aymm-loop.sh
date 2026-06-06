#!/usr/bin/env bash
# aymm-loop.sh — container orchestrator for the AYMM multi-provider loop.
# Runs inside the container. Iterates free providers before falling back to Claude.
set -uo pipefail

WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
# When engine is mounted separately in Docker (e.g. /engine), fall back to /workspace
if [[ "$WORKDIR" == "/" ]] && [[ -d "/workspace" ]]; then
    WORKDIR="/workspace"
fi
cd "$WORKDIR"
mkdir -p .ralph tasks/2_active tasks/3_done
# Engine scripts may be in a separate directory (Docker with engine mounted at /engine)
if [[ -d "/engine" ]]; then
    ENGINEDIR="/engine"
elif [[ -d "${WORKDIR}/ralph-aymm" ]]; then
    ENGINEDIR="${WORKDIR}/ralph-aymm"
else
    ENGINEDIR="$WORKDIR"
fi
rm -f "${WORKDIR}/STOP"
echo "aymm-loop.sh started, STOP cleared"

# ---------------------------------------------------------------------------
# Load provider configuration
# ---------------------------------------------------------------------------

# shellcheck source=provider-config.sh
source "${ENGINEDIR}/provider-config.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

read_autonomy() {
    local val
    val=$(grep -i 'autonomy:' ARCHITECTURE.md 2>/dev/null \
        | grep -oiP 'autonomy:\s*\K\w+' | head -1 | tr '[:upper:]' '[:lower:]')
    echo "${val:-low}"
}

read_run_mode() {
    local task_file="$1" val
    val=$(grep -oiP '\bRun:(?:\*\*\s*|\s+)\K\w+' "$task_file" 2>/dev/null \
        | head -1 | tr '[:upper:]' '[:lower:]')
    echo "${val:-any}"
}

# Read the per-step `-- mode:` annotation from the first unchecked step of a task file.
# Returns 'claude', 'aymm', or 'any' (default when absent). This lets a single task mix
# free-provider steps (new files) with Claude-only steps (edits to existing TypeScript),
# avoiding the file-corruption failure mode documented in ralph-engine-feedback.md.
read_step_mode() {
    local task_file="$1" step val
    step=$(grep -m1 -- '^- \[ \]' "$task_file" 2>/dev/null)
    val=$(printf '%s' "$step" | grep -oiP -- '-- mode:\s*\K[a-z]+' | head -1 | tr '[:upper:]' '[:lower:]')
    echo "${val:-any}"
}

# Read the Effort: header from a task file. Returns lowercase word (low/medium/high/etc.)
read_task_effort() {
    local task_file="$1"
    grep -oiP '\bEffort:\s*\**\s*\K\w+' "$task_file" 2>/dev/null \
        | head -1 | tr '[:upper:]' '[:lower:]'
}

# Return space-separated provider list for a given effort level.
# Drives which models are attempted and in what order for this task.
#   low/minimal  — 8b first (abundant), light escalation; skip 120b
#   medium       — 8b free shot, then coder/reasoner, then quality reserves
#   high/max     — skip 8b entirely; start at best coder, escalate fast to quality
#   default      — same as medium
build_provider_order() {
    local effort="$1"
    case "$effort" in
        low|minimal|lowest)
            echo "groq_8b groq_qwen3 groq_20b groq_70b" ;;
        medium)
            echo "groq_8b groq_qwen3 groq_70b groq_120b" ;;
        high|xhigh|max|maximum|highest)
            echo "groq_qwen3 groq_70b groq_120b" ;;
        *)
            echo "groq_8b groq_qwen3 groq_70b groq_120b" ;;
    esac
}

# Returns the current provider name given PROVIDER_INDEX and PROVIDERS array
current_provider() {
    echo "${PROVIDERS[$PROVIDER_INDEX]:-}"
}

# Advance to the next provider; write STOP or .ralph/aymm-escalate.txt if all exhausted.
# reason: "rate_limit" (429/403) or "failure" (task error)
advance_provider() {
    local task="$1"
    local reason="${2:-failure}"
    PROVIDER_INDEX=$(( PROVIDER_INDEX + 1 ))
    if [[ "$reason" == "rate_limit" ]]; then
        RATE_LIMIT_ADVANCES=$(( RATE_LIMIT_ADVANCES + 1 ))
    fi
    if (( PROVIDER_INDEX >= ${#PROVIDERS[@]} )); then
        if (( RATE_LIMIT_ADVANCES >= ${#PROVIDERS[@]} )); then
            RATE_LIMIT_SLEEP_COUNT=$(( RATE_LIMIT_SLEEP_COUNT + 1 ))
            if (( RATE_LIMIT_SLEEP_COUNT >= 3 )); then
                local stop_msg
                stop_msg="All free providers rate-limited after ${RATE_LIMIT_SLEEP_COUNT} retries. Run \`bash ralph.sh\` to continue with Claude now."
                echo "$stop_msg" > STOP
                notify "AYMM: all providers rate-limited" "$stop_msg"
            else
                local sleep_msg="All free providers rate-limited — retrying in 1hr (attempt ${RATE_LIMIT_SLEEP_COUNT}/3)"
                echo "All providers rate-limited — sleeping 1hr then retrying" | tee -a ".ralph/loop.log"
                notify "AYMM: all providers rate-limited" "$sleep_msg"
                sleep 3600
                PROVIDER_INDEX=0
                RATE_LIMIT_ADVANCES=0
            fi
        else
            echo "All free providers exhausted for task ${task} — escalating to Claude"
            touch ".ralph/aymm-escalate.txt"
        fi
    else
        echo "Switched to provider: ${PROVIDERS[$PROVIDER_INDEX]}"
    fi
}

# Initialize per-task failure counters file
init_failure_counters() {
    if [[ ! -f ".ralph/aymm-failure-counters.json" ]]; then
        echo '{}' > ".ralph/aymm-failure-counters.json"
    fi
}

# Get consecutive failure count for a given provider on the current task
get_failure_count() {
    local provider="$1"
    local task="$2"
    local key="${task}__${provider}"
    jq -r --arg k "$key" '.[$k] // 0' ".ralph/aymm-failure-counters.json"
}

# Increment consecutive failure count for provider+task
increment_failure_count() {
    local provider="$1"
    local task="$2"
    local key="${task}__${provider}"
    local current
    current="$(get_failure_count "$provider" "$task")"
    local updated=$(( current + 1 ))
    local tmp
    tmp="$(mktemp /tmp/aymm-counters-XXXXXX.json)"
    jq --arg k "$key" --argjson v "$updated" '.[$k] = $v' \
        ".ralph/aymm-failure-counters.json" > "$tmp"
    mv "$tmp" ".ralph/aymm-failure-counters.json"
}

# Reset consecutive failure count for provider+task
reset_failure_count() {
    local provider="$1"
    local task="$2"
    local key="${task}__${provider}"
    local tmp
    tmp="$(mktemp /tmp/aymm-counters-XXXXXX.json)"
    jq --arg k "$key" 'del(.[$k])' \
        ".ralph/aymm-failure-counters.json" > "$tmp"
    mv "$tmp" ".ralph/aymm-failure-counters.json"
}

# Reset failure counts for all providers for a given task (called when task is first picked)
reset_all_failure_counts() {
    local task="$1"
    local tmp
    tmp="$(mktemp /tmp/aymm-counters-XXXXXX.json)"
    jq --arg t "$task" 'with_entries(select(.key | startswith($t + "__") | not))' \
        ".ralph/aymm-failure-counters.json" > "$tmp"
    mv "$tmp" ".ralph/aymm-failure-counters.json"
}

# Write provider state JSON
write_provider_state() {
    local provider="$1"
    local task="$2"
    local fail_count
    fail_count="$(get_failure_count "$provider" "$task")"

    # Build tasks_attempted_per_provider JSON object
    local attempted_json="{"
    local first=true
    for p in "${PROVIDERS[@]}"; do
        [[ "$first" == "true" ]] && first=false || attempted_json="${attempted_json},"
        attempted_json="${attempted_json}\"${p}\": ${TASKS_ATTEMPTED[$p]:-0}"
    done
    attempted_json="${attempted_json}}"

    cat > ".ralph/aymm-provider-state.json" <<EOF
{
  "current_provider": "${provider}",
  "provider_index": ${PROVIDER_INDEX},
  "consecutive_failures": ${fail_count},
  "task": "${task}",
  "tasks_attempted_per_provider": ${attempted_json}
}
EOF
}

# Send ntfy notification if NTFY_TOPIC is set
notify() {
    local title="$1"
    local body="$2"
    if [[ -n "${NTFY_TOPIC:-}" ]]; then
        curl -fsS \
            -H "Title: ${title}" \
            -d "$body" \
            "https://ntfy.sh/${NTFY_TOPIC}" >/dev/null || true
    fi
}

# Mark the first unchecked step as done in the task file
mark_step_done() {
    local task="$1"
    local task_file="tasks/2_active/${task}.md"
    if [[ ! -f "$task_file" ]]; then
        echo "Warning: task file not found: $task_file" >&2
        return 1
    fi
    sed -i '0,/^- \[ \]/{s/^- \[ \]/- [x]/}' "$task_file"
    echo "Marked step done in ${task_file}"
}

# Returns 0 if unchecked steps remain, 1 if the task is complete
has_remaining_steps() {
    local task="$1"
    grep -q '^- \[ \]' "tasks/2_active/${task}.md" 2>/dev/null
}

# Stage and commit any pending changes
git_commit_step() {
    local task="$1"
    local provider="$2"
    git add -A
    if ! git diff --cached --quiet; then
        git commit -m "${task}: step via ${provider}"
    fi
}

# Build a prompt for Claude to review a completed phase
build_phase_review_prompt() {
    local phase="$1"
    printf 'You are reviewing completed work for %s of this project.\n\n' "$phase"
    printf '## Architecture\n\n'
    awk '/^## Directory/{exit} {print}' ARCHITECTURE.md 2>/dev/null
    printf '\n## Completed tasks in %s\n\n' "$phase"
    for f in "tasks/3_done/${phase}-"*.md; do
        [[ -f "$f" ]] || continue
        printf '### %s\n\n' "$(basename "$f")"
        cat "$f"
        printf '\n'
    done
    printf '## Recent test log (last 20 entries)\n\n'
    tail -20 .ralph/test-log.jsonl 2>/dev/null \
        | jq -r '"\(.ts) \(.provider) \(.outcome) — \(.task)"' || echo "(no log)"
    printf '\nWrite a concise phase review covering:\n'
    printf '1. What was built (bullet list)\n'
    printf '2. Test results summary\n'
    printf '3. Any issues or surprises noticed\n'
    printf '4. What the next phase builds on from this phase\n\n'
    printf 'Be specific. Free AI providers will read this as context for the next phase.\n'
}

# Run Claude to write the phase review, optionally pause for non-high autonomy
run_phase_review() {
    local phase="$1"
    echo "Running Claude phase review for ${phase}..."
    mkdir -p handoffs
    build_phase_review_prompt "$phase" | \
        claude --model sonnet -p --dangerously-skip-permissions \
        > "handoffs/${phase}-review.md"
    echo "Phase review written: handoffs/${phase}-review.md"

    if [[ "$(read_autonomy)" != "high" ]]; then
        echo "${phase} complete — review handoffs/${phase}-review.md, then delete STOP to continue" > STOP
    fi
}

# Move completed phase task files to _archive/phase<N>/
archive_phase() {
    local phase="$1"
    local date_suffix
    date_suffix="$(date '+%Y-%m-%d')"
    mkdir -p "_archive/${phase}"
    for f in "tasks/3_done/${phase}-"*.md; do
        [[ -f "$f" ]] || continue
        local base
        base="$(basename "$f")"
        local stripped="${base#${phase}-}"     # removes "phase1-"
        stripped="${stripped#[0-9][0-9]-}"     # removes "01-"
        local archived="_archive/${phase}/${stripped%.md}-${date_suffix}.md"
        mv "$f" "$archived"
        echo "Archived: $archived"
    done
}

# Move a finished task to done, update plan links and CHANGELOG
close_task() {
    local task="$1"
    local provider="$2"
    local task_file="tasks/2_active/${task}.md"
    local done_file="tasks/3_done/$(date +%Y-%m-%d)-${task}.md"

    # Merge task branch if it exists
    local branch_exists
    branch_exists="$(git branch --list "task/${task}")"
    if [[ -n "$branch_exists" ]]; then
        git checkout main 2>/dev/null || true
        git merge --ff-only "task/${task}" && git branch -D "task/${task}" || true
    fi

    mv "$task_file" "$done_file"

    echo "$(date '+%Y-%m-%d') | ${task} | Completed via ${provider} | [task](tasks/3_done/$(date +%Y-%m-%d)-${task}.md)" \
        >> CHANGELOG.md

    echo "Task ${task} closed."

    # Clean up iter scratch files and last-test-error for this run
    rm -f .ralph/iter-*.json .ralph/iter-*-stderr.log .ralph/iter-*-task.txt
    rm -f .ralph/last-test-error.txt

    # Prune closed task's entries from failure counters
    if [[ -f .ralph/aymm-failure-counters.json ]]; then
        local pruned
        pruned="$(jq --arg t "${task}__" 'with_entries(select(.key | startswith($t) | not))' \
            .ralph/aymm-failure-counters.json)"
        echo "$pruned" > .ralph/aymm-failure-counters.json
    fi

    # Phase completion check
    local phase="${task%%-*}"
    if [[ "$phase" =~ ^phase[0-9]+ ]]; then
        local remaining
        remaining="$(find tasks/1_queue tasks/2_active -name "${phase}-*.md" 2>/dev/null | wc -l)"
        if (( remaining == 0 )); then
            echo "Phase ${phase} complete"
            run_phase_review "$phase"
            archive_phase "$phase"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Main state
# ---------------------------------------------------------------------------

AUTONOMY="$(read_autonomy)"
PROVIDER_INDEX=0
RATE_LIMIT_ADVANCES=0
RATE_LIMIT_SLEEP_COUNT=0
PROVIDERS_TASK=""   # tracks which task PROVIDERS was last built for
declare -A TASKS_ATTEMPTED
declare -A COOLDOWN_COUNT

init_failure_counters

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

i=0

while [[ ! -f STOP ]]; do
    i=$(( i + 1 ))
    echo ""
    echo "── aymm iteration ${i}  $(date '+%Y-%m-%d %H:%M:%S') ──"

    # Pick task: resume from 2_active/ if occupied, else pull from 1_queue/
    active_task="$(ls tasks/2_active/*.md 2>/dev/null | sort | head -1 || true)"
    if [[ -n "$active_task" ]]; then
        CURRENT_TASK="$(basename "$active_task" .md)"
    else
        next_task="$(ls tasks/1_queue/*.md 2>/dev/null | sort | head -1 || true)"
        if [[ -n "$next_task" ]]; then
            CURRENT_TASK="$(basename "$next_task" .md)"
            if compgen -G "tasks/3_done/*-${CURRENT_TASK}.md" > /dev/null 2>&1; then
                echo "Warning: Task '${CURRENT_TASK}' already in 3_done/ - removing stale queue file and skipping."
                rm -f "$next_task"
                continue
            fi
            mv "$next_task" "tasks/2_active/${CURRENT_TASK}.md"
            echo "$CURRENT_TASK" > .ralph/last-task.txt
            reset_all_failure_counts "$CURRENT_TASK"
            PROVIDER_INDEX=0
            RATE_LIMIT_ADVANCES=0
            echo "Picked task from queue: ${CURRENT_TASK}"
        else
            if [[ "${AYMM_ONLY:-}" == "1" ]]; then
                echo "All tasks complete (aymm-only mode)" > STOP
                break
            fi
            echo "No tasks in queue — delegating to loop.sh"
            bash "${ENGINEDIR}/loop.sh"
            break
        fi
    fi

    # ── Effort-aware provider ordering (Phase 2) ────────────────────────────
    # Rebuild PROVIDERS when task changes. PROVIDER_INDEX is preserved across
    # iterations for the same task so mid-task escalation state survives.
    if [[ "$CURRENT_TASK" != "$PROVIDERS_TASK" ]]; then
        TASK_EFFORT="$(read_task_effort "tasks/2_active/${CURRENT_TASK}.md")"
        readarray -t PROVIDERS < <(build_provider_order "$TASK_EFFORT" | tr ' ' '\n')
        PROVIDERS_TASK="$CURRENT_TASK"
        echo "Provider order for '${CURRENT_TASK}' (effort=${TASK_EFFORT:-unset}): ${PROVIDERS[*]}"
    fi

    RUN_MODE="$(read_run_mode "tasks/2_active/${CURRENT_TASK}.md")"
    if [[ "$RUN_MODE" == "interactive" || "$RUN_MODE" == "ralph" ]]; then
        echo "Task ${CURRENT_TASK} is marked run:${RUN_MODE} — cannot run via ralph.sh aymm. Use Claude directly or bash ralph.sh." > STOP
        break
    fi

    CURRENT_PROVIDER="$(current_provider)"

    # Guard: provider index out of range → all free providers exhausted
    if [[ -z "$CURRENT_PROVIDER" ]]; then
        if (( RATE_LIMIT_ADVANCES >= ${#PROVIDERS[@]} )); then
            RATE_LIMIT_SLEEP_COUNT=$(( RATE_LIMIT_SLEEP_COUNT + 1 ))
            if (( RATE_LIMIT_SLEEP_COUNT >= 3 )); then
                STOP_MSG="All free providers rate-limited after ${RATE_LIMIT_SLEEP_COUNT} retries. Run \`bash ralph.sh\` to continue with Claude now."
                echo "$STOP_MSG" > STOP
                notify "AYMM: all providers rate-limited" "$STOP_MSG"
                break
            else
                SLEEP_MSG="All free providers rate-limited — retrying in 1hr (attempt ${RATE_LIMIT_SLEEP_COUNT}/3)"
                echo "All providers rate-limited — sleeping 1hr then retrying" | tee -a ".ralph/loop.log"
                notify "AYMM: all providers rate-limited" "$SLEEP_MSG"
                sleep 3600
                PROVIDER_INDEX=0
                RATE_LIMIT_ADVANCES=0
            fi
        else
            echo "All free providers exhausted for task ${CURRENT_TASK} — escalating to Claude"
            touch ".ralph/aymm-escalate.txt"
        fi
    fi

    write_provider_state "${CURRENT_PROVIDER:-exhausted}" "$CURRENT_TASK"

    # ── Claude escalation (Step 5) ──────────────────────────────────────────
    if [[ -f ".ralph/aymm-escalate.txt" ]]; then
        rm -f ".ralph/aymm-escalate.txt"
        if [[ "${AYMM_ONLY:-}" == "1" ]]; then
            echo "All free providers exhausted — stopping (aymm-only mode)" > STOP
            break
        fi
        echo "Escalating to Claude for task ${CURRENT_TASK} — will return to AYMM after"

        ESCALATION_CONTEXT_FILE=".ralph/escalation-context.md"
        # Generate escalation context for Claude based on failed attempts for the current task
        if [[ -f ".ralph/test-log.jsonl" ]]; then
            jq -r --arg task "$CURRENT_TASK" 'select(.task == $task and .outcome == "fail") | "[\(.ts)] \(.provider) — \(.output)"' .ralph/test-log.jsonl > "${ESCALATION_CONTEXT_FILE}"
            if [[ -s "${ESCALATION_CONTEXT_FILE}" ]]; then # Check if the file is not empty
                echo "Generated escalation context for Claude in ${ESCALATION_CONTEXT_FILE}"
            else
                rm -f "${ESCALATION_CONTEXT_FILE}" # Delete if empty
            fi
        fi

        SINGLE_TASK=1 bash "${ENGINEDIR}/loop.sh"

        # Clean up escalation context file after Claude returns
        rm -f "${ESCALATION_CONTEXT_FILE}"
        # loop.sh returned cleanly — reset provider state for next task
        PROVIDER_INDEX=0
        RATE_LIMIT_ADVANCES=0
        # If loop.sh completed the task (file gone or all steps done), do cleanup and move on
        task_active_file="tasks/2_active/${CURRENT_TASK}.md"
        if [[ ! -f "$task_active_file" ]] || ! grep -q '^- \[ \]' "$task_active_file" 2>/dev/null; then
            post_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
            if [[ "$post_branch" == "task/${CURRENT_TASK}" ]]; then
                git checkout main
                git merge --ff-only "task/${CURRENT_TASK}" && git branch -D "task/${CURRENT_TASK}" || true
            fi
            if [[ -f "$task_active_file" ]]; then
                close_task "$CURRENT_TASK" "claude-escalation"
            fi
            continue
        fi
    fi

    # ── Ensure task branch exists ────────────────────────────────────────────
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
    if [[ "$current_branch" != "task/${CURRENT_TASK}" ]]; then
        if ! git show-ref --quiet "refs/heads/task/${CURRENT_TASK}"; then
            git checkout -b "task/${CURRENT_TASK}"
        else
            git checkout "task/${CURRENT_TASK}"
        fi
    fi

    # ── Per-step mode: delegate `-- mode: claude` steps to Claude ─────────────
    # Some steps within an aymm task edit existing TypeScript (schema, routes, index)
    # which free providers reliably corrupt. Marking those steps `-- mode: claude`
    # routes just that step through loop.sh (Claude, one iteration) while the rest of
    # the task still runs on free providers. See ralph-engine-feedback.md ENH-001.
    STEP_MODE="$(read_step_mode "tasks/2_active/${CURRENT_TASK}.md")"
    if [[ "$STEP_MODE" == "claude" ]]; then
        if [[ "${AYMM_ONLY:-}" == "1" ]]; then
            echo "Step is mode:claude but AYMM_ONLY=1 — cannot delegate to Claude. Stopping." > STOP
            break
        fi
        echo "Step marked mode:claude — delegating one step to loop.sh (Claude)"
        SINGLE_STEP=1 SINGLE_TASK=1 bash "${ENGINEDIR}/loop.sh"
        # loop.sh marks the step done, commits, and closes the task if it was the last
        # step. If the task file is gone or has no unchecked steps, run close cleanup.
        if [[ ! -f "tasks/2_active/${CURRENT_TASK}.md" ]] || ! grep -q '^- \[ \]' "tasks/2_active/${CURRENT_TASK}.md" 2>/dev/null; then
            post_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
            if [[ "$post_branch" == "task/${CURRENT_TASK}" ]]; then
                git checkout main 2>/dev/null && git merge --ff-only "task/${CURRENT_TASK}" && git branch -D "task/${CURRENT_TASK}" || true
            fi
        fi
        PROVIDER_INDEX=0
        RATE_LIMIT_ADVANCES=0
        continue
    fi

    # ── BUG-020 fix: if no unchecked steps remain, close via loop.sh directly ──
    # Without this, run_agent_task.sh exits 1 ("no unchecked steps"), exhausts all
    # providers, and triggers a STOP via the escalation path. Delegating directly
    # to loop.sh (SINGLE_TASK=1, no SINGLE_STEP) runs the global test and closes
    # the task cleanly. This handles all-claude-mode tasks and the end of mixed tasks.
    if ! has_remaining_steps "$CURRENT_TASK"; then
        echo "No unchecked steps remain — delegating task close to loop.sh"
        SINGLE_TASK=1 bash "${ENGINEDIR}/loop.sh"
        PROVIDER_INDEX=0
        RATE_LIMIT_ADVANCES=0
        continue
    fi

    # ── Inner execution loop ─────────────────────────────────────────────────
    echo "Running provider: ${CURRENT_PROVIDER} | Task: ${CURRENT_TASK}"

    TASKS_ATTEMPTED["$CURRENT_PROVIDER"]=$(( ${TASKS_ATTEMPTED["$CURRENT_PROVIDER"]:-0} + 1 ))

    exit_code=0
    bash "${ENGINEDIR}/run_agent_task.sh" --provider="${CURRENT_PROVIDER}" || exit_code=$?

    # ── Handle exit code ─────────────────────────────────────────────────────
    case "$exit_code" in
        0)
            # Mark step done first so it's included in the commit
            mark_step_done "$CURRENT_TASK"
            git_commit_step "$CURRENT_TASK" "$CURRENT_PROVIDER"
            reset_failure_count "$CURRENT_PROVIDER" "$CURRENT_TASK"
            COOLDOWN_COUNT["$CURRENT_PROVIDER"]=0
            echo "Provider ${CURRENT_PROVIDER} succeeded on task ${CURRENT_TASK}"
            if ! has_remaining_steps "$CURRENT_TASK"; then
                close_task "$CURRENT_TASK" "$CURRENT_PROVIDER"
            fi
            ;;
        2)
            # Task failure: increment counter; switch provider after per-provider attempt limit
            increment_failure_count "$CURRENT_PROVIDER" "$CURRENT_TASK"
            fail_count="$(get_failure_count "$CURRENT_PROVIDER" "$CURRENT_TASK")"
            max_attempts="$(provider_max_attempts "$CURRENT_PROVIDER")"
            echo "Provider ${CURRENT_PROVIDER} failed (count: ${fail_count}/${max_attempts})"
            if (( fail_count >= max_attempts )); then
                echo "${fail_count} failures on ${CURRENT_PROVIDER} — switching provider"
                advance_provider "$CURRENT_TASK" "failure"
            fi
            ;;
        100)
            # Rate limited (429): immediately advance to next provider
            echo "Provider ${CURRENT_PROVIDER} rate-limited (429) — switching provider"
            advance_provider "$CURRENT_TASK" "rate_limit"
            ;;
        101)
            # Forbidden/exhausted (403): treat as rate-limit exhaustion
            echo "Provider ${CURRENT_PROVIDER} forbidden/exhausted (403) — switching provider"
            advance_provider "$CURRENT_TASK" "rate_limit"
            ;;
        *)
            # Unexpected exit: treat as task failure
            echo "Provider ${CURRENT_PROVIDER} returned exit ${exit_code} — treating as failure"
            increment_failure_count "$CURRENT_PROVIDER" "$CURRENT_TASK"
            fail_count="$(get_failure_count "$CURRENT_PROVIDER" "$CURRENT_TASK")"
            max_attempts="$(provider_max_attempts "$CURRENT_PROVIDER")"
            if (( fail_count >= max_attempts )); then
                echo "${fail_count} failures on ${CURRENT_PROVIDER} — switching provider"
                advance_provider "$CURRENT_TASK" "failure"
            fi
            ;;
    esac

    write_provider_state "${CURRENT_PROVIDER:-exhausted}" "$CURRENT_TASK"

    [[ -f STOP ]] || sleep 1
done

# ---------------------------------------------------------------------------
# Exit
# ---------------------------------------------------------------------------

REASON="$(cat STOP 2>/dev/null || echo "Loop stopped")"
echo ""
echo "STOPPED: ${REASON}"
echo "Exited after ${i} iterations."

notify "AYMM stopped" "${REASON} (${i} iterations)"
