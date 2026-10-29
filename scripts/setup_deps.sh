#!/usr/bin/env bash
# Resolve dependências Flutter do projeto (mobile, web e desktop).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Idempotente — necessário para `flutter build web` e CI web (Fase 7).
flutter config --enable-web >/dev/null 2>&1 || true

flutter pub get
