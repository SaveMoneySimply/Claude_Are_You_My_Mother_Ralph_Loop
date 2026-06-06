# Task — use-dynamic-tpm-threshold

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 12000 · **Attempts:** 0/3
**Run:** aymm
**Allowed files:** aymm-loop.sh

## Steps

- [x] In aymm-loop.sh, inside the Phase 3 context override block, replace the hardcoded `500` threshold with a dynamic value. The current check reads `if (( CONTEXT_LINES > 500 ));`. Replace it with `if (( CONTEXT_LINES > $(( $(provider_tpm "${PROVIDERS[$PROVIDER_INDEX]:-groq_8b}") / 12 )) ));`. Do not change anything else in the block. Done when: aymm-loop.sh passes bash -n and the string `CONTEXT_LINES > 500` no longer appears in the file. -- test: bash -n aymm-loop.sh && ! grep -q 'CONTEXT_LINES > 500' aymm-loop.sh -- files: aymm-loop.sh:567-590 -- mode: aymm

## Smoke test
`bash -n aymm-loop.sh` exits 0.
Grep confirms: `grep 'provider_tpm' aymm-loop.sh` shows the dynamic threshold line.
