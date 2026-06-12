#!/usr/bin/env bash
# Resolve dependências e aplica patch obrigatório do pdfx (swipe horizontal).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

flutter pub get
"$ROOT/scripts/apply_pdfx_patch.sh"
