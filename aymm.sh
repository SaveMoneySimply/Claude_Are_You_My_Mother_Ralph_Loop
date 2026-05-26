#!/usr/bin/env bash
# Host-side wrapper for the AYMM multi-provider loop. Run from project root:
#   bash aymm.sh        — execution mode (default): works through tasks using free providers first
#   bash aymm.sh plan   — breakdown mode: generates task files from plans
# Requires: docker, ANTHROPIC_API_KEY (for fallback escalation and plan mode)
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

mkdir -p .ralph

# Auth: use credentials file (subscription) or API key
AUTH_MOUNT=""
AUTH_ENV=""
if [ -d "$CLAUDE_DIR" ]; then
    AUTH_MOUNT="-v $CLAUDE_DIR:/home/claude/.claude"
fi
if [ -f "$HOME/.claude.json" ]; then
    AUTH_MOUNT="$AUTH_MOUNT -v $HOME/.claude.json:/home/claude/.claude.json"
fi
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    AUTH_ENV="-e ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}"
fi

PROVIDER_ENV=""
[ -n "${GEMINI_API_KEY:-}" ]      && PROVIDER_ENV="$PROVIDER_ENV -e GEMINI_API_KEY=${GEMINI_API_KEY}"
[ -n "${GROQ_API_KEY:-}" ]        && PROVIDER_ENV="$PROVIDER_ENV -e GROQ_API_KEY=${GROQ_API_KEY}"
[ -n "${MISTRAL_API_KEY:-}" ]     && PROVIDER_ENV="$PROVIDER_ENV -e MISTRAL_API_KEY=${MISTRAL_API_KEY}"
[ -n "${OPENROUTER_API_KEY:-}" ]  && PROVIDER_ENV="$PROVIDER_ENV -e OPENROUTER_API_KEY=${OPENROUTER_API_KEY}"

# Plan mode uses loop.sh (Claude) to read prompt-plan.md and generate task files.
# Execute mode uses aymm-loop.sh to try free providers before escalating to Claude.
if [ "$MODE" = "plan" ]; then
    LOOP_ENV="-e LOOP_SCRIPT=loop.sh"
    PROMPT_MOUNT="-v $(pwd)/prompt-plan.md:/workspace/prompt.md:ro"
    echo "Starting AYMM in breakdown mode (prompt-plan.md). Logs → .ralph/loop.log"
else
    LOOP_ENV="-e LOOP_SCRIPT=aymm-loop.sh"
    PROMPT_MOUNT=""
    echo "Starting AYMM in execution mode (aymm-loop.sh). Logs → .ralph/loop.log"
fi
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
