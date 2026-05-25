#!/usr/bin/env bash
# Runs inside the container as the claude user.
# Iterates: pick next step → run claude → check result → escalate on failure → repeat.
set -uo pipefail

WORKDIR=/workspace
cd "$WORKDIR"
mkdir -p .ralph tasks/active tasks/done

# Step number used to force a split on the next iteration
FORCE_SPLIT_STEP=50

# ─── helpers ────────────────────────────────────────────────────────────────

read_autonomy() {
    grep -i 'autonomy:' ARCHITECTURE.md 2>/dev/null \
        | grep -oiP 'autonomy:\s*\K\w+' | head -1 | tr '[:upper:]' '[:lower:]' \
        || echo "low"
}

# Given (declared_model, declared_effort, step_number) prints "model:effort"
# or one of the special keywords: context_expansion, split, blocked
get_step_spec() {
    local decl_model="$1" decl_effort="$2" step="$3"

    # Force-split override
    if [ "$step" -ge "$FORCE_SPLIT_STEP" ]; then
        echo "split"; return
    fi

    # Step 0 = declared settings
    if [ "$step" -eq 0 ]; then
        echo "${decl_model}:${decl_effort}"; return
    fi

    # Build the escalation sequence for steps 1+
    local seq=()

    # Step 1: same model + max (skip if haiku or already at max)
    if [ "$decl_model" != "haiku" ] && [ "$decl_effort" != "max" ]; then
        seq+=("${decl_model}:max")
    fi

    # Next models above declared, each at low then max
    local above=()
    case "$decl_model" in
        haiku)  above=(sonnet opus) ;;
        sonnet) above=(opus) ;;
        opus)   above=() ;;
        *)      above=(sonnet opus) ;;
    esac

    for m in "${above[@]}"; do
        seq+=("${m}:low" "${m}:max")
    done

    seq+=(context_expansion split blocked)

    local idx=$((step - 1))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#seq[@]}" ]; then
        echo "${seq[$idx]}"
    else
        echo "blocked"
    fi
}

# Load recovery state for a task into RECOVERY_* vars
load_recovery() {
    local task="$1"
    local file=".ralph/${task}-recovery.json"
    if [ -f "$file" ]; then
        RECOVERY_STEP=$(jq -r '.step // 0' "$file")
        RECOVERY_ATTEMPTS=$(jq -r '.attempts_at_step // 0' "$file")
        RECOVERY_SPLIT_DEPTH=$(jq -r '.split_depth // 0' "$file")
        RECOVERY_PARENT=$(jq -r '.parent_task // ""' "$file")
        RECOVERY_DECL_MODEL=$(jq -r '.declared_model // "sonnet"' "$file")
        RECOVERY_DECL_EFFORT=$(jq -r '.declared_effort // "high"' "$file")
    else
        RECOVERY_STEP=0
        RECOVERY_ATTEMPTS=0
        # Read split_depth from task file header (sub-tasks carry this from their creation)
        RECOVERY_SPLIT_DEPTH=$(grep -oP 'Split depth:\s*\K\d+' \
            "tasks/active/${task}.md" 2>/dev/null | head -1 || echo 0)
        RECOVERY_PARENT=$(grep -oiP 'Parent task:\s*\K\S+' \
            "tasks/active/${task}.md" 2>/dev/null | head -1 || echo "")
        RECOVERY_DECL_MODEL=$(grep -oiP '\bModel:(?:\*\*\s*|\s+)\K\w+' \
            "tasks/active/${task}.md" 2>/dev/null | head -1 | tr '[:upper:]' '[:lower:]' || echo "sonnet")
        RECOVERY_DECL_EFFORT=$(grep -oiP '\bEffort:(?:\*\*\s*|\s+)\K\w+' \
            "tasks/active/${task}.md" 2>/dev/null | head -1 | tr '[:upper:]' '[:lower:]' || echo "high")
    fi
}

save_recovery() {
    local task="$1"
    local parent_json
    parent_json=$([ -n "${RECOVERY_PARENT:-}" ] && printf '"%s"' "$RECOVERY_PARENT" || echo "null")
    cat > ".ralph/${task}-recovery.json" <<EOF
{
  "task": "$task",
  "step": $RECOVERY_STEP,
  "attempts_at_step": $RECOVERY_ATTEMPTS,
  "split_depth": $RECOVERY_SPLIT_DEPTH,
  "parent_task": $parent_json,
  "declared_model": "$RECOVERY_DECL_MODEL",
  "declared_effort": "$RECOVERY_DECL_EFFORT"
}
EOF
}

log_recovery() {
    local task="$1" trigger="$2" step_label="$3" result="$4" tokens="$5"
    local ts
    ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    printf '{"ts":"%s","task":"%s","trigger":"%s","step":"%s","result":"%s","tokens":%s}\n' \
        "$ts" "$task" "$trigger" "$step_label" "$result" "$tokens" \
        >> .ralph/recovery-log.jsonl
}

