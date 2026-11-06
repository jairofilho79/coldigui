#!/usr/bin/env bash
# Baixa isar_plus.js + isar_plus.wasm para web/ (mesma origem, COEP require-corp).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(awk '/^  isar_plus:/ {found=1; next} found && /^  [^ ]/ {exit} found && $1 == "version:" {gsub(/"/, "", $2); print $2; exit}' "$ROOT_DIR/pubspec.lock")"
if [[ -z "$VERSION" ]]; then
  echo "Erro: versão de isar_plus ausente no pubspec.lock; execute flutter pub get." >&2
  exit 1
fi
BASE="https://unpkg.com/isar_plus@${VERSION}"
WORK_DIR="$(mktemp -d)"
trap 'rm -f "$WORK_DIR/isar_plus.js" "$WORK_DIR/isar_plus.wasm"; rmdir "$WORK_DIR"' EXIT

for file in isar_plus.js isar_plus.wasm; do
  echo "==> Baixando $file ($VERSION)..."
  curl -fsSL "$BASE/$file" -o "$WORK_DIR/$file"
done

for file in isar_plus.js isar_plus.wasm; do
  mv "$WORK_DIR/$file" "$ROOT_DIR/web/$file"
done
