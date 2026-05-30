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

# Helper function for platform-agnostic sed -i
apply_sed_inplace() {
    local file="$1"
    shift
    if sed --version >/dev/null 2>&1; then
        # GNU sed
        sed -i "$@" "$file"
    else
        # BSD sed (macOS)
        sed -i "" "$@" "$file"
    fi
}

# ─── Core Docker Functions ──────────────────────────────────────────────────

_docker_build() {
    echo "Building Docker image..."
    docker build -t ralph-aymm-agent "$SCRIPT_DIR"
}

_docker_run_ralph() {
    local loop_script="$1"
    shift # Remove loop_script from arguments
    local args="$@" # Remaining arguments passed to the loop script
    echo "Running Ralph in Docker with $loop_script..."
    docker run --rm \
        -v "$(pwd):/workspace" \
        -v "$SCRIPT_DIR/ralph-aymm:/engine:ro" \
        -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
        -e OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}" \
        -e MISTRAL_API_KEY="${MISTRAL_API_KEY:-}" \
        -e GROQ_API_KEY="${GROQ_API_KEY:-}" \
        -e GEMINI_API_KEY="${GEMINI_API_KEY:-}" \
        -e OLLAMA_HOST="${OLLAMA_HOST:-}" \
        -it ralph-aymm-agent \
        bash "/engine/$loop_script" $args
}

# ─── Task Management Functions ──────────────────────────────────────────────

ralph_init() {
    local target_path="$1"
    if [ -z "$target_path" ]; then
        echo "Usage: ralph.sh init <path>"
        exit 1
    fi

    echo "Initializing new Ralph project at: $target_path"
    mkdir -p "$target_path"
    cd "$target_path"

    # Verify we're not inside the source repo itself
    if [[ "$(pwd)" == "$SCRIPT_DIR"* ]]; then
        echo "Error: Cannot initialize a project inside the Ralph Loop source repository."
        exit 1
    fi

    mkdir -p ralph-aymm \
             tasks/{0_backlog,1_queue,2_active,3_done} \
             .ralph \
             handoffs \
             planning

    local ENGINE_FILES=(
        "loop.sh"
        "aymm-loop.sh"
        "run_agent_task.sh"
        "apply_changes.sh"
        "provider-config.sh"
        "provider-status.sh"
        "init-firewall.sh"
        "Dockerfile"
        "prompt.md" # This prompt.md is from the engine, not the project one
    )

    echo "  Copying engine files to ralph-aymm/..."
    for file in "${ENGINE_FILES[@]}"; do
        cp "$SCRIPT_DIR/$file" "ralph-aymm/"
    done

    echo "  Copying ralph.sh and patching header for ralph-aymm/ralph.sh..."
    cp "$SCRIPT_DIR/ralph.sh" "ralph-aymm/ralph.sh"
    # Patch the comment block to indicate this is the ralph-aymm subdirectory version
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
    cat << 'EOF' > ARCHITECTURE.md
# Project Name - One-line description

## Stack
- Language: <e.g., Python, JavaScript, Bash>
- Framework: <e.g., Flask, React, none>
- Runtime: <e.g., Node.js, Python 3.9, JVM>
- Package Manager: <e.g., pip, npm, yarn, none>

## Test Command
<e.g., bash -n my_script.sh, npm test, python -m unittest>

## Directory Structure
- `.ralph/`: Ralph Loop internal state, logs, etc.
- `tasks/`: Holds task files (`0_backlog`, `1_queue`, `2_active`, `3_done`)
- `ralph-aymm/`: Ralph Loop engine scripts
- `handoffs/`: For human-readable handoff reports
- `planning/`: For blueprints, style guides, phase plans
- `ARCHITECTURE.md`: This file, project structure, setup, test command
- `CLAUDE.md`: Core prompt for Claude
- `prompt.md`: Step executor for Claude
- `CHANGELOG.md`: Project change log

## Ralph settings
- Autonomy: low
- Loop version: AYMM
- Provider count: 4 (Gemini, Mistral, Groq, OpenRouter) before Claude

## Firewall additions
# Any extra domains beyond the default allowlist (e.g., if you need to `curl` something)

## Doc map
- README
- CLAUDE.md
- CHANGELOG
- planning/
- tasks/
EOF

    echo "  Copying CLAUDE.md..."
    cp "$SCRIPT_DIR/CLAUDE.md" CLAUDE.md

    echo "  Copying project prompt.md..."
    # This is the prompt.md used by the project's root for Claude (the 'executor' prompt).
    # The one in ralph-aymm/ is for engine-internal use.
    cp "$SCRIPT_DIR/prompt.md" prompt.md

    echo "  Writing CHANGELOG.md..."
    cat << 'EOF' > CHANGELOG.md
# Changelog
All notable changes to this project will be documented in this file.
EOF

    echo "  Writing .gitignore..."
    cat << 'EOF' > .gitignore
STOP
.ralph/
node_modules/
.env
EOF

    echo "  Writing .ralph-source..."
    echo "$SCRIPT_DIR" > .ralph-source

    echo "  Initializing git repository and committing boilerplate..."
    git init > /dev/null
    git add -A
    git commit -m "init: ralph-aymm engine boilerplate" > /dev/null

    echo "Project initialized successfully at $target_path"
}

