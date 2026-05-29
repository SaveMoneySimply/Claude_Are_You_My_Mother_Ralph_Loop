You are running in Ralph split mode inside a sandboxed container.
CLAUDE.md is your operating manual (read-only). ARCHITECTURE.md describes this project (read-only).

A task has failed its full escalation ladder and needs to be broken into smaller pieces.

Your job this iteration:

1. Read `.ralph/last-task.txt` to find the failing task name.

2. Read the task file at `tasks/active/<name>.md`. Understand:
   - What the task was trying to accomplish
   - Which steps failed and why (check `.ralph/last-failure.txt`)
   - The task's current split depth (from `**Split depth:**` in the header, default 0)

3. Read surrounding context:
   - Last 2-3 completed tasks in `tasks/done/` (to understand what's already built)
   - The sub-plan this task belongs to (from `plans/`)
   - Any error logs in `.ralph/iter-*-stderr.log` for the recent iterations

4. Design 2-3 smaller sub-tasks that together accomplish the same goal.
   Each sub-task should be independently executable and testable.
   If the original task was unclear or too broad, make the sub-tasks explicit and narrow.

5. Create `tasks/active/<original-name>-part-1.md`, `-part-2.md`, etc.
   Each sub-task file MUST include:
   ```
   **Model:** <appropriate model> · **Effort:** <appropriate effort>
   **Tokens estimated:** <honest estimate> · **Attempts:** 0/3
   **Parent task:** <original-name> · **Split depth:** <parent-depth + 1>
   **Test command:** <test command from original task or ARCHITECTURE.md>
   ```
   Plus `## Steps` and `## Smoke test` sections.

6. Move the original task to done:
   `mv tasks/active/<name>.md tasks/done/<name>.md`
   Add to its header: `**Split into:** <part-1>, <part-2>, ...`

7. Update the plan file:
   Replace the original task's checklist item with one item per sub-task, in order.
   Example:
   ```
   - [ ] <sub-task 1 description> — [task](../tasks/active/<name>-part-1.md)
   - [ ] <sub-task 2 description> — [task](../tasks/active/<name>-part-2.md)
   ```

8. Write `<original-name>` to `.ralph/last-task.txt` — the loop will find the first sub-task next iteration.

9. Write `pass` to `.ralph/last-result.txt` if the split succeeded.
   Write `fail` to `.ralph/last-result.txt` if you could not split the task (explain why in `.ralph/last-failure.txt`).

10. Exit cleanly.

Important: sub-tasks inherit the split depth counter. At split depth 2, a task cannot be split further
regardless of autonomy settings — it will go to BLOCKED.md if it fails.
