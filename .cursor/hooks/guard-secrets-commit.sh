#!/bin/bash
# Pede confirmação antes de git add/commit de arquivos sensíveis.

set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.command // empty')

if [[ -z "$command" ]]; then
  echo '{"permission":"allow"}'
  exit 0
fi

if ! echo "$command" | grep -Eiq 'git\s+(add|commit)'; then
  echo '{"permission":"allow"}'
  exit 0
fi

if echo "$command" | grep -Eiq '(\.env(\.|$|\s)|credentials\.(json|ya?ml)|secrets\.(json|ya?ml)|\.pem|\.p12|\.pfx|id_rsa|id_ed25519|\.keystore|service-account.*\.json)'; then
  cat <<'EOF'
{
  "permission": "ask",
  "user_message": "Este comando git pode incluir arquivos com segredos no repositório. Revise antes de continuar.",
  "agent_message": "Um hook pediu confirmação: git add/commit pode expor credenciais ou chaves. Verifique .gitignore e remova arquivos sensíveis."
}
EOF
  exit 0
fi

echo '{"permission":"allow"}'
exit 0
