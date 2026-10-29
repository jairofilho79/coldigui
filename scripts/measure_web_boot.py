#!/usr/bin/env python3
"""Mede cold start web via Chrome CDP + window.__plpcgPerf (Fase H).

Uso:
  python3 scripts/measure_web_boot.py
  python3 scripts/measure_web_boot.py --check
  python3 scripts/measure_web_boot.py --output /tmp/metrics.json
"""
from __future__ import annotations

import sys
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

import argparse
import base64
import hashlib
import json
import os
import shutil
import socket
import statistics
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from web_frontend_server import DEFAULT_WEB_DIR, serve_frontend

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BASELINE = ROOT / "docs" / "web_perf_baseline.json"
POLL_INTERVAL_S = 0.25
BOOT_TIMEOUT_S = 60


class CdpError(RuntimeError):
    pass


class SimpleWebSocket:
    """Cliente WebSocket mínimo (stdlib) para Chrome DevTools Protocol."""

    def __init__(self, sock: socket.socket) -> None:
        self.sock = sock
        self._msg_id = 0

    @classmethod
    def connect(cls, url: str) -> SimpleWebSocket:
        # webSocketDebuggerUrl: ws://host:port/devtools/browser/...
        without_scheme = url.split("://", 1)[1]
        host_port, _, path = without_scheme.partition("/")
        if ":" in host_port:
            host, port_s = host_port.rsplit(":", 1)
            port = int(port_s)
        else:
            host, port = host_port, 80
        path = "/" + path

        sock = socket.create_connection((host, port), timeout=30)
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        request = (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: {host}:{port}\r\n"
            f"Upgrade: websocket\r\n"
            f"Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n"
            f"\r\n"
        ).encode()
        sock.sendall(request)

        response = b""
        while b"\r\n\r\n" not in response:
            chunk = sock.recv(4096)
            if not chunk:
                raise CdpError("handshake WebSocket falhou")
            response += chunk

        accept = base64.b64encode(
            hashlib.sha1(
                (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()
            ).digest()
        ).decode("ascii")
        if f"Sec-WebSocket-Accept: {accept}" not in response.decode(
            "latin-1", errors="replace"
        ):
            raise CdpError("Sec-WebSocket-Accept inválido")

        return cls(sock)

    def _read_exact(self, nbytes: int) -> bytes:
        data = b""
        while len(data) < nbytes:
            chunk = self.sock.recv(nbytes - len(data))
            if not chunk:
                raise CdpError("WebSocket fechado")
            data += chunk
        return data

    def _recv_frame(self) -> tuple[int, bytes]:
        b1, b2 = self._read_exact(2)
        opcode = b1 & 0x0F
        masked = bool(b2 & 0x80)
        length = b2 & 0x7F
        if length == 126:
            length = struct.unpack("!H", self._read_exact(2))[0]
        elif length == 127:
            length = struct.unpack("!Q", self._read_exact(8))[0]
        if masked:
            mask_key = self._read_exact(4)
            payload = self._read_exact(length)
            payload = bytes(b ^ mask_key[i % 4] for i, b in enumerate(payload))
        else:
            payload = self._read_exact(length)
        return opcode, payload

    def _send_frame(self, opcode: int, payload: bytes) -> None:
        length = len(payload)
        frame = bytearray([0x80 | opcode])
        mask_key = os.urandom(4)
        if length < 126:
            frame.append(0x80 | length)
        elif length < 65536:
            frame.extend([0x80 | 126, *struct.pack("!H", length)])
        else:
            frame.extend([0x80 | 127, *struct.pack("!Q", length)])
        frame.extend(mask_key)
        frame.extend(bytes(b ^ mask_key[i % 4] for i, b in enumerate(payload)))
        self.sock.sendall(frame)

    def send_json(self, obj: dict[str, Any]) -> int:
        self._msg_id += 1
        payload = dict(obj)
        payload["id"] = self._msg_id
        self._send_frame(0x1, json.dumps(payload).encode())
        return self._msg_id

    def recv_json(self, timeout: float = BOOT_TIMEOUT_S) -> dict[str, Any]:
        self.sock.settimeout(timeout)
        while True:
            opcode, payload = self._recv_frame()
            if opcode == 0x1:
                return json.loads(payload.decode())
            if opcode == 0x8:
                raise CdpError("WebSocket fechado pelo peer")

    def call(
        self,
        method: str,
        params: dict[str, Any] | None = None,
        timeout: float = BOOT_TIMEOUT_S,
    ) -> dict[str, Any]:
        msg_id = self.send_json({"method": method, "params": params or {}})
        while True:
            msg = self.recv_json(timeout)
            if msg.get("id") != msg_id:
                continue
            if "error" in msg:
                raise CdpError(str(msg["error"]))
            result = msg.get("result")
            return result if isinstance(result, dict) else {}

    def close(self) -> None:
        try:
            self._send_frame(0x8, b"")
        except OSError:
            pass
        try:
            self.sock.close()
        except OSError:
            pass


def find_chrome() -> str:
    env = os.environ.get("CHROME_EXECUTABLE")
    if env and Path(env).is_file():
        return env
    for name in (
        "google-chrome",
        "google-chrome-stable",
        "chromium",
        "chromium-browser",
        "chrome",
    ):
        path = shutil.which(name)
        if path:
            return path
    mac_paths = (
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
    )
    for path in mac_paths:
        if Path(path).is_file():
            return path
    raise CdpError(
        "Chrome não encontrado. Defina CHROME_EXECUTABLE ou instale Chrome/Chromium."
    )


def http_json(url: str, method: str = "GET") -> Any:
    req = urllib.request.Request(url, method=method)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode())


