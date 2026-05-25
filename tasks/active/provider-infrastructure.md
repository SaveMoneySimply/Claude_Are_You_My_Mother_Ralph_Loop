# Task — provider-infrastructure

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 30000 · **Attempts:** 0/3
**Test command:** bash -n provider-config.sh && bash -n test-providers.sh

## Steps
- [x] Step 1: Write `provider-config.sh` — define a PROVIDERS array and per-provider config (API_URL, MODEL, API_KEY_VAR, API_FORMAT) for Gemini, Mistral, Groq, and OpenRouter — done when: `bash -n provider-config.sh` exits 0 and sourcing it exposes the expected variables
- [x] Step 2: Update `Dockerfile` — add `ENV` passthrough for GEMINI_API_KEY, GROQ_API_KEY, MISTRAL_API_KEY, OPENROUTER_API_KEY alongside the existing ANTHROPIC_API_KEY pattern — done when: `docker build -t ralph:latest .` exits 0 (syntax check only, no push)
- [x] Step 3: Update `init-firewall.sh` — add allowlist entries for `generativelanguage.googleapis.com`, `api.groq.com`, `api.mistral.ai`, `openrouter.ai` in the same pattern as existing domains — done when: `bash -n init-firewall.sh` exits 0
- [x] Step 4: Write `test-providers.sh` — for each provider, if its API key env var is set, send a minimal "say hello" prompt via curl and report HTTP status + first 100 chars of response; if key not set, print "SKIPPED (no key)"; exit 0 always — done when: `bash -n test-providers.sh` exits 0 and running it with no keys set prints four SKIPPED lines
- [x] Step 5 (final): Run test command — on pass, commit and close task

## Smoke test
Run `bash test-providers.sh` with at least one real API key set. Confirm that provider returns a non-empty response and the script reports the HTTP status and a snippet of the reply.
