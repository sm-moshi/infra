#!/usr/bin/env python3
"""Helm scaffold for m0sh1.cc infra and helm-charts repos.

This is a compatibility wrapper that imports from the helm_scaffold package.
The actual implementation has been refactored into modular components:

- helm_scaffold.cli: Command-line interface and argument parsing
- helm_scaffold.detector: Repository type and layout detection
- helm_scaffold.scaffolder: Main scaffolding logic
- helm_scaffold.templates: Template strings for chart files

For development, edit the modules in helm_scaffold/ directory.
"""

from __future__ import annotations

import sys
from pathlib import Path

# Add scripts directory to path for importing helm_scaffold package
sys.path.insert(0, str(Path(__file__).parent))

from helm_scaffold.cli import main

if __name__ == "__main__":
    raise SystemExit(main())
