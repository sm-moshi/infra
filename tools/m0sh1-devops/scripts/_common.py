"""Shared helpers for m0sh1-devops guard scripts."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

SKIP_DIRS = {".git", ".venv", ".terraform", "node_modules", ".cache"}


def resolve_repo(repo_arg: str, *, allow_absolute: bool = True) -> Path:
    base = Path.cwd().resolve()
    repo_path = Path(repo_arg)

    if repo_path.is_absolute() and not allow_absolute:
        raise ValueError(f"Repo path must be relative, got absolute path: {repo_path}")

    repo_candidate = repo_path if repo_path.is_absolute() else (base / repo_path)
    repo_candidate = repo_candidate.resolve()

    try:
        repo_candidate.relative_to(base)
    except ValueError as exc:
        raise ValueError(f"Repo path must be within {base}, got: {repo_candidate}") from exc

    return repo_candidate


def should_skip(path: Path, *, skip_bootstrap: bool = False) -> bool:
    if any(part in SKIP_DIRS for part in path.parts):
        return True
    parts = path.parts
    if "docs" in parts and "archive" in parts:
        return True
    if skip_bootstrap:
        for idx, part in enumerate(parts[:-1]):
            if part == "cluster" and parts[idx + 1] == "bootstrap":
                return True
    return False


def iter_files(root: Path, patterns: Iterable[str], *, skip_bootstrap: bool = False) -> Iterable[Path]:
    for pattern in patterns:
        for path in root.rglob(pattern):
            if should_skip(path, skip_bootstrap=skip_bootstrap):
                continue
            yield path


def read_text(path: Path) -> str:
    try:
        return path.read_text()
    except UnicodeDecodeError:
        return path.read_text(errors="ignore")
