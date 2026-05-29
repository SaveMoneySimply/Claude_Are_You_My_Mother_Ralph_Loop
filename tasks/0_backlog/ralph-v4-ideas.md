# Ralph v4 — Ideas Backlog

Items deferred from v3. Not scheduled — collect here until there's enough to warrant a planning session.

---

## Open

**AYMM-all mode (`bash ralph.sh aymm --all`)**
Run the same task through every provider regardless of whether an earlier one passes. Two sub-modes:
- `--all --pick` — run all providers, Claude picks the best passing response
- `--all --show` — run all providers, display diffs side by side, human picks

Open design questions: sequential vs parallel? What does "best" mean for --pick? How to display diffs for --show?

**OpenRouter free model checker**
Utility that queries `https://openrouter.ai/api/v1/models`, filters for `:free` models, and compares against models currently configured in `provider-config.sh`. Alerts when our configured model changed or new free models appear (candidates for adding as direct APIs). Could be a standalone `check-free-models.sh` or added to `provider-status.sh --check-models`.

**Daily quota reset detection**
When a provider hits its daily limit (403 / quota-exhausted body), read the reset timestamp from response headers (`x-ratelimit-reset`, `Retry-After`) and sleep exactly that duration rather than writing STOP. Only worth building once we have real response examples from each provider hitting their daily limit — inspect `.ralph/http-error-log.jsonl` after a real quota hit.

**Timestamp done-task filenames** ✅ done in v3

**Rollback on test failure**
When a provider writes code that fails the test gate, revert the working tree to the pre-attempt state before trying the next provider. Without this, every subsequent provider (and Claude escalation) works from a broken baseline. Implementation: `git stash` before each provider attempt, `git stash pop` on pass, `git stash drop` + restore on fail — or just `git checkout -- .` after a failure since we haven't committed. Observed failure mode: Groq broke `aymm-loop.sh` with a partial edit; Mistral and OpenRouter then received the broken file as context.

**Pass AYMM failure history to Claude on escalation**
When all free providers exhaust and `loop.sh` is called as Claude fallback, inject the `previous-attempts` context from `.ralph/test-log.jsonl` into the prompt so Claude knows what was tried and broken. Currently `run_agent_task.sh` passes this context between free providers, but the handoff to `loop.sh` drops it. Claude succeeded without it in the p1s1 run, but for harder tasks it would help Claude avoid repeating the same broken approaches.

**Single-attempt-then-switch on task failure (consider alongside rollback)**
Currently retries the same provider up to 3× on task failure before switching. Once rollback is in place, a failed attempt is clean (no broken baseline), but retrying the same provider quickly can trigger 429s. Consider reducing to 1 attempt per provider for code-writing failures — log the result, pass it as context to the next provider, move on. Keep the retry count for rate-limit recovery (which is already handled separately).

**Matt's Thoughts**

-I need to understand what ralph.sh plan mode does and try to use it for the next planing session
