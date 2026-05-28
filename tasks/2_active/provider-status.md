# Task — provider-status

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 10000 · **Attempts:** 0/3
**Test command:** bash -n provider-status.sh

## Steps
- [x] Step 1: Create `provider-status.sh` — a bash script that sources `provider-config.sh` and iterates over the PROVIDERS array, printing each provider's name, model (via `provider_model`), and max attempt count (via `provider_max_attempts`) in a simple aligned table — done when: the file exists and `bash -n provider-status.sh` passes
- [x] Step 2: Edit `provider-status.sh` to add an API key status column — for each provider, call `provider_api_key_var` to get the key variable name, then check whether that variable is set in the environment and print "set" or "missing" beside the provider entry — done when: `bash -n provider-status.sh` passes and the script references all four key variable names
- [x] Step 3: Add a summary line at the bottom of `provider-status.sh` that counts how many providers have their key set vs missing — done when: `bash -n provider-status.sh` passes
- [ ] Step 4 (final): run `bash -n provider-status.sh` — on pass, commit and close task

## Smoke test
Run `bash provider-status.sh` manually. Verify it lists all 4 providers with model names, attempt limits, key status, and a summary count at the bottom.
