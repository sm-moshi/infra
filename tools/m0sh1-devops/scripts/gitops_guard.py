#!/usr/bin/env python3
"""
GitOps guard checks for m0sh1.cc infra repo.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List

from _common import read_text, resolve_repo, should_skip


@dataclass
class Issue:
    severity: str  # "error" | "warning"
    message: str
    path: str | None = None


def iter_yaml_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*.yml"):
        if should_skip(path, skip_bootstrap=True):
            continue
        yield path
    for path in root.rglob("*.yaml"):
        if should_skip(path, skip_bootstrap=True):
            continue
        yield path


def is_application(text: str) -> bool:
    return re.search(r"(?m)^kind:\s*Application(Set)?\b", text) is not None


def has_label_value(text: str, label: str, value: str) -> bool:
    pattern = rf"(?m)^\s*{re.escape(label)}:\s*{re.escape(value)}\b"
    return re.search(pattern, text) is not None


def is_argocd_application_path(path: Path) -> bool:
    parts = path.parts
    if "apps" not in parts:
        return False
    try:
        idx = parts.index("apps")
    except ValueError:
        return False
    return parts[idx : idx + 3] in (("apps", "argocd", "applications"), ("apps", "argocd", "disabled"))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="GitOps guard checks for m0sh1.cc infra repo")
    parser.add_argument("--repo", required=True, help="Path to infra repo")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    parser.add_argument("--strict", action="store_true", help="Fail on warnings")
    return parser.parse_args()


def resolve_repo_or_exit(repo_arg: str) -> Path | None:
    try:
        repo = resolve_repo(repo_arg, allow_absolute=False)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return None
    if not repo.exists():
        print(f"Repo path does not exist: {repo}", file=sys.stderr)
        return None
    return repo


def check_apps_layout(repo: Path) -> List[Issue]:
    issues: List[Issue] = []
    apps_dir = repo / "apps"
    if not apps_dir.exists():
        return issues
    allowed = {"cluster", "user", "argocd"}
    for child in apps_dir.iterdir():
        if child.is_dir() and child.name not in allowed:
            issues.append(Issue("error", f"Unexpected apps/ child directory: {child.name}", str(child)))
    return issues


def check_env_overlays(repo: Path) -> List[Issue]:
    issues: List[Issue] = []
    env_root = repo / "cluster" / "environments"
    if not env_root.exists():
        return issues
    for child in env_root.iterdir():
        if child.is_dir() and child.name != "lab":
            issues.append(Issue("error", f"Unexpected environment overlay: {child.name}", str(child)))
    return issues


def check_yaml_file(path: Path, text: str) -> List[Issue]:
    issues: List[Issue] = []
    if not text.strip():
        return issues
    has_sealed = re.search(r"(?m)^kind:\s*SealedSecret\b", text) is not None
    if re.search(r"(?m)^kind:\s*Secret\b", text) and not has_sealed:
        issues.append(Issue("error", "Plain Secret found; use SealedSecrets", str(path)))
    if "argocd.argoproj.io/skip-reconcile" in text:
        issues.append(Issue("warning", "skip-reconcile annotation present (recovery-only)", str(path)))
    if is_application(text):
        if not is_argocd_application_path(path):
            issues.append(
                Issue("error", "ArgoCD Application manifest outside apps/argocd/{applications,disabled}", str(path))
            )
        if not has_label_value(text, "app.kubernetes.io/part-of", "apps-root"):
            issues.append(
                Issue("error", "ArgoCD Application missing app.kubernetes.io/part-of: apps-root label", str(path))
            )
        if re.search(r"(?m)^\s*chart:\s*\S+", text):
            issues.append(
                Issue("error", "ArgoCD Application uses chart: (direct Helm repo); use wrapper chart path", str(path))
            )
    return issues


def scan_yaml(repo: Path) -> List[Issue]:
    issues: List[Issue] = []
    for path in iter_yaml_files(repo):
        text = read_text(path)
        issues.extend(check_yaml_file(path, text))
    return issues


def report_issues(repo: Path, issues: List[Issue], as_json: bool) -> None:
    if as_json:
        payload = {
            "repo": str(repo),
            "issues": [issue.__dict__ for issue in issues],
        }
        print(json.dumps(payload, indent=2))
        return
    if not issues:
        print("✅ No GitOps issues detected")
        return
    print("GitOps issues:")
    for issue in issues:
        loc = f" ({issue.path})" if issue.path else ""
        print(f"- [{issue.severity}] {issue.message}{loc}")


def exit_code(issues: List[Issue], strict: bool) -> int:
    if any(i.severity == "error" for i in issues):
        return 1
    if strict and issues:
        return 1
    return 0


def main() -> int:
    args = parse_args()
    repo = resolve_repo_or_exit(args.repo)
    if repo is None:
        return 2

    issues: List[Issue] = []
    issues.extend(check_apps_layout(repo))
    issues.extend(check_env_overlays(repo))
    issues.extend(scan_yaml(repo))

    report_issues(repo, issues, args.json)
    return exit_code(issues, args.strict)


if __name__ == "__main__":
    raise SystemExit(main())
