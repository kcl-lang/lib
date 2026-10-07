"""The generator's entry point.

``python3 tools/generate_ast.py`` writes the generated files in place.
``python3 tools/generate_ast.py --check`` writes them to a temporary directory
and diffs, which is what CI runs: a generated file nobody checks is just
another hand-written file.
"""

from __future__ import annotations

import argparse
import difflib
import os
import shutil
import subprocess
import sys
from typing import Dict, List

from .emit_go import GO_FILES, GoEmitter
from .emit_python import PY_MODULES, PythonEmitter
from .emit_typescript import TS_FILES, TypeScriptEmitter
from .model import build
from .rust_ast import parse_crate


def gofmt(text: str) -> str:
    """Run ``gofmt`` over generated Go.

    The emitter lays the source out and ``gofmt`` decides it: aligning a const
    block or a run of struct fields is exactly the work a formatter exists for,
    and re-deriving it here would be a second, weaker copy of the same rules.
    The failure is deliberately loud rather than skipped -- a checked-in file
    that one machine formatted and another did not is precisely the staleness
    ``--check`` exists to catch, so quietly emitting unformatted Go would turn
    that check into coin flips.
    """
    tool = shutil.which("gofmt")
    if tool is None:
        raise SystemExit(
            "gofmt not found on PATH.\n"
            "Generating the Go binding needs the Go toolchain; install Go and re-run."
        )
    done = subprocess.run([tool], input=text, capture_output=True, text=True)
    if done.returncode != 0:
        raise SystemExit(f"gofmt failed on generated Go:\n{done.stderr}")
    return done.stdout

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_AST_RS = os.environ.get("KCL_AST_RS") or os.path.join(
    os.path.dirname(REPO_ROOT), "kcl", "crates", "ast", "src", "ast.rs"
)

PYTHON_DIR = os.path.join("python", "kcl_lib", "ast")
TYPESCRIPT_DIR = os.path.join("wasm", "src", "ast")
GO_DIR = os.path.join("go", "ast")


def generate() -> Dict[str, str]:
    """Every generated file's text, keyed by its path relative to the repo root."""
    crate = parse_crate(DEFAULT_AST_RS)
    model = build(crate)

    files: Dict[str, str] = {}
    py = PythonEmitter(model)
    for module in PY_MODULES:
        files[os.path.join(PYTHON_DIR, f"{module}.py")] = py.emit_module(module)
    files[os.path.join(PYTHON_DIR, "__init__.py")] = py.emit_package_init()

    ts = TypeScriptEmitter(model)
    for name in TS_FILES:
        files[os.path.join(TYPESCRIPT_DIR, name)] = ts.emit(name)

    go = GoEmitter(model)
    for name in GO_FILES:
        files[os.path.join(GO_DIR, name)] = gofmt(go.emit(name))
    return files


def _fmt_diff(path: str, want: str, got: str) -> str:
    rel = os.path.relpath(path, REPO_ROOT)
    return "".join(
        difflib.unified_diff(
            got.splitlines(keepends=True),
            want.splitlines(keepends=True),
            fromfile=f"a/{rel} (on disk)",
            tofile=f"b/{rel} (freshly generated)",
            n=3,
        )
    )


def check() -> int:
    files = generate()
    stale: List[str] = []
    for rel in sorted(files):
        path = os.path.join(REPO_ROOT, rel)
        if not os.path.exists(path):
            print(f"MISSING  {rel}", file=sys.stderr)
            stale.append(rel)
            continue
        with open(path, "r", encoding="utf-8") as handle:
            on_disk = handle.read()
        if on_disk != files[rel]:
            print(f"STALE    {rel}", file=sys.stderr)
            sys.stderr.write(_fmt_diff(path, files[rel], on_disk))
            stale.append(rel)
    # Anything the generator owns that it no longer emits would otherwise be an
    # orphan nobody notices, so the reverse direction is checked too. A
    # directory that is not there at all is already reported above, one
    # `MISSING` line per file the generator owns; listing it would raise.
    for directory, suffixes in (
        (PYTHON_DIR, (".py",)),
        (TYPESCRIPT_DIR, (".ts",)),
        (GO_DIR, ("_gen.go",)),
    ):
        abs_dir = os.path.join(REPO_ROOT, directory)
        if not os.path.isdir(abs_dir):
            continue
        for name in sorted(os.listdir(abs_dir)):
            if not name.endswith(suffixes):
                continue
            rel = os.path.join(directory, name)
            if rel not in files:
                print(f"ORPHAN   {rel}", file=sys.stderr)
                stale.append(rel)
    if stale:
        print(
            f"\n{len(stale)} generated file(s) are not what the generator produces.\n"
            "Run `python3 tools/generate_ast.py` and commit the result.",
            file=sys.stderr,
        )
        return 1
    print(f"ok: {len(files)} generated file(s) match the generator")
    return 0


def write() -> int:
    files = generate()
    for rel in sorted(files):
        path = os.path.join(REPO_ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(files[rel])
        print(f"wrote {rel}")
    return 0


def selftest() -> int:
    """The generator's own invariants, including determinism.

    Run by `ruby hack/check_generated_ast.rb` alongside the diff, so a
    generator that has quietly stopped modelling something fails here rather
    than by producing a plausible-looking file.
    """
    from .selftest import run

    return run()


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--check", action="store_true", help="fail if the working tree is stale")
    group.add_argument("--selftest", action="store_true", help="run the generator's own tests")
    args = parser.parse_args(argv)
    if not os.path.exists(DEFAULT_AST_RS):
        print(
            f"ast.rs not found at {DEFAULT_AST_RS}\n"
            "Set KCL_AST_RS to the kcl repo's crates/ast/src/ast.rs, or check out "
            "kcl next to this repository.",
            file=sys.stderr,
        )
        return 2
    if args.check:
        return check()
    if args.selftest:
        return selftest()
    return write()
