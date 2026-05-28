# Task — log-http-errors

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 8000 · **Attempts:** 0/3
**Test command:** bash -n ralph.sh && bash -n loop.sh && bash -n aymm-loop.sh && bash -n run_agent_task.sh && bash -n provider-config.sh

## Steps
- [ ] Step 1: Edit `run_agent_task.sh` — update `handle_http_status` to accept a second argument (path to the response body file), and on any non-200 status append a JSON entry to `.ralph/http-error-log.jsonl` containing: timestamp (epoch seconds), provider name (from the `$PROVIDER` env var), http status code, and the full response body read from the file. Update all three call sites (`call_gemini` and the two `call_openai_compatible` calls) to pass `$tmp_response` as the second argument. — done when: `bash -n run_agent_task.sh` passes and `handle_http_status` references a second argument and `.ralph/http-error-log.jsonl`
- [ ] Step 2 (final): run test command — on pass, commit and close task

## Smoke test
Manually trigger a 429 or check `.ralph/http-error-log.jsonl` after the next run that hits a rate limit. Entry should contain provider name, status code, and the raw response body from the API.
