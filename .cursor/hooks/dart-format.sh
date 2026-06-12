#!/bin/bash
# Formata arquivos .dart após edições do Agent ou Tab.

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path // empty')

if [[ -z "$file_path" || "$file_path" != *.dart ]]; then
  exit 0
fi

if ! command -v dart >/dev/null 2>&1; then
  exit 0
fi

dart format "$file_path" >/dev/null 2>&1 || true
exit 0
