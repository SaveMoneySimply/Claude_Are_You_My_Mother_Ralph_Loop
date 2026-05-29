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
    printf '%s\n' "$next_step" > "${SCRIPT_DIR}/.ralph/last-step.txt"
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
    prompt="${prompt}IMPORTANT: The <context> blocks below are read-only background information."$'\n'
    prompt="${prompt}Do NOT write <file> blocks for context sections. Only write <file> or <edit> blocks"$'\n'
    prompt="${prompt}for files that must be created or changed to complete the task step."$'\n\n'

    if [[ -n "$arch_overview" ]]; then
        prompt="${prompt}<context name=\"project-overview\">"$'\n'
        prompt="${prompt}${arch_overview}"$'\n'
        prompt="${prompt}</context>"$'\n\n'
    fi

    if [[ -n "$prev_review" ]]; then
        prompt="${prompt}<context name=\"previous-phase-review\">"$'\n'
        prompt="${prompt}${prev_review}"$'\n'
        prompt="${prompt}</context>"$'\n\n'
    fi

    if [[ -n "$phase_tasks" ]]; then
        prompt="${prompt}<context name=\"phase-task-overview\">"$'\n'
        prompt="${prompt}${phase_tasks}"$'\n'
        prompt="${prompt}</context>"$'\n\n'
    fi

    prompt="${prompt}## Current task step"$'\n\n'
    prompt="${prompt}${next_step}"$'\n\n'

    prompt="${prompt}<context name=\"task\">"$'\n'
    prompt="${prompt}${task_content}"$'\n'
    prompt="${prompt}</context>"$'\n\n'

    # Full failure history for this task across all providers
    local test_log="${SCRIPT_DIR}/.ralph/test-log.jsonl"
    if [[ -f "$test_log" ]]; then
        local failure_history
        failure_history="$(jq -r --arg t "$task_name" \
            'select(.task == $t and .outcome == "fail") |
             "[\(.ts)] \(.provider)\nCode written:\n\(.response)\nTest error:\n\(.output)\n---"' \
            "$test_log")"
        if [[ -n "$failure_history" ]]; then
            prompt="${prompt}<context name=\"previous-attempts\">"$'\n'
            prompt="${prompt}${failure_history}"$'\n'
            prompt="${prompt}</context>"$'\n\n'
            prompt="${prompt}Study what was tried and why it failed before writing your solution."$'\n\n'
        fi
    fi

    # Append content of files mentioned in the step (backtick or single-quoted names)
    local fname
    while IFS= read -r fname; do
        [[ -z "$fname" ]] && continue
        if [[ -f "${SCRIPT_DIR}/${fname}" ]]; then
            prompt="${prompt}<context name=\"file:${fname}\">"$'\n'
            prompt="${prompt}$(cat "${SCRIPT_DIR}/${fname}")"$'\n'
            prompt="${prompt}</context>"$'\n\n'
        fi
    done < <(echo "$next_step" | grep -oE '[a-zA-Z0-9_./\-]+\.(sh|md|js|ts|py|json|txt)' || true)

    prompt="${prompt}## Response format"$'\n\n'
    prompt="${prompt}Tasks involve either creating new files or editing existing ones. Use the appropriate format:"$'\n\n'
    prompt="${prompt}New file or full file replacement:"$'\n'
    prompt="${prompt}<file path=\"relative/path/to/file\">"$'\n'
    prompt="${prompt}...complete file content..."$'\n'
    prompt="${prompt}</file>"$'\n\n'
    prompt="${prompt}Surgical edit (replace lines start through end inclusive):"$'\n'
    prompt="${prompt}<edit path=\"relative/path\" start=\"10\" end=\"15\">"$'\n'
    prompt="${prompt}...replacement lines only..."$'\n'
    prompt="${prompt}</edit>"$'\n\n'
    prompt="${prompt}Delete a file:"$'\n'
    prompt="${prompt}<delete path=\"relative/path\"/>"$'\n\n'
    prompt="${prompt}Always include the updated task file with the completed step marked [x]."$'\n'
    prompt="${prompt}Do not truncate file contents."$'\n'

    printf '%s' "$prompt"
}

# ---------------------------------------------------------------------------
# HTTP status handler
# ---------------------------------------------------------------------------

