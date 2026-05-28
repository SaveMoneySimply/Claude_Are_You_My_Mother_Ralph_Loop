#!/usr/bin/env bash
#
# provider-status.sh
# Displays the configuration and status of the AYMM providers.

# Source the provider configuration
source "provider-config.sh"

echo "AYMM Provider Status"
# Print table header
printf "%-12s | %-25s | %-12s | %-14s\n" "Provider" "Model" "Max Attempts" "API Key Status"
printf "-------------|---------------------------|--------------|----------------\n"

# Initialize counters for summary
keys_set_count=0
keys_missing_count=0

# Iterate over providers and print their status
for provider in "${PROVIDERS[@]}"; do
    model=$(provider_model "$provider")
    max_attempts=$(provider_max_attempts "$provider")
    api_key_var_name=$(provider_api_key_var "$provider")
    
    key_status="missing"
    # Check if the environment variable corresponding to the key_var_name is set and non-empty
    if [[ -n "${!api_key_var_name}" ]]; then
        key_status="set"
        ((keys_set_count++))
    else
        ((keys_missing_count++))
    fi

    printf "%-12s | %-25s | %-12s | %-14s\n" "$provider" "$model" "$max_attempts" "$key_status"
done

# Add a separator line before the summary
printf "-------------|---------------------------|--------------|----------------\n"
printf "API Key Summary: %d set, %d missing\n" "$keys_set_count" "$keys_missing_count"
