#!/usr/bin/env bash
# run_agent_task.sh — per-provider task runner for AYMM loop
# Usage: bash run_agent_task.sh --provider=<name>
# Providers: gemini, mistral, groq, openrouter

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

PROVIDER=""

for arg in "$@"; do
    case "$arg" in
        --provider=*)
            PROVIDER="${arg#--provider=}"
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            ;;
    esac
done

usage() {
    echo "Usage: bash run_agent_task.sh --provider=<name>" >&2
    echo "Providers: gemini, mistral, groq, openrouter" >&2
    exit 1
}

if [[ -z "$PROVIDER" ]]; then
    echo "Error: --provider is required" >&2
    usage
fi

# ---------------------------------------------------------------------------
# Load provider configuration
# ---------------------------------------------------------------------------

# shellcheck source=provider-config.sh
source "${SCRIPT_DIR}/provider-config.sh"

# Validate provider
API_URL="$(provider_api_url "$PROVIDER")"
if [[ -z "$API_URL" ]]; then
    echo "Error: unknown provider '${PROVIDER}'" >&2
    echo "Known providers: ${PROVIDERS[*]}" >&2
    usage
fi

MODEL="$(provider_model "$PROVIDER")"
API_KEY_VAR="$(provider_api_key_var "$PROVIDER")"
API_FORMAT="$(provider_api_format "$PROVIDER")"

# ---------------------------------------------------------------------------
# Context bundler
# ---------------------------------------------------------------------------

bundle_context() {
    local last_task_file="${SCRIPT_DIR}/.ralph/last-task.txt"
    if [[ ! -f "$last_task_file" ]]; then
        echo "Error: .ralph/last-task.txt not found" >&2
        return 1
    fi

    local task_name
    task_name="$(cat "$last_task_file")"
    local task_file="${SCRIPT_DIR}/tasks/2_active/${task_name}.md"

    if [[ ! -f "$task_file" ]]; then
        echo "Error: task file not found: $task_file" >&2
        return 1
    fi

    # Find next unchecked step
    local next_step
    next_step="$(grep -m1 -- '^\- \[ \]' "$task_file" || true)"
    if [[ -z "$next_step" ]]; then
        echo "Error: no unchecked steps found in $task_file" >&2
        return 1
    fi

    local task_content
    task_content="$(cat "$task_file")"

    # Project overview from ARCHITECTURE.md (everything before ## Directory Structure)
    local arch_overview=""
    if [[ -f "${SCRIPT_DIR}/ARCHITECTURE.md" ]]; then
        arch_overview="$(awk '/^## Directory/{exit} {print}' "${SCRIPT_DIR}/ARCHITECTURE.md")"
    fi

    # Phase tasks — all tasks across all four directories with the same phase prefix
    local phase="${task_name%%-*}"
    local phase_tasks=""
    if [[ "$phase" =~ ^phase[0-9]+ ]]; then
        while IFS= read -r f; do
            [[ -f "$f" ]] || continue
            phase_tasks+="### $(basename "$f")"$'\n'
            phase_tasks+="$(cat "$f")"$'\n\n'
        done < <(find "${SCRIPT_DIR}/tasks/0_backlog" "${SCRIPT_DIR}/tasks/1_queue" \
                      "${SCRIPT_DIR}/tasks/2_active" "${SCRIPT_DIR}/tasks/3_done" \
                      -name "${phase}-*.md" 2>/dev/null | sort)
    fi

    # Previous phase review (phase N-1 only)
    local prev_review=""
    local phase_num="${phase#phase}"
    if [[ "$phase_num" =~ ^[0-9]+$ ]] && (( phase_num > 1 )); then
        local prev_file="${SCRIPT_DIR}/handoffs/phase$(( phase_num - 1 ))-review.md"
        [[ -f "$prev_file" ]] && prev_review="$(cat "$prev_file")"
    fi

    local prompt=""
    prompt="${prompt}You are an autonomous coding agent. Your task is described below."$'\n\n'

    if [[ -n "$arch_overview" ]]; then
        prompt="${prompt}## Project overview"$'\n\n'
        prompt="${prompt}${arch_overview}"$'\n\n'
    fi

    if [[ -n "$prev_review" ]]; then
        prompt="${prompt}## Previous phase review"$'\n\n'
        prompt="${prompt}${prev_review}"$'\n\n'
    fi

    if [[ -n "$phase_tasks" ]]; then
        prompt="${prompt}## Phase task overview"$'\n\n'
        prompt="${prompt}${phase_tasks}"$'\n\n'
    fi

    prompt="${prompt}## Current task step"$'\n\n'
    prompt="${prompt}${next_step}"$'\n\n'
    prompt="${prompt}## Task context"$'\n\n'
    prompt="${prompt}${task_content}"$'\n\n'

    # Append content of files mentioned in the step (backtick or single-quoted names)
    local fname
    while IFS= read -r fname; do
        [[ -z "$fname" ]] && continue
        if [[ -f "${SCRIPT_DIR}/${fname}" ]]; then
            prompt="${prompt}## File: ${fname}"$'\n'
            prompt="${prompt}$(cat "${SCRIPT_DIR}/${fname}")"$'\n\n'
        fi
    done < <(echo "$next_step" | grep -oE '[a-zA-Z0-9_./\-]+\.(sh|md|js|ts|py|json|txt)' || true)

    prompt="${prompt}## Response format"$'\n'
    prompt="${prompt}Return any file changes as XML blocks:"$'\n'
    prompt="${prompt}<file path=\"relative/path/to/file\">"$'\n'
    prompt="${prompt}...full file content..."$'\n'
    prompt="${prompt}</file>"$'\n'
    prompt="${prompt}Write every file that needs to be created or modified. Do not truncate file contents."$'\n'

    printf '%s' "$prompt"
}

