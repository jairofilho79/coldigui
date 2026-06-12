#!/usr/bin/env bash
# Aplica patch local ao pdfx (bug scroll horizontal — divisão por zero em _determinePagesToShow).
# Executar após `flutter pub get` quando o cache do pdfx for recriado.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PDFX_DIR="$(find "${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev" -maxdepth 1 -type d -name 'pdfx-2.9.2' 2>/dev/null | head -1)"

if [[ -z "$PDFX_DIR" ]]; then
  echo "pdfx 2.9.2 não encontrado no pub cache; rode flutter pub get primeiro." >&2
  exit 1
fi

TARGET="$PDFX_DIR/lib/src/viewer/pinch/pdf_view_pinch.dart"
python3 - "$TARGET" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()

marker = "scrollExtent = _docSize!.width - _lastViewSize!.width"
if marker in text:
    print(f"Patch pdfx já aplicado em {path}")
    raise SystemExit(0)

old = """    if (_lastViewSize?.height != null) {
      final rawDocumentProgress =
          ((exposed.bottom / r - _lastViewSize!.height) /
              (_docSize!.height - _lastViewSize!.height));
      const precisionFactor = 10000;
      _controller._documentProgress =
          ((rawDocumentProgress * precisionFactor).round() / precisionFactor)
              .clamp(0.0, 1.0);
    }"""

new = """    if (_lastViewSize != null && _docSize != null) {
      final double rawDocumentProgress;
      if (widget.scrollDirection == Axis.horizontal) {
        final scrollExtent = _docSize!.width - _lastViewSize!.width;
        rawDocumentProgress = scrollExtent > 0
            ? ((exposed.right / r - _lastViewSize!.width) / scrollExtent)
            : 0.0;
      } else {
        final scrollExtent = _docSize!.height - _lastViewSize!.height;
        rawDocumentProgress = scrollExtent > 0
            ? ((exposed.bottom / r - _lastViewSize!.height) / scrollExtent)
            : 0.0;
      }
      const precisionFactor = 10000;
      if (rawDocumentProgress.isFinite) {
        _controller._documentProgress =
            ((rawDocumentProgress * precisionFactor).round() / precisionFactor)
                .clamp(0.0, 1.0);
      } else {
        _controller._documentProgress = 0.0;
      }
    }"""

if old not in text:
    print(f"Bloco alvo não encontrado em {path}; versão do pdfx inesperada.", file=sys.stderr)
    raise SystemExit(1)

path.write_text(text.replace(old, new, 1))
print(f"Patch pdfx aplicado em {path}")
PY
