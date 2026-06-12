#!/bin/bash
# subagentStop — encadeia agente QA após desenvolvimento.

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
  "followup_message": "Use a skill plpcg-qa-engineer: gere cenários Gherkin em integration_test/gherkin/ e testes unit/widget para os use cases implementados. Execute flutter test."
}'

exit 0
