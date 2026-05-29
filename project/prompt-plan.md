You are running in Ralph breakdown mode inside a sandboxed container.
CLAUDE.md is your operating manual (read-only). ARCHITECTURE.md describes this project (read-only).

Your job is to generate task files from the sub-plans. Do not execute any tasks — only create task files.

Each iteration:

1. Read state:
   - PLAN.md → list all sub-plans
   - plans/*.md → read each sub-plan's checklist
   - tasks/active/ → note which tasks already have files (skip those)

2. If every plan item already has a task file in tasks/active/ or tasks/done/:
   `echo "Breakdown complete — run: bash ralph.sh" > STOP` and exit.

3. Pick the next plan item that does not have a task file yet.

4. Create tasks/active/<short-name>.md using the task file format from CLAUDE.md:
   - Choose Model and Effort based on the complexity of the work:
     - haiku: purely mechanical (renaming, formatting, simple find/replace)
     - sonnet + low/medium: straightforward coding, well-understood changes
     - sonnet + high: standard feature work, debugging
     - opus + high/xhigh: architecture, subtle debugging, complex design
   - Estimate tokens honestly: ~10k small, ~50k medium, ~200k large
   - Write explicit steps with clear acceptance criteria
   - Write a smoke test section
   - Set Attempts: 0/3

5. Link the new task file from the relevant plan:
   Update the plan checklist item to: `- [ ] <item> — [task](../tasks/active/<name>.md)`

6. Write the task short name to `.ralph/last-task.txt`.

7. Exit cleanly. The loop will restart you for the next plan item.

If you are uncertain about scope or complexity of a plan item, err toward smaller tasks
and note the uncertainty in the task file's smoke test section.
