#!/usr/bin/env python3
"""Resolve ID de dispositivo Android físico (tablet ou phone) para scripts de install/run.

Uso:
  python3 scripts/android_resolve_device.py
  FLUTTER_DEVICE_ID=<serial> python3 scripts/android_resolve_device.py

Só retorna sucesso quando o dispositivo aparece em `flutter devices --machine`
(USB debugging ativo e autorizado). Falha antes do build se não estiver visível.

Consumidores: android_homolog_install.sh.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys

_PAIRING_HELP = """\
1. Conecte o cabo USB e desbloqueie o tablet
2. Ative Opções do desenvolvedor: Ajustes → Sobre o tablet → toque 7x em Número da versão
3. Ative Depuração USB: Ajustes → Sistema → Opções do desenvolvedor → Depuração USB
4. Aceite o prompt "Permitir depuração USB?" neste computador (marque Sempre permitir)
5. Confirme: flutter devices  (deve listar o dispositivo físico)
6. Rode o script novamente

Diagnóstico: adb devices"""


def _is_physical_android(device: dict) -> bool:
    platform = device.get("targetPlatform", "")
    return platform.startswith("android") and not device.get("emulator")


def _flutter_physical_android() -> list[tuple[str, str]]:
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
        if _is_physical_android(d)
    ]


def _flutter_diagnostics() -> str:
    probe = subprocess.run(
        ["flutter", "devices", "--device-timeout", "15"],
        capture_output=True,
        text=True,
    )
    return f"{probe.stdout}\n{probe.stderr}"


def _adb_diagnostics() -> str:
    probe = subprocess.run(
        ["adb", "devices"],
        capture_output=True,
        text=True,
    )
    return probe.stdout


def _fail(message: str) -> None:
    print(message, file=sys.stderr)
    sys.exit(1)


def _unauthorized_hint(diagnostics: str) -> None:
    if "unauthorized" in diagnostics.lower():
        _fail(
            "Dispositivo Android conectado, mas não autorizado para depuração USB.\n\n"
            "1. Desbloqueie o tablet\n"
            "2. Revogue autorizações antigas: Opções do desenvolvedor → Revogar autorizações de depuração USB\n"
            "3. Desconecte e reconecte o cabo\n"
            "4. Toque em Permitir no prompt deste computador\n"
            "5. Confirme: adb devices  (deve mostrar 'device', não 'unauthorized')"
        )


def main() -> None:
    requested = os.environ.get("FLUTTER_DEVICE_ID", "").strip() or None
    physical = _flutter_physical_android()
    diagnostics = ""

    if requested:
        match = next((d for d in physical if d[0] == requested), None)
        if match:
            device_id, name = match
            print(f"    {name} ({device_id})", file=sys.stderr)
            print(device_id)
            return
        diagnostics = _flutter_diagnostics()
        _unauthorized_hint(_adb_diagnostics())
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

    diagnostics = _flutter_diagnostics()
    _unauthorized_hint(_adb_diagnostics())

    if re.search(r"offline\b", diagnostics, re.IGNORECASE):
        _fail(
            "Dispositivo Android aparece como offline.\n\n"
            "1. Desbloqueie o tablet\n"
            "2. Reconecte o cabo USB\n"
            "3. Confirme: adb devices"
        )

    _fail(
        "Nenhum dispositivo Android físico conectado (tablet ou phone).\n\n"
        f"{_PAIRING_HELP}"
    )


if __name__ == "__main__":
    main()