handle_http_status() {
    local status="$1"
    local response_body_file="$2"

    if [[ "$status" -ne 200 ]]; then
        mkdir -p "${SCRIPT_DIR}/.ralph"

        local response_body=""
        if [[ -f "$response_body_file" ]]; then
            response_body="$(cat "$response_body_file")"
        fi

        local log_entry
        log_entry="$(jq -n \
            --arg ts "$(date +%s)" \
            --arg provider "$PROVIDER" \
            --arg status_code "$status" \
            --arg body "$response_body" \
            '{timestamp:($ts | tonumber), provider:$provider, http_status_code:($status_code | tonumber), response_body:$body}')"
        printf '%s\n' "$log_entry" >> "${SCRIPT_DIR}/.ralph/http-error-log.jsonl"
    fi

    case "$status" in
        200) return 0 ;;
        429)
            echo "Error: rate limited (429)" >&2
            exit 100
            ;;
        503)
            echo "Error: service unavailable (503) — treating as rate limit" >&2
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

    handle_http_status "$http_status" "$tmp_response"
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

    handle_http_status "$http_status" "$tmp_response"
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

    local tmp_text
    tmp_text="$(mktemp /tmp/aymm-text-XXXXXX.txt)"
    printf '%s' "$text_content" > "$tmp_text"
    # Persist for test log — run_test_command() reads this to record what was tried
    printf '%s' "$text_content" > "${SCRIPT_DIR}/.ralph/last-response.txt"
    local allowlist=""
    local last_task_name
    last_task_name="$(cat "${SCRIPT_DIR}/.ralph/last-task.txt" 2>/dev/null || echo "")"
    local at_file="${SCRIPT_DIR}/tasks/2_active/${last_task_name}.md"
    if [[ -n "$last_task_name" && -f "$at_file" ]]; then
        allowlist="$(grep -oP '(?<=\*\*Allowed files:\*\* ).*' "$at_file" | head -1 || true)"
    fi
    bash "${SCRIPT_DIR}/apply_changes.sh" "$tmp_text" "$SCRIPT_DIR" "$allowlist"
    local rc=$?
    rm -f "$tmp_text"
    return $rc
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

    # Extract test command: task file first, fall back to ARCHITECTURE.md
    local test_cmd=""
    local task_name
    task_name="$(cat "${SCRIPT_DIR}/.ralph/last-task.txt" 2>/dev/null || echo "")"
    local task_file="${SCRIPT_DIR}/tasks/2_active/${task_name}.md"
    if [[ -n "$task_name" && -f "$task_file" ]]; then
        test_cmd="$(grep -oP '(?<=\*\*Test command:\*\* ).*' "$task_file" | head -1 || true)"
    fi
    if [[ -z "$test_cmd" ]]; then
        test_cmd="$(awk '/^## Test Command/{found=1; next} found && /^```/{found=2; next} found==2 && /^```/{exit} found==2{print}' "$arch_file" | head -1)"
    fi

    if [[ -z "$test_cmd" ]]; then
        echo "Error: could not find test command in task file or ARCHITECTURE.md" >&2
        return 2
    fi

    local error_log="${SCRIPT_DIR}/.ralph/last-test-error.txt"
    local test_log="${SCRIPT_DIR}/.ralph/test-log.jsonl"
    local outcome output

    echo "Running test: $test_cmd"
    if output="$(eval "$test_cmd" 2>&1)"; then
        # Run per-step test if present (-- test: <cmd> at end of step text)
        local step_test step_output
        step_test="$(grep -oP '(?<=-- test: ).*' "${SCRIPT_DIR}/.ralph/last-step.txt" 2>/dev/null || true)"
        if [[ -n "$step_test" ]]; then
            echo "Running step test: $step_test"
            if step_output="$(eval "$step_test" 2>&1)"; then
                outcome="pass"
                rm -f "$error_log"
                echo "$step_output"
            else
                outcome="fail"
                printf '%s' "$step_output" > "$error_log"
                echo "$step_output"
            fi
        else
            outcome="pass"
            rm -f "$error_log"
            echo "$output"
        fi
    else
        outcome="fail"
        printf '%s' "$output" > "$error_log"
        echo "$output"
    fi

    local response
    response="$(cat "${SCRIPT_DIR}/.ralph/last-response.txt" 2>/dev/null || echo "")"

    local log_entry
    log_entry="$(jq -n \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg task "$(cat "${SCRIPT_DIR}/.ralph/last-task.txt" 2>/dev/null || true)" \
        --arg provider "${PROVIDER}" \
        --arg outcome "$outcome" \
        --arg output "$output" \
        --arg response "$response" \
        '{ts:$ts, task:$task, provider:$provider, outcome:$outcome, output:$output, response:$response}' \
        2>/dev/null || true)"
    [[ -n "$log_entry" ]] && printf '%s\n' "$log_entry" >> "$test_log" || true

    if [[ "$outcome" == "pass" ]]; then
        return 0
    else
        return 2
    fi
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

    # Temp file for raw API response — not local so the EXIT trap can see it
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

    # Capture what changed so we can roll back if the test fails.
    # Exclude tasks/ — the task mv (1_queue → 2_active) happened before this script
    # was called and must not be reverted, or the loop re-queues the task every iteration.
    local modified_files new_files
    modified_files=$(git -C "$SCRIPT_DIR" diff --name-only 2>/dev/null \
        | grep -v '^tasks/' || true)
    new_files=$(git -C "$SCRIPT_DIR" ls-files --others --exclude-standard 2>/dev/null \
        | grep -v '^\.ralph/' | grep -v '^tasks/' || true)

    # Run test — roll back any provider changes on failure
    run_test_command || {
        echo "Test failed — rolling back provider changes" >&2
        if [[ -n "$modified_files" ]]; then
            # shellcheck disable=SC2086
            git -C "$SCRIPT_DIR" checkout HEAD -- $modified_files 2>/dev/null || true
        fi
        if [[ -n "$new_files" ]]; then
            echo "$new_files" | xargs -I{} rm -f "${SCRIPT_DIR}/{}" 2>/dev/null || true
        fi
        exit 2
    }
}

main "$@"
