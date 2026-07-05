#!/usr/bin/env bash
# Verifica build/web/_headers após flutter build web (Fase D — gate CI/local).
set -euo pipefail

HEADERS_FILE="${1:-build/web/_headers}"

test -f "$HEADERS_FILE"
grep -q 'Cross-Origin-Opener-Policy: same-origin' "$HEADERS_FILE"
grep -q 'Cross-Origin-Embedder-Policy: require-corp' "$HEADERS_FILE"
grep -q 'flutter_service_worker.js' "$HEADERS_FILE"
grep -A1 'flutter_service_worker.js' "$HEADERS_FILE" | grep -q 'Cache-Control: no-cache'

echo "OK: $HEADERS_FILE contém COOP/COEP e no-cache do service worker."
