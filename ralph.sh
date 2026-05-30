#!/usr/bin/env bash
# Host-side wrapper. Run from project root:
#   bash ralph.sh          — execution mode (default): works through tasks
#   bash ralph.sh plan     — breakdown mode: generates task files from plans
#   bash ralph.sh aymm     — multi-provider mode: tries free providers before Claude
#   bash ralph.sh aymm --only — aymm mode without Claude fallback
# Requires: docker, and either 'claude login' (subscription) or ANTHROPIC_API_KEY set
set -euo pipefail

MODE="${1:-execute}"
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
