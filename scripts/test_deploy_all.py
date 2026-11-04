import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("deploy_all.sh")


class DeployAllTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.scripts = self.root / "scripts"
        self.scripts.mkdir()
        (self.root / "pubspec.yaml").touch()
        shutil.copy2(SCRIPT, self.scripts / "deploy_all.sh")
        self.log = self.root / "calls.log"

        for name in (
            "setup_deps.sh",
            "web_deploy.sh",
            "ios_homolog_install.sh",
            "android_homolog_install.sh",
        ):
            stub = self.scripts / name
            stub.write_text(
                "#!/bin/sh\n"
                f"printf '%s' '{name}' >> \"$DEPLOY_TEST_LOG\"\n"
                "printf ' argc=%s' \"$#\" >> \"$DEPLOY_TEST_LOG\"\n"
                "for arg in \"$@\"; do printf ' <%s>' \"$arg\" >> \"$DEPLOY_TEST_LOG\"; done\n"
                "printf '\\n' >> \"$DEPLOY_TEST_LOG\"\n"
                + ('exit "${WEB_EXIT:-0}"\n' if name == "web_deploy.sh" else "")
            )
            stub.chmod(0o755)

    def run_deploy(self, *args, web_exit="0"):
        env = os.environ.copy()
        env.update(DEPLOY_TEST_LOG=str(self.log), WEB_EXIT=web_exit)
        result = subprocess.run(
            ["/bin/bash", str(self.scripts / "deploy_all.sh"), *args],
            cwd=self.root,
            env=env,
            capture_output=True,
            text=True,
        )
        return result, self.log.read_text().splitlines()

    def test_web_without_skip_build_receives_no_arguments(self):
        result, calls = self.run_deploy("--skip-ios", "--skip-android", "--no-open")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, ["setup_deps.sh argc=0", "web_deploy.sh argc=0"])

    def test_skip_build_web_is_forwarded(self):
        result, calls = self.run_deploy(
            "--skip-build-web", "--skip-ios", "--skip-android", "--no-open"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            calls, ["setup_deps.sh argc=0", "web_deploy.sh argc=1 <--skip-build>"]
        )

    def test_skip_web_does_not_invoke_web_deploy(self):
        result, calls = self.run_deploy(
            "--skip-web", "--skip-ios", "--skip-android", "--no-open"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, ["setup_deps.sh argc=0"])

    def test_full_deploy_continues_to_mobile_after_web(self):
        result, calls = self.run_deploy("--no-open")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            calls,
            [
                "setup_deps.sh argc=0",
                "web_deploy.sh argc=0",
                "ios_homolog_install.sh argc=0",
                "android_homolog_install.sh argc=2 <--profile> <--allow-no-device>",
            ],
        )

    def test_web_failure_stops_mobile_deploys(self):
        result, calls = self.run_deploy("--no-open", web_exit="23")
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(calls, ["setup_deps.sh argc=0", "web_deploy.sh argc=0"])


if __name__ == "__main__":
    unittest.main()
