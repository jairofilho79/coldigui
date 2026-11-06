from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from scripts.validate_ios_isar import REQUIRED_SYMBOLS, validate


class ValidateIosIsarTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / "Runner.app"
        self.core = self.app / "Frameworks/IsarPlusCore.framework/IsarPlusCore"
        self.core.parent.mkdir(parents=True)
        self.core.touch()

    def test_rejects_archive_without_embedded_core(self):
        self.core.unlink()
        with self.assertRaisesRegex(ValueError, "not embedded"):
            validate(self.app)

    @patch("scripts.validate_ios_isar.subprocess.run")
    def test_accepts_exported_database_entry_points(self, run):
        run.return_value.stdout = "\n".join(REQUIRED_SYMBOLS)
        validate(self.app)
        self.assertEqual(run.call_args.args[0][-1], str(self.core))

    @patch("scripts.validate_ios_isar.subprocess.run")
    def test_rejects_missing_symbol_not_a_prefix_match(self, run):
        run.return_value.stdout = "\n".join(
            (REQUIRED_SYMBOLS - {"_isar_plus_version"}) | {"_isar_plus_version_extra"}
        )
        with self.assertRaisesRegex(ValueError, "_isar_plus_version"):
            validate(self.app)

    @patch("scripts.validate_ios_isar.subprocess.run")
    def test_surfaces_binary_inspection_failure(self, run):
        run.side_effect = subprocess.CalledProcessError(
            1, ["xcrun", "dyld_info"], stderr="invalid Mach-O"
        )
        with self.assertRaises(subprocess.CalledProcessError):
            validate(self.app)


if __name__ == "__main__":
    unittest.main()
