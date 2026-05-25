#!/usr/bin/env bash
# Test each configured provider by sending a minimal prompt.
# If the provider's API key env var is set, sends a request and reports HTTP status + response snippet.
# If not set, prints SKIPPED. Always exits 0.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=provider-config.sh
source "${SCRIPT_DIR}/provider-config.sh"

test_provider() {
    local provider="$1"
    local key_var
    key_var="$(provider_api_key_var "$provider")"
    local api_key="${!key_var:-}"

    if [ -z "$api_key" ]; then
        echo "${provider}: SKIPPED (no key)"
        return
    fi

    local url model format
    url="$(provider_api_url "$provider")"
    model="$(provider_model "$provider")"
    format="$(provider_api_format "$provider")"

    local http_status response body

    if [ "$format" = "gemini" ]; then
        body="$(printf '{"contents":[{"parts":[{"text":"Say hello in one word."}]}]}' )"
        response="$(curl -s -w "\n%{http_code}" \
            -H "Content-Type: application/json" \
            -d "$body" \
            "${url}?key=${api_key}" 2>&1)"
    else
        body="$(printf '{"model":"%s","messages":[{"role":"user","content":"Say hello in one word."}],"max_tokens":20}' "$model")"
        response="$(curl -s -w "\n%{http_code}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${api_key}" \
            -d "$body" \
            "$url" 2>&1)"
    fi

    http_status="$(echo "$response" | tail -1)"
    local resp_body
    resp_body="$(echo "$response" | head -n -1)"
    local snippet
    snippet="$(echo "$resp_body" | head -c 100)"

    echo "${provider}: HTTP ${http_status} | ${snippet}"
}

for provider in "${PROVIDERS[@]}"; do
    test_provider "$provider"
done

exit 0
