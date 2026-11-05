#!/usr/bin/env python3
"""Branch and version lifecycle for coldigui; Python standard library only."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile


VERSION = re.compile(r"^version: (\d+)\.(\d+)\.(\d+)\+(\d+)[ \t]*$", re.MULTILINE)
BRANCH = re.compile(r"(feature|fix)/[a-z0-9]+(?:-[a-z0-9]+)*")


class DeliveryError(Exception):
    pass


def command(*args):
    result = subprocess.run(args, text=True, capture_output=True, timeout=30)
    if result.returncode:
        raise DeliveryError(result.stderr.strip() or f"Command failed: {args[0]}")
    return result.stdout.strip()


def git(*args):
    return command("git", *args)


def branch():
    return git("branch", "--show-current")


def require_branch():
    name = branch()
    if not BRANCH.fullmatch(name):
        raise DeliveryError("Use feature/<slug> or fix/<slug>; main and detached HEAD are protected.")
    return name


def version(text):
    matches = list(VERSION.finditer(text))
    if len(matches) != 1 or len(re.findall(r"^version:", text, re.MULTILINE)) != 1:
        raise DeliveryError("Expected one pubspec version: MAJOR.MINOR.PATCH+BUILD.")
    return matches[0]


def next_version(value, kind):
    major, minor, patch, build = map(int, re.split(r"[.+]", value))
    if kind == "feature":
        minor, patch = minor + 1, 0
    else:
        patch += 1
    return f"{major}.{minor}.{patch}+{build + 1}"


def require_no_downgrade(value, minimum):
    numbers = tuple(map(int, re.split(r"[.+]", value)))
    lower = tuple(map(int, re.split(r"[.+]", minimum)))
    if numbers[:3] < lower[:3] or numbers[3] < lower[3]:
        raise DeliveryError("Version reconciliation cannot downgrade the version or build.")


def validate_state_version(state):
    planned = next_version(state["base_version"], branch().split("/")[0])
    source = state.get("version_source_commit")
    if source is None:
        if state.get("version") != planned:
            raise DeliveryError("Invalid task version.")
        return
    if not isinstance(source, str) or not re.fullmatch(r"[0-9a-f]{40}", source):
        raise DeliveryError("Invalid version source commit.")
    if git("merge-base", "HEAD", source) != source:
        raise DeliveryError("Version source must be an ancestor of HEAD.")
    inherited = version(git("show", f"{source}:pubspec.yaml")).group(0).split(": ", 1)[1].strip()
    if state["version"] != inherited:
        raise DeliveryError("Task version must match its recorded main commit.")
    require_no_downgrade(inherited, planned)


def state_path(name):
    key = hashlib.sha256(name.encode()).hexdigest()
    return Path(git("rev-parse", "--git-path", f"task-delivery/{key}.json"))


def load_state(required=True):
    path = state_path(require_branch())
    if not path.exists():
        if required:
            raise DeliveryError("No task registered. Run start before implementation.")
        return None
    state = json.loads(path.read_text())
    if not isinstance(state, dict) or state.get("branch") != branch():
        raise DeliveryError("Invalid task state.")
    if state.get("phase") not in ("active", "prepared", "awaiting-approval"):
        raise DeliveryError("Invalid task phase.")
    validate_state_version(state)
    return state


def save_state(state):
    path = state_path(state["branch"])
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as handle:
        json.dump(state, handle, indent=2)
        handle.write("\n")
        temp = handle.name
    os.replace(temp, path)


def start(args):
    name = f"{args.kind}/{args.slug}"
    if not BRANCH.fullmatch(name):
        raise DeliveryError("Slug must contain lowercase letters, digits and single hyphens.")
    current = branch()
    if args.adopt:
        if current != name:
            raise DeliveryError("--adopt requires the exact existing task branch.")
        existing = load_state(required=False)
        if existing:
            return existing
    elif current != "main":
        raise DeliveryError("Start a new task from main; use --adopt only for this task's branch.")
    dirty = git("status", "--porcelain")
    if dirty and not args.allow_dirty:
        raise DeliveryError("Existing changes found; review ownership before using --allow-dirty.")
    text = Path("pubspec.yaml").read_text()
    original = version(text).group(0).split(": ", 1)[1].strip()
    committed = version(git("show", "HEAD:pubspec.yaml")).group(0).split(": ", 1)[1].strip()
    if original != committed:
        raise DeliveryError("pubspec version has uncommitted changes; resolve them before start.")
    git("fetch", "--quiet", "origin", "main")
    base_commit = git("rev-parse", "origin/main")
    if git("rev-parse", "HEAD") != base_commit:
        raise DeliveryError(
            "Task must start at origin/main. Local commits/divergence must be preserved "
            "separately; use an isolated worktree based on origin/main."
        )
    if not args.adopt:
        git("switch", "-c", name)
    state = {
        "branch": name, "base_version": original, "base_commit": base_commit,
        "version": next_version(original, args.kind),
        "phase": "active", "initial_dirty": dirty,
    }
    save_state(state)
    return state


def prepare():
    state = load_state()
    if state["phase"] not in ("active", "prepared"):
        raise DeliveryError("Task already delivered; start a new branch for another task.")
    path = Path("pubspec.yaml")
    text = path.read_text()
    current = version(text).group(0).split(": ", 1)[1].strip()
    if current not in (state["base_version"], state["version"]):
        raise DeliveryError("Unexpected version change; reconcile it explicitly before preparing.")
    path.write_text(VERSION.sub(f'version: {state["version"]}', text, count=1))
    state["phase"] = "prepared"
    save_state(state)
    return state


def reconcile_version(reason):
    state = load_state()
    if state["phase"] != "prepared" or not reason.strip():
        raise DeliveryError("Reconciliation requires a prepared task and a nonempty --reason.")
    if git("status", "--porcelain", "--", "pubspec.yaml"):
        raise DeliveryError("Commit the resolved pubspec before reconciling its version.")
    git("fetch", "--quiet", "origin", "main")
    source = git("rev-parse", "origin/main")
    if git("merge-base", "HEAD", source) != source:
        raise DeliveryError("Merge origin/main first; it must be an ancestor of HEAD.")
    inherited = version(git("show", f"{source}:pubspec.yaml")).group(0).split(": ", 1)[1].strip()
    committed = version(git("show", "HEAD:pubspec.yaml")).group(0).split(": ", 1)[1].strip()
    if committed != inherited:
        raise DeliveryError("Resolved version must match the merged origin/main version.")
    require_no_downgrade(inherited, state["version"])
    state.update(
        version=inherited, version_source_commit=source,
        version_reconcile_reason=reason.strip(),
    )
    validate_state_version(state)
    save_state(state)
    return state


def validate_pr(state, pr):
    if not re.fullmatch(r"[1-9]\d*", pr):
        raise DeliveryError("Expected a positive PR number in jairofilho79/coldigui.")
    url = f"https://github.com/jairofilho79/coldigui/pull/{pr}"
    if state.get("pr") not in (None, url):
        raise DeliveryError("Use the same PR registered for this task.")
    committed = version(git("show", "HEAD:pubspec.yaml")).group(0).split(": ", 1)[1].strip()
    if committed != state["version"]:
        raise DeliveryError("Commit the prepared version before registering the PR.")
    if git("diff", "HEAD", "--", "pubspec.yaml"):
        raise DeliveryError("Uncommitted pubspec changes found; review before registering the PR.")
    info = json.loads(command(
        "gh", "pr", "view", pr, "--repo", "jairofilho79/coldigui",
        "--json", "url,baseRefName,headRefName,headRefOid,state",
    ))
    if (
        info["baseRefName"] != "main"
        or info["headRefName"] != state["branch"]
        or info["headRefOid"] != git("rev-parse", "HEAD")
        or info["state"] != "OPEN"
        or info["url"] != url
    ):
        raise DeliveryError("PR must be open, target main and match this branch and HEAD.")
    return info


def finish(pr):
    state = load_state()
    if state["phase"] not in ("prepared", "awaiting-approval"):
        raise DeliveryError("Validate the task and run prepare before registering its PR.")
    info = validate_pr(state, pr)
    state.update(phase="awaiting-approval", pr=info["url"])
    save_state(state)
    return state


def resume(pr, reason):
    state = load_state()
    if not reason.strip():
        raise DeliveryError("Describe the approved same-task correction with --reason.")
    if not state.get("pr") or state["phase"] not in ("prepared", "awaiting-approval"):
        raise DeliveryError("Resume requires this task's delivered, open PR.")
    info = validate_pr(state, pr)
    if state["phase"] == "awaiting-approval":
        state.update(
            phase="prepared", resume_reason=reason.strip(), resume_head=info["headRefOid"],
        )
        state.pop("stop_reminded", None)
        save_state(state)
    return state


def install():
    configured = subprocess.run(
        ["git", "config", "--get", "core.hooksPath"], text=True, capture_output=True,
        timeout=10,
    )
    if configured.returncode not in (0, 1):
        raise DeliveryError(configured.stderr.strip())
    if configured.stdout.strip() not in ("", ".githooks"):
        raise DeliveryError("Existing core.hooksPath found; integrate hooks manually.")
    if not configured.stdout.strip():
        old = Path(git("rev-parse", "--git-path", "hooks"))
        if any((old / name).exists() for name in ("pre-commit", "pre-merge-commit", "pre-push")):
            raise DeliveryError("Existing Git hooks found; integrate them manually.")
    for name in ("pre-commit", "pre-merge-commit", "pre-push"):
        path = Path(".githooks") / name
        if not path.is_file() or not os.access(path, os.X_OK):
            raise DeliveryError(f"Missing executable hook: {path}")
    git("config", "--local", "core.hooksPath", ".githooks")
    return {"hooksPath": ".githooks"}


def shell_words(arguments):
    if isinstance(arguments, str):
        arguments = json.loads(arguments)
    if not isinstance(arguments, dict):
        raise DeliveryError("Hook tool arguments must be an object.")
    text = arguments.get("command", "")
    if not isinstance(text, str):
        raise DeliveryError("Shell command must be a string.")
    return shlex.split(text)


def bootstrap_command(words):
    if words == ["git", "switch", "main"]:
        return True
    if branch() == "main" and words == ["git", "pull", "--ff-only", "origin", "main"]:
        return True
    if words[:3] != ["python3", "scripts/task_delivery.py", "start"] or len(words) < 5:
        return False
    return (
        BRANCH.fullmatch(f"{words[3]}/{words[4]}") is not None
        and all(word in ("--adopt", "--allow-dirty") for word in words[5:])
    )


def read_only_command(words):
    if words in (
        ["git", "status", "--short"], ["git", "branch", "--show-current"],
        ["git", "diff", "--stat"], ["git", "diff", "--check"],
        ["git", "log", "-5", "--oneline"], ["gh", "auth", "status"],
    ):
        return True
    return (
        len(words) in (4, 6) and words[:2] == ["gh", "pr"]
        and words[2] in ("view", "checks") and re.fullmatch(r"[1-9]\d*", words[3]) is not None
        and (len(words) == 4 or words[4:] == ["--repo", "jairofilho79/coldigui"])
    )


def deploy_permission(words):
    if not words or words[0] not in ("./deploy.sh", "./scripts/deploy_all.sh"):
        return None
    if words[1:] in (["--help"], ["-h"]):
        return {}
    flags = set(words[1:])
    allowed = {
        "--skip-web", "--skip-ios", "--skip-android", "--skip-build-web",
        "--release", "--profile", "--no-open",
    }
    if (
        flags - allowed or {"--skip-web", "--skip-ios", "--skip-android"} <= flags
        or branch() != "main" or git("status", "--porcelain")
    ):
        return {
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                "Deploy requires clean main, valid options and at least one selected platform."
            ),
        }
    return {
        "permissionDecision": "ask",
        "permissionDecisionReason": (
            "Confirm this is the merged PR commit and request separate explicit deploy approval."
        ),
    }


def hook(event, payload):
    if not isinstance(payload, dict):
        raise DeliveryError("Hook input must be a JSON object.")
    if event == "sessionStart":
        return {"additionalContext": (
            "For implementation tasks in coldigui, load .github/skills/task-delivery/SKILL.md. "
            "After task approval, start feature/<slug> or fix/<slug> before editing. "
            "At verified completion prepare the version and create a scoped PR. "
            "Never merge without explicit approval for that PR; offer deploy separately."
        )}
    valid = BRANCH.fullmatch(branch()) is not None
    state = load_state(required=False) if valid else None
    if event == "preToolUse":
        name = payload.get("toolName", payload.get("tool_name", ""))
        if not isinstance(name, str):
            raise DeliveryError("Hook toolName must be a string.")
        name = name.rsplit(".", 1)[-1].lower()
        guarded = name in {
            "apply_patch", "edit", "create", "write", "multiedit", "multi_edit",
            "replace_string_in_file", "multi_replace_string_in_file", "create_file",
            "bash", "shell", "run_in_terminal", "execute", "powershell",
        }
        shell = name in {"bash", "shell", "run_in_terminal", "execute", "powershell"}
        args = payload.get("toolArgs", payload.get("tool_input", {}))
        if shell:
            words = shell_words(args)
            deploy = deploy_permission(words)
            if deploy is not None:
                return deploy
            if bootstrap_command(words) or read_only_command(words):
                return {}
        if guarded and (not state or (not shell and state["phase"] == "awaiting-approval")):
            return {
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    "main is protected and each task needs a registered feature/fix branch. "
                    "Load task-delivery; run python3 scripts/task_delivery.py start "
                    "<feature|fix> <slug> after approval. Use --adopt only for this task's "
                    "existing branch. For an approved correction to the same open PR, run "
                    "resume <PR-number> --reason <approved-correction>. "
                    "A delivered task cannot receive unrelated edits."
                ),
            }
        return {}
    if (
        state and state["phase"] == "prepared"
        and not payload.get("stop_hook_active", False)
        and not state.get("stop_reminded", False)
    ):
        state["stop_reminded"] = True
        save_state(state)
        return {
            "decision": "block",
            "reason": (
                "Task prepared: create/update its scoped PR and run finish <PR-number>. "
                "If blocked, report the blocker instead of claiming delivery. "
                "Ask explicit approval before merge; suggest deploy after merge. "
                "Do not increment the version again."
            ),
        }
    return {}


def git_guard(event):
    if event == "pre-commit":
        require_branch()
    else:
        for line in sys.stdin:
            fields = line.split()
            if len(fields) != 4:
                raise DeliveryError("Invalid pre-push input.")
            if fields[2] == "refs/heads/main":
                raise DeliveryError("Direct pushes/deletions to main are blocked; use a PR.")
    return {"allowed": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    begin = commands.add_parser("start")
    begin.add_argument("kind", choices=("feature", "fix"))
    begin.add_argument("slug")
    begin.add_argument("--adopt", action="store_true")
    begin.add_argument("--allow-dirty", action="store_true")
    commands.add_parser("prepare")
    commands.add_parser("status")
    commands.add_parser("install")
    done = commands.add_parser("finish")
    done.add_argument("pr")
    reopen = commands.add_parser("resume")
    reopen.add_argument("pr")
    reopen.add_argument("--reason", required=True)
    reconcile = commands.add_parser("reconcile-version")
    reconcile.add_argument("--reason", required=True)
    events = commands.add_parser("hook")
    events.add_argument("event", choices=("sessionStart", "preToolUse", "agentStop"))
    guards = commands.add_parser("git-guard")
    guards.add_argument("event", choices=("pre-commit", "pre-push"))
    args = parser.parse_args()
    try:
        os.chdir(git("rev-parse", "--show-toplevel"))
        lock_path = Path(git("rev-parse", "--git-path", "task-delivery.lock"))
        with lock_path.open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if args.action == "start":
                result = start(args)
            elif args.action == "prepare":
                result = prepare()
            elif args.action == "finish":
                result = finish(args.pr)
            elif args.action == "resume":
                result = resume(args.pr, args.reason)
            elif args.action == "reconcile-version":
                result = reconcile_version(args.reason)
            elif args.action == "install":
                result = install()
            elif args.action == "hook":
                result = hook(args.event, json.load(sys.stdin))
            elif args.action == "git-guard":
                result = git_guard(args.event)
            else:
                result = load_state()
        print(json.dumps(result, indent=2))
    except (DeliveryError, OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        print(f"task-delivery: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
