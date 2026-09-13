#!/usr/bin/env bash
# Verificação local igual às etapas de teste do CI (.github/workflows/web.yml):
#   1. flutter analyze
#   2. flutter test                       — suíte VM (unit/widget/integration)
#   3. flutter test --platform chrome ... — só test/web/ (@TestOn('browser'))
#
# Os testes de test/web/ marcados @TestOn('browser') não carregam no VM (não
# aparecem nem como skipped); só existem de verdade na etapa 3. Sem ela a
# verificação local está incompleta.
#
# Uso: ./scripts/test_all.sh [--vm-only] [args extras para o `flutter test` VM]
#   --vm-only  pula a etapa Chrome (sem Chrome instalado / rodada rápida).
#   CHROME_EXECUTABLE pode apontar para um Chrome específico.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VM_ONLY=0
if [ "${1:-}" = "--vm-only" ]; then
  VM_ONLY=1
  shift
fi

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test (VM)"
flutter test "$@"

if [ "$VM_ONLY" = "1" ]; then
  echo "==> alvo Chrome pulado (--vm-only)"
  exit 0
fi

echo "==> flutter test --platform chrome test/web/"
flutter test \
  --platform chrome \
  --dart-define-from-file=dart_defines/plpcjf.json \
  test/web/

echo "OK: analyze + VM + Chrome verdes."
