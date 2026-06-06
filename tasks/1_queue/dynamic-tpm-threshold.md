# Task — dynamic-tpm-threshold

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 20000 · **Attempts:** 0/3
**Run:** aymm
**Allowed files:** provider-config.sh, aymm-loop.sh

## Steps

- [ ] Add a `provider_tpm()` function to provider-config.sh after the existing `provider_api_format()` function. The function takes a provider alias as $1 and returns its Tokens Per Minute limit as a plain integer. Use these values: groq_8b=6000, groq_scout=30000, groq_qwen3=6000, groq_20b=8000, groq_70b=12000, groq_120b=8000, groq_compound=70000, default=6000. Done when: the function exists and `provider_tpm groq_scout` returns 30000. -- test: bash -n provider-config.sh && grep -q 'provider_tpm()' provider-config.sh -- files: provider-config.sh:56-68 -- mode: aymm

- [ ] In aymm-loop.sh, inside the Phase 3 context override block, replace the hardcoded `500` line threshold with a dynamic value computed from the current provider's TPM. Compute it as: `$(( $(provider_tpm "${PROVIDERS[$PROVIDER_INDEX]:-groq_8b}") / 12 ))`. This gives 500 for 6K TPM models, 1000 for 12K TPM models, and 2500 for scout's 30K TPM. The check should read: `if (( CONTEXT_LINES > $(( $(provider_tpm "${PROVIDERS[$PROVIDER_INDEX]:-groq_8b}") / 12 )) ))`. Done when: aymm-loop.sh passes bash -n and the hardcoded 500 no longer appears in the Phase 3 block. -- test: bash -n aymm-loop.sh && ! grep -q 'CONTEXT_LINES > 500' aymm-loop.sh -- files: aymm-loop.sh:567-587 -- mode: aymm

## Smoke test
Run `bash -n provider-config.sh && bash -n aymm-loop.sh` — both should exit 0.
Source provider-config.sh and call `provider_tpm groq_70b` — should print 12000.
