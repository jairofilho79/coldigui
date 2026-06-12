#!/bin/bash
# Pede confirmação antes de ler arquivos potencialmente sensíveis (.env, chaves, credenciais).

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path // .path // empty')

if [[ -z "$file_path" ]]; then
  echo '{"permission":"allow"}'
  exit 0
fi

basename=$(basename "$file_path")

is_sensitive=false

case "$basename" in
  .env|.env.*|credentials.json|credentials.yaml|credentials.yml|secrets.json|secrets.yaml|secrets.yml|service-account*.json|google-services.json|GoogleService-Info.plist)
    is_sensitive=true
    ;;
esac

if [[ "$is_sensitive" == false ]]; then
  if echo "$file_path" | grep -Eiq '(\.env(\.|$)|/secrets/|/credentials/|\.pem$|\.p12$|\.pfx$|\.key$|id_rsa$|id_ed25519$|\.keystore$)'; then
    is_sensitive=true
  fi
fi

if [[ "$is_sensitive" == true ]]; then
  cat <<EOF
{
  "permission": "ask",
  "user_message": "Leitura de arquivo potencialmente sensível: ${file_path}. Confirme se deseja incluí-lo no contexto do Agent.",
  "agent_message": "Um hook pediu confirmação antes de ler um arquivo que pode conter segredos (${file_path}). Só prossiga se o usuário confirmar."
}
EOF
  exit 0
fi

echo '{"permission":"allow"}'
exit 0
