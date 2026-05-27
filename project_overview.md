## Project overview

# AYMM Architecture — Are You My Mother (Multi-Provider Ralph Loop)

## What This Is
An extension of the Ralph Loop that routes autonomous coding tasks through free AI APIs before
falling back to Claude. Run `bash ralph.sh aymm` to use free-AI-first execution.

Each task is tried by free-tier providers (Gemini → Mistral → Groq → OpenRouter) before Claude
is invoked. If a free AI's output passes the test suite, Claude never gets involved.

## Stack
- Shell: bash
- HTTP client: curl
- JSON parsing: jq
- Container: Docker (extends existing Ralph Loop infrastructure)
- Test gate: bash syntax check (see Test Command below)

## Phases

### Phase 1 — <name>
<one-sentence description of what this phase builds>

# Add more phases as work is planned

## Key Files
- `ralph.sh` — host wrapper; modes: `execute` (Claude only), `plan` (breakdown), `aymm` (free-AI-first)
- `aymm-loop.sh` — container orchestrator for aymm mode (outer provider loop + inner execution loop)
- `run_agent_task.sh` — per-provider task runner (context bundle → API → XML parse → test)
- `provider-config.sh` — API configuration per provider
- `prompt-aymm.md` — navigation wrapper for free AI context bundling
- `test-providers.sh` — live connectivity test for all 4 providers
- `loop.sh` — bash-side navigation (picks task from 4-stage pipeline, extracts next step, injects into prompt); Claude fallback
- `prompt.md` — step executor (~10 lines); bash injects the current step before passing to Claude

## Current task step

- [x] Step 1: Create a file called `hello.txt` in the project root containing exactly the text `hello`. — done when: `test -f hello.txt` exits 0.

## Task context

# Task — hello-test

**Model:** sonnet · **Effort:** low · **Tokens estimated:** 5000 · **Attempts:** 0/3
**Test command:** test -f hello.txt && echo "pass" || echo "fail"

## Steps
- [x] Step 1: Create a file called `hello.txt` in the project root containing exactly the text `hello`. — done when: `test -f hello.txt` exits 0.

## Smoke test
Open `hello.txt` and confirm it contains "hello".

## File: hello.txt
hello

## File: hello.txt
hello
