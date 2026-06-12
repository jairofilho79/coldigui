#!/bin/bash
# afterFileEdit — lembrete OpSec para paths sensíveis.

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path // empty')

if [[ -z "$file_path" ]]; then
  exit 0
fi

if echo "$file_path" | grep -qE '(admin|offline|dio|jwt|upload)'; then
  echo "Path sensível editado ($file_path). Considere plpcg-opsec-reviewer." >&2
fi

exit 0
