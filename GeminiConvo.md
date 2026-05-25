Here is the complete, cohesive architectural specification for your **AYMM (Are You My Mother) Phase-Gate and Flight-Recorder Extension**.

You can copy and paste this entire response directly into Claude Code once your usage resets. It provides Claude with the complete structural mental map, the modified code snippets, and the underlying reasoning so she can implement it without burning unnecessary tokens.

---

# ARCHITECTURE PROPOSAL: Phase-Gate Reviews & Flight-Recorder Logging for AYMM

## 1. Core Intent & Metaphor

The **AYMM (Are You My Mother)** loop is designed to minimize Claude token burn by running autonomous task steps through free-tier providers (Gemini, Mistral, Groq, OpenRouter). The task steps are like a wandering hatchling searching for a provider that can satisfy the local bash syntax gate.

To prevent compounding mistakes or logical drift across individual steps, we introduce a two-tier boundary system:

1. **The Task Step Gate (Free & Local):** Individual checklist items use low-cost `bash -n` syntax validation.
2. **The Phase Gate Review (Claude-Powered Last Resort):** Once an *entire* task phase file (e.g., a full Markdown specification file containing multiple steps) has all its checkboxes ticked, the loop pauses execution. It wakes Claude up in the nest for a highly constrained, single-turn **Phase Gate Review** using advanced test commands and structural code auditing before advancing to the next file.

Regardless of whether a step passes or fails, a comprehensive **Flight Recorder Diary** logs all code modifications and standard errors, providing Claude with full architectural context if she ever needs to step in.

---

## 2. Updated File Blueprint & Implementations

### A. Dynamic Task Files (The Planning Pattern)

When generating task files via `bash aymm.sh plan`, the planner must append strict phase-testing instructions at the bottom of each phase Markdown file:

```markdown
## Phase Gate Review
**Advanced Test Command:** pytest tests/test_core.py && bash scripts/verify_integration.sh
**Review Constraint:** You are a strict Senior Architect. Review the changes applied during this phase ONLY for logical regressions, infinite loops, or breaking architectural patterns. Do NOT refactor formatting, style, or syntax. Reply EXACTLY with "PHASE_PASSED" or provide an explicit error block.

```

### B. Upgrading `run_agent_task.sh` (Artifact Collection)

We modify `run_agent_task.sh` to pipe standard errors to a known location during local testing and track files touched during execution:

```bash
# Append tracking for modified files when the XML parser applies blocks
# (Inside your XML parsing block where files are written to disk)
echo "$target_path" >> .ralph/aymm-touched-files.log

run_test_command() {
    local arch_file="${SCRIPT_DIR}/ARCHITECTURE.md"
    if [[ ! -f "$arch_file" ]]; then
        echo "Error: ARCHITECTURE.md not found" >&2
        return 2
    fi

    local test_cmd
    test_cmd="$(awk '/^## Test Command/{found=1; next} found && /^```/{found=2; next} found==2 && /^```/{exit} found==2{print}' "$arch_file" | head -1)"

    if [[ -z "$test_cmd" ]]; then
        echo "Error: could not find test command in ARCHITECTURE.md" >&2
        return 2
    fi

    echo "Running test: $test_cmd"
    
    # Capture stderr to a temporary log so the orchestrator loop can record it
    if eval "$test_cmd" 2> ".ralph/aymm-test-error.log"; then
        rm -f ".ralph/aymm-test-error.log"
        return 0
    else
        return 2
    fi
}

```

### C. Upgrading `aymm-loop.sh` (The Logging and Phase Review Orchestrator)

We modify the inner execution loop's response handler and implement the conditional check for phase completion:

