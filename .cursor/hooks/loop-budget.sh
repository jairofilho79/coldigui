#!/bin/bash
# Utilitário compartilhado — budget máximo de 5 loops por sessão (ADR-003).

set -euo pipefail

LOOP_STATE_FILE="${LOOP_STATE_FILE:-.cursor/hooks/.loop-state}"
MAX_LOOPS=5

loop_budget_init() {
  if [[ ! -f "$LOOP_STATE_FILE" ]]; then
    echo "0" > "$LOOP_STATE_FILE"
  fi
}

loop_budget_current() {
  loop_budget_init
  cat "$LOOP_STATE_FILE"
}

loop_budget_consume() {
  local cost="${1:-1}"
  loop_budget_init
  local current
  current=$(cat "$LOOP_STATE_FILE")
  if [[ "$current" -ge "$MAX_LOOPS" ]]; then
    return 1
  fi
  echo $((current + cost)) > "$LOOP_STATE_FILE"
  return 0
}

loop_budget_remaining() {
  loop_budget_init
  local current
  current=$(cat "$LOOP_STATE_FILE")
  echo $((MAX_LOOPS - current))
}
