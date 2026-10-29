#!/usr/bin/env bash
# Deploy unificado: Web, iOS (iPad) e Android (APK).
#
# Pipeline:
#   1. Web:     scripts/web_deploy.sh (Cloudflare Pages → v2.plpcg.com)
#   2. iOS:     scripts/ios_homolog_install.sh (Homologação no iPad físico)
#   3. Android: scripts/android_homolog_install.sh (APK standalone + install no tablet se conectado)
#   4. Finder:  open "build/app/outputs/flutter-apk"
#
# Uso:
#   ./scripts/deploy_all.sh
#   ./scripts/deploy_all.sh --skip-web
#   ./scripts/deploy_all.sh --skip-ios
#   ./scripts/deploy_all.sh --skip-android
#   ./scripts/deploy_all.sh --release      # gera APK release em vez de profile
#   ./scripts/deploy_all.sh --no-open      # não abre o Finder ao terminar
set -euo pipefail

# Resolve o caminho canônico do script mesmo se chamado por symlink
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

if [[ -f "$SCRIPT_DIR/pubspec.yaml" ]]; then
  ROOT_DIR="$SCRIPT_DIR"
elif [[ -f "$SCRIPT_DIR/../pubspec.yaml" ]]; then
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
cd "$ROOT_DIR"


SKIP_WEB=false
SKIP_IOS=false
SKIP_ANDROID=false
SKIP_BUILD_WEB=false
OPEN_APK_FOLDER=true
BUILD_MODE="profile" # profile (homologação padrão) ou release

for arg in "$@"; do
  case "$arg" in
    --skip-web) SKIP_WEB=true ;;
    --skip-ios) SKIP_IOS=true ;;
    --skip-android) SKIP_ANDROID=true ;;
    --skip-build-web) SKIP_BUILD_WEB=true ;;
    --no-open) OPEN_APK_FOLDER=false ;;
    --release) BUILD_MODE="release" ;;
    --profile) BUILD_MODE="profile" ;;
    -h|--help)
      echo "Uso: $0 [opções]"
      echo ""
      echo "Opções:"
      echo "  --skip-web        Pula o deploy Web (Cloudflare Pages)"
      echo "  --skip-ios        Pula o deploy iOS (iPad físico)"
      echo "  --skip-android    Pula o deploy Android (APK)"
      echo "  --skip-build-web  Reusa build/web existente no deploy Web"
      echo "  --release         Compila APK Android em modo release (padrão: profile)"
      echo "  --profile         Compila APK Android em modo profile"
      echo "  --no-open         Não abre a pasta do APK no Finder ao terminar"
      echo "  -h, --help        Exibe esta mensagem de ajuda"
      exit 0
      ;;
    *)
      echo "Opção desconhecida: $arg" >&2
      echo "Use $0 --help para ver as opções disponíveis." >&2
      exit 1
      ;;
  esac
done

# Cores para formatação de terminal
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
START_TIME="$(TZ="America/Sao_Paulo" date "+%d/%m/%Y %H:%M:%S (UTC-3)" 2>/dev/null || date "+%d/%m/%Y %H:%M:%S")"

echo -e "${BOLD}${BLUE}================================================================${NC}"
echo -e "${BOLD}${BLUE}   DEPLOY MULTIPLATAFORMA — Web | iPad (iOS) | Android          ${NC}"
echo -e "${BOLD}${BLUE}================================================================${NC}"
echo -e "Data de início : $START_TIME"
echo -e "Commit         : $COMMIT"
echo -e "Modo APK       : $BUILD_MODE"
echo ""

