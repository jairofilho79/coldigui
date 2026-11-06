#!/usr/bin/env python3
"""Reject iOS archives that cannot load the Isar native core."""

import argparse
from pathlib import Path
import re
import subprocess
import sys


REQUIRED_SYMBOLS = {
    "_isar_plus_version",
    "_isar_plus_connect_dart_api",
    "_isar_plus_open_instance",
}


def validate(app):
    core = app / "Frameworks/IsarPlusCore.framework/IsarPlusCore"
    if not core.is_file():
        raise ValueError(f"IsarPlusCore.framework is not embedded in {app}")
    result = subprocess.run(
        ["xcrun", "dyld_info", "-exports", str(core)],
        check=True,
        capture_output=True,
        text=True,
    )
    exports = set(re.findall(r"\b_isar_plus_[a-z_]+\b", result.stdout))
    missing = REQUIRED_SYMBOLS - exports
    if missing:
        raise ValueError(f"Isar native symbols missing: {', '.join(sorted(missing))}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="Path to the archived Runner.app")
    args = parser.parse_args()
    try:
        validate(args.app)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Isar validation failed: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError):
            print(error.stderr, file=sys.stderr)
        return 1
    print("OK: embedded IsarPlusCore exports the native database entry points")
    return 0


if __name__ == "__main__":
    sys.exit(main())
