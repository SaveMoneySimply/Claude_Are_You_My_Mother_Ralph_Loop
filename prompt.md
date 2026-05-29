You are running in Ralph loop mode. Bash has already identified your task and next step (injected below).

1. Execute the next step. Mark it complete: change `- [ ]` to `- [x]` in the task file.
2. Write `pass` or `fail` to `.ralph/last-result.txt`. On fail, write details to `.ralph/last-failure.txt`.
3. If this was the **final step** and it passed:
   - Commit: `git add -A && git commit -m "<task>: <one-line summary>"`
   - Move task file: `mv tasks/2_active/<name>.md "tasks/3_done/$(date +%Y-%m-%d)-<name>.md"`
   - Append to CHANGELOG.md: `date | task name | one-line description | link`
   - If ARCHITECTURE.md needs updating: write proposal to ARCHITECTURE_REVIEW.md, then `echo "ARCHITECTURE review requested" > STOP`

If uncertain, prefer the simpler, more reversible action.
