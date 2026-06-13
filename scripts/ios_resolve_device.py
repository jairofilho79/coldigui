#!/usr/bin/env python3
"""Resolve UDID de dispositivo iOS físico (iPhone ou iPad) para scripts de install/run.

Uso:
  python3 scripts/ios_resolve_device.py
  FLUTTER_DEVICE_ID=<udid> python3 scripts/ios_resolve_device.py

Só retorna sucesso quando o dispositivo aparece em `flutter devices --machine`
(pareado e pronto para instalação). Falha antes do build se não estiver visível.

Consumidores: ios_homolog_install.sh, ios_dev_run.sh.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys

_PAIRING_HELP = """\
1. Conecte o cabo USB, desbloqueie o dispositivo e toque em Confiar neste computador
2. Abra Xcode → Window → Devices and Simulators → selecione o dispositivo → Pair
3. Responda ao prompt de pareamento no dispositivo
4. Ative Modo Desenvolvedor: Ajustes → Privacidade e Segurança → Modo Desenvolvedor (reinicie se pedir)
5. Confirme: flutter devices  (deve listar o dispositivo físico)
6. Rode o script novamente

Atalho: open -a Xcode"""


def _flutter_physical_ios() -> list[tuple[str, str]]:
    machine = subprocess.run(
        ["flutter", "devices", "--machine"],
        capture_output=True,
        text=True,
        check=True,
    )
    devices = json.loads(machine.stdout)
    return [
        (d["id"], d.get("name", d["id"]))
        for d in devices
        if d.get("targetPlatform") == "ios" and not d.get("emulator")
    ]


def _flutter_diagnostics() -> str:
    probe = subprocess.run(
        ["flutter", "devices", "--device-timeout", "15"],
        capture_output=True,
        text=True,
    )
    return f"{probe.stdout}\n{probe.stderr}"


def _fail(message: str) -> None:
    print(message, file=sys.stderr)
    sys.exit(1)


def _pairing_error(diagnostics: str, requested_id: str | None = None) -> None:
    unpaired = re.search(
        r"Error: ([^\n]+) is not available because it is unpaired",
        diagnostics,
    )
    if unpaired:
        name = unpaired.group(1).strip()
        _fail(f"O {name} não está pareado com este Mac.\n\n{_PAIRING_HELP}")

    if requested_id and (
        "must be paired" in diagnostics.lower()
        or "RemotePairingError" in diagnostics
    ):
        _fail(
            f"O dispositivo {requested_id} não está pareado (instalação impossível).\n\n"
            f"{_PAIRING_HELP}"
        )

    if "Developer Mode" in diagnostics or "code -27" in diagnostics:
        _fail(
            "Dispositivo encontrado na rede, mas o Flutter não consegue conectar.\n\n"
            "1. Prefira cabo USB (mais confiável que Wi‑Fi)\n"
            "2. Desbloqueie o dispositivo\n"
            "3. Ative Modo Desenvolvedor: Ajustes → Privacidade e Segurança → Modo Desenvolvedor\n"
            "4. Pareie no Xcode: Window → Devices and Simulators\n"
            "5. Confirme: flutter devices"
        )


def main() -> None:
    validate_only = "--validate" in sys.argv
    requested = os.environ.get("FLUTTER_DEVICE_ID", "").strip() or None
    physical = _flutter_physical_ios()
    diagnostics = ""

    if requested:
        match = next((d for d in physical if d[0] == requested), None)
        if match:
            device_id, name = match
            print(f"    {name} ({device_id})", file=sys.stderr)
            print(device_id)
            return
        diagnostics = _flutter_diagnostics()
        _pairing_error(diagnostics, requested_id=requested)
        known = "\n".join(f"  - {name}: {device_id}" for device_id, name in physical)
        hint = (
            f"\n\nDispositivos físicos visíveis ao Flutter:\n{known}"
            if physical
            else "\n\nNenhum dispositivo físico visível ao Flutter."
        )
        _fail(
            f"FLUTTER_DEVICE_ID={requested} não está disponível para instalação.{hint}\n\n"
            f"{_PAIRING_HELP}"
        )

    if physical:
        device_id, name = physical[0]
        print(f"    {name} ({device_id})", file=sys.stderr)
        print(device_id)
        return

    if not validate_only:
        diagnostics = _flutter_diagnostics()
        _pairing_error(diagnostics)

    _fail(
        "Nenhum dispositivo iOS físico pareado (iPhone ou iPad).\n\n"
        f"{_PAIRING_HELP}"
    )


if __name__ == "__main__":
    main()
