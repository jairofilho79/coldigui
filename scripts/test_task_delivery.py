#!/usr/bin/env python3
"""Isolated delivery tests; never contact GitHub or deploy."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parent
SCRIPT = SOURCE / "task_delivery.py"


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="coldigui-delivery-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "-b", "main")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "Delivery test")
        (self.root / "pubspec.yaml").write_text("name: example\nversion: 1.3.8+6\n")
        self.git("add", "pubspec.yaml")
        self.git("commit", "-m", "Initial")
        self.git("remote", "add", "origin", str(self.root))

    def git(self, *args, check=True, input=None):
        return subprocess.run(
            ["git", *args], cwd=self.root, text=True, capture_output=True,
            check=check, input=input,
        )

    def run_delivery(self, *args, ok=True, payload=None, env=None):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), *args], cwd=self.root,
            text=True, capture_output=True,
            input=json.dumps(payload) if payload is not None else None,
            env=env,
        )
        if ok:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def version(self):
        return (self.root / "pubspec.yaml").read_text().split("version: ")[1].strip()

    def test_feature_bumps_minor_resets_patch_and_increments_build_once(self):
        self.run_delivery("start", "feature", "example")
        self.run_delivery("prepare")
        self.run_delivery("prepare")
        self.assertEqual(self.version(), "1.4.0+7")
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "feature/example")

    def test_fix_bumps_patch_and_build_once(self):
        self.run_delivery("start", "fix", "example")
        self.run_delivery("prepare")
        self.run_delivery("prepare")
        self.assertEqual(self.version(), "1.3.9+7")

    def test_start_rejects_dirty_tree_without_explicit_permission(self):
        (self.root / "existing.txt").write_text("keep me")
        self.run_delivery("start", "feature", "example", ok=False)
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "main")
        self.run_delivery("start", "feature", "example", "--allow-dirty")
        self.assertEqual((self.root / "existing.txt").read_text(), "keep me")

    def test_start_rejects_invalid_name_and_wrong_base(self):
        self.run_delivery("start", "feature", "../main", ok=False)
        self.git("switch", "-c", "fix/other")
        self.run_delivery("start", "feature", "example", ok=False)

    def test_existing_branch_requires_explicit_adoption(self):
        self.git("switch", "-c", "feature/example")
        self.run_delivery("start", "feature", "example", ok=False)
        self.run_delivery("start", "feature", "example", "--adopt")
        self.run_delivery("prepare")
        self.assertEqual(self.version(), "1.4.0+7")

    def test_prepare_requires_task_and_rejects_manual_version_changes(self):
        self.run_delivery("prepare", ok=False)
        self.run_delivery("start", "feature", "example")
        (self.root / "pubspec.yaml").write_text("version: 5.0.0+99\n")
        self.run_delivery("prepare", ok=False)
        self.assertEqual(self.version(), "5.0.0+99")

    def test_repeated_start_preserves_original_version_and_phase(self):
        self.run_delivery("start", "feature", "example")
        self.run_delivery("prepare")
        self.run_delivery("start", "feature", "example", "--adopt", "--allow-dirty")
        self.run_delivery("prepare")
        self.assertEqual(self.version(), "1.4.0+7")

    def test_invalid_or_duplicate_version_fails_without_changes(self):
        (self.root / "pubspec.yaml").write_text("version: 1.2.3\n")
        self.run_delivery("start", "fix", "invalid", "--allow-dirty", ok=False)
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "main")

    def hook(self, event, **payload):
        return json.loads(self.run_delivery("hook", event, payload=payload).stdout)

    def install(self):
        shutil.copytree(SOURCE.parent / ".githooks", self.root / ".githooks")
        (self.root / "scripts").mkdir()
        shutil.copy2(SCRIPT, self.root / "scripts/task_delivery.py")
        self.run_delivery("install")

    def test_pre_tool_denies_edits_and_shell_on_main_but_allows_reads(self):
        for name in ("apply_patch", "functions.apply_patch", "edit", "Write", "bash"):
            result = self.hook("preToolUse", toolName=name, toolArgs={})
            self.assertEqual(result["permissionDecision"], "deny")
        self.assertEqual(self.hook("preToolUse", toolName="view"), {})

    def test_pre_tool_allows_only_literal_start_not_shell_chaining(self):
        cmd = "python3 scripts/task_delivery.py start feature/example"
        result = self.hook("preToolUse", toolName="bash", toolArgs={"command": cmd})
        self.assertEqual(result["permissionDecision"], "deny")
        cmd = "python3 scripts/task_delivery.py start feature example"
        self.assertEqual(self.hook("preToolUse", toolName="bash", toolArgs={"command": cmd}), {})
        result = self.hook(
            "preToolUse", toolName="bash",
            toolArgs={"command": cmd + "; git commit -am bypass"},
        )
        self.assertEqual(result["permissionDecision"], "deny")

    def test_pre_tool_requires_registered_task_on_valid_branch(self):
        self.git("switch", "-c", "fix/example")
        self.assertEqual(
            self.hook("preToolUse", toolName="edit")["permissionDecision"], "deny",
        )
        self.run_delivery("start", "fix", "example", "--adopt")
        self.assertEqual(self.hook("preToolUse", toolName="edit"), {})

    def test_session_start_injects_skill_without_mutation(self):
        before = self.git("status", "--porcelain").stdout
        self.assertIn("task-delivery", self.hook("sessionStart")["additionalContext"])
        self.assertEqual(self.git("status", "--porcelain").stdout, before)

    def test_stop_does_not_finalize_an_active_task_or_a_question(self):
        self.assertEqual(self.hook("agentStop"), {})
        self.run_delivery("start", "feature", "example")
        self.assertEqual(self.hook("agentStop"), {})
        self.assertEqual(self.version(), "1.3.8+6")

    def test_prepared_stop_reminds_once_without_loops(self):
        self.run_delivery("start", "feature", "example")
        self.run_delivery("prepare")
        self.assertEqual(self.hook("agentStop")["decision"], "block")
        self.assertEqual(self.hook("agentStop"), {})
        self.assertEqual(self.hook("agentStop", stop_hook_active=True), {})
        self.assertEqual(self.version(), "1.4.0+7")

    def test_stop_forced_continuation_does_not_reblock(self):
        self.run_delivery("start", "feature", "example")
        self.run_delivery("prepare")
        self.assertEqual(self.hook("agentStop", stop_hook_active=True), {})

    def test_installed_git_hooks_reject_main_commit_and_main_ref_push(self):
        self.install()
        result = self.git("commit", "--allow-empty", "-m", "Forbidden", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("main", result.stderr)
        self.git("switch", "-c", "feature/example")
        self.git("commit", "--allow-empty", "-m", "Allowed")
        result = subprocess.run(
            [str(self.root / ".githooks/pre-push"), "origin", "unused"],
            cwd=self.root, text=True, capture_output=True,
            input="refs/heads/feature/example abc refs/heads/main def\n",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("main", result.stderr)

    def test_install_refuses_to_replace_existing_hooks(self):
        self.git("config", "core.hooksPath", "custom-hooks")
        self.run_delivery("install", ok=False)
        self.assertEqual(self.git("config", "--get", "core.hooksPath").stdout.strip(), "custom-hooks")

    def test_finish_requires_prepared_task_and_valid_pr_number(self):
        self.run_delivery("start", "fix", "example")
        self.run_delivery("finish", "42", ok=False)
        self.run_delivery("prepare")
        self.run_delivery("finish", "https://evil.invalid/42", ok=False)

    def prepared_pr(self):
        self.run_delivery("start", "fix", "example")
        self.run_delivery("prepare")
        self.git("add", "pubspec.yaml")
        self.git("commit", "-m", "Fix")
        binary = self.root / "fake-bin"
        binary.mkdir()
        gh = binary / "gh"
        gh.write_text(
            "#!/usr/bin/env python3\nimport os\nprint(os.environ['DELIVERY_TEST_PR'])\n"
        )
        gh.chmod(0o755)
        info = {
            "baseRefName": "main", "headRefName": "fix/example",
            "headRefOid": self.git("rev-parse", "HEAD").stdout.strip(),
            "state": "OPEN", "url": "https://github.com/jairofilho79/coldigui/pull/42",
        }
        return info, dict(os.environ, PATH=str(binary) + os.pathsep + os.environ["PATH"])

    def test_finish_registers_matching_pr_without_merging_or_deploying(self):
        info, env = self.prepared_pr()
        env["DELIVERY_TEST_PR"] = json.dumps(info)
        result = self.run_delivery("finish", "42", env=env)
        self.assertEqual(json.loads(result.stdout)["phase"], "awaiting-approval")
        self.assertEqual(self.hook("agentStop"), {})
        self.assertEqual(self.hook("preToolUse", toolName="bash"), {})
        self.assertEqual(self.hook("preToolUse", toolName="edit")["permissionDecision"], "deny")
        self.run_delivery("prepare", ok=False)

    def test_finish_rejects_wrong_repo_base_branch_head_and_closed_pr(self):
        info, env = self.prepared_pr()
        for field, value in (
            ("baseRefName", "develop"), ("headRefName", "fix/another"),
            ("headRefOid", "0" * 40), ("state", "CLOSED"),
            ("url", "https://github.com/other/repo/pull/42"),
        ):
            with self.subTest(field=field):
                env["DELIVERY_TEST_PR"] = json.dumps(dict(info, **{field: value}))
                self.run_delivery("finish", "42", env=env, ok=False)
                state = json.loads(self.run_delivery("status").stdout)
                self.assertEqual(state["phase"], "prepared")

    def test_finish_rejects_uncommitted_version(self):
        self.run_delivery("start", "fix", "example")
        self.run_delivery("prepare")
        result = self.run_delivery("finish", "42", ok=False)
        self.assertIn("Commit the prepared version", result.stderr)

    def delivered_pr(self):
        info, env = self.prepared_pr()
        env["DELIVERY_TEST_PR"] = json.dumps(info)
        self.run_delivery("finish", "42", env=env)
        return info, env

    def test_resume_reopens_matching_pr_preserving_version_and_unrelated_changes(self):
        info, env = self.delivered_pr()
        (self.root / "existing.txt").write_text("keep me")
        self.assertEqual(self.hook("preToolUse", toolName="edit")["permissionDecision"], "deny")
        result = self.run_delivery("resume", "42", "--reason", "Fix failed CI", env=env)
        state = json.loads(result.stdout)
        self.assertEqual(state["phase"], "prepared")
        self.assertEqual(state["resume_reason"], "Fix failed CI")
        self.assertEqual(state["resume_head"], info["headRefOid"])
        self.assertEqual(state["pr"], info["url"])
        self.assertEqual(self.hook("preToolUse", toolName="edit"), {})
        self.run_delivery("prepare")
        self.run_delivery("resume", "42", "--reason", "Fix failed CI", env=env)
        self.assertEqual(self.version(), "1.3.9+7")
        self.assertEqual((self.root / "existing.txt").read_text(), "keep me")
        self.run_delivery("finish", "42", env=env)
        self.assertEqual(self.hook("preToolUse", toolName="edit")["permissionDecision"], "deny")

    def test_resume_requires_delivered_task_matching_number_and_reason(self):
        self.run_delivery("resume", "42", "--reason", "Fix CI", ok=False)
        info, env = self.prepared_pr()
        env["DELIVERY_TEST_PR"] = json.dumps(info)
        self.run_delivery("resume", "42", "--reason", "Fix CI", env=env, ok=False)
        self.run_delivery("finish", "42", env=env)
        for args in (
            ("43", "--reason", "Fix CI"), ("42",), ("42", "--reason", " "),
            ("https://evil.invalid/42", "--reason", "Fix CI"),
        ):
            self.run_delivery("resume", *args, env=env, ok=False)
            self.assertEqual(json.loads(self.run_delivery("status").stdout)["phase"], "awaiting-approval")

    def test_resume_rejects_closed_merged_wrong_repo_base_branch_and_head(self):
        info, env = self.delivered_pr()
        for field, value in (
            ("baseRefName", "develop"), ("headRefName", "fix/another"),
            ("headRefOid", "0" * 40), ("state", "CLOSED"), ("state", "MERGED"),
            ("url", "https://github.com/other/repo/pull/42"),
        ):
            with self.subTest(field=field, value=value):
                env["DELIVERY_TEST_PR"] = json.dumps(dict(info, **{field: value}))
                self.run_delivery("resume", "42", "--reason", "Fix CI", env=env, ok=False)
                self.assertEqual(
                    json.loads(self.run_delivery("status").stdout)["phase"], "awaiting-approval",
                )
                self.assertEqual(self.hook("preToolUse", toolName="edit")["permissionDecision"], "deny")

    def test_resume_rejects_uncommitted_pubspec_and_local_head_divergence(self):
        info, env = self.delivered_pr()
        pubspec = self.root / "pubspec.yaml"
        original = pubspec.read_text()
        pubspec.write_text(original + "# uncommitted\n")
        self.run_delivery("resume", "42", "--reason", "Fix CI", env=env, ok=False)
        pubspec.write_text(original)
        self.git("commit", "--allow-empty", "-m", "Unpublished work")
        self.run_delivery("resume", "42", "--reason", "Fix CI", env=env, ok=False)
        self.assertEqual(json.loads(self.run_delivery("status").stdout)["phase"], "awaiting-approval")

    def test_resumed_task_reminds_again_then_accepts_updated_remote_head(self):
        info, env = self.delivered_pr()
        self.hook("agentStop")
        self.run_delivery("resume", "42", "--reason", "Fix CI", env=env)
        self.assertEqual(self.hook("agentStop")["decision"], "block")
        self.assertEqual(self.hook("agentStop"), {})
        self.git("commit", "--allow-empty", "-m", "Correct CI")
        env["DELIVERY_TEST_PR"] = json.dumps(
            dict(info, headRefOid=self.git("rev-parse", "HEAD").stdout.strip()),
        )
        self.run_delivery("finish", "42", env=env)
        self.assertEqual(json.loads(self.run_delivery("status").stdout)["phase"], "awaiting-approval")
        self.assertEqual(self.version(), "1.3.9+7")

    def test_hook_alias_payload_and_invalid_json_fail_explicitly(self):
        result = self.hook("preToolUse", tool_name="Edit", tool_input={})
        self.assertEqual(result["permissionDecision"], "deny")
        self.run_delivery("hook", "preToolUse", payload=["not an object"], ok=False)

    def test_string_tool_args_can_bootstrap_without_granting_other_commands(self):
        args = json.dumps({"command": "python3 scripts/task_delivery.py start fix example"})
        self.assertEqual(self.hook("preToolUse", toolName="bash", toolArgs=args), {})

    def test_deploy_on_clean_main_requests_permission_and_dirty_main_is_blocked(self):
        args = {"command": "./deploy.sh --skip-ios --skip-android"}
        result = self.hook("preToolUse", toolName="bash", toolArgs=args)
        self.assertEqual(result["permissionDecision"], "ask")
        (self.root / "uncommitted.txt").write_text("not deployable")
        result = self.hook("preToolUse", toolName="bash", toolArgs=args)
        self.assertEqual(result["permissionDecision"], "deny")

    def test_deploy_rejects_all_skips_and_shell_chaining(self):
        for cmd in (
            "./deploy.sh --skip-web --skip-ios --skip-android",
            "./deploy.sh; git commit -am bypass",
        ):
            result = self.hook("preToolUse", toolName="bash", toolArgs={"command": cmd})
            self.assertEqual(result["permissionDecision"], "deny")

    def test_deploy_help_remains_available_without_a_task(self):
        for cmd in ("./deploy.sh --help", "./scripts/deploy_all.sh -h"):
            result = self.hook("preToolUse", toolName="bash", toolArgs={"command": cmd})
            self.assertEqual(result, {})

    def test_git_read_only_queries_do_not_require_a_task(self):
        for cmd in ("git status --short", "git branch --show-current", "gh pr view 42"):
            result = self.hook("preToolUse", toolName="bash", toolArgs={"command": cmd})
            self.assertEqual(result, {})

    def test_concurrent_prepare_increments_only_once(self):
        self.run_delivery("start", "feature", "example")
        processes = [
            subprocess.Popen(
                [sys.executable, str(SCRIPT), "prepare"], cwd=self.root,
                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
            for _ in range(2)
        ]
        for process in processes:
            stdout, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, stdout + stderr)
        self.assertEqual(self.version(), "1.4.0+7")

    def test_local_merge_on_main_is_rejected(self):
        self.install()
        self.git("switch", "-c", "fix/example")
        self.git("commit", "--allow-empty", "-m", "Fix")
        self.git("switch", "main")
        result = self.git("merge", "--no-ff", "fix/example", "--no-edit", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("main", result.stderr)

    def test_install_preserves_existing_default_hook(self):
        hook = self.root / ".git/hooks/pre-commit"
        hook.write_text("# existing team hook\n")
        self.run_delivery("install", ok=False)
        self.assertEqual(hook.read_text(), "# existing team hook\n")

    def test_start_rejects_main_ahead_of_remote_without_publishing_old_commits(self):
        remote = self.root / "remote.git"
        self.git("clone", "--bare", str(self.root), str(remote))
        self.git("remote", "set-url", "origin", str(remote))
        self.git("commit", "--allow-empty", "-m", "Unpublished work")
        original = self.git("rev-parse", "HEAD").stdout
        result = self.run_delivery("start", "feature", "isolated", "--allow-dirty", ok=False)
        self.assertIn("origin/main", result.stderr)
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "main")
        self.assertEqual(self.git("rev-parse", "HEAD").stdout, original)

    def test_start_requires_fetchable_origin_main(self):
        self.git("remote", "remove", "origin")
        self.run_delivery("start", "fix", "example", ok=False)
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "main")


if __name__ == "__main__":
    unittest.main()
