"""Command-line interface for helm_scaffold."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .detector import detect_layout, detect_repo_type
from .scaffolder import scaffold_chart, scaffold_wrapper_chart


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="Helm scaffold for m0sh1.cc repos")
    parser.add_argument("--repo", required=True, help="Path to infra or helm-charts repo")
    parser.add_argument("--name", required=True, help="Chart/app name")
    parser.add_argument("--repo-type", choices=["infra", "helm-charts", "auto"], default="auto")
    parser.add_argument("--scope", choices=["cluster", "user"], help="Required for infra repo")
    parser.add_argument("--layout", choices=["detect", "helm", "root"], default="detect")
    parser.add_argument("--argocd", action="store_true", help="Create ArgoCD Application stub")
    parser.add_argument("--disabled", action="store_true", help="Place Application under disabled")
    parser.add_argument("--dest-namespace", help="Destination namespace for ArgoCD Application")
    parser.add_argument("--repo-url", help="Override repoURL in ArgoCD Application")
    parser.add_argument("--revision", default="main", help="Git revision for ArgoCD Application")
    parser.add_argument("--force", action="store_true", help="Overwrite existing files")
    return parser.parse_args()


def main() -> int:
    """Main entry point for helm_scaffold CLI."""
    args = parse_args()

    repo = Path(args.repo).resolve()
    if not repo.exists():
        print(f"Repo path does not exist: {repo}", file=sys.stderr)
        return 2

    repo_type = args.repo_type
    if repo_type == "auto":
        repo_type = detect_repo_type(repo)

    if repo_type == "infra":
        if not args.scope:
            print("--scope is required for infra repo", file=sys.stderr)
            return 2
        layout = args.layout
        if layout == "detect":
            layout = detect_layout(repo)
        scaffold_wrapper_chart(
            repo=repo,
            name=args.name,
            scope=args.scope,
            layout=layout,
            argocd=args.argocd,
            disabled=args.disabled,
            dest_namespace=args.dest_namespace,
            repo_url=args.repo_url,
            revision=args.revision,
            force=args.force,
        )
        print(f"Scaffolded wrapper chart in {repo}")
        return 0

    if repo_type == "helm-charts":
        scaffold_chart(repo=repo, name=args.name, force=args.force)
        print(f"Scaffolded chart in {repo}")
        return 0

    print("Could not detect repo type; use --repo-type", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
