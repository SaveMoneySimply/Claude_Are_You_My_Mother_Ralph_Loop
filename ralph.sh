#!/usr/bin/env bash
# Host-side wrapper. Run from project root:
#   bash ralph.sh          — execution mode (default): works through tasks
#   bash ralph.sh plan     — breakdown mode: generates task files from plans
#   bash ralph.sh aymm     — multi-provider mode: tries free providers before Claude
#   bash ralph.sh aymm --only — aymm mode without Claude fallback
#   bash ralph.sh stats    — show free provider pass/fail rates from test-log.jsonl
#   bash ralph.sh init <path> — bootstrap a new Ralph project at <path>
#   bash ralph.sh update   — update Ralph engine files in current project
# Requires: docker, and either 'claude login' (subscription) or ANTHROPIC_API_KEY set
set -euo pipefail

# SCRIPT_DIR is used by init/update functions, so define it early.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Helper function for sed -i compatibility across macOS and Linux
apply_sed_inplace() {
    local file="$1"
    shift
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$@" "$file"
    else
        sed -i "$@" "$file"
    fi
}

# ─── Initialization and Update Functions ────────────────────────────────────

ralph_init() {
    local TARGET_PATH="$1"
    if [ -z "$TARGET_PATH" ]; then
        echo "ERROR: Missing target path for 'init' command."
        echo "Usage: bash ralph.sh init <path>"
        exit 1
    fi

    # Resolve target path to absolute path
    if [[ ! "$TARGET_PATH" =~ ^/ ]]; then
        TARGET_PATH="$(pwd)/$TARGET_PATH"
    fi

    if [ -d "$TARGET_PATH" ]; then
        echo "ERROR: Target directory '$TARGET_PATH' already exists. Aborting."
        exit 1
    fi

    echo "Initializing new Ralph project at '$TARGET_PATH'..."
    mkdir -p "$TARGET_PATH"
    pushd "$TARGET_PATH" > /dev/null

    echo "  Creating directory structure..."
    mkdir -p ralph-aymm tasks/{0_backlog,1_queue,2_active,3_done} .ralph handoffs planning

    local ENGINE_FILES=(
        "loop.sh"
        "aymm-loop.sh"
        "run_agent_task.sh"
        "apply_changes.sh"
        "provider-config.sh"
        "provider-status.sh"
        "init-firewall.sh"
        "Dockerfile"
        "prompt.md"
    )

    echo "  Copying engine files to ralph-aymm/..."
    for file in "${ENGINE_FILES[@]}"; do
        cp "$SCRIPT_DIR/$file" "ralph-aymm/"
    done

    echo "  Copying ralph.sh and patching header..."
    cp "$SCRIPT_DIR/ralph.sh" "ralph-aymm/ralph.sh"
    apply_sed_inplace "ralph-aymm/ralph.sh" -e '1,8s|bash ralph.sh|bash ralph-aymm/ralph.sh|'

    echo "  Applying patch 1 (WORKDIR in loop.sh, aymm-loop.sh)..."
    apply_sed_inplace "ralph-aymm/loop.sh" -e 's|WORKDIR=/workspace|WORKDIR="$(cd "$(dirname "$0")/.." \&\& pwd)"|'
    apply_sed_inplace "ralph-aymm/aymm-loop.sh" -e 's|WORKDIR=/workspace|WORKDIR="$(cd "$(dirname "$0")/.." \&\& pwd)"|'

    echo "  Applying patch 2 (PROJECT_ROOT in run_agent_task.sh)..."
    local RUN_AGENT_TASK_PATH="ralph-aymm/run_agent_task.sh"
    # Insert PROJECT_ROOT detection after SCRIPT_DIR assignment
    apply_sed_inplace "$RUN_AGENT_TASK_PATH" -e '/^SCRIPT_DIR/a\
[ -d "$(dirname "$SCRIPT_DIR")/tasks" ] \\\
  \&\& PROJECT_ROOT="$(dirname "$SCRIPT_DIR")" \\\
  \|\| PROJECT_ROOT="$SCRIPT_DIR"'
    # Replace SCRIPT_DIR references with PROJECT_ROOT for specific paths
    apply_sed_inplace "$RUN_AGENT_TASK_PATH" -E 's:\$\{SCRIPT_DIR\}(/\.ralph/|/tasks/|/ARCHITECTURE\.md):\$\{PROJECT_ROOT\}\1:g'

    echo "  Applying patch 3 (run_agent_task.sh path in aymm-loop.sh)..."
    apply_sed_inplace "ralph-aymm/aymm-loop.sh" -e 's|bash "${WORKDIR}/run_agent_task.sh"|bash "${WORKDIR}/ralph-aymm/run_agent_task.sh"|'

    echo "  Writing ARCHITECTURE.md..."
    cat << EOF > ARCHITECTURE.md
# Project Name - One-line description

## Stack
- Language: <e.g., Python, JavaScript, Bash>
- Framework: <e.g., Flask, React, none>
- Runtime: <e.g., Node.js, Python 3.9, JVM>
- Package Manager: <e.g., pip, npm, yarn, none>

## Test Command
<The command that must pass before any task closes, e.g., 'bash -n loop.sh' or 'pytest'>

## Directory Structure
- \`.\`: Project root, contains documentation, configuration, and task pipeline.
- \`ralph-aymm/\`: Ralph engine scripts and Dockerfile.
- \`tasks/\`: Contains the 4-stage task pipeline (\`0_backlog/\`, \`1_queue/\`, \`2_active/\`, \`3_done/\`).
- \`planning/\`: For blueprints, style guides, phase plans, and other high-level documentation.
- \`.ralph/\`: Internal state for the Ralph Loop (e.g., \`last_step\`, \`test-log.jsonl\`, \`state.json\`).
- \`handoffs/\`: For saving work product that needs to be handed off or reviewed.

## Ralph settings
- Autonomy: low  # low | medium | high (low is default, requests approval for changes)
- Loop version: AYMM  # AYMM | ClaudeOnly
- Provider count: 4  # 1-4 for AYMM mode; 1 for ClaudeOnly

## Firewall additions
# Any extra domains beyond the default allowlist (e.g., "example.com", "api.stripe.com")
FIREWALL_ALLOWLIST=()

## Doc map
- \`README.md\`: High-level project overview (this file).
- \`CLAUDE.md\`: Claude's persona and instructions (travels unchanged).
- \`CHANGELOG.md\`: Project change history.
- \`planning/\`: Folder for detailed plans and design docs.
- \`tasks/\`: Task pipeline.
EOF

    echo "  Copying CLAUDE.md..."
    cp "$SCRIPT_DIR/CLAUDE.md" .

    echo "  Writing CHANGELOG.md..."
    cat << EOF > CHANGELOG.md
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased
### Added
- Initial project setup with Ralph Loop engine.
EOF

    echo "  Writing .gitignore..."
    cat << EOF > .gitignore
STOP
.ralph/
node_modules/
.env
EOF

    echo "  Writing .ralph-source..."
    echo "$SCRIPT_DIR" > .ralph-source

    echo "  Initializing git repository and making initial commit..."
    git init > /dev/null
    git add -A
    git commit -m "init: ralph-aymm engine boilerplate" > /dev/null

    popd > /dev/null
    echo "Ralph project initialized successfully at '$TARGET_PATH'."
    echo "Next steps: cd '$TARGET_PATH' and start developing!"
}

ralph_update() {
    echo "Update function placeholder - Not yet implemented."
    exit 1 # Placeholder, will be implemented in the next step
}

# ─── Main Logic ─────────────────────────────────────────────────────────────
MODE="execute" # Default mode for the rest of the script
AYMM_ONLY="false"

case "${1:-}" in
    "init")
        ralph_init "$2"
        exit 0
        ;;
    "update")
        ralph_update
        exit 0
        ;;
    "stats")
        MODE="stats"
        shift # Consume 'stats' argument
        ;;
    "plan")
        MODE="plan"
        shift # Consume 'plan' argument
        ;;
    "aymm")
        MODE="aymm"
        if [ "${2:-}" = "--only" ]; then
            AYMM_ONLY="true"
            shift 2 # Consume 'aymm' and '--only'
        else
            shift # Consume 'aymm'
        fi
        ;;
    "execute"|"") # "execute" or no argument (default)
        # If "execute" was explicitly given, consume it. If no args, $1 is empty, MODE is default.
        if [ "$1" = "execute" ]; then
            shift
        fi
        ;;
    *)
        echo "ERROR: Unknown mode '$1'"
        echo "Usage: bash ralph.sh [execute|plan|aymm [--only]|stats|init <path>|update]"
        exit 1
        ;;
esac

# At this point, $1 and remaining arguments are for the dockerized loop scripts,
# or for the stats block, if applicable.

# ─── stats mode (no docker needed) ──────────────────────────────────────────
if [ "$MODE" = "stats" ]; then
    LOG=".ralph/test-log.jsonl"
    if [ ! -f "$LOG" ]; then
        echo "No stats log found at $LOG"
        exit 0
    fi

    echo "Provider execution stats from $LOG:"
    echo "  Free AI Provider                          Total   Success"
    echo "  ────────────────────────────────────────  ───────  ───────"

    # Use jq to parse the log and count successes/failures per provider
    # provider, ok (boolean)
    jq -r 'select(.provider | contains("gemini") or contains("mistral") or contains("groq") or contains("openrouter")) | [.provider, .ok] | @tsv' "$LOG" | \
    awk -F'\t' '
    {
        total[$1]++;
        if ($2 == "true") {
            success[$1]++;
        }
    }
    END {
        for (p in total) {
            printf "%s\t%d\t%d\n", p, total[p], success[p];
        }
    }' | sort -k1
    # Output to awk for formatting (jq's tab-separated values are easy for awk)
    # Then sort by provider name for consistent output.

    echo ""
    exit 0
fi

IMAGE="ralph:latest"

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

# Run the appropriate loop script in the Docker container
if [ "$MODE" = "aymm" ]; then
    echo "Starting Ralph Loop (AYMM mode)..."
    docker run -it --rm \
        -v "$SCRIPT_DIR":/engine:ro \
        -v "$(pwd)":/workspace \
        --env-file <(env | grep ANTHROPIC_API_KEY || true) \
        --env AYMM_ONLY="$AYMM_ONLY" \
        "$IMAGE" \
        bash /engine/aymm-loop.sh "$@"
elif [ "$MODE" = "plan" ]; then
    echo "Starting Ralph Loop (plan mode)..."
    docker run -it --rm \
        -v "$SCRIPT_DIR":/engine:ro \
        -v "$(pwd)":/workspace \
        --env-file <(env | grep ANTHROPIC_API_KEY || true) \
        "$IMAGE" \
        bash /engine/loop.sh plan "$@"
else # MODE = "execute" (default)
    echo "Starting Ralph Loop (execute mode)..."
    docker run -it --rm \
        -v "$SCRIPT_DIR":/engine:ro \
        -v "$(pwd)":/workspace \
        --env-file <(env | grep ANTHROPIC_API_KEY || true) \
        "$IMAGE" \
        bash /engine/loop.sh execute "$@"
fi
