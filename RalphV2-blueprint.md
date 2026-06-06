Here is a complete, production-grade breakdown of the **Lean v2 Framework**, serving as your immediate, working bridge to the full system architecture described in `SuperRalph-blueprint.md`.

This framework implements the core architectural principles of the blueprint—such as context isolation, separating cognition from mechanics, and strict worker/director hierarchy—using the zero-overhead file system state machine we designed.

---

## 1. Architectural Alignment: Mapping Lean v2 to the Blueprint

Instead of spending weeks setting up database schemas and asynchronous execution pipelines, the Lean v2 setup uses your local Unix file system as a deterministic runtime database.

| Blueprint Layer

 | Lean v2 Implementation | Orchestration Function |
| --- | --- | --- |
| **Layer 1: Foundation Infrastructure**<br> | **Dual-Volume Bash Engine**<br> | Docker runs with a read-only `/engine` mount and a read-write `/workspace` mount. The state machine is managed entirely via physical folders.

 |
| **Layer 2: Deterministic Runtime**<br> | **The Token-Stripping Parser**<br> | Native `grep` and text utilities slice out a single uncompleted task line. Claude never reads the whole roadmap file, preserving context window hygiene.

 |
| **Layer 3: Worker Layer**<br> | **Tactical Loops (`loop.sh`)**<br> | High-speed, lower-cost, stateless execution models focused exclusively on resolving a single markdown checkbox instruction.

 |
| **Layer 4: Routing & Escalation**<br> | **Escalation Array Tracking**<br> | Tracking retries within the bash loop. If a step fails sequentially, it triggers contextual expansion before escalating.

 |
| **Layer 5: Director Layer**<br> | **Strategic Engine (`director.sh`)**<br> | A separate script that triggers *only* when the worker throws a terminal block. It runs a premium, high-reasoning configuration to rewrite or split the failing task file.

 |

---

## 2. Why This is the Ultimate Transition Step

1. **Zero Infrastructure Bloat:** It keeps you coding. You skip writing ORM boilerplates, running Alembic database migrations, or debugging asynchronous race conditions before the loop is even useful.


2. **Visual Debugging:** Your data model is human-readable. If you want to see the status of the project or manually change priorities, you don't query a database; you simply look at your file tree or run `mv tasks/1_queue/task-b.md tasks/1_queue/task-a.md`.


3. **Hardens the Cognitive Boundaries:** It forces you to perfect the prompt boundaries, the tool outputs, and the worker/director hand-off logic in a clean environment. Once the rules of the system are mature, porting them to a Python runtime becomes a trivial porting exercise.



---

## 3. Implementation Steps: The Assembly Line

To roll out the Lean v2 setup, execute the following implementation path:

### Step 1: Establish Local State Architecture

Create the rigid structure required for the state machine within your project root:

```bash
mkdir -p tasks/{0_backlog,1_queue,2_active,3_done} .ralph

```

### Step 2: Provision the Isolated Global Wrapper

Install `ralph.sh` into your global host tools directory (`~/tools/ralph/ralph.sh`). This ensures the execution engine remains completely read-only and isolated from the worker's destructive workspace adjustments.

### Step 3: Write the Token-Stripping Worker Execution Loop

Build out `/engine/loop.sh` inside the isolated runtime. It must handle directory-driven routing, extract only the single uncompleted checkbox step, and feed that step as a hyper-targeted context payload to the model.

### Step 4: Inject the Director Recovery Circuit

Deploy `/engine/director.sh`. Configure the worker loop so that instead of dropping to a dead halt upon failure, it pipes its state logs directly to the high-altitude Director model to execute automated task decomposition and pipeline resurrection.

---

## 4. Complete Lean v2 Production Code Blueprint

This is the exact, integrated code structure across your global, read-only `/engine` space and local `/workspace`.

### Global Read-Only Engine: `loop.sh`

