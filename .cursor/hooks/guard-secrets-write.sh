#!/bin/bash
# Alerta após Write em caminhos sensíveis — complementa a regra security-devsecops.

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path // .path // empty')

if [[ -z "$file_path" ]]; then
  echo '{}'
  exit 0
fi

basename=$(basename "$file_path")
is_sensitive=false

case "$basename" in
  .env|.env.*|credentials.json|credentials.yaml|credentials.yml|secrets.json|secrets.yaml|secrets.yml)
    is_sensitive=true
    ;;
esac

if [[ "$is_sensitive" == false ]]; then
  if echo "$file_path" | grep -Eiq '(\.env(\.|$)|/secrets/|/credentials/|\.pem$|\.p12$|\.key$|id_rsa$|id_ed25519$|\.keystore$)'; then
    is_sensitive=true
  fi
fi

if [[ "$is_sensitive" == true ]]; then
  jq -n --arg path "$file_path" '{
    "additional_context": ("SECURITY: arquivo sensível escrito em " + $path + ". Confirme que não contém segredos hardcoded e que está no .gitignore se necessário.")
  }'
  exit 0
fi

echo '{}'
exit 0
