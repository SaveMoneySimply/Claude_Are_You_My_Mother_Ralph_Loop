#!/usr/bin/env bash
# apply_changes.sh — apply XML code change blocks to the workspace
# Usage: apply_changes.sh <text-file> <workspace-dir>
set -euo pipefail

TEXT_FILE="$1"
WORKSPACE="${2:-$(pwd)}"
files_written=0

# <file> blocks — whole file write or create
while IFS= read -r -d $'\x00' block; do
    fpath="$(echo "$block" | head -1 | grep -oE 'path="[^"]+"' | sed 's/path="\(.*\)"/\1/')"
    [[ -z "$fpath" ]] && continue
    content="$(echo "$block" | tail -n +2 | head -n -1)"
    full_path="${WORKSPACE}/${fpath}"
    mkdir -p "$(dirname "$full_path")"
    printf '%s\n' "$content" > "$full_path"
    echo "Wrote: $fpath"
    files_written=$(( files_written + 1 ))
done < <(perl -0777 -ne 'while (/<file\s[^>]*>.*?<\/file>/gs) { print $&, "\x00" }' "$TEXT_FILE")

# <edit> blocks — surgical line range replacement
while IFS= read -r -d $'\x00' block; do
    fpath="$(echo "$block" | head -1 | grep -oE 'path="[^"]+"' | sed 's/path="\(.*\)"/\1/')"
    start="$(echo "$block" | head -1 | grep -oE 'start="[0-9]+"' | grep -oE '[0-9]+')"
    end_line="$(echo "$block" | head -1 | grep -oE 'end="[0-9]+"' | grep -oE '[0-9]+')"
    [[ -z "$fpath" || -z "$start" || -z "$end_line" ]] && continue
    content="$(echo "$block" | tail -n +2 | head -n -1)"
    full_path="${WORKSPACE}/${fpath}"
    if [[ ! -f "$full_path" ]]; then
        echo "Warning: edit target not found: $fpath" >&2
        continue
    fi
    tmp="$(mktemp /tmp/aymm-edit-XXXXXX.txt)"
    awk -v s="$start" -v e="$end_line" -v rep="$content" \
        'NR==s{print rep; skip=1} skip && NR<=e{next} {skip=0; print}' \
        "$full_path" > "$tmp"
    mv "$tmp" "$full_path"
    echo "Edited: $fpath (lines ${start}-${end_line})"
    files_written=$(( files_written + 1 ))
done < <(perl -0777 -ne 'while (/<edit\s[^>]*>.*?<\/edit>/gs) { print $&, "\x00" }' "$TEXT_FILE")

# <delete> blocks — file deletion (self-closing tag)
while IFS= read -r -d $'\x00' block; do
    fpath="$(echo "$block" | grep -oE 'path="[^"]+"' | sed 's/path="\(.*\)"/\1/')"
    [[ -z "$fpath" ]] && continue
    full_path="${WORKSPACE}/${fpath}"
    if [[ -f "$full_path" ]]; then
        rm "$full_path"
        echo "Deleted: $fpath"
        files_written=$(( files_written + 1 ))
    fi
done < <(perl -0777 -ne 'while (/<delete\s[^>]*\/>/gs) { print $&, "\x00" }' "$TEXT_FILE")

if [[ "$files_written" -eq 0 ]]; then
    echo "Warning: no change blocks found in response" >&2
    exit 1
fi
exit 0
