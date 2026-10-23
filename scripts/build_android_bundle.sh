#!/usr/bin/env bash
# Gera o pacote oficial Android App Bundle (.aab) assinado para publicação na Google Play Store.
#
# Uso:
#   ./scripts/build_android_bundle.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Carrega ambiente Java 17 e Android SDK
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/android_env.sh"

KEY_PROPS="$ROOT_DIR/android/key.properties"
KEYSTORE="$ROOT_DIR/android/app/upload-keystore.jks"

if [[ ! -f "$KEY_PROPS" || ! -f "$KEYSTORE" ]]; then
  echo "ERRO: Chave de assinatura não encontrada!"
  echo "Certifique-se de que '$KEY_PROPS' e '$KEYSTORE' existam."
  exit 1
fi

DART_DEFINES_FILE="dart_defines/plpcg.json"
PRIVATE_DEFINES_FILE="dart_defines/private.json"

DEFINE_ARGS=(--dart-define-from-file="$DART_DEFINES_FILE")
if [[ -f "$PRIVATE_DEFINES_FILE" ]]; then
  echo "==> Usando defines privados: $PRIVATE_DEFINES_FILE"
  DEFINE_ARGS+=(--dart-define-from-file="$PRIVATE_DEFINES_FILE")
fi

echo "==> Compilando Android App Bundle (.aab) em modo Release..."
flutter build appbundle --release "${DEFINE_ARGS[@]}"

AAB_OUTPUT="build/app/outputs/bundle/release/app-release.aab"
if [[ -f "$AAB_OUTPUT" ]]; then
  echo ""
  echo "================================================================="
  echo "✅ SUCESSO! Android App Bundle gerado com sucesso:"
  echo "   $ROOT_DIR/$AAB_OUTPUT"
  echo "   Tamanho: $(du -h "$AAB_OUTPUT" | cut -f1)"
  echo "================================================================="
  echo "Este é o arquivo que você fará upload no Google Play Console!"
else
  echo "ERRO: O arquivo .aab não foi encontrado em $AAB_OUTPUT"
  exit 1
fi
