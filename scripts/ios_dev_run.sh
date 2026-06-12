#!/usr/bin/env bash
# Build e executa o app no iPhone físico (modo debug).
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
