# Changelog

<!-- Append-only. One entry per completed task. -->
<!-- Format: YYYY-MM-DD | task-name | one-line description | [task](tasks/done/name.md) -->
2026-05-27 | cooldown-detection | Sleep 60s and retry on first 429 per provider; advance to next provider on second consecutive 429; 403 still advances immediately | [task](tasks/3_done/cooldown-detection.md)
2026-05-27 | sleep-retry-rate-limit | Sleep 1hr and retry when all providers rate-limited; STOP after 3 consecutive sleeps; ntfy notification on each sleep | [task](tasks/3_done/sleep-retry-rate-limit.md)
2026-05-25 | provider-infrastructure | Added provider-config.sh, Dockerfile env passthroughs, firewall allowlists, and test-providers.sh for Gemini/Mistral/Groq/OpenRouter | [task](tasks/done/provider-infrastructure.md)
2026-05-25 | task-runner | Implemented run_agent_task.sh with context bundler, Gemini + OpenAI-compat API calls, XML response parser, and test runner | [task](tasks/done/task-runner.md)
2026-05-26 | aymm-orchestrator | Implemented aymm-loop.sh with multi-provider orchestration, failure tracking, rate-limit switching, Claude escalation, and provider state logging | [task](tasks/done/aymm-orchestrator.md)
2026-05-26 | integration | Wrote aymm.sh, prompt-aymm.md, updated README with AYMM section; all syntax checks pass | [task](tasks/done/integration.md)
2026-05-28 | log-http-errors | handle_http_status now accepts response body file path and appends JSON error entries to .ralph/http-error-log.jsonl on non-200 status | [task](tasks/3_done/log-http-errors.md)
2026-05-26 | ralph-v2 | Migrated to 4-stage task pipeline (0_backlog/1_queue/2_active/3_done); bash-side navigation in loop.sh; prompt.md shrunk to 11 lines; CLAUDE.md and ARCHITECTURE.md updated | [task](tasks/3_done/ralph-v2.md)
2026-05-26 | aymm-unify | Absorbed aymm.sh into ralph.sh as `bash ralph.sh aymm` mode; updated aymm-loop.sh for new directory paths; deleted aymm.sh | [task](tasks/3_done/aymm-unify.md)
| 2026-05-27 | aymm-test | Completed via groq | [task](tasks/3_done/aymm-test.md) |
| 2026-05-28 | provider-status | Completed via gemini | [task](tasks/3_done/provider-status.md) |