# Build an extended prompt with surrounding task context, returns file path
build_context_prompt() {
    local task="$1"
    local out=".ralph/prompt-context-${task}.md"
    cp prompt.md "$out"

    {
        echo ""
        echo "## Surrounding context (recovery: context expansion)"
        echo ""
        echo "### Recently completed tasks"
    } >> "$out"

    local count=0
    while IFS= read -r -d '' f && [ "$count" -lt 2 ]; do
        { echo ""; echo "#### $(basename "$f" .md)"; head -20 "$f"; } >> "$out"
        count=$((count + 1))
    done < <(find tasks/done -name '*.md' -printf '%T@ %p\0' 2>/dev/null \
        | sort -zrn | cut -z -d' ' -f2-)

    {
        echo ""
        echo "### Upcoming tasks (next unchecked in plan)"
        grep -m 4 '\- \[ \]' PLAN.md 2>/dev/null || true
    } >> "$out"

    echo "$out"
}

mark_blocked() {
    local task="$1" reason="$2" tokens="$3"
    {
        echo ""
        echo "## $(date '+%Y-%m-%d') — ${task}"
        echo "$reason"
        echo ""
    } >> BLOCKED.md
    log_recovery "$task" "gate_fail" "blocked" "blocked" "$tokens"
}

# ─── main loop ──────────────────────────────────────────────────────────────

i=0

