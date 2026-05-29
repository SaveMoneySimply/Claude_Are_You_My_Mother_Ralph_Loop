#!/bin/bash

# Detect the script's directory and change to it
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

# Initialize test counters
PASS_COUNT=0
FAIL_COUNT=0

# Create a temporary directory for tests
TESTDIR=$(mktemp -d)

# Register a trap to clean up the temporary directory on exit
trap "rm -rf $TESTDIR" EXIT

# Helper functions
pass() {
  echo "  PASS: $1"
  ((PASS_COUNT++))
}

fail() {
  echo "  FAIL: $1 — $2"
  ((FAIL_COUNT++))
}

assert_eq() {
  if [ "$2" = "$3" ]; then
    pass "$1"
  else
    fail "$1" "Expected '$2', but got '$3'"
  fi
}

assert_contains() {
  if [[ "$3" == *"$2"* ]]; then
    pass "$1"
  else
    fail "$1" "Needle '$2' not found in haystack '$3'"
  fi
}

assert_file_exists() {
  if [ -e "$2" ]; then
    pass "$1"
  else
    fail "$1" "File '$2' does not exist"
  fi
}

FORCE_SPLIT_STEP=50

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

setup_workspace() {
  mkdir -p "$TESTDIR/tasks/0_backlog" "$TESTDIR/tasks/1_queue" "$TESTDIR/tasks/2_active" "$TESTDIR/tasks/3_done"
  echo "- [ ] Step 1" > "$TESTDIR/tasks/1_queue/task.md"
  echo "- [ ] Step 2" >> "$TESTDIR/tasks/1_queue/task.md"
}

teardown_workspace() {
  rm -rf "$TESTDIR/tasks"
}

# Syntax checks for engine scripts
echo "=== Syntax checks ==="
if bash -n loop.sh 2>/dev/null; then pass "syntax: loop.sh"; else fail "syntax: loop.sh" "$(bash -n loop.sh 2>&1)"; fi
if bash -n aymm-loop.sh 2>/dev/null; then pass "syntax: aymm-loop.sh"; else fail "syntax: aymm-loop.sh" "$(bash -n aymm-loop.sh 2>&1)"; fi
if bash -n ralph.sh 2>/dev/null; then pass "syntax: ralph.sh"; else fail "syntax: ralph.sh" "$(bash -n ralph.sh 2>&1)"; fi
if bash -n run_agent_task.sh 2>/dev/null; then pass "syntax: run_agent_task.sh"; else fail "syntax: run_agent_task.sh" "$(bash -n run_agent_task.sh 2>&1)"; fi
if bash -n apply_changes.sh 2>/dev/null; then pass "syntax: apply_changes.sh"; else fail "syntax: apply_changes.sh" "$(bash -n apply_changes.sh 2>&1)"; fi
if bash -n provider-config.sh 2>/dev/null; then pass "syntax: provider-config.sh"; else fail "syntax: provider-config.sh" "$(bash -n provider-config.sh 2>&1)"; fi
if bash -n provider-status.sh 2>/dev/null; then pass "syntax: provider-status.sh"; else fail "syntax: provider-status.sh" "$(bash -n provider-status.sh 2>&1)"; fi
if bash -n init-firewall.sh 2>/dev/null; then pass "syntax: init-firewall.sh"; else fail "syntax: init-firewall.sh" "$(bash -n init-firewall.sh 2>&1)"; fi
if bash -n test-providers.sh 2>/dev/null; then pass "syntax: test-providers.sh"; else fail "syntax: test-providers.sh" "$(bash -n test-providers.sh 2>&1)"; fi

echo ""
echo "=== escalation_edge ==="
# (a) haiku at step 0 returns something starting with "haiku"
result=$(get_step_spec haiku "" 0)
if [[ "$result" == haiku* ]]; then pass "escalation_edge: haiku step 0 starts with haiku"; else fail "escalation_edge: haiku step 0 starts with haiku" "got '$result'"; fi

# (b) opus max at step 1 returns "context_expansion" (no same-model-max, no higher models)
result=$(get_step_spec opus max 1)
assert_eq "escalation_edge: opus max step 1 = context_expansion" "context_expansion" "$result"

# (c) sonnet max at step 1 returns "opus:low" (skips same-model-max since already max)
result=$(get_step_spec sonnet max 1)
assert_eq "escalation_edge: sonnet max step 1 = opus:low" "opus:low" "$result"

# (d) any model at step >= 50 returns "split" (FORCE_SPLIT_STEP)
result=$(get_step_spec sonnet high 50)
assert_eq "escalation_edge: step 50 = split" "split" "$result"

echo ""
echo "SUMMARY: $PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
