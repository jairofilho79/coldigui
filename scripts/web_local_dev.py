#!/usr/bin/env python3
"""Servidor local: frontend (8080) + proxy CORS → plpcg.com (8081).

Uso (após `flutter build web --wasm --dart-define-from-file=dart_defines/plpcjf.local-dev.json`):
  python3 scripts/web_local_dev.py

Frontend: http://127.0.0.1:8080
API proxy: http://127.0.0.1:8081 → https://plpcg.com
"""
from __future__ import annotations

import http.server
import os
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from web_frontend_server import DEFAULT_WEB_DIR, ReusableTCPServer, make_frontend_handler

ROOT = Path(__file__).resolve().parent.parent
WEB_DIR = DEFAULT_WEB_DIR
UPSTREAM = "https://plpcg.com"
FRONTEND_PORT = 8080
PROXY_PORT = 8081

FORWARD_REQUEST_HEADERS = frozenset(
    {"if-none-match", "accept", "accept-encoding", "user-agent", "range"}
)
SKIP_RESPONSE_HEADERS = frozenset(
    {"transfer-encoding", "connection", "access-control-allow-origin"}
)


class ApiProxyHandler(http.server.BaseHTTPRequestHandler):
    def _cors(self) -> None:
        origin = self.headers.get("Origin", "*")
        self.send_header("Access-Control-Allow-Origin", origin)
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers", "Content-Type, If-None-Match, Range"
        )
        self.send_header("Access-Control-Expose-Headers", "ETag, Content-Length")

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self) -> None:
        url = UPSTREAM + self.path
        headers = {
            k: v
            for k, v in self.headers.items()
            if k.lower() in FORWARD_REQUEST_HEADERS
        }
        req = urllib.request.Request(url, method="GET", headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                body = resp.read()
                self.send_response(resp.status)
                for key, value in resp.headers.items():
                    if key.lower() not in SKIP_RESPONSE_HEADERS:
                        self.send_header(key, value)
                self._cors()
                self.end_headers()
                self.wfile.write(body)
        except urllib.error.HTTPError as err:
            self.send_response(err.code)
            self._cors()
            self.end_headers()
            self.wfile.write(err.read())

    def log_message(self, fmt: str, *args: object) -> None:
        print(f"[api-proxy] {args[0]}")


class FrontendHandler(make_frontend_handler(WEB_DIR)):
    def log_message(self, fmt: str, *args: object) -> None:
        print(f"[frontend] {args[0]}")


def run_proxy() -> None:
    with ReusableTCPServer(("127.0.0.1", PROXY_PORT), ApiProxyHandler) as httpd:
        print(f"API proxy http://127.0.0.1:{PROXY_PORT} → {UPSTREAM}")
        httpd.serve_forever()


def main() -> int:
    if not WEB_DIR.is_dir():
        print(
            f"Erro: {WEB_DIR} não existe. Rode scripts/web_build.sh com plpcjf.local-dev.json",
            file=sys.stderr,
        )
        return 1

    threading.Thread(target=run_proxy, daemon=True).start()
    time.sleep(0.3)

    with ReusableTCPServer(("127.0.0.1", FRONTEND_PORT), FrontendHandler) as httpd:
        print(f"Frontend http://127.0.0.1:{FRONTEND_PORT} (build/web + COOP/COEP)")
        print("Ctrl+C para parar.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nEncerrado.")
    return 0


if __name__ == "__main__":
    os.chdir(ROOT)
    raise SystemExit(main())
