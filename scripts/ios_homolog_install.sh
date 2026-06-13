#!/usr/bin/env bash
# Instala build de homologação no iPhone/iPad — funciona pelo ícone, sem terminal/debugger.
#
# Pipeline: ios_resolve_device.py → flutter build --profile → xcodebuild
#   -allowProvisioningUpdates (registra UDID no profile) → install.
# Artefato: build/ios/XcodeDerivedData/Build/Products/Profile-iphoneos/Runner.app
#
# Modo profile (AOT): abre offline do Mac, diferente do debug que exige flutter run.
# Validade ~7 dias: limite do perfil de desenvolvimento iOS (Apple); reinstale após expirar.
# Usa Runner-Homolog.entitlements (sem Associated Domains) — conta Apple pessoal não suporta deep links.
#
# Uso:
#   ./scripts/ios_homolog_install.sh
#   FLUTTER_DEVICE_ID=<udid> ./scripts/ios_homolog_install.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_ID="com.example.coldigui"
DART_DEFINES_FILE="dart_defines/plpcg.json"
DERIVED_DATA="build/ios/XcodeDerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Profile-iphoneos/Runner.app"

resolve_ios_device() {
  python3 "$ROOT_DIR/scripts/ios_resolve_device.py"
}

install_on_device() {
  local device_id="$1"
  if flutter install -d "$device_id" --use-application-binary="$APP_PATH" 2>/dev/null; then
    return 0
  fi
  echo "    flutter install falhou; tentando devicectl..."
  xcrun devicectl device install app -d "$device_id" "$APP_PATH"
}

echo "==> Resolvendo dispositivo iOS (deve aparecer em 'flutter devices')..."
DEVICE_ID="$(resolve_ios_device)"

echo "==> Desinstalando versão anterior ($BUNDLE_ID)..."
if xcrun devicectl device uninstall app -d "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1; then
  echo "    App desinstalado."
else
  echo "    App não estava instalado (ok)."
fi

echo "==> Dependências + patch pdfx (swipe horizontal)..."
"$ROOT_DIR/scripts/setup_deps.sh"

echo "==> Build iOS (profile — standalone, ~7 dias de validade)..."
flutter build ios --profile --dart-define-from-file="$DART_DEFINES_FILE"

echo "==> Assinatura para o dispositivo conectado (provisioning profile)..."
xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Profile \
  -destination "id=$DEVICE_ID" \
  -allowProvisioningUpdates \
  -derivedDataPath "$DERIVED_DATA" \
  DEVELOPMENT_TEAM=PX8Z8276X5 \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Erro: $APP_PATH não encontrado após xcodebuild." >&2
  exit 1
fi

echo "==> Instalando no dispositivo..."
install_on_device "$DEVICE_ID"

echo ""
echo "Pronto. Abra o app pelo ícone no dispositivo."
echo "Se pedir confiança: Ajustes → Geral → VPN e Gerenciamento de Dispositivo."
echo "Reinstale com este script quando o perfil de desenvolvimento expirar (~7 dias)."
