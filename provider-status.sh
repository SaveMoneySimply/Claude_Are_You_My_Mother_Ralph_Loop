#!/usr/bin/env bash
#
# provider-status.sh
# Displays the configuration and status of the AYMM providers.

# Source the provider configuration
source "provider-config.sh"

echo "AYMM Provider Status"
echo "--------------------"

# Print table header
printf "%-12s | %-25s | %-12s\n" "Provider" "Model" "Max Attempts"
printf "-------------|---------------------------|--------------\n"

# Iterate over providers and print their status
for provider in "${PROVIDERS[@]}"; do
    model=$(provider_model "$provider")
    max_attempts=$(provider_max_attempts "$provider")
    printf "%-12s | %-25s | %-12s\n" "$provider" "$model" "$max_attempts"
done
