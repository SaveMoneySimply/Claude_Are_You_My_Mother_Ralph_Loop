# AYMM Agent Prompt Format

Context is bundled dynamically by `run_agent_task.sh`. This file documents the expected
response format for free-AI providers.

## Task types

Tasks will specify whether they require creating new files or editing existing ones.

## Response format

### New file or full replacement
```
<file path="relative/path/to/file">
...complete file content...
</file>
```

### Surgical edit (replace lines start through end inclusive)
```
<edit path="relative/path/to/file" start="10" end="15">
...replacement lines only...
</edit>
```

### Delete a file
```
<delete path="relative/path/to/file"/>
```

Always include the updated task file with the completed step marked [x].
Do not truncate file contents.
If all tasks in the phase are complete: `<file path="STOP">All tasks complete</file>`