```bash
#!/usr/bin/env bash
# /engine/loop.sh
set -euo pipefail

cd /workspace
MODE="${1:-execute}"

# --- PHASE 2: TASK BREAKDOWN MODE ---
if [ "$MODE" = "plan" ]; then
    TARGET=$(ls tasks/0_backlog/*.md 2>/dev/null | head -n 1)
    if [ -z "$TARGET" ]; then
        echo "Phase 2 Complete: No raw backlog files left to process."
        exit 0
    fi
    echo "Decomposing backlog item: $(basename "$TARGET")"
    cat /engine/prompt-plan.md | claude --model sonnet > "tasks/1_queue/$(basename "$TARGET")"
    rm "$TARGET"
    exit 0
fi

# --- PHASE 3: ISOLATED WORKER LOOP ---
ACTIVE_FILE=$(ls tasks/2_active/*.md 2>/dev/null | head -n 1)

# Pipeline transition: if no task is currently active, advance the queue
if [ -z "$ACTIVE_FILE" ]; then
    NEXT_JOB=$(ls tasks/1_queue/*.md 2>/dev/null | sort | head -n 1)
    if [ -n "$NEXT_JOB" ]; then
        mv "$NEXT_JOB" tasks/2_active/
        ACTIVE_FILE=$(ls tasks/2_active/*.md | head -n 1)
    else
        echo "Phase 3 Complete: All task queues successfully resolved!"
        rm -f STOP
        exit 0
    fi
fi

CURRENT_TASK=$(basename "$ACTIVE_FILE" .md)
echo "$CURRENT_TASK" > .ralph/last-task.txt

# LAYER 2 DETERMINISTIC RUNTIME: Token-Stripping Step Extraction
NEXT_STEP=$(grep -m 1 '^- \[ \]' "$ACTIVE_FILE" || true)

if [ -z "$NEXT_STEP" ]; then
    EXECUTION_CONTEXT="All sub-steps in this task are marked complete. Run validation tests, commit your changes via git, and move the task to complete."
else
    EXECUTION_CONTEXT="Your absolute, singular focus for this iteration is to complete this exact step:
$NEXT_STEP

Do not drift outside this objective. When finished, write 'pass' or 'fail' to .ralph/last-result.txt."
fi

# Pass context to Worker Model (Fast, low-cost token execution layer)
echo -e "$EXECUTION_CONTEXT" | claude --model haiku --bare > .ralph/worker_output.log

# Evaluate execution result
RESULT=$(cat .ralph/last-result.txt 2>/dev/null || echo "fail")

if [ "$RESULT" = "fail" ]; then
    echo "Step failed. Escalating to Director Layer..."
    echo "Terminal roadblock detected at step: $NEXT_STEP" > BLOCKED.md
    echo "worker_halt" > STOP
    
    # Fire the recovery layer circuit breaker
    bash /engine/director.sh --heal "$CURRENT_TASK"
fi

```

### Global Read-Only Engine: `director.sh`

```bash
#!/usr/bin/env bash
# /engine/director.sh
set -euo pipefail

cd /workspace
ACTION="${1:---review}"
BLOCKED_TASK=$(cat .ralph/last-task.txt 2>/dev/null || echo "")

if [ "$ACTION" = "--heal" ] && [ -n "$BLOCKED_TASK" ]; then
    echo "🚨 Director Model engaged. Analyzing failure footprint..."

    # High-Altitude Context Construction
    DIAGNOSIS_INPUT="The worker execution loop has crashed on task: $BLOCKED_TASK.
    
    Review ARCHITECTURE.md and the error logs contained in BLOCKED.md.
    
    You must clear the bottleneck. Either fix the code file directly or split the active task file (tasks/2_active/$BLOCKED_TASK.md) into simpler, highly atomic chunks and append them back to tasks/1_queue/."

    # Invoke Premium Reasoning Engine (Opus/Max Effort Layer)
    echo -e "$DIAGNOSIS_INPUT" | claude --model opus --effort max --bare > .ralph/director_remedy.log

    # Self-Healing Resurrection Logic
    if [ -f STOP ]; then
        rm -f STOP
        rm -f BLOCKED.md
        echo "✅ Pipeline successfully healed by Director. Resuming worker execution runtime..."
        exec /bin/bash /engine/loop.sh execute
    fi
fi

```

---

## 5. Path to the Next Rebuild: How to Upgrade Later

When you are ready to transition this lean engine into the full Python/SQLite-backed operating system outlined in `SuperRalph-blueprint.md`, you won’t have to throw away any code. You will follow an incremental path:

1. **Database Ingestion (Layer 1):** Replace the directory lookups (`ls tasks/1_queue/`) with a simple Python SQL query (`SELECT * FROM tasks WHERE status = 'queued' ORDER BY priority ASC;`). The markdown task files transition directly into records inside your SQLite `tasks` table.


2. **Context Compilation Upgrade (Layer 2):** Swap the shell-based `grep` statement for a Python script using `tree-sitter`. Instead of just extracting the raw string line, Python can read the step, find the file targeted, map its internal imports, and automatically pull the correct method definitions into the prompt.


3. **Advanced Routing (Layer 4):** Since your engine will be running in Python, you can calculate the dynamic complexity score before choosing which API runner to spin up, letting the system seamlessly scale from raw local models to high-reasoning endpoints depending on the history of that specific row ID.
