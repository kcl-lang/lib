#!/usr/bin/env python3
"""Generate the AST declarations for a binding from the Rust source of truth.

    python3 tools/generate_ast.py              # write the generated files
    python3 tools/generate_ast.py --check      # fail if the tree is stale (CI)
    python3 tools/generate_ast.py --selftest   # the generator's own tests

The input is ``kcl-lang/kcl/crates/ast/src/ast.rs``, which lives in the
sibling ``kcl`` repository. Override the location with ``KCL_AST_RS``.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from astgen.cli import main  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