```bash
    # Run the per-provider task step
    exit_code=0
    bash "${WORKDIR}/run_agent_task.sh" --provider="${CURRENT_PROVIDER}" || exit_code=$?

    case "$exit_code" in
        0)
            reset_failure_count "$CURRENT_PROVIDER" "$CURRENT_TASK"
            echo "Provider ${CURRENT_PROVIDER} succeeded on task step."
            
            # Record successful modifications to the Flight Recorder
            {
                echo "=================================================="
                echo "PROVIDER SUCCESS: ${CURRENT_PROVIDER}"
                echo "TASK STEP COMPLETE: ${CURRENT_TASK}"
                echo "TIMESTAMP: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "STATUS: Passed syntax gate, applied to workspace."
                echo "--------------------------------------------------"
                echo "FILES MODIFIED IN THIS STEP:"
                cat .ralph/aymm-touched-files.log 2>/dev/null || echo "Unknown files."
                echo "=================================================="
                echo ""
            } >> ".ralph/aymm-flight-recorder.log"
            rm -f .ralph/aymm-touched-files.log
            ;;
        2)
            increment_failure_count "$CURRENT_PROVIDER" "$CURRENT_TASK"
            fail_count="$(get_failure_count "$CURRENT_PROVIDER" "$CURRENT_TASK")"
            echo "Provider ${CURRENT_PROVIDER} failed test gate (count: ${fail_count})"
            
            # Record the failure details to the Flight Recorder
            {
                echo "=================================================="
                echo "PROVIDER ATTEMPT FAILURE: ${CURRENT_PROVIDER}"
                echo "TASK STEP: ${CURRENT_TASK}"
                echo "TIMESTAMP: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "FAILURE NUMBER: ${fail_count}"
                echo "--------------------------------------------------"
                echo "TEST FAILURE OUTPUT:"
                cat .ralph/aymm-test-error.log 2>/dev/null || echo "No stderr captured."
                echo "=================================================="
                echo ""
            } >> ".ralph/aymm-flight-recorder.log"
            rm -f .ralph/aymm-test-error.log .ralph/aymm-touched-files.log
            ;;
        *)
            echo "Provider ${CURRENT_PROVIDER} returned exit ${exit_code} — switching provider"
            PROVIDER_INDEX=$(( PROVIDER_INDEX + 1 ))
            rm -f .ralph/aymm-touched-files.log
            ;;
    esac

    write_provider_state "${CURRENT_PROVIDER:-exhausted}" "$CURRENT_TASK"

    # ── PHASE GATE CHECK ───────────────────────────────────────────────────
    # Verify if any unchecked task items remain in the current phase file
    REMAINING_STEPS="$(grep -c '^\- \[ \]' "tasks/active/${CURRENT_TASK}.md" || true)"

    if [[ "$REMAINING_STEPS" -eq 0 ]]; then
        echo "🎉 Phase ${CURRENT_TASK} completed by free tier. Triggering Claude Phase Gate Review..."
        
        # 1. Parse phase testing configurations
        ADVANCED_TEST="$(awk '/^\*\*Advanced Test Command:\*\*/{print $0}' "tasks/active/${CURRENT_TASK}.md" | sed 's/\*\*Advanced Test Command:\*\* //')"
        REVIEW_CONSTRAINT="$(awk '/^\*\*Review Constraint:\*\*/{print $0}' "tasks/active/${CURRENT_TASK}.md" | sed 's/\*\*Review Constraint:\*\* //')"

        # 2. Execute advanced test suite
        if [[ -n "$ADVANCED_TEST" ]]; then
            echo "Running advanced integration tests: $ADVANCED_TEST"
            if ! eval "$ADVANCED_TEST" 2> .ralph/phase-test-error.log; then
                echo "❌ Integration tests failed. Escalating phase to Claude nest for repair."
                touch .ralph/aymm-escalate.txt
                break
            fi
        fi

        # 3. Execution of single-turn constrained code review via Claude
        # (Pass the contents of .ralph/aymm-flight-recorder.log and $REVIEW_CONSTRAINT)
        # If Claude flags a logical flaw (Response != "PHASE_PASSED"), treat as escalation.
        
        # On absolute phase verification success, wipe the flight recorder clean for the next phase
        rm -f .ralph/aymm-flight-recorder.log
    fi

```

---

## 3. Highly Constrained System Prompt Wrapper for Claude Phase Reviews

To prevent Claude from wandering off into long execution thoughts or consuming unnecessary tokens during the review, the single-turn call must wrap the context in this strict prompt wrapper:

```markdown
You are a Senior Systems Architect evaluating a Phase Gate Review within an autonomous framework.
The code changes applied by free-tier sub-agents have successfully passed local syntax and advanced integration gates.

Evaluate the complete history of modifications documented below for structural flaws or architectural regressions.
You must strictly adhere to this constraint: <INSERT_REVIEW_CONSTRAINT_VARIABLE>

[CRITICAL DIRECTIVE]
- If the implementation is structurally sound, respond with exactly one word: PHASE_PASSED
- If a deep logical error exists, output an XML block explaining the error so the repair sequence can capture it. Do not attempt a full rewrite.

```

---

## Why This Implementation is Optimal

* **Aggressive Quota Protection:** Claude remains completely passive while the free providers cycle through granular updates. She only executes a single, highly truncated verification call at the hard boundary of an entire phase milestone.
* **No Blind Spot Repetition:** If the free tiers fail or hit an integration roadblock, Claude doesn't run a standard guess-and-test approach. The comprehensive `aymm-flight-recorder.log` hands her a diagnostic map of precisely what was modified, how it failed, and what the logs reported across every attempted provider execution.