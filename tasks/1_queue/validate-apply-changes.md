# Task — validate-apply-changes

**Model:** sonnet · **Effort:** low · **Tokens estimated:** 5000 · **Attempts:** 0/3

## Steps
- [ ] Step 1: Edit `provider-config.sh` — add a `has_provider()` function at the bottom of the file that takes a name argument and returns 0 if the name is in the PROVIDERS array, 1 if not (loop through `"${PROVIDERS[@]}"` and compare with `[[ "$p" == "$name" ]]`) — done when: `bash -n provider-config.sh` passes and the function exists -- test: grep -q 'has_provider' provider-config.sh

## Smoke test
Run `source provider-config.sh && has_provider gemini && echo ok` — should print "ok".
Run `source provider-config.sh && has_provider fake && echo found || echo notfound` — should print "notfound".
