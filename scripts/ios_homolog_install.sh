#!/usr/bin/env bash
# Instala build de homologação no iPhone — funciona pelo ícone, sem terminal/debugger.
#
# Modo profile (AOT): abre offline do Mac, diferente do debug que exige flutter run.
# Validade ~7 dias: limite do perfil de desenvolvimento iOS (Apple); reinstale após expirar.
#
# Uso:
#   ./scripts/ios_homolog_install.sh
#   FLUTTER_DEVICE_ID=<udid> ./scripts/ios_homolog_install.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_ID="com.example.coldigui"
DART_DEFINES_FILE="dart_defines/plpcg.json"

resolve_ios_device() {
  if [[ -n "${FLUTTER_DEVICE_ID:-}" ]]; then
    echo "$FLUTTER_DEVICE_ID"
    return
  fi

  python3 - <<'PY'
import json
import subprocess
import sys

raw = subprocess.check_output(["flutter", "devices", "--machine"], text=True)
devices = json.loads(raw)
ios = [d for d in devices if d.get("targetPlatform") == "ios" and not d.get("emulator")]
if not ios:
    sys.exit("Nenhum iPhone físico conectado. Conecte via USB e tente novamente.")
print(ios[0]["id"])
PY
}

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

echo "==> Build iOS (profile — standalone, ~7 dias de validade)..."
flutter build ios --profile --dart-define-from-file="$DART_DEFINES_FILE"

echo "==> Instalando no iPhone..."
flutter install -d "$DEVICE_ID"

echo ""
echo "Pronto. Abra o app pelo ícone no iPhone."
echo "Se pedir confiança: Ajustes → Geral → VPN e Gerenciamento de Dispositivo."
echo "Reinstale com este script quando o perfil de desenvolvimento expirar (~7 dias)."
