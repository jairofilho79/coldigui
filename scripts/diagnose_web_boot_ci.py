#!/usr/bin/env python3
"""Temporary paired cold-page experiments; does not change build/web or gates."""
import json
from pathlib import Path
import tempfile
import time
from unittest.mock import patch

import measure_web_boot as boot
from web_frontend_server import serve_frontend


def measure_case(case, html, source):
    with tempfile.TemporaryDirectory(prefix="boot-compare-", dir=source.parent) as name:
        directory = Path(name)
        for item in source.iterdir():
            if item.name != "index.html":
                (directory / item.name).symlink_to(item.resolve(), target_is_directory=item.is_dir())
        (directory / "index.html").write_text(html, encoding="utf-8")
        original_call = boot.SimpleWebSocket.call

        def call(ws, method, params=None, timeout=boot.BOOT_TIMEOUT_S):
            if method == "Page.navigate":
                if case == "foreground":
                    original_call(ws, "Page.bringToFront")
                elif case == "ready-blank":
                    deadline = time.monotonic() + 5
                    while time.monotonic() < deadline:
                        result = original_call(ws, "Runtime.evaluate", {
                            "expression": "document.readyState",
                            "returnByValue": True,
                        })
                        if result.get("result", {}).get("value") == "complete":
                            break
                        time.sleep(0.01)
                    else:
                        raise boot.CdpError("blank document did not become ready")
            return original_call(ws, method, params, timeout)

        with patch.object(boot.SimpleWebSocket, "call", call):
            with serve_frontend(web_dir=directory) as (_, port):
                metrics = boot.median_run(boot.find_chrome(), f"http://127.0.0.1:{port}/", 2)
        return {
            "case": case,
            "loaderVisibleMs": metrics["loaderVisibleMs"],
            "firstFrameMs": metrics["firstFrameMs"],
            "samples": [{
                "loaderVisibleMs": s["loaderVisibleMs"],
                "firstFrameMs": s["firstFrameMs"],
                "diagnostics": s["diagnostics"],
            } for s in metrics["samples"]],
        }


def main():
    source = boot.DEFAULT_WEB_DIR.resolve()
    original = (source / "index.html").read_text(encoding="utf-8")
    variants = {
        "control-before": original,
        "without-preloads": original.replace('rel="preload"', 'rel="prefetch"')
            .replace("link.rel = 'preload'", "link.rel = 'prefetch'"),
        "without-glow": original.replace("filter: blur(18px);", "filter: none;"),
        "foreground": original,
        "ready-blank": original,
        "control-after": original,
    }
    for case, html in variants.items():
        print(json.dumps(measure_case(case, html, source), ensure_ascii=False), flush=True)
    if (source / "index.html").read_text(encoding="utf-8") != original:
        raise boot.CdpError("experiment unexpectedly changed build/web/index.html")


if __name__ == "__main__":
    main()
