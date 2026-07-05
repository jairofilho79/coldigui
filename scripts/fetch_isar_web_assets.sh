#!/usr/bin/env bash
# Baixa isar_plus.js + isar_plus.wasm para web/ (mesma origem, COEP require-corp).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(rg '^  isar_plus:' "$ROOT_DIR/pubspec.yaml" | awk '{print $2}' | tr -d '^')"
BASE="https://unpkg.com/isar_plus@${VERSION}"

for file in isar_plus.js isar_plus.wasm; do
  dest="$ROOT_DIR/web/$file"
  if [[ -f "$dest" ]]; then
    echo "==> $file já existe, pulando"
    continue
  fi
  echo "==> Baixando $file ($VERSION)..."
  curl -fsSL "$BASE/$file" -o "$dest"
done
