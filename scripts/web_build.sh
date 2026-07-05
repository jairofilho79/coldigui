#!/usr/bin/env bash
# Build release do app Flutter Web (WASM) para deploy em v2.plpcg.com.
#
# Usa dart_defines/plpcjf.json (API em plpcg.com; frontend em v2.plpcg.com / plpcjf.org — D7).
# Requer cabeçalhos COOP/COEP no hosting — ver web/_headers (D6).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DART_DEFINES_FILE="dart_defines/plpcjf.json"

echo "==> Dependências Flutter..."
"$ROOT_DIR/scripts/setup_deps.sh"

echo "==> Assets Isar web (OPFS + COEP)..."
"$ROOT_DIR/scripts/fetch_isar_web_assets.sh"

echo "==> Build Web (WASM, release)..."
flutter build web \
  --wasm \
  --release \
  --dart-define-from-file="$DART_DEFINES_FILE"

echo "==> Artefato em build/web/"
"$ROOT_DIR/scripts/verify_web_headers_artifact.sh"
