#!/usr/bin/env bash
# Resolve dependências Flutter do projeto.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

flutter pub get
