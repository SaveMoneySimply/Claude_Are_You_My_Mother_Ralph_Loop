local _est
_est=$(grep 'Tokens estimated' "$TASK_FILE" | grep -oP '\d+' | head -1)
