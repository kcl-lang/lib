#!/usr/bin/env python3
"""Fail if a TestArgs field from spec.proto is missing in a language binding.

The C++ binding failed to compile when kcl added TestArgs.eval_once and the
manual kcl_api::TestArgs initializer was not updated (E0063, issue #421).
Generated stubs and the hand-written wrappers are checked here so the next
additive field is caught without waiting for that compile.

eval_once stays opt-in: the proto documents the default as false, and this
script rejects a different default comment on that field.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "spec" / "spec.proto"

# Each binding must mention every TestArgs field. Camel-case names are how
# Java, Kotlin, C#, Swift, Dart, Node's .d.ts, and wasm spell the same field.
BINDINGS = [
    ROOT / "cpp/src/lib.rs",
    ROOT / "nodejs/src/lib.rs",
    ROOT / "nodejs/index.d.ts",
    ROOT / "wasm/src/api.ts",
    ROOT / "python/kcl_lib/api/spec_pb2.pyi",
    ROOT / "go/api/spec.pb.go",
    ROOT / "dotnet/KclLib/api/Spec.cs",
    ROOT / "java/src/main/java/com/kcl/api/Spec.java",
    ROOT / "kotlin/src/main/java/com/kcl/api/Spec.java",
    ROOT / "kotlin/src/main/kotlin/com/kcl/api/TestArgsKt.kt",
    ROOT / "php/src/Api/Com/Kcl/Api/TestArgs.php",
    ROOT / "ruby/lib/kcl_lib/spec_pb.rb",
    ROOT / "swift/Sources/KclLib/spec.pb.swift",
    ROOT / "zig/src/proto/com/kcl/api.pb.zig",
    ROOT / "julia/src/pb/com/kcl/api/spec_pb.jl",
    ROOT / "dart/lib/src/pb/spec.pb.dart",
    ROOT / "dart/lib/src/pb/spec.pbjson.dart",
    ROOT / "c/include/spec.pb.h",
    ROOT / "lua/kcl_lib/schema.lua",
    ROOT / "src/tests.rs",
]


def message_body(proto: str, name: str) -> str:
    match = re.search(rf"message {name} \{{", proto)
    if not match:
        raise SystemExit(f"spec.proto has no message {name}")
    start = match.end()
    depth = 1
    i = start
    while i < len(proto) and depth:
        if proto[i] == "{":
            depth += 1
        elif proto[i] == "}":
            depth -= 1
        i += 1
    return proto[start : i - 1]


def fields(body: str) -> list[tuple[str, int]]:
    found = re.findall(
        r"^\s*(?:repeated\s+|map<[^>]+>\s+)?(?:optional\s+)?[\w.]+\s+(\w+)\s*=\s*(\d+)\s*;",
        body,
        flags=re.M,
    )
    return [(name, int(number)) for name, number in found]


def spellings(name: str) -> set[str]:
    parts = name.split("_")
    camel = parts[0] + "".join(part.capitalize() for part in parts[1:])
    pascal = "".join(part.capitalize() for part in parts)
    return {name, camel, pascal}


def main() -> int:
    proto = SPEC.read_text()
    body = message_body(proto, "TestArgs")
    declared = fields(body)
    names = [name for name, _ in declared]
    if ("eval_once", 6) not in declared:
        print("TestArgs.eval_once must be field 6", file=sys.stderr)
        return 1
    # The sentence that states the default sits on the field, not an earlier one.
    if not re.search(r"Defaults to false\.\s*bool eval_once = 6;", body):
        print("TestArgs.eval_once must stay default false", file=sys.stderr)
        return 1

    errors = []
    for path in BINDINGS:
        if not path.is_file():
            errors.append(f"missing binding file {path.relative_to(ROOT)}")
            continue
        text = path.read_text(errors="replace")
        missing = [name for name in names if not any(form in text for form in spellings(name))]
        if missing:
            errors.append(
                f"{path.relative_to(ROOT)} is missing TestArgs fields: {', '.join(missing)}"
            )
    # The C++ and Node initializers must set the flag explicitly. `..Default`
    # would hide the next missing field; these two lines are what E0063 checks.
    cpp = (ROOT / "cpp/src/lib.rs").read_text()
    if "eval_once: args.eval_once" not in cpp:
        errors.append("cpp/src/lib.rs build_test_args does not set eval_once")
    node = (ROOT / "nodejs/src/lib.rs").read_text()
    if "eval_once: eval_once.unwrap_or_default()" not in node:
        errors.append("nodejs/src/lib.rs TestArgs initializer does not set eval_once")
    # Python's TestOptions facade is a subset of the proto (it never grew
    # coverage). eval_once is part of that facade and must default to false.
    facade = (ROOT / "python/kcl_lib/kcl.py").read_text()
    if "eval_once: bool = False" not in facade or "eval_once=test_opts.eval_once" not in facade:
        errors.append("python/kcl_lib/kcl.py does not pass eval_once through, default false")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"TestArgs fields present in {len(BINDINGS)} bindings: {', '.join(names)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
