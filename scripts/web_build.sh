#!/usr/bin/env bash
# Build release do app Flutter Web (WASM) para deploy em v2.plpcg.com.
#
# Usa dart_defines/plpcjf.json (API em plpcg.com; frontend em v2.plpcg.com / plpcjf.org — D7).
# Se existir, também aplica dart_defines/private.json (gitignored — Client ID Google).
# Requer cabeçalhos COOP/COEP no hosting — ver web/_headers (D6).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DART_DEFINES_FILE="dart_defines/plpcjf.json"
PRIVATE_DEFINES_FILE="dart_defines/private.json"

DEFINE_ARGS=(--dart-define-from-file="$DART_DEFINES_FILE")

if [[ -f "$PRIVATE_DEFINES_FILE" ]]; then
  echo "==> dart_defines privados: $PRIVATE_DEFINES_FILE"
  DEFINE_ARGS+=(--dart-define-from-file="$PRIVATE_DEFINES_FILE")
else
  echo "Aviso: $PRIVATE_DEFINES_FILE ausente — login Google ficará desabilitado no build." >&2
  echo "  Copie dart_defines/private.json.example → private.json e cole o Client ID Web." >&2
fi

echo "==> Dependências Flutter..."
"$ROOT_DIR/scripts/setup_deps.sh"

echo "==> Assets Isar web (OPFS + COEP)..."
"$ROOT_DIR/scripts/fetch_isar_web_assets.sh"

echo "==> Build Web (WASM, release)..."
# --no-tree-shake-icons: subset de MaterialIcons muda quando o menu troca ícones;
# /assets/* é cache immutable — fonte velha = ícones em branco no bottom nav.
# just_audio_web: se faltar no registrant, ensureAudioWebPlatformRegistered cobre no boot.
flutter build web \
  --wasm \
  --release \
  --no-tree-shake-icons \
  "${DEFINE_ARGS[@]}"

echo "==> Artefato em build/web/"
"$ROOT_DIR/scripts/verify_web_headers_artifact.sh"
"$ROOT_DIR/scripts/cache_bust_web_entrypoints.sh"

COMMIT="$(git rev-parse --short HEAD)"
CACHE_TAG="$(
  python3 -c "import json; print(json.load(open('build/web/version.json')).get('web_cache_tag',''))"
)"

echo
echo "Build OK — Commit: ${COMMIT} | Cache tag: ${CACHE_TAG}"
echo "Para publicar: ./scripts/web_deploy.sh [--skip-build]"
