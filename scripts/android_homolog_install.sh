#!/usr/bin/env bash
# Instala build de homologação no tablet/phone Android — funciona pelo ícone, sem terminal/debugger.
#
# Pipeline: android_resolve_device.py → flutter build apk --profile → adb install.
# Artefato: build/app/outputs/flutter-apk/app-profile.apk
#
# Modo profile (AOT): abre offline do Mac, diferente do debug que exige flutter run.
# Assinado com debug keystore (homologação local); sem limite de 7 dias como no iOS.
#
# Uso:
#   ./scripts/android_homolog_install.sh
#   FLUTTER_DEVICE_ID=<serial> ./scripts/android_homolog_install.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PACKAGE_ID="com.plpcg.app"
DART_DEFINES_FILE="dart_defines/plpcg.json"
PRIVATE_DEFINES_FILE="dart_defines/private.json"

BUILD_MODE="profile"
ALLOW_NO_DEVICE=false
SKIP_INSTALL=false

for arg in "$@"; do
  case "$arg" in
    --release) BUILD_MODE="release" ;;
    --profile) BUILD_MODE="profile" ;;
    --allow-no-device) ALLOW_NO_DEVICE=true ;;
    --skip-install) SKIP_INSTALL=true ;;
    -h|--help)
      echo "Uso: $0 [--release|--profile] [--allow-no-device] [--skip-install]"
      exit 0
      ;;
  esac
done

APK_PATH="build/app/outputs/flutter-apk/app-${BUILD_MODE}.apk"

DEFINE_ARGS=(--dart-define-from-file="$DART_DEFINES_FILE")
if [[ -f "$PRIVATE_DEFINES_FILE" ]]; then
  echo "==> dart_defines privados: $PRIVATE_DEFINES_FILE"
  DEFINE_ARGS+=(--dart-define-from-file="$PRIVATE_DEFINES_FILE")
fi

ensure_android_toolchain() {
  # shellcheck source=/dev/null
  source "$ROOT_DIR/scripts/android_env.sh"
  if ! command -v adb >/dev/null 2>&1; then
    echo "Erro: adb não encontrado em \$ANDROID_HOME/platform-tools." >&2
    echo "Rode: brew install --cask android-commandlinetools" >&2
    echo "Depois: source scripts/android_env.sh" >&2
    exit 1
  fi
}

resolve_android_device() {
  python3 "$ROOT_DIR/scripts/android_resolve_device.py"
}

install_on_device() {
  local device_id="$1"
  if flutter install -d "$device_id" --use-application-binary="$APK_PATH" 2>/dev/null; then
    return 0
  fi
  echo "    flutter install falhou; tentando adb install..."
  adb -s "$device_id" install -r "$APK_PATH"
}

ensure_android_toolchain

DEVICE_ID=""
if [[ "$SKIP_INSTALL" == false ]]; then
  echo "==> Verificando dispositivo Android..."
  if DEVICE_ID="$(resolve_android_device 2>/dev/null)"; then
    echo "    Dispositivo conectado: $DEVICE_ID"
    echo "==> Desinstalando versão anterior ($PACKAGE_ID)..."
    if adb -s "$DEVICE_ID" uninstall "$PACKAGE_ID" >/dev/null 2>&1; then
      echo "    App desinstalado."
    else
      echo "    App não estava instalado (ok)."
    fi
  else
    if [[ "$ALLOW_NO_DEVICE" == true ]]; then
      echo "    Nenhum dispositivo Android físico detectado (continuando pois --allow-no-device foi informado)."
    else
      # Falha com mensagem detalhada de diagnóstico
      DEVICE_ID="$(resolve_android_device)"
    fi
  fi
fi

echo "==> Dependências Flutter..."
"$ROOT_DIR/scripts/setup_deps.sh"

echo "==> Build Android ($BUILD_MODE — standalone, homologação)..."
flutter build apk "--$BUILD_MODE" "${DEFINE_ARGS[@]}"

if [[ ! -f "$APK_PATH" ]]; then
  echo "Erro: $APK_PATH não encontrado após flutter build." >&2
  exit 1
fi

if [[ -n "$DEVICE_ID" && "$SKIP_INSTALL" == false ]]; then
  echo "==> Instalando no dispositivo ($DEVICE_ID)..."
  install_on_device "$DEVICE_ID"
  echo ""
  echo "Pronto. Abra o app pelo ícone no tablet/telefone."
else
  echo ""
  echo "APK pronto em: $APK_PATH"
  if [[ "$SKIP_INSTALL" == false && -z "$DEVICE_ID" ]]; then
    echo "(Nenhum dispositivo conectado para instalação automática via adb)"
  fi
fi

echo "API: https://plpcg.com (dart_defines/plpcg.json)."

