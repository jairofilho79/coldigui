#!/usr/bin/env bash
# Serve a partir de tmp/ para o fetch ../louvores-manifest-grouped.json funcionar.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-8765}"
echo "http://localhost:${PORT}/grouping-viewer/"
cd "$ROOT"
exec python3 -m http.server "$PORT"
