#!/usr/bin/env bash
# Verifica build/web/_headers após flutter build web (Fase D — gate CI/local).
set -euo pipefail

HEADERS_FILE="${1:-build/web/_headers}"

test -f "$HEADERS_FILE"
grep -qx '  Cross-Origin-Opener-Policy: same-origin' "$HEADERS_FILE"
grep -q 'Cross-Origin-Embedder-Policy: require-corp' "$HEADERS_FILE"
grep -q 'flutter_service_worker.js' "$HEADERS_FILE"
grep -A1 'flutter_service_worker.js' "$HEADERS_FILE" | grep -q 'Cache-Control: no-cache'
# sw.js é registado por ?v=<tag>: se a CDN o cacheasse, um deploy novo ficaria
# preso no SW velho até o objeto expirar.
grep -qx '/sw.js' "$HEADERS_FILE"
grep -A1 -x '/sw.js' "$HEADERS_FILE" | grep -q 'Cache-Control: no-cache'

echo "OK: $HEADERS_FILE contém COOP/COEP e no-cache dos service workers."