# Carrega ferramentas do ambiente Android (adb, JAVA_HOME, ANDROID_HOME)
if [[ -f "$ROOT_DIR/scripts/android_env.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/scripts/android_env.sh"
fi

# 1. Dependências do Flutter (uma vez para todas as etapas)
echo -e "${BOLD}==> Preparando dependências do projeto...${NC}"
"$ROOT_DIR/scripts/setup_deps.sh"
echo ""

# 2. Deploy Web (Cloudflare Pages)
if [[ "$SKIP_WEB" == false ]]; then
  echo -e "${BOLD}${BLUE}----------------------------------------------------------------${NC}"
  echo -e "${BOLD}${BLUE}[1/3] Deploy Web — Cloudflare Pages (v2.plpcg.com)${NC}"
  echo -e "${BOLD}${BLUE}----------------------------------------------------------------${NC}"
  
  WEB_DEPLOY_ARGS=()
  if [[ "$SKIP_BUILD_WEB" == true ]]; then
    WEB_DEPLOY_ARGS+=(--skip-build)
  fi

  "$ROOT_DIR/scripts/web_deploy.sh" "${WEB_DEPLOY_ARGS[@]}"
  echo ""
else
  echo -e "${YELLOW}==> [1/3] Deploy Web pulado (--skip-web).${NC}"
  echo ""
fi

# 3. Deploy iOS (iPad físico)
if [[ "$SKIP_IOS" == false ]]; then
  echo -e "${BOLD}${BLUE}----------------------------------------------------------------${NC}"
  echo -e "${BOLD}${BLUE}[2/3] Deploy iOS — Homologação iPad físico${NC}"
  echo -e "${BOLD}${BLUE}----------------------------------------------------------------${NC}"
  
  "$ROOT_DIR/scripts/ios_homolog_install.sh"
  echo ""
else
  echo -e "${YELLOW}==> [2/3] Deploy iOS pulado (--skip-ios).${NC}"
  echo ""
fi

# 4. Deploy Android (APK + instalação se conectado)
if [[ "$SKIP_ANDROID" == false ]]; then
  echo -e "${BOLD}${BLUE}----------------------------------------------------------------${NC}"
  echo -e "${BOLD}${BLUE}[3/3] Deploy Android — APK ($BUILD_MODE)${NC}"
  echo -e "${BOLD}${BLUE}----------------------------------------------------------------${NC}"
  
  "$ROOT_DIR/scripts/android_homolog_install.sh" "--$BUILD_MODE" --allow-no-device
  echo ""
else
  echo -e "${YELLOW}==> [3/3] Deploy Android pulado (--skip-android).${NC}"
  echo ""
fi

APK_DIR="$ROOT_DIR/build/app/outputs/flutter-apk"

# 5. Abrir pasta do APK no Finder
if [[ "$OPEN_APK_FOLDER" == true ]]; then
  echo -e "${BOLD}${BLUE}----------------------------------------------------------------${NC}"
  echo -e "${BOLD}${BLUE}Abrindo pasta do APK no Finder...${NC}"
  echo -e "${BOLD}${BLUE}----------------------------------------------------------------${NC}"

  if [[ -d "$APK_DIR" ]]; then
    echo -e "Pasta: ${GREEN}$APK_DIR${NC}"
    if command -v open >/dev/null 2>&1; then
      open "$APK_DIR"
    fi
  else
    echo -e "${YELLOW}Aviso: Diretório $APK_DIR ainda não existe.${NC}"
  fi
  echo ""
fi

FINISH_TIME="$(TZ="America/Sao_Paulo" date "+%d/%m/%Y %H:%M:%S (UTC-3)" 2>/dev/null || date "+%d/%m/%Y %H:%M:%S")"

echo -e "${BOLD}${GREEN}================================================================${NC}"
echo -e "${BOLD}${GREEN}   DEPLOY CONCLUÍDO COM SUCESSO! 🎉                             ${NC}"
echo -e "${BOLD}${GREEN}================================================================${NC}"
echo -e "Concluído em: $FINISH_TIME"
if [[ "$SKIP_WEB" == false ]]; then
  echo -e "  • Web     : https://v2.plpcg.com"
fi
if [[ "$SKIP_IOS" == false ]]; then
  echo -e "  • iOS     : Instalado no iPad"
fi
if [[ "$SKIP_ANDROID" == false ]]; then
  echo -e "  • Android : APK disponível em $APK_DIR"
fi
echo -e "${BOLD}${GREEN}================================================================${NC}"
