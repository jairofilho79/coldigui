#!/usr/bin/env bash
# Anexa ?v=<tag> aos entrypoints do build web — contorna CDN com cache immutable
# em v2.plpcg.com quando purge manual não invalida objetos antigos.
set -euo pipefail

WEB_DIR="${1:-build/web}"
INDEX="$WEB_DIR/index.html"
BOOTSTRAP="$WEB_DIR/flutter_bootstrap.js"
VERSION="$WEB_DIR/version.json"

for f in "$INDEX" "$BOOTSTRAP" "$WEB_DIR/main.dart.js" "$WEB_DIR/main.dart.wasm" "$WEB_DIR/main.dart.mjs"; do
  test -f "$f"
done

TAG="$(
  shasum -a 256 "$WEB_DIR/main.dart.js" "$BOOTSTRAP" \
    | shasum -a 256 \
    | cut -c1-12
)"

echo "==> Cache-bust entrypoints (tag=${TAG})..."

python3 - "$INDEX" "$BOOTSTRAP" "$VERSION" "$TAG" <<'PY'
import json
import re
import sys
from pathlib import Path

index_path, bootstrap_path, version_path, tag = sys.argv[1:5]
query = f"?v={tag}"

index = Path(index_path)
content = index.read_text()
content = content.replace(
    'href="main.dart.wasm"',
    f'href="main.dart.wasm{query}"',
)
content = content.replace(
    'src="flutter_bootstrap.js"',
    f'src="flutter_bootstrap.js{query}"',
)
index.write_text(content)

bootstrap = Path(bootstrap_path)
b = bootstrap.read_text()
b = b.replace('"mainWasmPath":"main.dart.wasm"', f'"mainWasmPath":"main.dart.wasm{query}"')
b = b.replace('"jsSupportRuntimePath":"main.dart.mjs"', f'"jsSupportRuntimePath":"main.dart.mjs{query}"')
b = b.replace('"mainJsPath":"main.dart.js"', f'"mainJsPath":"main.dart.js{query}"')
bootstrap.write_text(b)

version = Path(version_path)
data = json.loads(version.read_text())
data["web_cache_tag"] = tag
version.write_text(json.dumps(data, separators=(",", ":")) + "\n")

print(f"OK: tag={tag}")
PY

echo "OK: cache-bust aplicado em ${INDEX} e ${BOOTSTRAP}"
