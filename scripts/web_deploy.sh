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
COMMIT_FULL="$(git rev-parse HEAD)"
CACHE_TAG="$(
  python3 -c "import json; print(json.load(open('build/web/version.json')).get('web_cache_tag',''))"
)"

# Identifica commit do deploy anterior para saber quais commits foram adicionados
GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || true)"
LAST_DEPLOY_FILE=""
if [[ -n "$GIT_DIR" ]]; then
  LAST_DEPLOY_FILE="$(git rev-parse --path-format=absolute --git-path last_web_deploy_commit 2>/dev/null || echo "$ROOT_DIR/.git/last_web_deploy_commit")"
fi

PREV_COMMIT=""
if [[ -n "$LAST_DEPLOY_FILE" && -f "$LAST_DEPLOY_FILE" ]]; then
  PREV_COMMIT="$(tr -d '[:space:]' < "$LAST_DEPLOY_FILE" 2>/dev/null || true)"
fi

# Fallback se não houver arquivo local de deploy anterior: consulta Cloudflare Pages
if [[ -z "$PREV_COMMIT" ]]; then
  PREV_COMMIT="$(wrangler pages deployment list --project-name "$PROJECT_NAME" 2>/dev/null | awk -F'│' '$3 ~ /Production/ {gsub(/[[:space:]]/, "", $5); print $5; exit}' || true)"
fi

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

DEPLOY_TIME="$(TZ="America/Sao_Paulo" date "+%d/%m/%Y %H:%M:%S (UTC-3)" 2>/dev/null || date "+%d/%m/%Y %H:%M:%S")"

PREV_COMMIT_FULL=""
if [[ -n "$PREV_COMMIT" ]]; then
  PREV_COMMIT_FULL="$(git rev-parse "$PREV_COMMIT" 2>/dev/null || true)"
fi

COMMITS_HEADER=""
COMMITS_OUTPUT=""

if [[ -n "$PREV_COMMIT_FULL" && "$PREV_COMMIT_FULL" == "$COMMIT_FULL" ]]; then
  COMMITS_HEADER="Commit do deploy (mesmo commit do deploy anterior — redeploy):"
  COMMITS_OUTPUT="$(TZ="America/Sao_Paulo" git log -1 --pretty=format:"  * %h - %s (%cd)" --date=format-local:"%d/%m/%Y %H:%M" "$COMMIT_FULL" 2>/dev/null || true)"
elif [[ -n "$PREV_COMMIT_FULL" ]] && git merge-base --is-ancestor "$PREV_COMMIT_FULL" "$COMMIT_FULL" 2>/dev/null; then
  PREV_SHORT="$(git rev-parse --short "$PREV_COMMIT_FULL")"
  COUNT="$(git rev-list --count "${PREV_COMMIT_FULL}..${COMMIT_FULL}" 2>/dev/null || echo "0")"
  if [[ "$COUNT" -eq 1 ]]; then
    COMMITS_HEADER="1 commit adicionado neste deploy (desde ${PREV_SHORT}):"
  else
    COMMITS_HEADER="${COUNT} commits adicionados neste deploy (desde ${PREV_SHORT}):"
  fi
  COMMITS_OUTPUT="$(TZ="America/Sao_Paulo" git log "${PREV_COMMIT_FULL}..${COMMIT_FULL}" --pretty=format:"  * %h - %s (%cd)" --date=format-local:"%d/%m/%Y %H:%M" 2>/dev/null || true)"
else
  COMMITS_HEADER="Último commit incluído no deploy:"
  COMMITS_OUTPUT="$(TZ="America/Sao_Paulo" git log -1 --pretty=format:"  * %h - %s (%cd)" --date=format-local:"%d/%m/%Y %H:%M" "$COMMIT_FULL" 2>/dev/null || true)"
fi

# Salva o commit deste deploy como referência para os próximos
if [[ -n "$LAST_DEPLOY_FILE" ]]; then
  echo "$COMMIT_FULL" > "$LAST_DEPLOY_FILE"
fi

echo
echo "┌────────────┬──────────────────────────────────────────────────────────┐"
printf "│ %-10s │ %-56s │\n" "Item" "Valor"
echo "├────────────┼──────────────────────────────────────────────────────────┤"
printf "│ %-10s │ %-56s │\n" "Data/Hora" "$DEPLOY_TIME"
printf "│ %-10s │ %-56s │\n" "Commit" "$COMMIT"
printf "│ %-10s │ %-56s │\n" "Cache tag" "$CACHE_TAG"
printf "│ %-10s │ %-56s │\n" "Preview" "$PREVIEW_URL"
printf "│ %-12s │ %-56s │\n" "Produção" "$PRODUCTION_URL"
echo "└────────────┴──────────────────────────────────────────────────────────┘"

if [[ -n "$COMMITS_HEADER" ]]; then
  echo
  echo "==> ${COMMITS_HEADER}"
  if [[ -n "$COMMITS_OUTPUT" ]]; then
    echo "$COMMITS_OUTPUT"
  fi
fi

if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  echo
  echo "Aviso: existem arquivos modificados e não commitados no working tree."
fi

