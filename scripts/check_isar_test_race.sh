#!/usr/bin/env bash
# Reproduz a race de extração do isar_plus em `flutter test` (worktree novo).
#
# Apaga o cache .dart_tool/isar_plus_test e dispara vários processos
# flutter_tester de uma vez: todos passam por test/flutter_test_config.dart ->
# ensureIsarPlusTestCore() ao mesmo tempo. Antes da extração atômica com lock
# isso quebrava com «libisar_plus.a ausente após extração do xcframework» e
# deixava um xcframework/ vazio para trás (a suíte ficava quebrada até um
# `rm -rf` manual). Uso: ./scripts/check_isar_test_race.sh [concurrency]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONCURRENCY="${1:-8}"
CACHE_DIR=".dart_tool/isar_plus_test"

rm -rf "$CACHE_DIR"

# Diretórios pequenos, só para ter >= CONCURRENCY arquivos carregando juntos.
flutter test --concurrency="$CONCURRENCY" \
  test/unit/features/chords \
  test/unit/features/gestures

test -s "$CACHE_DIR/libisar_plus.dylib" || test -s "$CACHE_DIR/libisar_plus.so" \
  || { echo "ERRO: binário isar_plus não foi gerado em $CACHE_DIR" >&2; exit 1; }
test -z "$(ls -d "$CACHE_DIR"/xcframework "$CACHE_DIR"/.work_* 2>/dev/null)" \
  || { echo "ERRO: resíduo de extração (xcframework/ ou .work_*) ficou em $CACHE_DIR" >&2; exit 1; }

echo "OK: extração do isar_plus sobreviveu a $CONCURRENCY processos concorrentes."
