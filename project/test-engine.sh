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
