#!/usr/bin/env bash
# Mede cold start web e opcionalmente valida contra baseline (Fase H).
#
# Uso:
#   ./scripts/measure_web_boot.sh
#   ./scripts/measure_web_boot.sh --check
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -d build/web ]]; then
  echo "Erro: build/web não existe. Rode:" >&2
  echo "  flutter build web --wasm --release --dart-define-from-file=dart_defines/plpcjf.json" >&2
  exit 1
fi

exec python3 scripts/measure_web_boot.py "$@"
