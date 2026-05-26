Here is a comprehensive, production-ready specification for **Ralph v2 (Structural Self-Isolation & Token Optimization)**. It brings together our entire conversation regarding file isolation, directory-driven phase tracking, and bash-pre-parsed token stripping into a clear blueprint you can hand off directly to Claude.

---

# Ralph v2 Production Specification — Structural Self-Isolation & Token Optimization

This document outlines the architectural changes required to upgrade the Ralph Loop from v1 to v2.

## Core Objectives

1. **Structural Self-Isolation ("Don't Pick Your Nose"):** Separate the immutable execution engine from the local project files to ensure the loop agent cannot physically alter its own codebase.
2. **Extreme Token Efficiency:** Move state-parsing and navigation out of Claude's context window and into native Bash pre-processing, dropping typical iteration routing context down significantly.
3. **Directory-Driven State Machine:** Replace index file maintenance (`PLAN.md`, `plans/*.md`) with physical file placement across specialized directories to make project state deterministic and human-visible.

---

## 1. Directory & Mount Architecture

Instead of mounting a single workspace containing both the engine scripts and project codebase, Ralph v2 uses a **Dual-Volume Mount Configuration** inside the container.

### The Host and Container Separation

* **`/engine` (Read-Only):** Mounts the global `~/tools/ralph` directory containing the core engine logic. Marked `:ro` at the system level.
* **`/workspace` (Read-Write):** Mounts the active project working directory (`$(pwd)`). Marked `:rw`.

### Updated Host Wrapper (`ralph.sh`)

The host script is installed globally and handles environment routing and the dual-mount contract:

```bash
#!/usr/bin/env bash
# ~/tools/ralph/ralph.sh
set -euo pipefail

MODE="${1:-execute}"
IMAGE="ralph:v2"
ENGINE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKSPACE_DIR="$(pwd)"

if [ ! -f "$WORKSPACE_DIR/ARCHITECTURE.md" ]; then
    echo "ERROR: ARCHITECTURE.md not found in $WORKSPACE_DIR"
    exit 1
fi

# Ensure internal states folder architecture exists locally
mkdir -p tasks/{0_backlog,1_queue,2_active,3_done} .ralph

# Handle Claude Authentication
AUTH_MOUNT=""
AUTH_ENV=""
[ -d "$HOME/.claude" ] && AUTH_MOUNT="-v $HOME/.claude:/home/claude/.claude"
[ -f "$HOME/.claude.json" ] && AUTH_MOUNT="$AUTH_MOUNT -v $HOME/.claude.json:/home/claude/.claude.json"
[ -n "${ANTHROPIC_API_KEY:-}" ] && AUTH_ENV="-e ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}"

docker run -it --rm \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v "$ENGINE_DIR:/engine:ro" \
  -v "$WORKSPACE_DIR:/workspace:rw" \
  $AUTH_MOUNT \
  $AUTH_ENV \
  -e NTFY_TOPIC="${NTFY_TOPIC:-}" \
  "$IMAGE" /bin/bash /engine/loop.sh "$MODE"

```

---

## 2. Directory-Driven Phase Tracking

We eliminate centralized markdown indexes. The filesystem's folder distribution becomes the source of truth for the project lifecycle.

```
tasks/
├── 0_backlog/        ← Phase 1: High-level requirements and un-itemized tasks
├── 1_queue/          ← Phase 2: Broken down, fully structured task files ready for execution
├── 2_active/         ← Phase 3: THE single task currently in progress (Strict Limit: 1)
└── 3_done/           ← Phase 3: Archive of fully completed and merged tasks

```

### Phase Lifecycles

* **Phase 0 & 1 (Setup & High-Level Planning):** User and Claude create `ARCHITECTURE.md` and populate raw markdown placeholders into `tasks/0_backlog/`.
* **Phase 2 (Task Breakdown Mode - `bash ralph.sh plan`):** The engine takes the first file from `0_backlog/`, passes it to Claude with `prompt-plan.md` to append explicit, sequential checkbox steps, and writes the output directly into `tasks/1_queue/`.
* **Phase 3 (Autonomous Loop Execution - `bash ralph.sh`):** The engine pulls the first alphabetical item from `1_queue/` into `2_active/` and processes it step-by-step.

---

## 3. Token-Stripping Bash Parser (`loop.sh`)

Instead of throwing index files at Claude and forcing the LLM to search for what to do next, `loop.sh` extracts *only* the specific target step and passes it as a strict, localized execution context.

### The Upgraded Execution & Routing Logic