# ---------------------------------------------------------------------------
# HTTP status handler
# ---------------------------------------------------------------------------

handle_http_status() {
    local status="$1"
    case "$status" in
        200) return 0 ;;
        429)
            echo "Error: rate limited (429)" >&2
            exit 100
            ;;
        403)
            echo "Error: forbidden (403) — provider may be exhausted" >&2
            exit 101
            ;;
        *)
            echo "Error: unexpected HTTP status ${status}" >&2
            exit 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# API call — Gemini
# ---------------------------------------------------------------------------

call_gemini() {
    local prompt="$1"
    local tmp_response="$2"
    local api_key
    api_key="${!API_KEY_VAR:-}"

    if [[ -z "$api_key" ]]; then
        echo "Error: ${API_KEY_VAR} is not set" >&2
        return 1
    fi

    local payload
    payload="$(jq -n --arg text "$prompt" \
        '{"contents":[{"parts":[{"text":$text}]}]}')"

    local http_status
    http_status="$(curl -s -o "$tmp_response" -w "%{http_code}" \
        -X POST "${API_URL}?key=${api_key}" \
        -H "Content-Type: application/json" \
        -d "$payload")"

    handle_http_status "$http_status"
}

# ---------------------------------------------------------------------------
# API call — OpenAI-compatible (Mistral, Groq, OpenRouter)
# ---------------------------------------------------------------------------

call_openai_compat() {
    local prompt="$1"
    local tmp_response="$2"
    local api_key
    api_key="${!API_KEY_VAR:-}"

    if [[ -z "$api_key" ]]; then
        echo "Error: ${API_KEY_VAR} is not set" >&2
        return 1
    fi

    local payload
    payload="$(jq -n --arg model "$MODEL" --arg content "$prompt" \
        '{"model":$model,"messages":[{"role":"user","content":$content}]}')"

    local http_status
    http_status="$(curl -s -o "$tmp_response" -w "%{http_code}" \
        -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${api_key}" \
        -d "$payload")"

    handle_http_status "$http_status"
}

# ---------------------------------------------------------------------------
# XML response parser
# ---------------------------------------------------------------------------

