#!/bin/bash
# subagentStop — encadeia agente Performance após OpSec.

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
  "followup_message": "Use a skill plpcg-performance-auditor: audite PDFx (cold-open, dispose), índice Isar O(1) e gravação paralela offline se paths pdf_reader/offline/core/database foram tocados."
}'

exit 0
