# Ralph v3 — Ideas Backlog

Items deferred from v2/AYMM. Not scheduled — collect here until there's enough to warrant a planning session.

---

## ✅ Already built

**Phase Reviews (Claude at phase boundaries)**
`run_phase_review()` in `aymm-loop.sh` — Claude writes a review to `handoffs/phase<N>-review.md` when all tasks in a phase complete. Review is injected as context into the next phase.

**Failure history passed to next provider**
`test-log.jsonl` records every attempt (provider, response, test error). Each provider receives the full failure history for the current task so it can learn from prior attempts.

**Error feedback loop**
Failed test output is injected back into the same provider's retry prompt. Provider gets 3 attempts (Gemini/Groq), 2 (Mistral), 1 (OpenRouter) before switching.

**HTTP error logging**
`run_agent_task.sh` logs full response body + status to `.ralph/http-error-log.jsonl` on every non-200. Prerequisite for daily quota reset detection.

**provider-status.sh**
Diagnostic script — lists all providers with model, attempt limit, and API key status. Run `bash provider-status.sh` before a run to confirm all keys are set.

**Per-step tests (`-- test:` tag)**
Step lines can end with `-- test: <cmd>`. After the global test passes, bash extracts and runs the step-level command. Fails the step if it returns non-zero. Use `grep -q` or `test -f` to verify the AI made the right specific change, not just syntactically valid code.

---

## Open — AYMM provider tuning

**OpenRouter model rotation**
If one `:free` model hits its quota, try the next free model before giving up. Each model has its own separate quota on OpenRouter. Would add `provider_fallback_models()` to `provider-config.sh`. Low priority — do after basic loop proves out.

**Extend free quota via direct APIs**
Multiple paths: (1) multiple OpenRouter accounts, each with its own free quota; (2) go direct to each company's free API (DeepSeek, Poolside, NVIDIA) for more generous quotas than OpenRouter-routed versions. Add best direct APIs as extra providers in the chain if rate limits become a problem.

**Sleep-and-retry on full rate limit exhaustion**
Currently when all providers are rate-limited, the loop writes STOP and exits. Alternative: sleep 1hr, reset provider index, retry automatically. Keeps AYMM running overnight without manual intervention. Add a max-retry count to prevent infinite loops.

**Cooldown detection (429 vs quota blown)**
HTTP 429 = temporary rate limit (resets in minutes). HTTP 403/quota = daily limit (resets in hours). Currently both advance the provider immediately. On 429, could sleep 60s and retry the same provider before advancing. Only advance on true quota exhaustion.

---

## Open — Core engine

**Global engine install (dual-volume mount)**
Engine lives at `~/tools/ralph`, mounted read-only as `/engine` into any project's container. Project workspace mounted separately as `/workspace`. `ralph.sh` moves to `~/tools/ralph/ralph.sh` — installed globally, run from any project dir. Project repos become clean: just `ARCHITECTURE.md` + `tasks/` + project source.

**When to do it:** After AYMM is stable and ralph is being pointed at real external projects.

## My Thoughts

I want to make sure we are sending the files that are needed for the task to the free AI

**Daily quota reset detection**
When a provider hits its daily limit (403 / quota-exhausted body), read the reset timestamp from the response headers (e.g. `x-ratelimit-reset`, `Retry-After`) and sleep exactly that long before retrying, rather than stopping the loop entirely. Temporary 429s don't need this — the loop naturally cycles back after working through other providers and the window has reset by then. This is only worth building once we have real response examples from each provider hitting their daily limit.

**Prerequisite: log full HTTP error responses** ✅ done
`.ralph/http-error-log.jsonl` now captures full response body + status on every non-200. Next step: hit a real daily limit and inspect the log to see what each provider returns.
