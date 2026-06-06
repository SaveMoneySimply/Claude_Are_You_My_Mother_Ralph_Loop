# Backlog — Director Triage: Fix-vs-Regenerate on Provider Failure

## Problem

When a free provider fails the `bash -n` syntax check, the loop currently rolls back and retries from scratch. But some failures are "close" (structural nesting error, one misplaced token) while others are "hopeless" (TPM truncation, completely wrong output). Treating them the same wastes Claude tokens on cases a targeted fix pass could handle cheaply.

## Proposed approach

Two changes to the failure path:

**1. Capture failed attempts before rollback**

Instead of (or in addition to) `git restore`, save the broken file to `.ralph/last-failed-attempt/<provider>-<step-n>.<ext>` and the error to `.ralph/last-failed-attempt/error.txt`. This gives the director something to work from.

**2. Triage before Claude escalation**

Before writing `aymm-escalate.txt`, classify the failure:

| Signal | Classification | Action |
|---|---|---|
| `bash -n` exit 0, grep test fails | Logic error | Normal retry/escalate |
| `bash -n` fails, file ≥ 90% expected length | Syntax-close | Route to director "fix syntax only" prompt |
| `bash -n` fails, file < 90% expected length | TPM truncation | Skip to scout or Claude directly |
| No change blocks in response | Empty output | Normal retry |

"Expected length" can be estimated from the line ranges in `-- files:` annotations, or just compared against the pre-attempt file size.

**Director fix prompt (cheap):** inject the broken file + `bash -n` error + "fix only the syntax error, do not change logic" — targeted 2-3K token pass vs 5-8K full regeneration.

## When this matters most

- Large functions (50+ lines) where providers get logic right but structure wrong
- Steps with `-- mode: context` (large file injection) where 70b hits nesting issues
- Cascading escalations where 4+ providers all fail the same structural way (as seen in `use-dynamic-tpm-threshold`)

## When it doesn't help

- TPM truncation (file cut off mid-response) — fix pass would just get the same truncation
- One-liner substitutions — context cost is the same either way
- Completely wrong output — cheaper to start over

## Dependencies

- Requires director.sh to exist (Phase 4)
- Could prototype the capture step now (just save to `.ralph/last-failed-attempt/`) even before director exists — the files would be there for manual inspection

## Estimated effort

- Capture step alone: low (2-3 lines in the rollback path)
- Triage + director fix prompt: medium (new code path in aymm-loop.sh + new prompt template)