parse_and_apply_response() {
    local raw_response="$1"

    # Extract text content from API response
    local text_content=""
    if [[ "$API_FORMAT" == "gemini" ]]; then
        text_content="$(jq -r '.candidates[0].content.parts[0].text // ""' "$raw_response")"
    else
        text_content="$(jq -r '.choices[0].message.content // ""' "$raw_response")"
    fi

    if [[ -z "$text_content" ]]; then
        echo "Error: empty response from API" >&2
        return 1
    fi

    # Write text content to a temp file for perl to process
    local tmp_text
    tmp_text="$(mktemp /tmp/aymm-text-XXXXXX.txt)"
    printf '%s' "$text_content" > "$tmp_text"

    # Extract <file path="...">...</file> blocks and apply them
    local files_written=0
    local fpath content full_path

    while IFS= read -r -d $'\x00' block; do
        # Extract path from opening tag
        fpath="$(echo "$block" | head -1 | grep -oE 'path="[^"]+"' | sed 's/path="\(.*\)"/\1/')"
        [[ -z "$fpath" ]] && continue

        # Strip opening and closing tags to get content
        content="$(echo "$block" | tail -n +2 | head -n -1)"

        # Write file creating parent dirs as needed
        full_path="${SCRIPT_DIR}/${fpath}"
        mkdir -p "$(dirname "$full_path")"
        printf '%s\n' "$content" > "$full_path"
        echo "Wrote: $fpath"
        files_written=$(( files_written + 1 ))
    done < <(perl -0777 -ne 'while (/<file\s[^>]*>.*?<\/file>/gs) { print $&, "\x00" }' "$tmp_text")

    rm -f "$tmp_text"

    if [[ "$files_written" -eq 0 ]]; then
        echo "Warning: no file blocks found in response" >&2
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------

run_test_command() {
    local arch_file="${SCRIPT_DIR}/ARCHITECTURE.md"
    if [[ ! -f "$arch_file" ]]; then
        echo "Error: ARCHITECTURE.md not found" >&2
        return 2
    fi

    # Extract test command from ARCHITECTURE.md (block under ## Test Command)
    local test_cmd
    test_cmd="$(awk '/^## Test Command/{found=1; next} found && /^```/{found=2; next} found==2 && /^```/{exit} found==2{print}' "$arch_file" | head -1)"

    if [[ -z "$test_cmd" ]]; then
        echo "Error: could not find test command in ARCHITECTURE.md" >&2
        return 2
    fi

    local error_log="${SCRIPT_DIR}/.ralph/last-test-error.txt"
    local test_log="${SCRIPT_DIR}/.ralph/test-log.jsonl"
    local outcome output

    echo "Running test: $test_cmd"
    if output="$(eval "$test_cmd" 2>&1)"; then
        outcome="pass"
        rm -f "$error_log"
        echo "$output"
    else
        outcome="fail"
        printf '%s' "$output" > "$error_log"
        echo "$output"
    fi

    printf '%s\n' "$(jq -n \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg task "$(cat "${SCRIPT_DIR}/.ralph/last-task.txt" 2>/dev/null)" \
        --arg provider "${PROVIDER}" \
        --arg outcome "$outcome" \
        --arg output "$output" \
        '{ts:$ts, task:$task, provider:$provider, outcome:$outcome, output:$output}')" \
        >> "$test_log"

    [[ "$outcome" == "pass" ]] && return 0 || return 2
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    echo "Provider: ${PROVIDER} | Model: ${MODEL} | Format: ${API_FORMAT}"

    # Bundle context
    local prompt
    prompt="$(bundle_context)"

    if [[ -z "$prompt" ]]; then
        echo "Error: context bundler returned empty prompt" >&2
        exit 1
    fi

    # Temp file for raw API response
    local tmp_response
    tmp_response="$(mktemp /tmp/aymm-response-XXXXXX.json)"
    trap 'rm -f "$tmp_response"' EXIT

    # Call appropriate API
    if [[ "$API_FORMAT" == "gemini" ]]; then
        call_gemini "$prompt" "$tmp_response"
    else
        call_openai_compat "$prompt" "$tmp_response"
    fi

    # Parse and apply file changes
    parse_and_apply_response "$tmp_response"

    # Run test suite
    run_test_command
}

main "$@"
