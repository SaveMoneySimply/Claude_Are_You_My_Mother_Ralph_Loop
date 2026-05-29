# Task — te-03-escalation-ladder

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 5000 · **Attempts:** 0/3
**Test command:** (cd project && bash test-engine.sh)
**Allowed files:** project/test-engine.sh, tasks/2_active/te-03-escalation-ladder.md

## Context
Adds tests for the `get_step_spec` escalation ladder from loop.sh.

`get_step_spec` is a pure function (no file I/O, no globals beyond its parameters and FORCE_SPLIT_STEP).
The correct approach: copy the function verbatim into test-engine.sh and test it there.
If the function ever changes in loop.sh, the copy in test-engine.sh must be updated too — that's expected.

Full function signature: `get_step_spec DECLARED_MODEL DECLARED_EFFORT STEP_NUMBER`
Returns one of: `model:effort`, `context_expansion`, `split`, `blocked`
FORCE_SPLIT_STEP=50 (any step >= 50 returns "split" regardless of other state)

Expected escalation sequences (step 0 = declared, steps 1+):
- `sonnet high` → sonnet:high, sonnet:max, opus:low, opus:max, context_expansion, split, blocked
- `haiku -`     → haiku:(no effort), sonnet:low, sonnet:max, opus:low, opus:max, context_expansion, split, blocked
- `opus max`    → opus:max, context_expansion, split, blocked  (no same-model-max step since already at max)
- `sonnet max`  → sonnet:max, opus:low, opus:max, context_expansion, split, blocked  (no same-model-max since already max)

## Steps
- [x] Copy the `get_step_spec` function verbatim from `project/loop.sh` into `project/test-engine.sh` — include the `FORCE_SPLIT_STEP=50` constant — done when: function is present and callable -- test: grep -q 'get_step_spec' project/test-engine.sh -- files: project/test-engine.sh, project/loop.sh:13-74
- [x] Add tests for edge cases: (a) `haiku` at step 0 returns something starting with "haiku"; (b) `opus max` at step 1 returns "context_expansion" (skips same-model-max and no higher models); (c) `sonnet max` at step 1 returns "opus:low" (skips same-model-max since already max); (d) any model at step >= 50 returns "split" (FORCE_SPLIT_STEP) — done when: 4 edge-case assertions pass -- test: (cd project && bash test-engine.sh) | grep -q 'escalation_edge' -- files: project/test-engine.sh

## Smoke test
Run `(cd project && bash test-engine.sh)` and confirm the escalation tests all pass alongside prior tests.
