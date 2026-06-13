#!/bin/bash
# stop — flutter analyze antes de encerrar a tarefa.

set -euo pipefail

input=$(cat)
status=$(echo "$input" | jq -r '.status // empty')
loop_count=$(echo "$input" | jq -r '.loop_count // 0')

if [[ "$status" != "completed" ]]; then
  exit 0
fi

if [[ "$loop_count" -ge 1 ]]; then
  exit 0
fi

if [[ ! -f pubspec.yaml ]]; then
  exit 0
fi

if ! command -v flutter >/dev/null 2>&1; then
  exit 0
fi

analyze_output=$(flutter analyze --no-pub 2>&1 || true)

if echo "$analyze_output" | grep -Eq '(^|\s)(error|warning)\s+•'; then
  escaped=$(echo "$analyze_output" | jq -Rs .)
  jq -n --argjson msg "$escaped" '{
    "followup_message": ("flutter analyze encontrou problemas. Corrija antes de encerrar:\n\n" + $msg)
  }'
  exit 0
fi

echo '{}'
exit 0
