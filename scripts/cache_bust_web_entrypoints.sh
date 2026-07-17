#!/usr/bin/env bash
# Anexa ?v=<tag> aos entrypoints do build web — contorna CDN com cache immutable
# em v2.plpcg.com quando purge manual não invalida objetos antigos.
#
# Também renomeia MaterialIcons-Regular.otf com hash do conteúdo: o custom domain
# da zone plpcg.com cacheia /assets/* por 1 ano (HIT stale = ícones em branco).
set -euo pipefail

WEB_DIR="${1:-build/web}"
INDEX="$WEB_DIR/index.html"
BOOTSTRAP="$WEB_DIR/flutter_bootstrap.js"
VERSION="$WEB_DIR/version.json"
FONT_MANIFEST="$WEB_DIR/assets/FontManifest.json"
ICONS_FONT="$WEB_DIR/assets/fonts/MaterialIcons-Regular.otf"

for f in "$INDEX" "$BOOTSTRAP" "$WEB_DIR/main.dart.js" "$WEB_DIR/main.dart.wasm" "$WEB_DIR/main.dart.mjs" "$FONT_MANIFEST" "$ICONS_FONT"; do
  test -f "$f"
done

TAG="$(
  shasum -a 256 "$WEB_DIR/main.dart.js" "$BOOTSTRAP" \
    | shasum -a 256 \
    | cut -c1-12
)"

ICONS_HASH="$(shasum -a 256 "$ICONS_FONT" | cut -c1-12)"
ICONS_HASHED="MaterialIcons-Regular.${ICONS_HASH}.otf"
ICONS_HASHED_PATH="$WEB_DIR/assets/fonts/$ICONS_HASHED"

echo "==> Cache-bust entrypoints (tag=${TAG}) + MaterialIcons (${ICONS_HASH})..."

mv "$ICONS_FONT" "$ICONS_HASHED_PATH"

python3 - "$INDEX" "$BOOTSTRAP" "$VERSION" "$TAG" "$FONT_MANIFEST" "$ICONS_HASHED" <<'PY'
import json
import sys
from pathlib import Path

index_path, bootstrap_path, version_path, tag, font_manifest_path, icons_hashed = sys.argv[1:7]
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

# Query string obrigatória: a zone plpcg.com já envenenou URLs sem ?v=
# (HIT immutable com index.html SPA no lugar do .otf).
font_manifest = Path(font_manifest_path)
fonts = json.loads(font_manifest.read_text())
old_asset = "fonts/MaterialIcons-Regular.otf"
new_asset = f"fonts/{icons_hashed}{query}"
replaced = False
for family in fonts:
    for entry in family.get("fonts", []):
        asset = entry.get("asset", "")
        if asset == old_asset or asset.startswith("fonts/MaterialIcons-Regular."):
            entry["asset"] = new_asset
            replaced = True
if not replaced:
    raise SystemExit(f"FontManifest sem {old_asset}")
font_manifest.write_text(json.dumps(fonts, separators=(",", ":")) + "\n")

version = Path(version_path)
data = json.loads(version.read_text())
data["web_cache_tag"] = tag
data["material_icons_tag"] = icons_hashed.removeprefix("MaterialIcons-Regular.").removesuffix(".otf")
version.write_text(json.dumps(data, separators=(",", ":")) + "\n")

print(f"OK: tag={tag} icons={icons_hashed}")
PY

echo "OK: cache-bust aplicado em ${INDEX}, ${BOOTSTRAP} e ${ICONS_HASHED}"
