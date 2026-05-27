#!/usr/bin/env bash
# Provider configuration for AYMM multi-provider loop.
# Source this file to get PROVIDERS array and per-provider config functions.

PROVIDERS=(gemini groq mistral openrouter)

# Per-provider configuration.
# Usage: provider_api_url <provider>
#        provider_model <provider>
#        provider_api_key_var <provider>
#        provider_api_format <provider>

provider_api_url() {
    case "$1" in
        gemini)      echo "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" ;;
        mistral)     echo "https://api.mistral.ai/v1/chat/completions" ;;
        groq)        echo "https://api.groq.com/openai/v1/chat/completions" ;;
        openrouter)  echo "https://openrouter.ai/api/v1/chat/completions" ;;
        *)           echo "" ;;
    esac
}

provider_model() {
    case "$1" in
        gemini)      echo "gemini-2.5-flash" ;;
        mistral)     echo "codestral-latest" ;;
        groq)        echo "llama-3.3-70b-versatile" ;;
        openrouter)  echo "poolside/laguna-m.1:free" ;;
        *)           echo "" ;;
    esac
}

provider_api_key_var() {
    case "$1" in
        gemini)      echo "GEMINI_API_KEY" ;;
        mistral)     echo "MISTRAL_API_KEY" ;;
        groq)        echo "GROQ_API_KEY" ;;
        openrouter)  echo "OPENROUTER_API_KEY" ;;
        *)           echo "" ;;
    esac
}

# Max consecutive failures before switching to the next provider.
# Lower = conserve scarce quota; higher = give the model more self-correction chances.
provider_max_attempts() {
    case "$1" in
        gemini)      echo 3 ;;
        groq)        echo 3 ;;
        mistral)     echo 2 ;;
        openrouter)  echo 1 ;;
        *)           echo 3 ;;
    esac
}

# api_format: "gemini" uses Google's generateContent format; "openai" uses OpenAI-compatible chat completions
provider_api_format() {
    case "$1" in
        gemini)      echo "gemini" ;;
        mistral)     echo "openai" ;;
        groq)        echo "openai" ;;
        openrouter)  echo "openai" ;;
        *)           echo "" ;;
    esac
}