while [ ! -f STOP ]; do
    i=$((i + 1))
    echo ""
    echo "── iteration $i  $(date '+%Y-%m-%d %H:%M:%S') ──"

    ITER_JSON=".ralph/iter-${i}.json"
    ITER_TASK=".ralph/iter-${i}-task.txt"
    ITER_ERR=".ralph/iter-${i}-stderr.log"

    AUTONOMY=$(read_autonomy)
    CURRENT_TASK=$(cat .ralph/last-task.txt 2>/dev/null || echo "unknown")

    # ─── determine model/effort from escalation state ───────────────────

    load_recovery "$CURRENT_TASK"

    STEP_SPEC=$(get_step_spec \
        "$RECOVERY_DECL_MODEL" "$RECOVERY_DECL_EFFORT" "$RECOVERY_STEP")

    PROMPT_FILE=prompt.md

    if [ "$STEP_SPEC" = "context_expansion" ]; then
        echo "Recovery: context expansion — injecting surrounding task context"
        PROMPT_FILE=$(build_context_prompt "$CURRENT_TASK")
        MODEL=opus; EFFORT=max

    elif [ "$STEP_SPEC" = "split" ]; then
        if [ "$AUTONOMY" = "high" ] && [ "${RECOVERY_SPLIT_DEPTH:-0}" -lt 2 ]; then
            echo "Recovery: task split (depth $RECOVERY_SPLIT_DEPTH → $((RECOVERY_SPLIT_DEPTH + 1)))"
            PROMPT_FILE=prompt-split.md
            MODEL=opus; EFFORT=max
        else
            mark_blocked "$CURRENT_TASK" \
                "Escalation exhausted. autonomy=$AUTONOMY split_depth=${RECOVERY_SPLIT_DEPTH:-0}" \
                0
            STOP_REASON="Blocked: ${CURRENT_TASK} — escalation exhausted"
            [ "$AUTONOMY" = "high" ] && echo "$STOP_REASON" > STOP || echo "$STOP_REASON" > STOP
            break
        fi

    elif [ "$STEP_SPEC" = "blocked" ]; then
        mark_blocked "$CURRENT_TASK" "Full escalation ladder exhausted." 0
        echo "Blocked: ${CURRENT_TASK} — all escalation levels failed" > STOP
        break

    else
        IFS=':' read -r MODEL EFFORT <<< "$STEP_SPEC"
        MODEL="${MODEL:-sonnet}"
        EFFORT="${EFFORT:-high}"
    fi

    # ─── build and run claude invocation ────────────────────────────────

    CLAUDE_ARGS="--model $MODEL"
    [ "$MODEL" != "haiku" ] && [ -n "$EFFORT" ] && CLAUDE_ARGS="$CLAUDE_ARGS --effort $EFFORT"
    CLAUDE_ARGS="$CLAUDE_ARGS -p --output-format json --dangerously-skip-permissions"

    echo "Model: $MODEL | Effort: ${EFFORT:-(none)} | Step: $RECOVERY_STEP | Task: $CURRENT_TASK"

    # shellcheck disable=SC2086
    if ! cat "$PROMPT_FILE" \
            | claude $CLAUDE_ARGS \
            > "$ITER_JSON" 2>"$ITER_ERR"; then
        echo "WARNING: claude exited non-zero on iteration $i — see $ITER_ERR"
        cat "$ITER_ERR" || true
        sleep 5
        continue
    fi

    jq -r '.result // empty' "$ITER_JSON" 2>/dev/null || true

    # ─── update task tracking ────────────────────────────────────────────

    cp ".ralph/last-task.txt" "$ITER_TASK" 2>/dev/null \
        || echo "$CURRENT_TASK" > "$ITER_TASK"
    CURRENT_TASK=$(cat "$ITER_TASK")

    ITER_TOKENS=$(jq -r '.usage.output_tokens // 0' "$ITER_JSON" 2>/dev/null || echo 0)

    # ─── read result written by agent ────────────────────────────────────
    # Agent writes "pass" or "fail" to .ralph/last-result.txt each iteration

    RESULT=$(cat .ralph/last-result.txt 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")
    rm -f .ralph/last-result.txt  # consume it

    # ─── handle pass/fail ────────────────────────────────────────────────

    STEP_LABEL="${MODEL}+${EFFORT:-none}"

    if [ "$STEP_SPEC" = "split" ] && [ "$RESULT" = "pass" ]; then
        # Split succeeded — sub-tasks are in tasks/active/; clear original recovery state
        log_recovery "$CURRENT_TASK" "split" "split" "pass" "$ITER_TOKENS"
        rm -f ".ralph/${CURRENT_TASK}-recovery.json"

    elif [ "$RESULT" = "pass" ]; then
        log_recovery "$CURRENT_TASK" "gate_pass" "$STEP_LABEL" "pass" "$ITER_TOKENS"
        rm -f ".ralph/${CURRENT_TASK}-recovery.json"
        rm -f ".ralph/prompt-context-${CURRENT_TASK}.md"

    elif [ "$RESULT" = "fail" ]; then
        RECOVERY_ATTEMPTS=$((RECOVERY_ATTEMPTS + 1))
        # Step 0 gets 2 attempts; all other steps get 1
        MAX_AT_STEP=$([ "$RECOVERY_STEP" -eq 0 ] && echo 2 || echo 1)

        log_recovery "$CURRENT_TASK" "gate_fail" "$STEP_LABEL" "fail" "$ITER_TOKENS"

        if [ "$RECOVERY_ATTEMPTS" -ge "$MAX_AT_STEP" ]; then
            RECOVERY_STEP=$((RECOVERY_STEP + 1))
            RECOVERY_ATTEMPTS=0
            echo "Escalating → step $RECOVERY_STEP"
        fi
        save_recovery "$CURRENT_TASK"
    fi
    # any other result (e.g. file missing) = treat as no-op; no escalation

    # ─── budget check ────────────────────────────────────────────────────

    TASK_MD="tasks/active/${CURRENT_TASK}.md"
    ESTIMATE=0
    if [ -f "$TASK_MD" ]; then
        ESTIMATE=$(grep 'Tokens estimated' "$TASK_MD" | grep -oP '\d+' | head -1 || echo 0)
    fi

    TOTAL_TOKENS=0
    for tfile in .ralph/iter-*-task.txt; do
        [ -f "$tfile" ] || continue
        if [ "$(cat "$tfile")" = "$CURRENT_TASK" ]; then
            N=$(echo "$tfile" | grep -oP '(?<=iter-)\d+(?=-task)')
            T=$(jq -r '.usage.output_tokens // 0' ".ralph/iter-${N}.json" 2>/dev/null || echo 0)
            TOTAL_TOKENS=$((TOTAL_TOKENS + T))
        fi
    done

    echo "Tokens this task: ${TOTAL_TOKENS} / estimate: ${ESTIMATE} (2× = $((ESTIMATE * 2)))"

    if [ "${ESTIMATE:-0}" -gt 0 ] && [ "$TOTAL_TOKENS" -gt $((ESTIMATE * 2)) ]; then
        load_recovery "$CURRENT_TASK"
        if [ "$AUTONOMY" = "high" ] && [ "${RECOVERY_SPLIT_DEPTH:-0}" -lt 2 ]; then
            echo "Budget exceeded — scheduling split (autonomy: high)"
            RECOVERY_STEP=$FORCE_SPLIT_STEP
            save_recovery "$CURRENT_TASK"
            log_recovery "$CURRENT_TASK" "budget_exceeded" "split_scheduled" "split" "$TOTAL_TOKENS"
        else
            echo "Budget exceeded — stopping (autonomy: $AUTONOMY)" > STOP
            log_recovery "$CURRENT_TASK" "budget_exceeded" "stop" "blocked" "$TOTAL_TOKENS"
        fi
    fi

    [ -f STOP ] || sleep 2
done

# ─── exit ────────────────────────────────────────────────────────────────────

REASON=$(cat STOP 2>/dev/null || echo "Loop stopped")
echo ""
echo "STOPPED: $REASON"
echo "Exited after $i iterations."

if [ -n "${NTFY_TOPIC:-}" ]; then
    curl -fsS \
        -H "Title: Ralph stopped" \
        -d "$REASON ($i iterations)" \
        "https://ntfy.sh/${NTFY_TOPIC}" >/dev/null || true
fi
