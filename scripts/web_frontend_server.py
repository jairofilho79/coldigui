"""Servidor estático build/web com COOP/COEP e cache immutable (Fase C/D)."""
from __future__ import annotations

import http.server
import socketserver
import threading
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_WEB_DIR = ROOT / "build" / "web"


class ReusableTCPServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True


def make_frontend_handler(web_dir: Path) -> type[http.server.SimpleHTTPRequestHandler]:
    directory = str(web_dir)

    class FrontendHandler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=directory, **kwargs)

        def end_headers(self) -> None:
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
            path = self.path.split("?", 1)[0]
            if path.endswith("flutter_service_worker.js"):
                self.send_header("Cache-Control", "no-cache")
            elif path.endswith((".wasm", ".js")):
                self.send_header(
                    "Cache-Control", "public, max-age=31536000, immutable"
                )
            super().end_headers()

        def log_message(self, fmt: str, *args: object) -> None:
            pass

    return FrontendHandler


@contextmanager
def serve_frontend(
    web_dir: Path = DEFAULT_WEB_DIR,
    host: str = "127.0.0.1",
    port: int = 0,
) -> Iterator[tuple[ReusableTCPServer, int]]:
    """Sobe servidor em thread daemon; porta 0 = efêmera."""
    handler = make_frontend_handler(web_dir)
    httpd = ReusableTCPServer((host, port), handler)
    actual_port = httpd.server_address[1]
    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    try:
        yield httpd, actual_port
    finally:
        httpd.shutdown()
        httpd.server_close()
        thread.join(timeout=5)
