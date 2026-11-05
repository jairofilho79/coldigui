#!/usr/bin/env python3
"""Real SF2/MIDI/WASM test: python3 scripts/test_score_audio_web.py [test paths].

Uses the existing Flutter Chrome runner and stdlib CDP client. Exposes the
runner's generated assets only for this run and supplies trusted WebAudio
activation automatically. Uncaught browser exceptions fail the command.
"""
from __future__ import annotations

import re
import select
import subprocess
import sys
import threading
import time
from pathlib import Path

from measure_web_boot import CdpError, SimpleWebSocket, http_json

ROOT = Path(__file__).resolve().parent.parent
TEST = "test/web/score_audio_engine_web_test.dart"


def monitor_chrome(process: subprocess.Popen, errors: list[str]) -> None:
    client = None
    try:
        deadline = time.monotonic() + 180
        port = None
        while process.poll() is None and time.monotonic() < deadline:
            for line in subprocess.check_output(
                ["ps", "-Ao", "pid,ppid,args"], text=True
            ).splitlines():
                fields = line.strip().split(None, 2)
                if len(fields) == 3 and fields[1] == str(process.pid):
                    match = re.search(r"--remote-debugging-port=(\d+)", fields[2])
                    if match:
                        port = int(match.group(1))
                        break
            if port is not None:
                break
            time.sleep(0.05)
        if port is None:
            raise RuntimeError("Isolated Flutter Chrome CDP endpoint not found")
        while process.poll() is None and time.monotonic() < deadline:
            try:
                pages = http_json(f"http://127.0.0.1:{port}/json")
                target = next(page for page in pages if page["type"] == "page")
                client = SimpleWebSocket.connect(target["webSocketDebuggerUrl"])
                break
            except (OSError, StopIteration):
                time.sleep(0.05)
        if client is None:
            raise RuntimeError("Could not attach to isolated test Chrome")
        client.send_json({"method": "Runtime.enable"})
        contexts: set[int] = set()
        pending: set[int] = set()
        last_poll = 0.0
        while process.poll() is None:
            if time.monotonic() - last_poll >= 0.1:
                last_poll = time.monotonic()
                for context in contexts:
                    pending.add(client.send_json({
                        "method": "Runtime.evaluate",
                        "params": {
                            "contextId": context,
                            "expression": (
                                "typeof miniaudio !== 'undefined' && "
                                "miniaudio.devices.some(d => d && "
                                "d.state === miniaudio.device_state.started && "
                                "d.webaudio?.state === 'suspended')"
                            ),
                            "returnByValue": True,
                        },
                    }))
            if not select.select([client.sock], [], [], 0.05)[0]:
                continue
            message = client.recv_json(timeout=3)
            method = message.get("method")
            params = message.get("params", {})
            if method == "Runtime.executionContextCreated":
                contexts.add(params["context"]["id"])
            elif method == "Runtime.executionContextDestroyed":
                contexts.discard(params["executionContextId"])
            elif method == "Runtime.exceptionThrown":
                details = params["exceptionDetails"]
                description = details.get("exception", {}).get(
                    "description", details["text"]
                )
                errors.append(description)
                print(f"BROWSER EXCEPTION:\n{description}", flush=True)
                for frame in details.get("stackTrace", {}).get("callFrames", []):
                    print(
                        f"  {frame['functionName']} "
                        f"({frame['url']}:{frame['lineNumber'] + 1}:"
                        f"{frame['columnNumber'] + 1})",
                        flush=True,
                    )
            elif method == "Runtime.consoleAPICalled":
                if params["type"] in ("error", "warning"):
                    text = " ".join(
                        str(arg.get("value", arg.get("description", "")))
                        for arg in params["args"]
                    )
                    print(f"BROWSER {params['type']}: {text}", flush=True)
            elif message.get("id") in pending:
                pending.discard(message["id"])
                if message.get("result", {}).get("result", {}).get("value") is True:
                    # The target context is the test iframe, not the host page.
                    for context in contexts:
                        client.send_json({
                            "method": "Runtime.evaluate",
                            "params": {
                                "contextId": context,
                                "expression": (
                                    "if (typeof miniaudio !== 'undefined') "
                                    "miniaudio.unlock()"
                                ),
                                "userGesture": True,
                            },
                        })
    except (OSError, CdpError) as error:
        if client is None:
            errors.append(str(error))
        else:
            print(f"CDP transport closed: {error}", flush=True)
    except Exception as error:
        errors.append(str(error))
        print(f"CDP monitor error: {error}", flush=True)
    finally:
        if client is not None:
            client.close()


def main() -> int:
    assets = ROOT / "test/web/assets"
    if assets.exists() or assets.is_symlink():
        raise SystemExit("Refusing to replace existing test/web/assets")
    command = [
        "flutter", "test", "--no-pub", "--platform", "chrome",
        "--dart-define-from-file=dart_defines/plpcjf.json",
        *(sys.argv[1:] or [TEST]),
        "--reporter", "expanded",
    ]
    errors: list[str] = []
    process = None
    monitor = None
    assets.symlink_to("../../build/unit_test_assets", target_is_directory=True)
    try:
        print("COMMAND:", " ".join(command), flush=True)
        process = subprocess.Popen(command, cwd=ROOT)
        monitor = threading.Thread(target=monitor_chrome, args=(process, errors))
        monitor.start()
        result = process.wait(timeout=300)
        monitor.join(timeout=5)
        if monitor.is_alive():
            errors.append("CDP monitor did not stop")
        if errors:
            print(f"FAILED: {len(errors)} browser/monitor error(s)", flush=True)
        return result or bool(errors)
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        if monitor is not None:
            monitor.join(timeout=5)
        assets.unlink()
        print("CLEANUP: generated asset link removed; no helper server", flush=True)


if __name__ == "__main__":
    sys.exit(main())
