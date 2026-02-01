#!/usr/bin/env python3
"""Helm scaffold for m0sh1.cc infra and helm-charts repos.

REFACTORED VERSION (2026-02-01):
This script has been modularized into the helm_scaffold/ package for better
maintainability. The implementation is now split across:

- helm_scaffold/cli.py: Command-line interface and argument parsing
- helm_scaffold/detector.py: Repository type and layout detection
- helm_scaffold/scaffolder.py: Main scaffolding logic
- helm_scaffold/templates.py: Template strings for chart files

This file now acts as a thin compatibility wrapper. For development,
edit the modules in helm_scaffold/ directory.
"""

from __future__ import annotations

import sys
from pathlib import Path

# Add scripts directory to path for importing helm_scaffold package
sys.path.insert(0, str(Path(__file__).parent))

# Import and expose main function
from helm_scaffold.cli import main

if __name__ == "__main__":
    raise SystemExit(main())