ralph_update() {
    echo "Updating Ralph engine files..."

    if [ ! -f ".ralph-source" ]; then
        echo "Error: .ralph-source not found. Cannot update. Please run 'ralph.sh init' first."
        exit 1
    fi

    local RALPH_SOURCE_REPO
    RALPH_SOURCE_REPO="$(cat .ralph-source)"

    if [ ! -d "$RALPH_SOURCE_REPO" ]; then
        echo "Error: Ralph source repository path '$RALPH_SOURCE_REPO' from .ralph-source does not exist or is not a directory."
        exit 1
    fi

    # Ensure we are in a git repository to commit
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: Not in a git repository. Cannot commit updates."
        exit 1
    fi

    # Ensure ralph-aymm directory exists
    if [ ! -d "ralph-aymm" ]; then
        echo "Error: ralph-aymm/ directory not found. Cannot update."
        exit 1
    fi

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

    echo "  Copying latest engine files from $RALPH_SOURCE_REPO to ralph-aymm/..."
    for file in "${ENGINE_FILES[@]}"; do
        cp "$RALPH_SOURCE_REPO/$file" "ralph-aymm/"
    done

    echo "  Copying ralph.sh and patching header for ralph-aymm/ralph.sh..."
    cp "$RALPH_SOURCE_REPO/ralph.sh" "ralph-aymm/ralph.sh"
    apply_sed_inplace "ralph-aymm/ralph.sh" -e '1,8s|bash ralph.sh|bash ralph-aymm/ralph.sh|'

    echo "  Re-applying patch 1 (WORKDIR in loop.sh, aymm-loop.sh)..."
    apply_sed_inplace "ralph-aymm/loop.sh" -e 's|WORKDIR=/workspace|WORKDIR="$(cd "$(dirname "$0")/.." \&\& pwd)"|'
    apply_sed_inplace "ralph-aymm/aymm-loop.sh" -e 's|WORKDIR=/workspace|WORKDIR="$(cd "$(dirname "$0")/.." \&\& pwd)"|'

    echo "  Re-applying patch 2 (PROJECT_ROOT in run_agent_task.sh)..."
    local RUN_AGENT_TASK_PATH="ralph-aymm/run_agent_task.sh"
    apply_sed_inplace "$RUN_AGENT_TASK_PATH" -e '/^SCRIPT_DIR/a\
[ -d "$(dirname "$SCRIPT_DIR")/tasks" ] \\\
  \&\& PROJECT_ROOT="$(dirname "$SCRIPT_DIR")" \\\
  \|\| PROJECT_ROOT="$SCRIPT_DIR"'
    apply_sed_inplace "$RUN_AGENT_TASK_PATH" -E 's:\$\{SCRIPT_DIR\}(/\.ralph/|/tasks/|/ARCHITECTURE\.md):\$\{PROJECT_ROOT\}\1:g'

    echo "  Re-applying patch 3 (run_agent_task.sh path in aymm-loop.sh)..."
    apply_sed_inplace "ralph-aymm/aymm-loop.sh" -e 's|bash "${WORKDIR}/run_agent_task.sh"|bash "${WORKDIR}/ralph-aymm/run_agent_task.sh"|'

    echo "  Committing updates..."
    git add ralph-aymm/
    git commit -m "update: ralph-aymm engine scripts"

    echo "Ralph engine files updated successfully."
}

# ─── Main Execution ─────────────────────────────────────────────────────────

MODE="${1:-execute}"
shift || true # Shift if an argument was provided for MODE

case "$MODE" in
    execute)
        _docker_build
        _docker_run_ralph "loop.sh" "$@"
        ;;
    plan)
        echo "Plan mode not fully implemented yet."
        # _docker_build
        # _docker_run_ralph "plan_loop.sh" "$@" # Assuming a separate plan loop script
        ;;
    aymm)
        _docker_build
        local aymm_args=""
        if [[ "$1" == "--only" ]]; then
            aymm_args="--only"
            shift # Consume --only so that subsequent "$@" is correct
        fi
        _docker_run_ralph "aymm-loop.sh" "$aymm_args" "$@"
        ;;
    stats)
        LOG=".ralph/test-log.jsonl"
        if [ ! -f "$LOG" ]; then
            echo "No test log found at $LOG"
            exit 0
        fi
        jq -s '
            (map(select(.outcome == "success")) | length) as $success_count |
            (map(select(.outcome == "failure")) | length) as $failure_count |
            ($success_count + $failure_count) as $total_attempts |
            {
                total_attempts: $total_attempts,
                success_rate: if $total_attempts > 0 then ($success_count / $total_attempts * 100) | round else 0 end,
                provider_stats: ([
                    "gemini", "mistral", "groq", "openrouter", "claude"
                ] | map({
                    provider: .,
                    success_rate: (
                        (map(select(.provider == .provider and .outcome == "success")) | length) as $prov_success |
                        (map(select(.provider == .provider and .outcome == "failure")) | length) as $prov_failure |
                        ($prov_success + $prov_failure) as $prov_total |
                        if $prov_total > 0 then ($prov_success / $prov_total * 100) | round else 0 end
                    )
                }))
            }
        ' "$LOG"
        ;;
    init)
        ralph_init "$@"
        ;;
    update)
        ralph_update
        ;;
    *)
        echo "Unknown mode: $MODE"
        echo "Usage: ralph.sh [execute|plan|aymm|aymm --only|stats|init <path>|update]"
        exit 1
        ;;
esac
