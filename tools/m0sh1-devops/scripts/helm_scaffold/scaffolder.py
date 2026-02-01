"""Main scaffolding logic for Helm charts and wrapper charts."""

from __future__ import annotations

from pathlib import Path
from typing import Optional

from . import templates
from .detector import CHART_FILE, git_origin


def ensure_dir(path: Path) -> None:
    """Create directory and parents if they don't exist."""
    path.mkdir(parents=True, exist_ok=True)


def write_file(path: Path, content: str, force: bool) -> None:
    """Write file to disk, optionally overwriting existing file.

    Args:
        path: File path to write
        content: Content to write
        force: If True, overwrite existing files

    Raises:
        FileExistsError: If file exists and force=False
    """
    if path.exists() and not force:
        raise FileExistsError(f"File exists: {path}")
    path.write_text(content)


def scaffold_wrapper_chart(
    repo: Path,
    name: str,
    scope: str,
    layout: str,
    argocd: bool,
    disabled: bool,
    dest_namespace: Optional[str],
    repo_url: Optional[str],
    revision: str,
    force: bool,
) -> None:
    """Scaffold a wrapper chart for infra repo.

    Args:
        repo: Path to infra repository root
        name: Chart/app name
        scope: "cluster" or "user"
        layout: "root" or "helm" (chart directory layout)
        argocd: If True, create ArgoCD Application manifest
        disabled: If True, place Application under argocd/disabled/
        dest_namespace: Destination namespace (defaults based on scope)
        repo_url: Git repo URL (auto-detected if not provided)
        revision: Git revision for ArgoCD (default: "main")
        force: If True, overwrite existing files
    """
    base_dir = repo / "apps" / scope / name
    chart_dir = base_dir / "helm" if layout == "helm" else base_dir

    ensure_dir(chart_dir / "templates")

    # Write chart files
    write_file(chart_dir / CHART_FILE, templates.chart_yaml(name), force)
    write_file(chart_dir / "values.yaml", templates.values_yaml_wrapper(), force)
    write_file(chart_dir / "templates" / "deployment.yaml", templates.deployment_yaml(name), force)
    write_file(chart_dir / "templates" / "service.yaml", templates.service_yaml(name), force)
    write_file(chart_dir / "templates" / "ingress.yaml", templates.ingress_yaml(), force)

    # Create ArgoCD Application if requested
    if argocd:
        app_base = repo / "argocd" / ("disabled" if disabled else "apps") / scope
        ensure_dir(app_base)
        app_path = app_base / f"{name}.yaml"

        repo_url = repo_url or git_origin(repo) or "REPO_URL"
        dest_ns = dest_namespace or ("apps" if scope == "user" else name)
        source_path = f"apps/{scope}/{name}"
        if layout == "helm":
            source_path = f"{source_path}/helm"

        app_yaml = templates.argocd_application_yaml(
            name=name,
            scope=scope,
            repo_url=repo_url,
            revision=revision,
            source_path=source_path,
            dest_namespace=dest_ns,
        )
        write_file(app_path, app_yaml, force)


def scaffold_chart(repo: Path, name: str, force: bool) -> None:
    """Scaffold a standalone chart for helm-charts repo.

    Args:
        repo: Path to helm-charts repository root
        name: Chart name
        force: If True, overwrite existing files
    """
    chart_dir = repo / "charts" / name
    ensure_dir(chart_dir / "templates")

    # Write chart files
    write_file(chart_dir / CHART_FILE, templates.chart_yaml(name), force)
    write_file(chart_dir / "values.yaml", templates.values_yaml_simple(), force)
    write_file(chart_dir / "templates" / "deployment.yaml", templates.deployment_yaml(name), force)
    write_file(chart_dir / "templates" / "service.yaml", templates.service_yaml(name), force)
