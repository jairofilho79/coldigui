#!/usr/bin/env bash
# Prepara e compila o Release iOS (Archive / IPA) para envio à App Store.
#
# Uso:
#   ./scripts/build_ios_ipa.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DART_DEFINES_FILE="dart_defines/plpcg.json"
PRIVATE_DEFINES_FILE="dart_defines/private.json"

DEFINE_ARGS=(--dart-define-from-file="$DART_DEFINES_FILE")
if [[ -f "$PRIVATE_DEFINES_FILE" ]]; then
  echo "==> Usando defines privados: $PRIVATE_DEFINES_FILE"
  DEFINE_ARGS+=(--dart-define-from-file="$PRIVATE_DEFINES_FILE")
fi

APP_VERSION=$(grep '^version:' "$ROOT_DIR/pubspec.yaml" | sed 's/version:[[:space:]]*//' | tr -d '\r\n')

echo "==> Compilando pacote Release iOS PLPCG v${APP_VERSION}..."
flutter build ipa --release "${DEFINE_ARGS[@]}"

echo ""
echo "================================================================="
echo "✅ Processo de build iOS v${APP_VERSION} concluído!"
echo "   Você pode subir o pacote gerado via app Transporter ou abrir"
echo "   o Xcode Organizer para fazer o upload com 1 clique para a App Store."
echo "================================================================="
