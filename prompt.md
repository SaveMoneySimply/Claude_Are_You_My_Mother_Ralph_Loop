You are running in Ralph loop mode. Bash has already identified your task and next step (injected below).

1. Execute the next step. Mark it complete: change `- [ ]` to `- [x]` in the task file.
2. Commit: `git add -A && git commit -m "<task>: <one-line summary>"`
3. Write `pass` or `fail` to `.ralph/last-result.txt`. On fail, write details to `.ralph/last-failure.txt`.

If ARCHITECTURE.md needs updating: write proposal to ARCHITECTURE_REVIEW.md, then `echo "ARCHITECTURE review requested" > STOP`
