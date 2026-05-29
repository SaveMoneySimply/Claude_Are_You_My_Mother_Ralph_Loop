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

**Phase 1 — Polish**
- p1s1: Timestamp filenames in tasks/3_done/ (YYYY-MM-DD-<name>.md for chronological ordering)

**Phase 2 — Engine Extraction**
- p2s1: Create ~/tools/ralph/, mount as /engine:ro in container, update init-firewall.sh exec path
- p2s2: SCRIPT_DIR/WORKSPACE split in engine scripts (loop.sh, aymm-loop.sh, run_agent_task.sh)

**After Phase 2:** Point Ralph at an external project to validate end-to-end.

**Deferred to v4:** AYMM-all mode, OpenRouter model checker, daily quota reset detection.

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

## Directory Structure
Tasks flow through four directories; bash moves files between them, Claude never navigates:
- `tasks/0_backlog/` — area plans and ideas not yet broken into task files
- `tasks/1_queue/` — task files waiting to run (add new tasks here)
- `tasks/2_active/` — the single task currently being worked (loop.sh moves it here)
- `tasks/3_done/` — archived completed tasks

## Provider Priority
1. Gemini 2.5 Flash (GEMINI_API_KEY) — most generous free tier (~1500 req/day), large context window; 3 attempts
2. Groq Llama 3.3 70B (GROQ_API_KEY) — very generous daily quota, fast inference; 3 attempts
3. Mistral Codestral (MISTRAL_API_KEY) — coding-specific model, moderate free quota; 2 attempts
4. OpenRouter free models (OPENROUTER_API_KEY) — scarcest quota but strongest available model; 1 attempt, receives full failure history from all prior providers
5. Claude fallback via existing loop.sh

Total free-AI attempts per task: up to 10 (3+3+2+1) before Claude escalation.

## Escalation
- Per-provider failure threshold exceeded → switch provider (gemini/groq: 3×, mistral: 2×, openrouter: 1×)
- HTTP 429 → immediate provider switch
- HTTP 403 → mark provider exhausted for session
- All providers fail one task → escalate to Claude (loop.sh)
- Claude fails same task → BLOCKED (no second free-AI round)
- All providers rate-limited → STOP + ntfy notification (user chooses: run ralph.sh now or wait ~1hr)
- Each retry receives full failure history from all prior providers on this task

## Free AI Output Format
The task runner sends file contents as context and asks the free AI to return changes as XML blocks:
```xml
<file path="src/foo.sh">
...full file content...
</file>
```
The runner parses these blocks and writes them to disk, then runs the test command.

## Environment Variables Required
- `ANTHROPIC_API_KEY` — existing, required for Claude fallback
- `GEMINI_API_KEY` — Google AI Studio (free tier, no credit card required)
- `GROQ_API_KEY` — groq.com (free tier)
- `MISTRAL_API_KEY` — console.mistral.ai (free tier)
- `OPENROUTER_API_KEY` — openrouter.ai (free tier)

## Test Command
```bash
bash -n ralph.sh && bash -n loop.sh && bash -n aymm-loop.sh && bash -n run_agent_task.sh && bash -n provider-config.sh
```
Bash syntax check — runs after every step, zero API calls, no quota burned during build.

## Smoke Test (run manually after loop completes — requires live API keys)
```bash
bash test-providers.sh
```
Hits each provider with a minimal real request. Have all four free API keys set in your shell before running.

## Ralph Settings
autonomy: low

## Firewall Additions
generativelanguage.googleapis.com
api.groq.com
api.mistral.ai
openrouter.ai
