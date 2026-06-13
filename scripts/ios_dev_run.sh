#!/usr/bin/env bash
# Build e executa o app no iPhone/iPad físico (modo debug).
#
# Usa Runner-Homolog.entitlements (sem Associated Domains) — conta Apple pessoal.
# Resolve dispositivo via scripts/ios_resolve_device.py (iPhone ou iPad).
#
# Usa ios/Runner.xcworkspace (projeto real). Evita --use-application-binary,
# que cria um Runner.xcworkspace temporário em /var/folders/.../flutter_empty_xcode.*
# e faz o Xcode exibir "workspace file has disappeared" quando o Flutter encerra.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_ID="com.example.coldigui"
DART_DEFINES_FILE="dart_defines/plpcg.json"

resolve_ios_device() {
  python3 "$ROOT_DIR/scripts/ios_resolve_device.py"
}

if pgrep -x Xcode >/dev/null 2>&1; then
  echo "==> Fechando Xcode (evita conflito com flutter run)..."
  osascript -e 'quit app "Xcode"' >/dev/null 2>&1 || true
  sleep 2
fi

echo "==> Resolvendo dispositivo iOS..."
DEVICE_ID="$(resolve_ios_device)"
echo "    Dispositivo: $DEVICE_ID"

echo "==> Desinstalando versão anterior ($BUNDLE_ID)..."
if xcrun devicectl device uninstall app -d "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1; then
  echo "    App desinstalado."
else
  echo "    App não estava instalado (ok)."
fi

echo "==> Dependências + patch pdfx (swipe horizontal)..."
"$ROOT_DIR/scripts/setup_deps.sh"

echo "==> Build iOS (debug)..."
flutter build ios --debug --dart-define-from-file="$DART_DEFINES_FILE"

echo "==> Executando no dispositivo (workspace real: ios/Runner.xcworkspace)..."
flutter run \
  --dart-define-from-file="$DART_DEFINES_FILE" \
  -d "$DEVICE_ID"
