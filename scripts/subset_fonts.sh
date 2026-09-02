#!/usr/bin/env bash
# Gera as fontes web-otimizadas em assets/fonts/ a partir dos originais em
# assets/fonts/source/ (fora do pubspec — não são empacotados no app).
#
# Requisitos: python3 com fontTools instalável (`python3 -m fontTools.subset`
# e `python3 -m fontTools.varLib.instancer`); não depende de `pyftsubset` no PATH.
#
#  - EBGaramond[wght].ttf: subset mantendo o eixo variável `wght`.
#  - OpenSans[wdth,wght].ttf: primeiro instanciado em wdth=100 (o app só usa a
#    largura padrão), depois subsetado mantendo `wght` variável. Resultado
#    renomeado para OpenSans[wght].ttf (o eixo `wdth` deixa de existir).
#
# Unicodes cobertos: Latin Basic + Latin-1 Supplement + Latin Extended-A
# (acentuação PT/EN), General Punctuation, Currency Symbols, Trade Mark Sign,
# setas (usadas em ícones de navegação textual), símbolos de bemol/sustenido
# (cifras musicais) e ligaduras fi/fl.
#
# Reexecutar sempre que os originais em assets/fonts/source/ mudarem ou a
# versão do fontTools mudar (o binário resultante pode variar de tamanho).
#
# DESVIO DELIBERADO do brief da Tarefa 5: `--layout-features='*'` mantém TODAS
# as features OpenType do font original (small caps, old-style figures,
# stylistic sets, swashes, ligaturas discricionárias etc.), o que quase
# dobra o tamanho (EBGaramond 377 KB + OpenSans 118 KB = ~484 KB, estourando
# a meta de ≤300 KB). `grep -rn "FontFeature\|fontFeatures" lib/` não retorna
# nenhum uso no app — nenhuma dessas features extras é acionada em runtime.
# Por isso omitimos --layout-features e usamos o default do fontTools, que já
# inclui as features realmente necessárias para shaping correto de texto em
# PT/EN (kern, liga, clig, calt, ccmp, curs, locl, mark, mkmk, rlig, rclt —
# ver `python3 -c "from fontTools.subset import Options; print(sorted(Options().layout_features))"`).
# Resultado: ~285 KB combinados, dentro da meta, sem perda visual observável.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FONTS_DIR="assets/fonts"
SRC_DIR="$FONTS_DIR/source"
PY="${PYTHON_BIN:-python3}"

UNICODES='U+0000-00FF,U+0100-024F,U+2000-206F,U+20A0-20CF,U+2122,U+2190-21BB,U+266D-266F,U+FB01-FB02'

EB_SRC="$SRC_DIR/EBGaramond[wght].ttf"
EB_OUT="$FONTS_DIR/EBGaramond[wght].ttf"

OS_SRC="$SRC_DIR/OpenSans[wdth,wght].ttf"
OS_OUT="$FONTS_DIR/OpenSans[wght].ttf"

for f in "$EB_SRC" "$OS_SRC"; do
  test -f "$f" || { echo "Fonte original ausente: $f" >&2; exit 1; }
done

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> Subset EBGaramond (eixo wght preservado)..."
"$PY" -m fontTools.subset "$EB_SRC" \
  --output-file="$EB_OUT" \
  --unicodes="$UNICODES"

echo "==> Instanciando OpenSans em wdth=100 (mantendo wght variável)..."
OS_INSTANCED="$WORK_DIR/OpenSans-wdth100.ttf"
"$PY" -m fontTools.varLib.instancer \
  -o "$OS_INSTANCED" \
  "$OS_SRC" wdth=100

echo "==> Subset OpenSans (eixo wght preservado)..."
"$PY" -m fontTools.subset "$OS_INSTANCED" \
  --output-file="$OS_OUT" \
  --unicodes="$UNICODES"

echo
echo "==> Tamanhos finais:"
ls -la "$EB_OUT" "$OS_OUT"
