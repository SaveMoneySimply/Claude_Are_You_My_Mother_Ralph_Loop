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

**Matt's Thoughts

-We need to make sure the README files is updated so someone can try this out, needs to explain the task folder structure and what scripts to run and the callouts and what they do.
