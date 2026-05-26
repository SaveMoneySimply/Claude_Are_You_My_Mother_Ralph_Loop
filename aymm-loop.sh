#!/usr/bin/env bash
# aymm-loop.sh — container orchestrator for the AYMM multi-provider loop.
# Runs inside the container. Iterates free providers before falling back to Claude.
set -uo pipefail

WORKDIR=/workspace
cd "$WORKDIR"
mkdir -p .ralph tasks/active tasks/done

# ---------------------------------------------------------------------------
# Load provider configuration
# ---------------------------------------------------------------------------

# shellcheck source=provider-config.sh
source "${WORKDIR}/provider-config.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

read_autonomy() {
    grep -i 'autonomy:' ARCHITECTURE.md 2>/dev/null \
        | grep -oiP 'autonomy:\s*\K\w+' | head -1 | tr '[:upper:]' '[:lower:]' \
        || echo "low"
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
            local stop_msg
            stop_msg="All free providers exhausted. Run \`bash ralph.sh\` to continue with Claude now, or wait ~1hr and run \`bash aymm.sh\` again."
            echo "$stop_msg" > STOP
            notify "AYMM: all providers rate-limited" "$stop_msg"
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
    local task_file="tasks/active/${task}.md"
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
    grep -q '^- \[ \]' "tasks/active/${task}.md" 2>/dev/null
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

# Move a finished task to done, update plan links and CHANGELOG
close_task() {
    local task="$1"
    local provider="$2"
    local task_file="tasks/active/${task}.md"
    local done_file="tasks/done/${task}.md"

    # Merge task branch if we're on it
    local current_branch
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
    if [[ "$current_branch" == "task/${task}" ]]; then
        git checkout main
        git merge --ff-only "task/${task}" && git branch -d "task/${task}" || true
    fi

    mv "$task_file" "$done_file"

    # Update active→done links in plan files
    find plans/ -name "*.md" -exec \
        sed -i "s|tasks/active/${task}\.md|tasks/done/${task}.md|g" {} \;

    # Tick the checkbox for this task in plan files
    find plans/ -name "*.md" -exec \
        sed -i "/\[task\](.*${task}.*)/s/^- \[ \]/- [x]/" {} \;

    echo "| $(date '+%Y-%m-%d') | ${task} | Completed via ${provider} | [task](tasks/done/${task}.md) |" \
        >> CHANGELOG.md

    echo "Task ${task} closed."
}

# ---------------------------------------------------------------------------
# Main state
# ---------------------------------------------------------------------------

AUTONOMY="$(read_autonomy)"
PROVIDER_INDEX=0
RATE_LIMIT_ADVANCES=0
declare -A TASKS_ATTEMPTED

init_failure_counters

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

i=0

while [[ ! -f STOP ]]; do
    i=$(( i + 1 ))
    echo ""
    echo "── aymm iteration ${i}  $(date '+%Y-%m-%d %H:%M:%S') ──"

    CURRENT_TASK="$(cat .ralph/last-task.txt 2>/dev/null || echo "unknown")"

    # Guard: no active task
    if [[ "$CURRENT_TASK" == "unknown" ]] || [[ ! -f "tasks/active/${CURRENT_TASK}.md" ]]; then
        echo "No active task found — delegating to loop.sh"
        exec bash "${WORKDIR}/loop.sh"
    fi

    CURRENT_PROVIDER="$(current_provider)"

    # Guard: provider index out of range → all free providers exhausted
    if [[ -z "$CURRENT_PROVIDER" ]]; then
        if (( RATE_LIMIT_ADVANCES >= ${#PROVIDERS[@]} )); then
            STOP_MSG="All free providers exhausted. Run \`bash ralph.sh\` to continue with Claude now, or wait ~1hr and run \`bash aymm.sh\` again."
            echo "$STOP_MSG" > STOP
            notify "AYMM: all providers rate-limited" "$STOP_MSG"
        else
            echo "All free providers exhausted for task ${CURRENT_TASK} — escalating to Claude"
            touch ".ralph/aymm-escalate.txt"
        fi
    fi

    write_provider_state "${CURRENT_PROVIDER:-exhausted}" "$CURRENT_TASK"

    # ── Claude escalation (Step 5) ──────────────────────────────────────────
    if [[ -f ".ralph/aymm-escalate.txt" ]]; then
        rm -f ".ralph/aymm-escalate.txt"
        echo "Escalating to Claude via loop.sh"
        exec bash "${WORKDIR}/loop.sh"
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

    # ── Inner execution loop ─────────────────────────────────────────────────
    echo "Running provider: ${CURRENT_PROVIDER} | Task: ${CURRENT_TASK}"

    TASKS_ATTEMPTED["$CURRENT_PROVIDER"]=$(( ${TASKS_ATTEMPTED["$CURRENT_PROVIDER"]:-0} + 1 ))

    exit_code=0
    bash "${WORKDIR}/run_agent_task.sh" --provider="${CURRENT_PROVIDER}" || exit_code=$?

    # ── Handle exit code ─────────────────────────────────────────────────────
    case "$exit_code" in
        0)
            # Pass: mark step done, commit, reset failure counter
            mark_step_done "$CURRENT_TASK"
            git_commit_step "$CURRENT_TASK" "$CURRENT_PROVIDER"
            reset_failure_count "$CURRENT_PROVIDER" "$CURRENT_TASK"
            echo "Provider ${CURRENT_PROVIDER} succeeded on task ${CURRENT_TASK}"
            if ! has_remaining_steps "$CURRENT_TASK"; then
                close_task "$CURRENT_TASK" "$CURRENT_PROVIDER"
            fi
            ;;
        2)
            # Task failure: increment counter; switch provider after 2 consecutive failures
            increment_failure_count "$CURRENT_PROVIDER" "$CURRENT_TASK"
            fail_count="$(get_failure_count "$CURRENT_PROVIDER" "$CURRENT_TASK")"
            echo "Provider ${CURRENT_PROVIDER} failed (count: ${fail_count})"
            if (( fail_count >= 2 )); then
                echo "2 consecutive failures on ${CURRENT_PROVIDER} — switching provider"
                advance_provider "$CURRENT_TASK" "failure"
            fi
            ;;
        3)
            # Forbidden/exhausted (403): treat as rate-limit exhaustion
            echo "Provider ${CURRENT_PROVIDER} forbidden/exhausted (403) — switching provider"
            advance_provider "$CURRENT_TASK" "rate_limit"
            ;;
        429)
            # Rate limited: advance to next provider immediately
            echo "Provider ${CURRENT_PROVIDER} rate-limited (429) — switching provider"
            advance_provider "$CURRENT_TASK" "rate_limit"
            ;;
        *)
            # Unexpected exit: treat as task failure
            echo "Provider ${CURRENT_PROVIDER} returned exit ${exit_code} — treating as failure"
            increment_failure_count "$CURRENT_PROVIDER" "$CURRENT_TASK"
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
