#!/usr/bin/env bash
# Build + deploy do Flutter Web (WASM) em Cloudflare Pages (plpcg-v2 → v2.plpcg.com).
#
# Uso:
#   ./scripts/web_deploy.sh           # build limpo + deploy
#   ./scripts/web_deploy.sh --skip-build  # só deploy do build/web existente
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_NAME="plpcg-v2"
BRANCH="web/integration"
PRODUCTION_URL="https://v2.plpcg.com"
SKIP_BUILD=false

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=true ;;
    -h|--help)
      echo "Uso: $0 [--skip-build]"
      exit 0
      ;;
    *)
      echo "Argumento desconhecido: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ "$SKIP_BUILD" == false ]]; then
  echo "==> Build limpo..."
  rm -rf build/web
  "$ROOT_DIR/scripts/web_build.sh"
else
  if [[ ! -f build/web/version.json ]]; then
    echo "Erro: build/web/version.json não existe. Rode sem --skip-build." >&2
    exit 1
  fi
  echo "==> Reusando build/web existente..."
fi

COMMIT="$(git rev-parse --short HEAD)"
CACHE_TAG="$(
  python3 -c "import json; print(json.load(open('build/web/version.json')).get('web_cache_tag',''))"
)"

echo "==> Deploy Cloudflare Pages (${PROJECT_NAME}, branch ${BRANCH})..."
DEPLOY_LOG="$(mktemp)"
trap 'rm -f "$DEPLOY_LOG"' EXIT

wrangler pages deploy build/web \
  --project-name "$PROJECT_NAME" \
  --branch "$BRANCH" \
  --commit-dirty=true \
  2>&1 | tee "$DEPLOY_LOG"

PREVIEW_URL="$(
  grep -Eo 'https://[a-z0-9]+\.plpcg-v2\.pages\.dev' "$DEPLOY_LOG" | tail -1 || true
)"

if [[ -z "$PREVIEW_URL" ]]; then
  PREVIEW_URL="(não encontrado no output do wrangler)"
fi

echo
echo "┌────────────┬──────────────────────────────────────────────┐"
printf "│ %-10s │ %-44s │\n" "Item" "Valor"
echo "├────────────┼──────────────────────────────────────────────┤"
printf "│ %-10s │ %-44s │\n" "Commit" "$COMMIT"
printf "│ %-10s │ %-44s │\n" "Cache tag" "$CACHE_TAG"
printf "│ %-10s │ %-44s │\n" "Preview" "$PREVIEW_URL"
printf "│ %-10s │ %-44s │\n" "Produção" "$PRODUCTION_URL"
echo "└────────────┴──────────────────────────────────────────────┘"