```bash
# Inside /engine/loop.sh running inside the container
cd /workspace

MODE="${1:-execute}"

# --- PHASE 2 ROUTING: BREAKDOWN MODE ---
if [ "$MODE" = "plan" ]; then
    TARGET=$(ls tasks/0_backlog/*.md 2>/dev/null | head -n 1)
    if [ -z "$TARGET" ]; then
        echo "Phase 2 Complete: Backlog is fully broken down." > STOP
        exit 0
    fi
    # Execute breakdown on this single file, outputting straight to queue
    cat /engine/prompt-plan.md | claude ... > "tasks/1_queue/$(basename "$TARGET")"
    rm "$TARGET"
    exit 0
fi

# --- PHASE 3 ROUTING: EXECUTION MODE ---
ACTIVE_FILE=$(ls tasks/2_active/*.md 2>/dev/null | head -n 1)

# Pipeline transition: if no task is active, pull the next in line from the queue
if [ -z "$ACTIVE_FILE" ]; then
    NEXT_JOB=$(ls tasks/1_queue/*.md 2>/dev/null | sort | head -n 1)
    if [ -n "$NEXT_JOB" ]; then
        mv "$NEXT_JOB" tasks/2_active/
        ACTIVE_FILE=$(ls tasks/2_active/*.md | head -n 1)
    else
        echo "Phase 3 Complete: All tasks in queue resolved!" > STOP
        exit 0
    fi
fi

CURRENT_TASK=$(basename "$ACTIVE_FILE" .md)
echo "$CURRENT_TASK" > .ralph/last-task.txt

# EXTRACT ONLY THE NEXT UNCHECKED STEP (The Token Saver)
NEXT_STEP=$(grep -m 1 '^- \[ \]' "$ACTIVE_FILE" || true)

if [ -z "$NEXT_STEP" ]; then
    # No unchecked checkboxes remain: trigger final verification gate
    EXECUTION_CONTEXT="All sub-steps are complete. Run the task test command, commit, merge to main, and close the task."
else
    # Isolate execution scope entirely
    EXECUTION_CONTEXT="Your singular focus for this iteration is to complete this step:
$NEXT_STEP

When finished, evaluate the outcome and write 'pass' or 'fail' to .ralph/last-result.txt."
fi

# --- INCORPORATING ESCALATION LEVEL N: CONTEXT EXPANSION ---
# (Triggered if loop.sh's tracking array determines a Step N retry is active)
if [ "$ESCALATION_LEVEL" = "context_expansion" ]; then
    # Grab historical and upcoming task file states natively via directory sorting
    LAST_DONE_1=$(ls -t tasks/3_done/*.md 2>/dev/null | sed -n '1p')
    LAST_DONE_2=$(ls -t tasks/3_done/*.md 2>/dev/null | sed -n '2p')
    NEXT_QUEUE_1=$(ls tasks/1_queue/*.md 2>/dev/null | sort | sed -n '1p')
    NEXT_QUEUE_2=$(ls tasks/1_queue/*.md 2>/dev/null | sort | sed -n '2p')

    EXPANDED_CONTEXT="\n\n=== CONTEXT EXPANSION (DIAGNOSTIC READ-ONLY REFERENCE) ==="
    [ -n "$LAST_DONE_1" ] && EXPANDED_CONTEXT="$EXPANDED_CONTEXT\n[Completed recently]:\n$(cat "$LAST_DONE_1")"
    [ -n "$LAST_DONE_2" ] && EXPANDED_CONTEXT="$EXPANDED_CONTEXT\n$(cat "$LAST_DONE_2")"
    [ -n "$NEXT_QUEUE_1" ] && EXPANDED_CONTEXT="$EXPANDED_CONTEXT\n[Planned next]:\n$(cat "$NEXT_QUEUE_1")"
    [ -n "$NEXT_QUEUE_2" ] && EXPANDED_CONTEXT="$EXPANDED_CONTEXT\n$(cat "$NEXT_QUEUE_2")"
    
    EXECUTION_CONTEXT="$EXECUTION_CONTEXT\n$EXPANDED_CONTEXT"
fi

# Construct payload and invoke Claude headless
# (Pipes basic instructions + the tightly scoped step payload)
echo -e "$EXECUTION_CONTEXT" | claude --model "$MODEL" --effort "$EFFORT" ...

```

---

## 4. Key Advantages over v1

1. **Stateless Iterations:** Claude never has to maintain or track project-level index charts. Every iteration receives exactly what it must complete and nothing else, preventing systemic context drift and token drain.
2. **Native Escalation Sourcing:** Context expansion no longer scans markdown layout tables. It grabs files using standard shell timestamps (`ls -t`) and file lists, keeping escalation lightweight, accurate, and ephemeral.
3. **Clean Repository History:** The implementation files (`CLAUDE.md`, `loop.sh`, etc.) are hidden outside the workspace. Project repositories remain entirely clean, tracking nothing but actual source code and the clean, linear `tasks/` directory progression.
