"""Repository type and layout detection."""

from __future__ import annotations

import logging
import subprocess
from pathlib import Path
from typing import Optional

CHART_FILE = "Chart.yaml"


def detect_repo_type(repo: Path) -> str:
    """Detect if repo is 'infra' or 'helm-charts' type.

    Args:
        repo: Path to repository root

    Returns:
        "infra", "helm-charts", or "unknown"
    """
    if (repo / "apps").exists() and (repo / "cluster").exists():
        return "infra"
    if (repo / "charts").exists():
        return "helm-charts"
    return "unknown"


def detect_layout(repo: Path) -> str:
    """Detect chart layout within infra repo.

    Args:
        repo: Path to infra repository root

    Returns:
        "root" (preferred) or "helm" (legacy)
    """
    # Prefer repo default layout under apps/<scope>/<name>/Chart.yaml
    if list(repo.glob(f"apps/cluster/*/{CHART_FILE}")) or list(repo.glob(f"apps/user/*/{CHART_FILE}")):
        return "root"

    # Fallback to "helm" layout under apps/<scope>/<name>/helm/ if present
    helm_glob_cluster = str(Path("apps") / "cluster" / "*" / "helm" / CHART_FILE)
    helm_glob_user = str(Path("apps") / "user" / "*" / "helm" / CHART_FILE)
    if list(repo.glob(helm_glob_cluster)) or list(repo.glob(helm_glob_user)):
        return "helm"

    return "root"


def git_origin(repo: Path) -> Optional[str]:
    """Detect git remote origin URL.

    Args:
        repo: Path to git repository

    Returns:
        Origin URL string or None if detection fails
    """
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), "remote", "get-url", "origin"],
            check=True,
            capture_output=True,
            text=True,
        )
        origin = result.stdout.strip()
        if origin:
            return origin
        logging.warning("Git origin is empty")
        return None
    except subprocess.CalledProcessError as exc:
        logging.warning(f"Failed to detect git origin (git command failed): {exc}")
        return None
    except Exception as exc:
        logging.warning(f"Failed to detect git origin: {exc}")
        return None