def wait_for_cdp(port: int, timeout_s: float = 15) -> None:
    deadline = time.monotonic() + timeout_s
    url = f"http://127.0.0.1:{port}/json/version"
    while time.monotonic() < deadline:
        try:
            http_json(url)
            return
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
            time.sleep(0.1)
    raise CdpError(f"CDP não respondeu na porta {port}")


def measure_once(
    chrome: str,
    app_url: str,
    cdp_port: int,
) -> dict[str, Any]:
    user_data = Path("/tmp") / f"plpcg-measure-{os.getpid()}-{time.time_ns()}"
    user_data.mkdir(parents=True, exist_ok=True)

    proc = subprocess.Popen(
        [
            chrome,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--disable-dev-shm-usage",
            "--remote-allow-origins=*",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-cache",
            "--disable-application-cache",
            f"--remote-debugging-port={cdp_port}",
            f"--user-data-dir={user_data}",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    ws: SimpleWebSocket | None = None
    try:
        wait_for_cdp(cdp_port)
        target = http_json(f"http://127.0.0.1:{cdp_port}/json/new", method="PUT")
        ws = SimpleWebSocket.connect(target["webSocketDebuggerUrl"])
        ws.call("Page.enable")
        ws.call("Runtime.enable")
        ws.call("Page.navigate", {"url": app_url})

        deadline = time.monotonic() + BOOT_TIMEOUT_S
        perf: dict[str, Any] | None = None
        while time.monotonic() < deadline:
            result = ws.call(
                "Runtime.evaluate",
                {
                    "expression": "window.__plpcgPerf",
                    "returnByValue": True,
                },
                timeout=5,
            )
            value = result.get("result", {}).get("value")
            if isinstance(value, dict) and value.get("firstFrameMs") is not None:
                perf = value
                break
            time.sleep(POLL_INTERVAL_S)

        if perf is None:
            raise CdpError(
                f"timeout ({BOOT_TIMEOUT_S}s): window.__plpcgPerf.firstFrameMs ausente"
            )
        return perf
    finally:
        if ws is not None:
            ws.close()
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        shutil.rmtree(user_data, ignore_errors=True)


def median_run(
    chrome: str,
    app_url: str,
    runs: int,
) -> dict[str, Any]:
    samples: list[dict[str, Any]] = []
    for i in range(runs):
        cdp_port = 9300 + (os.getpid() % 500) + i
        samples.append(measure_once(chrome, app_url, cdp_port))

    loader_vals = [
        s["loaderVisibleMs"]
        for s in samples
        if isinstance(s.get("loaderVisibleMs"), (int, float))
    ]
    frame_vals = [
        s["firstFrameMs"]
        for s in samples
        if isinstance(s.get("firstFrameMs"), (int, float))
    ]

    return {
        "runs": runs,
        "samples": samples,
        "loaderVisibleMs": int(statistics.median(loader_vals))
        if loader_vals
        else None,
        "firstFrameMs": int(statistics.median(frame_vals)) if frame_vals else None,
        "crossOriginIsolated": samples[-1].get("crossOriginIsolated"),
        "sab": samples[-1].get("sab"),
        "capturedAt": samples[-1].get("capturedAt"),
    }


def load_baseline(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def check_against_baseline(
    metrics: dict[str, Any],
    baseline: dict[str, Any],
) -> list[str]:
    failures: list[str] = []
    baseline_metrics = baseline.get("metrics", {})
    for key in ("loaderVisibleMs", "firstFrameMs"):
        spec = baseline_metrics.get(key)
        measured = metrics.get(key)
        if not spec or spec.get("value") is None:
            continue
        if measured is None:
            failures.append(f"{key}: métrica ausente na medição")
            continue
        limit = spec["value"] + spec.get("maxRegression", 0)
        if measured > limit:
            failures.append(
                f"{key}: {measured}ms > limite {limit}ms "
                f"(baseline {spec['value']} + {spec.get('maxRegression', 0)})"
            )
    return failures


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Mede cold start web PLPCG")
    parser.add_argument(
        "--web-dir",
        type=Path,
        default=DEFAULT_WEB_DIR,
        help="Diretório build/web",
    )
    parser.add_argument(
        "--baseline",
        type=Path,
        default=DEFAULT_BASELINE,
        help="Arquivo baseline JSON",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Grava métricas em JSON",
    )
    parser.add_argument(
        "--runs",
        type=int,
        default=2,
        help="Execuções para mediana (gate CI)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Falha se métricas excederem baseline + margem",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    web_dir = args.web_dir.resolve()

    if not web_dir.is_dir():
        print(f"Erro: {web_dir} não existe. Rode flutter build web primeiro.", file=sys.stderr)
        return 1

    try:
        chrome = find_chrome()
    except CdpError as err:
        print(f"Erro: {err}", file=sys.stderr)
        return 1

    with serve_frontend(web_dir=web_dir) as (_httpd, port):
        app_url = f"http://127.0.0.1:{port}/"
        metrics = median_run(chrome, app_url, max(1, args.runs))

    output = json.dumps(metrics, indent=2, ensure_ascii=False)
    print(output)

    if args.output:
        args.output.write_text(output + "\n", encoding="utf-8")

    if args.check:
        if not args.baseline.is_file():
            print(f"Erro: baseline não encontrado: {args.baseline}", file=sys.stderr)
            return 1
        failures = check_against_baseline(metrics, load_baseline(args.baseline))
        if failures:
            print("REGRESSÃO detectada:", file=sys.stderr)
            for line in failures:
                print(f"  - {line}", file=sys.stderr)
            return 1
        print("OK: métricas dentro do baseline.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
