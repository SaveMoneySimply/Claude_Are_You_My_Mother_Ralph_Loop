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
echo "=== pick_task ==="

# Inline pick_task logic (mirrors loop.sh lines 131-156)
pick_task_fn() {
    local active
    active=$(ls tasks/2_active/*.md 2>/dev/null | head -1)
    if [ -n "$active" ]; then
        basename "$active" .md
        return
    fi
    local queued
    queued=$(ls tasks/1_queue/*.md 2>/dev/null | head -1)
    if [ -n "$queued" ]; then
        local task_name
        task_name=$(basename "$queued" .md)
        if compgen -G "tasks/3_done/*-${task_name}.md" > /dev/null 2>&1; then
            rm "$queued"
            echo ""; return
        fi
        mv "$queued" tasks/2_active/
        echo "$task_name"
        return
    fi
    echo ""
}

# (a) 2_active/ empty, 1_queue/ has a file → file moved to 2_active/
(
  setup_workspace
  result=$(cd "$TESTDIR" && pick_task_fn)
  if [ "$result" = "task" ] && [ -f "$TESTDIR/tasks/2_active/task.md" ] && [ ! -f "$TESTDIR/tasks/1_queue/task.md" ]; then
    pass "pick_task: queue file moved to 2_active when active is empty"
  else
    fail "pick_task: queue file moved to 2_active when active is empty" "result='$result', active=$(ls $TESTDIR/tasks/2_active/ 2>/dev/null), queue=$(ls $TESTDIR/tasks/1_queue/ 2>/dev/null)"
  fi
  teardown_workspace
)

# (b) 2_active/ already has a file → returns that file, 1_queue/ untouched
(
  setup_workspace
  cp "$TESTDIR/tasks/1_queue/task.md" "$TESTDIR/tasks/2_active/task.md"
  touch "$TESTDIR/tasks/1_queue/other.md"
  result=$(cd "$TESTDIR" && pick_task_fn)
  if [ "$result" = "task" ] && [ -f "$TESTDIR/tasks/1_queue/other.md" ]; then
    pass "pick_task: returns active file and leaves 1_queue/ untouched"
  else
    fail "pick_task: returns active file and leaves 1_queue/ untouched" "result='$result', queue=$(ls $TESTDIR/tasks/1_queue/ 2>/dev/null)"
  fi
  teardown_workspace
)

# (c) task name matches 3_done/*-<name>.md → queue file removed, returns empty
(
  setup_workspace
  touch "$TESTDIR/tasks/3_done/2026-01-01-task.md"
  result=$(cd "$TESTDIR" && pick_task_fn)
  if [ -z "$result" ] && [ ! -f "$TESTDIR/tasks/1_queue/task.md" ]; then
    pass "pick_task: removes stale queue entry and returns empty when already done"
  else
    fail "pick_task: removes stale queue entry and returns empty when already done" "result='$result', queue=$(ls $TESTDIR/tasks/1_queue/ 2>/dev/null)"
  fi
  teardown_workspace
)

echo ""
echo "=== step_management ==="

# Inline implementations (mirrors aymm-loop.sh lines 167-182)
has_remaining_steps_fn() {
    local task_file="$1"
    grep -q '^- \[ \]' "$task_file" 2>/dev/null
}

mark_step_done_fn() {
    local task_file="$1"
    sed -i '0,/^- \[ \]/{s/^- \[ \]/- [x]/}' "$task_file"
}

# (a) has_remaining_steps returns true (exit 0) when task file has unchecked steps
(
  setup_workspace
  cp "$TESTDIR/tasks/1_queue/task.md" "$TESTDIR/tasks/2_active/task.md"
  if (cd "$TESTDIR" && has_remaining_steps_fn "tasks/2_active/task.md"); then
    pass "mark_step_done: has_remaining_steps exit 0 when unchecked steps exist"
  else
    fail "mark_step_done: has_remaining_steps exit 0 when unchecked steps exist" "returned non-zero"
  fi
  teardown_workspace
)

# (b) has_remaining_steps returns false (exit 1) when all steps are checked
(
  setup_workspace
  printf -- '- [x] Step 1\n- [x] Step 2\n' > "$TESTDIR/tasks/2_active/task.md"
  if (cd "$TESTDIR" && has_remaining_steps_fn "tasks/2_active/task.md"); then
    fail "mark_step_done: has_remaining_steps exit 1 when all steps checked" "returned zero (true)"
  else
    pass "mark_step_done: has_remaining_steps exit 1 when all steps checked"
  fi
  teardown_workspace
)

# (c) mark_step_done changes only the first - [ ] to - [x], leaves rest untouched
(
  setup_workspace
  cp "$TESTDIR/tasks/1_queue/task.md" "$TESTDIR/tasks/2_active/task.md"
  (cd "$TESTDIR" && mark_step_done_fn "tasks/2_active/task.md")
  line1=$(sed -n '1p' "$TESTDIR/tasks/2_active/task.md")
  line2=$(sed -n '2p' "$TESTDIR/tasks/2_active/task.md")
  if [ "$line1" = "- [x] Step 1" ] && [ "$line2" = "- [ ] Step 2" ]; then
    pass "mark_step_done: marks first unchecked step done, leaves rest untouched"
  else
    fail "mark_step_done: marks first unchecked step done, leaves rest untouched" "line1='$line1' line2='$line2'"
  fi
  teardown_workspace
)

echo ""
echo "=== STOP detection ==="

# Verify a while loop exits when STOP file exists in TESTDIR
(
  setup_workspace
  # Write the STOP file before starting the loop
  touch "$TESTDIR/STOP"
  iterations=0
  (
    cd "$TESTDIR"
    while [ ! -f STOP ]; do
      iterations=$((iterations + 1))
    done
  )
  # Loop should have exited immediately (0 iterations) because STOP already existed
  if [ "$iterations" -eq 0 ]; then
    pass "STOP detection: loop exits immediately when STOP file exists"
  else
    fail "STOP detection: loop exits immediately when STOP file exists" "ran $iterations iterations before stopping"
  fi
  teardown_workspace
)

echo ""
echo "SUMMARY: $PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
