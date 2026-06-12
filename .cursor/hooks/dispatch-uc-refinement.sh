#!/bin/bash
# beforeSubmitPrompt — detecta UC-XX e sugere skill de refinamento.

set -euo pipefail

input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // empty')

if [[ -z "$prompt" ]]; then
  echo '{}'
  exit 0
fi

uc_match=""
if echo "$prompt" | grep -qE 'UC-[0-9]{2}'; then
  uc_match=$(echo "$prompt" | grep -oE 'UC-[0-9]{2}' | head -1)
elif echo "$prompt" | grep -qiE 'implementar|offline|leitor|biblioteca|carousel|playlist'; then
  uc_match="UC-XX"
fi

if [[ -n "$uc_match" ]]; then
  jq -n --arg uc "$uc_match" '{
    "agent_message": ("Detectado " + $uc + ". Antes de implementar, use a skill plpcg-uc-refinement: leia docs/use-cases/ correspondente e produza plano de arquivos, providers e testes.")
  }'
else
  echo '{}'
fi

exit 0
