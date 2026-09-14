#!/usr/bin/env python3
"""Prova que o shell abre sem rede (spec 2026-09-14-pwa-shell-offline, §5).

Sobe build/web no servidor local (mesmos headers do _headers), deixa o
index.html registar o sw.js, o install precachear CRITICAL e a mensagem
`used` aquecer o engine realmente carregado (main.dart.* + canvaskit/<hash>/),
derruba o servidor e navega outra vez: o flutter-first-frame tem de chegar só
com o cache do service worker — e com COOP/COEP preservados
(crossOriginIsolated).

Uso:
  python3 scripts/verify_web_sw.py [--web-dir build/web]

Requer build/web pós-processado (scripts/web_build.sh, ou
flutter build web --wasm + scripts/cache_bust_web_entrypoints.sh).
"""
from __future__ import annotations

import sys
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

import argparse
import json
import os
import shutil
import subprocess
import time
from typing import Any

from measure_web_boot import (
    BOOT_TIMEOUT_S,
    POLL_INTERVAL_S,
    CdpError,
    SimpleWebSocket,
    find_chrome,
    http_json,
    wait_for_cdp,
)
from web_frontend_server import DEFAULT_WEB_DIR, serve_frontend

# O install baixa CRITICAL (~3 MB) e a mensagem `used` copia o engine (~10 MB)
# do servidor local; o runner do CI é lento e --disable-cache obriga tudo a
# vir pela rede (sem cache HTTP, o `used` também custa rede aqui).
SW_TIMEOUT_S = 120


def evaluate(ws: SimpleWebSocket, expression: str, timeout: float = 10) -> Any:
    result = ws.call(
        "Runtime.evaluate",
        {"expression": expression, "returnByValue": True, "awaitPromise": True},
        timeout=timeout,
    )
    if "exceptionDetails" in result:
        text = result["exceptionDetails"].get("text", "exceção JS")
        raise CdpError(f"{text} em: {expression}")
    return result.get("result", {}).get("value")


def wait_first_frame(ws: SimpleWebSocket) -> dict[str, Any]:
    """Espera o flutter-first-frame do documento atual.

    `__plpcgSwProbe` marca o documento anterior antes de cada navegação:
    Page.navigate volta antes do commit e o poll podia ler o __plpcgPerf velho.
    """
    expression = (
        "(window.__plpcgSwProbe === undefined && window.__plpcgPerf"
        " && window.__plpcgPerf.firstFrameMs != null) ? window.__plpcgPerf : null"
    )
    deadline = time.monotonic() + BOOT_TIMEOUT_S
    while time.monotonic() < deadline:
        try:
            perf = evaluate(ws, expression, timeout=5)
        except CdpError:
            perf = None  # contexto destruído a meio da navegação: tenta outra vez
        if isinstance(perf, dict):
            return perf
        time.sleep(POLL_INTERVAL_S)
    raise CdpError(f"timeout ({BOOT_TIMEOUT_S}s) à espera do flutter-first-frame")


def wait_service_worker(ws: SimpleWebSocket, cache_name: str) -> None:
    state_expr = (
        "navigator.serviceWorker.getRegistration().then(function (r) {"
        " if (!r) return 'sem registo';"
        " if (r.active) return r.active.state;"
        " return r.installing ? 'installing' : 'waiting'; })"
    )
    state: Any = None
    keys: Any = []
    deadline = time.monotonic() + SW_TIMEOUT_S
    while time.monotonic() < deadline:
        state = evaluate(ws, state_expr)
        keys = evaluate(ws, "caches.keys()") or []
        if state == "activated" and cache_name in keys:
            return
        time.sleep(POLL_INTERVAL_S)
    raise CdpError(
        f"timeout ({SW_TIMEOUT_S}s): service worker não ativou com o cache "
        f"{cache_name} (estado={state}, caches={keys})"
    )


def cached_urls(ws: SimpleWebSocket, cache_name: str) -> list[str]:
    return evaluate(
        ws,
        f"caches.open('{cache_name}').then(function (c) {{ return c.keys(); }})"
        ".then(function (ks) { return ks.map(function (r) { return r.url; }); })",
    ) or []


