# Task — fix-changelog-format

**Model:** sonnet · **Effort:** low · **Tokens estimated:** 3000 · **Attempts:** 0/3

Two entries at the bottom of CHANGELOG.md use a Markdown table row format (`| date | name | ... |`) instead of the standard pipe-separated format (`date | name | ...`). Fix both in a single edit block.

## Steps
- [ ] Step 1: Edit `CHANGELOG.md` lines 18-19 — replace both malformatted entries with the standard format (no leading `|`, no trailing `|`): line 18 becomes `2026-05-27 | aymm-test | Completed via groq | [task](tasks/3_done/aymm-test.md)` and line 19 becomes `2026-05-28 | provider-status | Completed via gemini | [task](tasks/3_done/provider-status.md)` — done when: no lines in CHANGELOG.md start with `| ` -- test: ! grep -q '^| ' CHANGELOG.md

## Smoke test
Run `grep '^| ' CHANGELOG.md` — should return no output (exit 1 means no matches, which is correct).
Run `grep '2026-05-27' CHANGELOG.md` — should show the line without leading/trailing pipes.
