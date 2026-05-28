# Task — validate-per-step-test

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 8000 · **Attempts:** 0/3

## Steps
- [ ] Step 1: Edit `provider-config.sh` — add a `loop_version()` function at the bottom of the file that echoes "aymm-1.0" — done when: `bash -n provider-config.sh` passes and the function exists -- test: grep -q 'loop_version' provider-config.sh
- [ ] Step 2: Edit `provider-config.sh` — add a `provider_count()` function that echoes the number of entries in the PROVIDERS array (use `echo "${#PROVIDERS[@]}"`) — done when: `bash -n provider-config.sh` passes and the function exists -- test: grep -q 'provider_count' provider-config.sh

## Smoke test
Run `bash provider-config.sh` (will do nothing but not error). Run `source provider-config.sh && loop_version && provider_count` and confirm outputs are "aymm-1.0" and "4".
