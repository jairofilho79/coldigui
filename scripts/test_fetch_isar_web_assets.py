import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class FetchIsarWebAssetsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        (self.root / "web").mkdir()
        (self.root / "bin").mkdir()
        self.script = self.root / "scripts/fetch_isar_web_assets.sh"
        shutil.copy2(Path(__file__).with_name(self.script.name), self.script)
        (self.root / "pubspec.lock").write_text(
            'packages:\n  isar_plus:\n    dependency: "direct main"\n'
            '    version: "1.3.9"\n'
        )
        self.assets = [self.root / "web" / name for name in
                       ("isar_plus.js", "isar_plus.wasm")]
        for asset in self.assets:
            asset.write_text("old asset")
        curl = self.root / "bin/curl"
        curl.write_text(
            '#!/bin/sh\n'
            'if [ "$FAIL_WASM" = 1 ] && [ "${2##*/}" = isar_plus.wasm ]; then\n'
            '  echo "download failed" >&2; exit 22\nfi\n'
            'printf "%s" "$2" > "$4"\n'
        )
        curl.chmod(0o755)

    def run_fetch(self, fail_wasm=False):
        env = os.environ.copy()
        env.update(PATH=f"{self.root / 'bin'}:{env['PATH']}",
                   FAIL_WASM="1" if fail_wasm else "0")
        return subprocess.run(["bash", str(self.script)], env=env,
                              capture_output=True, text=True)

    def test_refreshes_existing_assets_using_locked_version(self):
        result = self.run_fetch()
        self.assertEqual(result.returncode, 0, result.stderr)
        for asset in self.assets:
            self.assertEqual(asset.read_text(),
                             f"https://unpkg.com/isar_plus@1.3.9/{asset.name}")

    def test_failed_download_preserves_both_previous_assets(self):
        result = self.run_fetch(fail_wasm=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("download failed", result.stderr)
        for asset in self.assets:
            self.assertEqual(asset.read_text(), "old asset")

    def test_missing_locked_version_fails_explicitly(self):
        (self.root / "pubspec.lock").write_text("packages:\n")
        result = self.run_fetch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("pubspec.lock", result.stderr)
        for asset in self.assets:
            self.assertEqual(asset.read_text(), "old asset")

    def test_does_not_use_another_packages_version(self):
        (self.root / "pubspec.lock").write_text(
            'packages:\n  isar_plus:\n    source: hosted\n'
            '  other_package:\n    version: "9.0.0"\n'
        )
        result = self.run_fetch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("pubspec.lock", result.stderr)
        for asset in self.assets:
            self.assertEqual(asset.read_text(), "old asset")


if __name__ == "__main__":
    unittest.main()
