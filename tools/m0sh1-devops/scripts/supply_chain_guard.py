#!/usr/bin/env python3
"""Supply chain guard checks for m0sh1.cc repos."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List

from _common import iter_files, read_text, resolve_repo


@dataclass
class Issue:
    severity: str
    message: str
    path: str | None = None


def is_pinned_action(ref: str) -> bool:
    if "@" not in ref:
        return False
    _, version = ref.rsplit("@", 1)
    return bool(re.fullmatch(r"[0-9a-f]{40}", version))


def from_line_image(line: str) -> str | None:
    line = line.strip()
    if not line.startswith("FROM "):
        return None
    # Handle optional --platform flag
    parts = line.split()
    if len(parts) >= 3 and parts[1].startswith("--platform="):
        return parts[2]
    if len(parts) >= 2:
        return parts[1]
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Supply chain guard checks")
    parser.add_argument("--repo", required=True, help="Path to repo")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    parser.add_argument("--strict", action="store_true", help="Fail on warnings")
    return parser.parse_args()


def resolve_repo_or_exit(repo_arg: str) -> Path | None:
    try:
        repo = resolve_repo(repo_arg, allow_absolute=True)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return None
    if not repo.exists():
        print(f"Repo path does not exist: {repo}", file=sys.stderr)
        return None
    if not repo.is_dir():
        print(f"Repo path is not a directory: {repo}", file=sys.stderr)
        return None
    return repo


def scan_workflows_dir(workflows_dir: Path) -> List[Issue]:
    if not workflows_dir.exists():
        return []
    issues: List[Issue] = []
    for wf in workflows_dir.rglob("*.yml"):
        text = read_text(wf)
        for line in text.splitlines():
            line = line.strip()
            if not line.startswith("uses:"):
                continue
            ref = line.split("uses:", 1)[1].strip()
            if ref.startswith("./") or ref.startswith("docker://"):
                continue
            if not is_pinned_action(ref):
                issues.append(Issue("warning", f"Action not pinned to SHA: {ref}", str(wf)))
    return issues


def scan_workflows(repo: Path) -> List[Issue]:
    issues: List[Issue] = []
    issues.extend(scan_workflows_dir(repo / ".github" / "workflows"))
    issues.extend(scan_workflows_dir(repo / ".gitea" / "workflows"))
    return issues


def scan_dockerfiles(repo: Path) -> List[Issue]:
    issues: List[Issue] = []
    for df in iter_files(repo, ["Dockerfile", "Containerfile", "*.Dockerfile"]):
        text = read_text(df)
        for line in text.splitlines():
            image = from_line_image(line)
            if not image or image == "scratch":
                continue
            if "@sha256:" not in image:
                issues.append(Issue("warning", f"Base image not pinned by digest: {image}", str(df)))
    return issues


def scan_values_repo_tag(text: str, values_path: Path) -> List[Issue]:
    issues: List[Issue] = []
    repo_name = None
    repo_indent = None
    for line in text.splitlines():
        if "repository:" in line:
            repo_indent = len(line) - len(line.lstrip(" "))
            repo_name = line.split("repository:", 1)[1].strip().strip('"')
        if repo_name is not None and "tag:" in line:
            tag_indent = len(line) - len(line.lstrip(" "))
            if repo_indent is not None and tag_indent == repo_indent:
                tag = line.split("tag:", 1)[1].strip().strip('"')
                if "sha256" not in tag and "@" not in tag:
                    issues.append(
                        Issue("warning", f"Image tag not pinned by digest: {repo_name}:{tag}", str(values_path))
                    )
                repo_name = None
                repo_indent = None
    return issues


def scan_values_image_field(text: str, values_path: Path) -> List[Issue]:
    issues: List[Issue] = []
    for line in text.splitlines():
        if re.search(r"\bimage:\s*", line):
            image = line.split("image:", 1)[1].strip().strip('"')
            if image and "@sha256:" not in image and ":" in image:
                issues.append(Issue("warning", f"Image not pinned by digest: {image}", str(values_path)))
    return issues


def scan_values(repo: Path) -> List[Issue]:
    issues: List[Issue] = []
    for values in iter_files(repo, ["values.yaml", "values.yml"]):
        text = read_text(values)
        issues.extend(scan_values_repo_tag(text, values))
        issues.extend(scan_values_image_field(text, values))
    return issues


def check_history(repo: Path) -> List[Issue]:
    history = repo / "docs" / "history.md"
    if history.exists():
        return []
    return [Issue("warning", "docs/history.md missing (used to document tag usage/exceptions)", str(history))]


def report_issues(repo: Path, issues: List[Issue], as_json: bool) -> None:
    if as_json:
        payload = {"repo": str(repo), "issues": [issue.__dict__ for issue in issues]}
        print(json.dumps(payload, indent=2))
        return
    if not issues:
        print("✅ Supply chain checks passed")
        return
    print("Supply chain findings:")
    for issue in issues:
        loc = f" ({issue.path})" if issue.path else ""
        print(f"- [{issue.severity}] {issue.message}{loc}")
    print("\nReminder: document temporary tag usage or exceptions in docs/history.md")


def exit_code(issues: List[Issue], strict: bool) -> int:
    if strict and issues:
        return 1
    return 0


def main() -> int:
    args = parse_args()
    repo = resolve_repo_or_exit(args.repo)
    if repo is None:
        return 2

    issues: List[Issue] = []
    issues.extend(scan_workflows(repo))
    issues.extend(scan_dockerfiles(repo))
    issues.extend(scan_values(repo))
    issues.extend(check_history(repo))

    report_issues(repo, issues, args.json)
    return exit_code(issues, args.strict)


if __name__ == "__main__":
    raise SystemExit(main())
