#!/usr/bin/env bash
# Verifica build/web/_headers e o service worker gerado — gate CI/local
# (Fase D + shell offline). Corre DEPOIS de cache_bust_web_entrypoints.sh.
set -euo pipefail

HEADERS_FILE="${1:-build/web/_headers}"
WEB_DIR="$(dirname "$HEADERS_FILE")"
SW_FILE="$WEB_DIR/sw.js"
INDEX_FILE="$WEB_DIR/index.html"

test -f "$HEADERS_FILE"
grep -qx '  Cross-Origin-Opener-Policy: same-origin' "$HEADERS_FILE"
grep -q 'Cross-Origin-Embedder-Policy: require-corp' "$HEADERS_FILE"
grep -q 'flutter_service_worker.js' "$HEADERS_FILE"
grep -A1 'flutter_service_worker.js' "$HEADERS_FILE" | grep -q 'Cache-Control: no-cache'
# sw.js é registado por ?v=<tag>: se a CDN o cacheasse, um deploy novo ficaria
# preso no SW velho até o objeto expirar.
grep -qx '/sw.js' "$HEADERS_FILE"
grep -A1 -x '/sw.js' "$HEADERS_FILE" | grep -q 'Cache-Control: no-cache'

# O SW só é válido depois de generate_sw_manifest.py substituir os
# placeholders; um __PLPCG_ restante é erro em runtime e o registo falha em
# silêncio — o app "funcionaria" mas nunca abriria offline.
test -f "$SW_FILE"
test -f "$INDEX_FILE"
if grep -q '__PLPCG_' "$SW_FILE" "$INDEX_FILE"; then
  echo "ERRO: placeholder __PLPCG_ por substituir em $SW_FILE / $INDEX_FILE — corra scripts/cache_bust_web_entrypoints.sh antes." >&2
  exit 1
fi

echo "OK: $HEADERS_FILE contém COOP/COEP e no-cache dos service workers; $SW_FILE sem placeholders."
