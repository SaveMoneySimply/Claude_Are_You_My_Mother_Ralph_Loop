#!/usr/bin/env bash
# Provider configuration for AYMM multi-provider loop.
# Source this file to get PROVIDERS array and per-provider config functions.
#
# All providers are Groq model variants sharing one GROQ_API_KEY.
# Rate limits are per-model, giving ~72,000+ free requests/day across all variants.
#
# Model IDs verified at console.groq.com/playground — re-verify periodically.
#
# RPD budget by tier:
#   14,400 RPD: groq_8b, groq_scout, groq_qwen32b, groq_deepseek, groq_kimi
#    1,000 RPD: groq_70b, groq_120b  (quality reserve — spend wisely)
#      250 RPD: groq_compound        (director only — not in default PROVIDERS)

# Default escalation order: fast workhorse → reasoning → quality reserve
PROVIDERS=(groq_8b groq_scout groq_qwen32b groq_deepseek groq_kimi groq_70b groq_120b)

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
        groq_qwen32b)   echo "qwen-qwq-32b" ;;
        groq_deepseek)  echo "deepseek-r1-distill-llama-70b" ;;
        groq_kimi)      echo "kimi-k2-instruct" ;;
        groq_70b)       echo "llama-3.3-70b-versatile" ;;
        groq_120b)      echo "gpt-oss-120b" ;;
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
        groq_qwen32b)   echo 2 ;;
        groq_deepseek)  echo 2 ;;
        groq_kimi)      echo 2 ;;
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
    echo "aymm-1.1"
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
