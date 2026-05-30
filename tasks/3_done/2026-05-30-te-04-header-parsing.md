# Task — te-04-header-parsing

**Model:** sonnet · **Effort:** medium · **Tokens estimated:** 3500 · **Attempts:** 0/3
**Test command:** (cd project && bash test-engine.sh)
**Allowed files:** project/test-engine.sh, tasks/2_active/te-04-header-parsing.md

## Context
Adds tests for task file header parsing to `project/test-engine.sh`.

These are the grep/regex one-liners used by loop.sh and aymm-loop.sh to read task metadata.
Test them directly against temp files — no sourcing needed.

Regexes under test (from loop.sh / aymm-loop.sh):
- Run mode:     `grep -oiP '\bRun:(?:\*\*\s*|\s+)\K\w+' taskfile | head -1 | tr '[:upper:]' '[:lower:]'`
- Autonomy:     `grep -i 'autonomy:' ARCHITECTURE.md | grep -oiP 'autonomy:\s*\K\w+' | head -1 | tr '[:upper:]' '[:lower:]'`
- Model:        `grep -oiP '\bModel:(?:\*\*\s*|\s+)\K\w+' taskfile | head -1 | tr '[:upper:]' '[:lower:]'`
- Effort:       `grep -oiP '\bEffort:(?:\*\*\s*|\s+)\K\w+' taskfile | head -1 | tr '[:upper:]' '[:lower:]'`
- Tokens:       `grep 'Tokens estimated' taskfile | grep -oP '\d+' | head -1`

## Steps
- [x] Add Run mode tests: write temp task files with `**Run:** interactive`, `**Run:** ralph`, `**Run:** aymm`, `**Run:** any`, and no Run field; verify the grep returns the correct lowercase value for each, and defaults to "any" when field is absent — done when: 5 assertions pass -- test: (cd project && bash test-engine.sh) | grep -q 'run_mode' -- files: project/test-engine.sh, project/loop.sh:23-28
- [x] Add autonomy tests: write a temp ARCHITECTURE.md with `autonomy: high`, `autonomy: low`, and no autonomy line; verify correct values returned and default is "low" — done when: 3 assertions pass -- test: (cd project && bash test-engine.sh) | grep -q 'autonomy' -- files: project/test-engine.sh, project/aymm-loop.sh:23-27
- [x] Add model/effort/tokens tests: write temp task files covering (a) `**Model:** sonnet · **Effort:** high` format (with bold markers); (b) `Model: opus` format (without bold); (c) missing fields (should default to sonnet/high/0); (d) `**Tokens estimated:** 5000`; verify each grep returns the expected value -- done when: 6 assertions pass -- test: (cd project && bash test-engine.sh) | grep -q 'header_parsing' -- files: project/test-engine.sh, project/loop.sh:77-99

## Smoke test
Run `(cd project && bash test-engine.sh)` and confirm all new header parsing tests pass.
