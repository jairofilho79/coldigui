#!/bin/bash
# Protege comandos destrutivos comuns em projetos Flutter.

set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.command // empty')

if [[ -z "$command" ]]; then
  echo '{"permission":"allow"}'
  exit 0
fi

if echo "$command" | grep -Eq 'rm\s+-rf\s+(\.|lib/|test/|\.dart_tool|build/|ios/|android/)'; then
  cat <<'EOF'
{
  "permission": "ask",
  "user_message": "Este comando pode apagar arquivos críticos do projeto Flutter.",
  "agent_message": "Um hook pediu confirmação antes de executar rm -rf em diretório sensível."
}
EOF
  exit 0
fi

if echo "$command" | grep -Eq '(^|[;&|]\s*)(flutter\s+clean|dart\s+pub\s+cache\s+clean)'; then
  cat <<'EOF'
{
  "permission": "ask",
  "user_message": "Limpeza de cache/build pode demorar e exigir novo pub get.",
  "agent_message": "Um hook pediu confirmação antes de limpar cache ou build do Flutter/Dart."
}
EOF
  exit 0
fi

echo '{"permission":"allow"}'
exit 0
