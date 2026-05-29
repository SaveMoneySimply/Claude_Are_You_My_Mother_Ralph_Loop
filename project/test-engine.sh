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
