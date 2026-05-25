# Phase 2 — Task Runner

**Model:** sonnet · **Effort:** high · **Tokens estimated:** 60000 · **Attempts:** 0/3
**Test command:** bash -n run_agent_task.sh

## Steps

- [ ] Step 1: Write `run_agent_task.sh` skeleton — parse `--provider=<name>` argument, source `provider-config.sh`, validate the provider name is known, print usage on bad args — done when: `bash -n run_agent_task.sh` exits 0 and `bash run_agent_task.sh --provider=invalid` exits 1 with a usage message

- [ ] Step 2: Implement context bundler — find the current task file (via `.ralph/last-task.txt`), locate the next unchecked `- [ ]` step, extract the step description and any file paths mentioned in it, read those file contents, assemble a prompt string — done when: bundler produces a non-empty prompt string for a synthetic task file with a known unchecked step

- [ ] Step 3: Implement Gemini API call — POST the bundled prompt to `generativelanguage.googleapis.com` using the API key from `$GEMINI_API_KEY`; capture HTTP status; exit 429 on rate limit, exit 1 on other errors, write raw response to a temp file on 200 — done when: `bash -n run_agent_task.sh` exits 0; the curl command structure is correct (verified by inspection)

- [ ] Step 4: Implement OpenAI-compatible API call — shared curl function for Groq, Mistral, and OpenRouter using Bearer token auth and the OpenAI chat completions schema; reuse the same HTTP status handling as Step 3 — done when: `bash -n run_agent_task.sh` exits 0; function accepts provider name and dispatches correctly

- [ ] Step 5: Implement XML response parser — extract all `<file path="...">...</file>` blocks from the raw API response; for each block, create any missing parent directories and write the content to the specified path — done when: a synthetic response string with two file blocks produces the correct files on disk when the parser runs

- [ ] Step 6: Implement test runner — read the test command from `ARCHITECTURE.md` (line starting with `bash -n` under `## Test Command`), run it, return exit 0 on pass or exit 2 on fail — done when: `bash -n run_agent_task.sh` exits 0; running against a known-passing test command returns 0 and a known-failing one returns 2

- [ ] Step 7 (final): Run test command — on pass, commit and close task

## Smoke test
With a real provider API key set, run `bash run_agent_task.sh --provider=gemini` against a minimal task file that asks the AI to write "echo hello" to `tmp/test.sh`. Confirm `tmp/test.sh` is created and `bash tmp/test.sh` prints "hello".
