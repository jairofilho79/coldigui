#!/bin/bash
# subagentStop — encadeia agente OpSec após QA.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=loop-budget.sh
source "$SCRIPT_DIR/loop-budget.sh"

input=$(cat)
status=$(echo "$input" | jq -r '.status // empty')

if [[ "$status" != "completed" ]]; then
  echo '{}'
  exit 0
fi

if ! loop_budget_consume 1; then
  echo '{}'
  exit 0
fi

jq -n '{
  "followup_message": "Use a skill plpcg-opsec-reviewer: varra secrets hardcoded em todo o projeto, valide sanitização de inputs e storage seguro nos paths alterados."
}'

exit 0