def wait_engine_warm(ws: SimpleWebSocket, cache_name: str) -> list[str]:
    """Espera a lista `used` da página entrar no cache.

    O engine (main.dart.* e canvaskit/<hash>/) não está em CRITICAL: chega
    pela mensagem {type:'warm', used} depois do primeiro frame. Sem ele o
    boot offline não tem como arrancar, por isso é condição para desligar o
    servidor. Risco aceite em produção: fechar a aba < ~2 s após o primeiro
    frame deixa o engine fora do cache; a próxima abertura online corrige.
    """
    urls: list[str] = []
    deadline = time.monotonic() + SW_TIMEOUT_S
    while time.monotonic() < deadline:
        urls = cached_urls(ws, cache_name)
        has_main = any("/main.dart.wasm?v=" in u or "/main.dart.js?v=" in u for u in urls)
        has_engine = any("/canvaskit/" in u and u.endswith(".wasm") for u in urls)
        if has_main and has_engine:
            return urls
        time.sleep(POLL_INTERVAL_S)
    engine = [u for u in urls if "/main.dart." in u or "/canvaskit/" in u]
    raise CdpError(
        f"timeout ({SW_TIMEOUT_S}s): a lista `used` não pôs o engine no cache "
        f"{cache_name} (entradas de engine: {engine})"
    )


def launch_chrome(chrome: str, cdp_port: int, user_data: Path) -> subprocess.Popen[bytes]:
    return subprocess.Popen(
        [
            chrome,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--disable-dev-shm-usage",
            "--remote-allow-origins=*",
            "--no-first-run",
            "--no-default-browser-check",
            # Sem cache HTTP: offline, cada byte tem de vir do Cache API do SW.
            "--disable-cache",
            "--disable-application-cache",
            f"--remote-debugging-port={cdp_port}",
            f"--user-data-dir={user_data}",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def verify(web_dir: Path, chrome: str) -> None:
    sw = web_dir / "sw.js"
    if not sw.is_file() or "__PLPCG_" in sw.read_text():
        raise CdpError(f"{sw} ausente ou com placeholders — corra scripts/cache_bust_web_entrypoints.sh")
    tag = json.loads((web_dir / "version.json").read_text())["web_cache_tag"]
    cache_name = f"plpcg-shell-{tag}"

    cdp_port = 9800 + (os.getpid() % 500)
    user_data = Path("/tmp") / f"plpcg-sw-{os.getpid()}-{time.time_ns()}"
    user_data.mkdir(parents=True, exist_ok=True)
    proc = launch_chrome(chrome, cdp_port, user_data)
    ws: SimpleWebSocket | None = None
    try:
        wait_for_cdp(cdp_port)
        target = http_json(f"http://127.0.0.1:{cdp_port}/json/new", method="PUT")
        ws = SimpleWebSocket.connect(target["webSocketDebuggerUrl"])
        ws.call("Page.enable")
        ws.call("Runtime.enable")

        with serve_frontend(web_dir=web_dir) as (_httpd, port):
            app_url = f"http://127.0.0.1:{port}/"
            ws.call("Page.navigate", {"url": app_url})
            online = wait_first_frame(ws)
            print(
                f"online: first frame {online['firstFrameMs']} ms, "
                f"crossOriginIsolated={online.get('crossOriginIsolated')}"
            )
            wait_service_worker(ws, cache_name)
            cached = cached_urls(ws, cache_name)
            if app_url not in cached:
                raise CdpError(f"index.html ('./') não está no cache {cache_name}: {cached[:5]}…")
            print(f"service worker ativo; {cache_name} com {len(cached)} entradas")
            warmed = wait_engine_warm(ws, cache_name)
            engine = sorted(u.split("/", 3)[-1] for u in warmed if "/main.dart." in u or "/canvaskit/" in u)
            print(f"engine aquecido pela lista used: {engine}")
            evaluate(ws, "window.__plpcgSwProbe = 'stale'; true")

        # Servidor em baixo: a navegação só pode ser servida pelo SW.
        ws.call("Page.navigate", {"url": app_url})
        offline = wait_first_frame(ws)
        if offline.get("crossOriginIsolated") is not True:
            raise CdpError(
                "sem rede o documento perdeu COOP/COEP (crossOriginIsolated != true): "
                "o cache não preservou os headers do index.html"
            )
        print(f"offline: first frame {offline['firstFrameMs']} ms a partir do cache — OK")
    finally:
        if ws is not None:
            ws.close()
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        shutil.rmtree(user_data, ignore_errors=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prova o boot offline do shell PLPCG")
    parser.add_argument("--web-dir", type=Path, default=DEFAULT_WEB_DIR, help="Diretório build/web")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    web_dir = args.web_dir.resolve()
    if not web_dir.is_dir():
        print(f"Erro: {web_dir} não existe. Rode scripts/web_build.sh primeiro.", file=sys.stderr)
        return 1
    try:
        verify(web_dir, find_chrome())
    except CdpError as err:
        print(f"Erro: {err}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
