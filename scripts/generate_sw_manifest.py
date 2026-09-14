#!/usr/bin/env python3
"""Gera as listas CRITICAL/WARM do service worker e preenche build/web/sw.js.

Spec: docs/superpowers/specs/2026-09-14-pwa-shell-offline-design.md (§3.1, §3.2);
plano 2026-09-14-pwa-shell-offline.md, precisão P1 (classe ENGINE).

Corre depois de cache_bust_web_entrypoints.sh ter reescrito os ?v=<tag>,
renomeado MaterialIcons-Regular.<hash>.otf e movido canvaskit/ → canvaskit/<hash>/:
lê as tags de version.json e classifica todos os ficheiros de build/web em
CRITICAL (install), ENGINE (fora do sw.js) e WARM (background).

Uso: python3 scripts/generate_sw_manifest.py [build/web]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from urllib.parse import quote, unquote

# Nunca entram em nenhuma lista: o próprio SW (cachear-se a si mesmo congelaria
# a versão), o stub do Flutter, e metadados que o browser nunca pede.
EXCLUDED_NAMES = frozenset(
    {"sw.js", "flutter_service_worker.js", ".last_build_id", "_headers", "_redirects"}
)
# Mapas de símbolos do engine (~10 MB): só para depuração; nada os carrega.
EXCLUDED_SUFFIXES = (".symbols",)
FONT_SUFFIXES = (".otf", ".ttf", ".woff", ".woff2")
# ENGINE: o flutter_bootstrap.js 3.47 escolhe a variante por browser (skwasm no
# Chrome/Edge/Android; skwasm_heavy no Safari/Firefox, sem ImageDecoder nem
# v8BreakIterator; canvaskit ou chromium/canvaskit + main.dart.js sem WasmGC,
# iOS ≤ 17). Listar um par fixo deixava o iPhone sem engine offline; listar
# todos eram ~33 MB por deploy. Por isso main.dart.* e canvaskit/<hash>/**
# ficam FORA das duas listas: a página manda ao SW a lista `used` do que
# carregou (resource timing) e só essa variante entra no cache.
ENGINE_NAMES = frozenset({"main.dart.wasm", "main.dart.mjs", "main.dart.js"})
ENGINE_PREFIX = "canvaskit/"
PLACEHOLDERS = ("__PLPCG_TAG__", "__PLPCG_CRITICAL__", "__PLPCG_WARM__")


def is_engine(posix: str) -> bool:
    return posix in ENGINE_NAMES or posix.startswith(ENGINE_PREFIX)


def url_for(relative: Path) -> str:
    # Os nomes em build/web já são URL-safe (o Flutter grava
    # `EBGaramond%5Bwght%5D.ttf` literalmente); quote() codifica o `%` → `%25`,
    # que é exatamente o URL que o engine pede (FontManifest.json + encode) e
    # que a produção serve.
    return quote(relative.as_posix(), safe="/")


def disk_path(url: str) -> str:
    """URL relativa (com ou sem ?v=) → caminho relativo no disco."""
    path = url.split("?", 1)[0]
    if path == "./":
        return "index.html"
    return unquote(path)


def classify(web_dir: Path, tag: str, icons_tag: str) -> tuple[list[str], list[str]]:
    """Devolve (critical, warm). CRITICAL por ordem de importância; WARM = o
    resto carregável; ENGINE (main.dart.*, canvaskit/**) fica fora de ambas."""
    query = f"?v={tag}"
    critical = [
        "./",
        f"flutter_bootstrap.js{query}",
        "flutter.js",
        "isar_plus.js",
        "isar_plus.wasm",
        "manifest.json",
        "version.json",
        "assets/FontManifest.json",
        f"assets/fonts/MaterialIcons-Regular.{icons_tag}.otf{query}",
    ]
    # AssetManifest: o nome varia entre versões do Flutter (.bin.json, .bin,
    # .json); entra o que existir.
    for manifest in ("assets/AssetManifest.bin.json", "assets/AssetManifest.bin", "assets/AssetManifest.json"):
        if (web_dir / manifest).is_file():
            critical.append(manifest)
    listed = {disk_path(u) for u in critical}

    fonts: list[str] = []
    icons: list[str] = []
    warm: list[str] = []
    for path in sorted(p for p in web_dir.rglob("*") if p.is_file()):
        rel = path.relative_to(web_dir)
        posix = rel.as_posix()
        if posix in listed or rel.name in EXCLUDED_NAMES or rel.name.endswith(EXCLUDED_SUFFIXES):
            continue
        if is_engine(posix):
            continue
        url = url_for(rel)
        if posix.startswith("assets/") and rel.suffix in FONT_SUFFIXES:
            fonts.append(url)
        elif (posix.startswith("icons/") and rel.suffix == ".png") or posix == "favicon.png":
            icons.append(url)
        else:
            warm.append(url)
    return critical + fonts + icons, warm


def count_engine(web_dir: Path) -> int:
    return sum(
        1
        for p in web_dir.rglob("*")
        if p.is_file() and is_engine(p.relative_to(web_dir).as_posix())
    )


def render(template: str, tag: str, critical: list[str], warm: list[str]) -> str:
    for placeholder in PLACEHOLDERS:
        if placeholder not in template:
            raise SystemExit(f"sw.js sem placeholder {placeholder} (já processado? template alterado?)")
    out = (
        template.replace("__PLPCG_TAG__", tag)
        .replace("__PLPCG_CRITICAL__", json.dumps(critical))
        .replace("__PLPCG_WARM__", json.dumps(warm))
    )
    if "__PLPCG_" in out:
        raise SystemExit("sw.js ainda com placeholder __PLPCG_ depois da substituição")
    return out


def size_mb(web_dir: Path, urls: list[str]) -> float:
    return sum((web_dir / disk_path(u)).stat().st_size for u in urls) / 1_000_000


def main(argv: list[str]) -> int:
    web_dir = Path(argv[1] if len(argv) > 1 else "build/web")
    sw = web_dir / "sw.js"
    if not sw.is_file():
        raise SystemExit(f"{sw} ausente — web/sw.js não foi copiado pelo flutter build?")
    version = json.loads((web_dir / "version.json").read_text())
    try:
        tag = version["web_cache_tag"]
        icons_tag = version["material_icons_tag"]
    except KeyError as err:
        raise SystemExit(f"version.json sem {err}: corra cache_bust_web_entrypoints.sh antes")
    # O engine não entra nas listas, mas o build tem de o ter movido para
    # canvaskit/<hash>/ (senão o cache-bust não correu e o ?v= está errado).
    if "canvaskit_tag" not in version or not (web_dir / "canvaskit" / version["canvaskit_tag"]).is_dir():
        raise SystemExit("canvaskit/<hash>/ ausente: corra cache_bust_web_entrypoints.sh antes")

    critical, warm = classify(web_dir, tag, icons_tag)
    missing = [u for u in critical if not (web_dir / disk_path(u)).is_file()]
    if missing:
        raise SystemExit("CRITICAL referencia ficheiros inexistentes:\n  " + "\n  ".join(missing))

    sw.write_text(render(sw.read_text(), tag, critical, warm))
    print(
        f"OK: sw.js tag={tag} "
        f"CRITICAL={len(critical)} ({size_mb(web_dir, critical):.1f} MB) "
        f"WARM={len(warm)} ({size_mb(web_dir, warm):.1f} MB) "
        f"ENGINE fora das listas={count_engine(web_dir)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
