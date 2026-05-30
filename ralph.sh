#!/usr/bin/env bash
# Host-side wrapper. Run from project root:
#   bash ralph.sh          — execution mode (default): works through tasks
#   bash ralph.sh plan     — breakdown mode: generates task files from plans
#   bash ralph.sh aymm     — multi-provider mode: tries free providers before Claude
#   bash ralph.sh aymm --only — aymm mode without Claude fallback
#   bash ralph.sh stats    — show free provider pass/fail rates from test-log.jsonl
# Requires: docker, and either 'claude login' (subscription) or ANTHROPIC_API_KEY set
set -euo pipefail

MODE="${1:-execute}"

# ─── stats mode (no docker needed) ──────────────────────────────────────────
if [ "$MODE" = "stats" ]; then
    LOG=".ralph/test-log.jsonl"
    if [ ! -f "$LOG" ]; then
        echo "No test log found at $LOG — run 'bash ralph.sh aymm' at least once."
        exit 0
    fi

    total=$(wc -l < "$LOG")
    echo ""
    echo "AYMM Free Provider Pass Rates"
    echo "══════════════════════════════════════════════════"

    _table() {
        local filter="$1" label="$2"
        local count
        count=$(jq -r "$filter | .provider" "$LOG" | wc -l)
        echo ""
        echo "$label ($count attempts)"
        printf "  %-14s %9s %6s %6s %8s\n" "Provider" "Attempts" "Pass" "Fail" "Rate"
        printf "  %s\n" "─────────────────────────────────────────────"
        jq -rs "[.[] | $filter] | group_by(.provider)[] |
            { p: .[0].provider, t: length,
              ok: (map(select(.outcome==\"pass\")) | length) } |
            \"\(.p)\t\(.t)\t\(.ok)\t\(.t - .ok)\"" "$LOG" | sort | \
        while IFS=$'\t' read -r p t ok fail; do
            rate=$(( ok * 100 / t ))
            printf "  %-14s %9d %6d %6d %7d%%\n" "$p" "$t" "$ok" "$fail" "$rate"
        done
    }

    _table "." "All time"

    # Last 7 days — date arithmetic works on Linux; graceful fallback
    cutoff=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || echo "2000-01-01")
    _table "select(.ts >= \"$cutoff\")" "Last 7 days"

    echo ""
    echo "Attempts per task (most expensive first)"
    printf "  %-40s %9s %6s\n" "Task" "Attempts" "Passes"
    printf "  %s\n" "──────────────────────────────────────────────────────"
    jq -rs 'group_by(.task)[] |
        { t: .[0].task,
          n: length,
          ok: (map(select(.outcome=="pass")) | length) } |
        "\(.n)\t\(.ok)\t\(.t)"' "$LOG" | sort -rn | \
    while IFS=$'\t' read -r n ok t; do
        printf "  %-40s %9d %6d\n" "$t" "$n" "$ok"
    done

    echo ""
    exit 0
fi
IMAGE="ralph:latest"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Preflight checks
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found. Install Docker and try again."
    exit 1
fi

CLAUDE_DIR="$HOME/.claude"
if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ ! -f "$CLAUDE_DIR/.credentials.json" ]; then
    echo "ERROR: No Claude authentication found."
    echo "  Option 1: run 'claude login' to use your Claude subscription"
    echo "  Option 2: export ANTHROPIC_API_KEY=sk-ant-..."
    exit 1
fi

# In plan mode, prompt-plan.md must exist
if [ "$MODE" = "plan" ] && [ ! -f prompt-plan.md ]; then
    echo "ERROR: prompt-plan.md not found. Cannot run breakdown mode."
    exit 1
fi

# Build image if it doesn't exist yet
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Building $IMAGE (first run)..."
    docker build -t "$IMAGE" "$SCRIPT_DIR"
fi

mkdir -p .ralph .ralph/archive

# Rotate loop.log if it has meaningful content (> 20 lines)
if [ -f .ralph/loop.log ] && [ "$(wc -l < .ralph/loop.log)" -gt 20 ]; then
    mv .ralph/loop.log ".ralph/archive/loop-$(date +%Y-%m-%d-%H%M).log"
fi

# Auth: use credentials file (subscription) or API key
AUTH_MOUNT=""
AUTH_ENV=""
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    AUTH_ENV="-e ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}"
elif [ -f "$CLAUDE_DIR/.credentials.json" ]; then
    AUTH_MOUNT="-v ${CLAUDE_DIR}:/home/claude/.claude"
fi

PROVIDER_ENV=""
[ -n "${GEMINI_API_KEY:-}" ]      && PROVIDER_ENV="$PROVIDER_ENV -e GEMINI_API_KEY=${GEMINI_API_KEY}"
[ -n "${GROQ_API_KEY:-}" ]        && PROVIDER_ENV="$PROVIDER_ENV -e GROQ_API_KEY=${GROQ_API_KEY}"
[ -n "${MISTRAL_API_KEY:-}" ]     && PROVIDER_ENV="$PROVIDER_ENV -e MISTRAL_API_KEY=${MISTRAL_API_KEY}"
[ -n "${OPENROUTER_API_KEY:-}" ]  && PROVIDER_ENV="$PROVIDER_ENV -e OPENROUTER_API_KEY=${OPENROUTER_API_KEY}"

PROMPT_MOUNT=""
LOOP_ENV=""
case "$MODE" in
    plan)
        echo "Starting Ralph in breakdown mode (prompt-plan.md). Logs → .ralph/loop.log"
        PROMPT_MOUNT="-v $(pwd)/prompt-plan.md:/workspace/prompt.md:ro"
        ;;
    aymm)
        echo "Starting Ralph in multi-provider mode (aymm-loop.sh). Logs → .ralph/loop.log"
        if [ "${2:-}" = "--only" ]; then
            LOOP_ENV="$LOOP_ENV -e AYMM_ONLY=1"
            echo "(--only: no Claude fallback)"
        fi
        LOOP_ENV="$LOOP_ENV -e LOOP_SCRIPT=aymm-loop.sh"
        ;;
    *)
        echo "Starting Ralph in execution mode (prompt.md). Logs → .ralph/loop.log"
        ;;
esac
echo "To stop: touch STOP"
echo ""

# shellcheck disable=SC2086
docker run --rm \
    -v "$(pwd):/workspace" \
    ${PROMPT_MOUNT} \
    ${AUTH_MOUNT} \
    ${AUTH_ENV} \
    ${PROVIDER_ENV} \
    ${LOOP_ENV} \
    -e "NTFY_TOPIC=${NTFY_TOPIC:-}" \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    "$IMAGE" \
    | tee -a .ralph/loop.log

# Preserve docker's exit code, not tee's
exit "${PIPESTATUS[0]}"
