#!/usr/bin/env bash
# Provider configuration for AYMM multi-provider loop.
# Source this file to get PROVIDERS array and per-provider config functions.
#
# All providers are Groq model variants sharing one GROQ_API_KEY.
# Rate limits verified against console.groq.com/docs/rate-limits (June 2026).
#
# RPD budget by tier:
#   14,400 RPD: groq_8b only — the free workhorse
#    1,000 RPD: groq_scout, groq_qwen3, groq_20b, groq_70b, groq_120b
#      250 RPD: groq_compound (director only — not in default PROVIDERS)
#
# Default escalation: fast workhorse → coder/reasoner → speed-quality bridge → quality reserve → max
# Phase 2 (aymm-loop.sh) overrides this per-task based on Effort: header.

PROVIDERS=(groq_8b groq_qwen3 groq_20b groq_70b groq_120b)

provider_api_url() {
    case "$1" in
        groq_*)  echo "https://api.groq.com/openai/v1/chat/completions" ;;
        *)       echo "" ;;
    esac
}

provider_model() {
    case "$1" in
        groq_8b)        echo "llama-3.1-8b-instant" ;;
        groq_scout)     echo "meta-llama/llama-4-scout-17b-16e-instruct" ;;
        groq_qwen3)     echo "qwen/qwen3-32b" ;;
        groq_20b)       echo "openai/gpt-oss-20b" ;;
        groq_70b)       echo "llama-3.3-70b-versatile" ;;
        groq_120b)      echo "openai/gpt-oss-120b" ;;
        groq_compound)  echo "compound-beta" ;;
        *)              echo "" ;;
    esac
}

provider_api_key_var() {
    case "$1" in
        groq_*)  echo "GROQ_API_KEY" ;;
        *)       echo "" ;;
    esac
}

# Max consecutive failures before switching to the next provider.
# Lower = conserve scarce quota; higher = give the model more self-correction chances.
provider_max_attempts() {
    case "$1" in
        groq_8b)        echo 2 ;;
        groq_scout)     echo 2 ;;
        groq_qwen3)     echo 2 ;;
        groq_20b)       echo 2 ;;
        groq_70b)       echo 3 ;;  # quality reserve — worth more attempts
        groq_120b)      echo 2 ;;
        groq_compound)  echo 1 ;;  # 250 RPD — use once, don't retry
        *)              echo 2 ;;
    esac
}

# api_format: "openai" uses OpenAI-compatible chat completions
provider_api_format() {
    case "$1" in
        groq_*)  echo "openai" ;;
        *)       echo "" ;;
    esac
}

loop_version() {
    echo "aymm-1.2"
}

provider_count() {
    echo "${#PROVIDERS[@]}"
}

has_provider() {
    local name="$1"
    for p in "${PROVIDERS[@]}"; do
        [[ "$p" == "$name" ]] && return 0
    done
    return 1
}
