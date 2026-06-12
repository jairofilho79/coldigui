#!/bin/bash
# subagentStart — permite apenas subagents alinhados ao pipeline PLPCG.

set -euo pipefail

input=$(cat)
subagent_type=$(echo "$input" | jq -r '.subagent_type // empty')

allowed='^(explore|generalPurpose|code-architect|code-reviewer|code-simplifier|shell)$'

if [[ -z "$subagent_type" ]] || echo "$subagent_type" | grep -qE "$allowed"; then
  echo '{"permission": "allow"}'
else
  jq -n --arg t "$subagent_type" '{
    "permission": "deny",
    "user_message": ("Subagent \"" + $t + "\" não faz parte do pipeline PLPCG.")
  }'
fi

exit 0
