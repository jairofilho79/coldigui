#!/bin/bash
# stop — flutter analyze + encadeia Docs Creator se budget permitir.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=loop-budget.sh
source "$SCRIPT_DIR/loop-budget.sh"

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

if loop_budget_consume 1; then
  jq -n '{
    "followup_message": "flutter analyze OK. Use a skill plpcg-docs-creator: atualize docs/features/FEATURE_INDEX.md e documente APIs públicas novas."
  }'
else
  echo '{}'
fi

exit 0
