# Core / Binding Layering Decision

This record fixes the boundary between the KCL core and the language
bindings in this repository. Every cross-language feature request is
sorted into a layer by the rules in §2; the pending work items are
mapped in §3. It complements `docs/abi.md`, which specifies the binary
interface, and should be read together with it.

## 1. Layers

```
L0  Core          kcl-lang/kcl (../kcl)
                  crates/api    RPC implementations, capi dispatcher, spec.proto (package gpyrpc)
                  crates/ast    AST struct definitions (ast.rs); its serde JSON is the AST wire format
                  crates/tools  formatter, linter, tester, bundler, ...

L1  Contract      spec/spec.proto (this repo)
                  Public mirror of the core proto (package com.kcl.api), renamed/options added.
                  Sole codegen input for the generated binding types.

L2  Bindings      <language>/ directories (python/, dotnet/, nodejs/, kotlin/, ...)
                  Stateless adapters, five sub-parts per binding:
                    1. FFI loader      — locate the native library, call_native, ERROR: prefix,
                                       4 MiB result buffer, plugin-agent entry point
                    2. Protobuf types  — generated from L1, or hand-maintained where codegen
                                       is pinned (see spec/Makefile constraints)
                    3. Service client  — one method per RPC; serialize, call, decode, raise
                    4. AST DTO + decoder — mirrors crates/ast/src/ast.rs field by field;
                                       constrained by hack/check_ast_field_types.rb
                    5. Ergonomics      — AST New* constructors, helper functions, idiomatic
                                       naming and error types

L3  Consistency  hack/, testdata/, .github/workflows/
                  Static shape checks (check_ast_field_types.rb, running in
                  ast-shape-test.yaml) and the behavioral golden suite
                  (same input -> same output across languages) to be built.
```

## 2. Boundary rules

1. **Behavior lives in core, exactly once.** Anything that changes what
   KCL computes or emits ships as a new RPC, or as new fields on an
   existing RPC's messages, in `kcl-lang/kcl`. Bindings never
   reimplement behavior: no shelling out to a CLI, no parsing side
   channels such as `log_message`, no client-side re-derivation of
   dependency graphs.

   *Active violation being removed:* `python/kcl_lib/kcl.py`
   `_run_cli_listing` implements `list_dep_files`/`list_upstream_files`/
   `list_downstream_files` by invoking `ExecProgram` with a magic
   `kcl_cli` argument and parsing `log_message`. This is replaced by
   enriching `LoadPackageResult` (§3, item A) — the RPC the core
   already exposes for package introspection — and deleting the hack.

2. **Idiomatics are binding-local.** Naming, constructors, collection
   wrappers, error types, and async-ness are unrestricted per language.
   AST `New*` constructors are pure ergonomics: they set no behavior
   and therefore stay in L2, but their shapes must remain mechanically
   checkable against `ast.rs` (extend the L3 checks; never hand-audit).

3. **New cross-language data shapes go through the proto.** Request /
   response types are added to the core `spec.proto` and mirrored to
   `spec/spec.proto`; bindings regenerate or hand-apply per the
   `spec/Makefile` constraints. The one exception is the AST, whose
   wire format is fixed by `crates/ast` serde; bindings mirror it as
   DTOs instead of proto messages.

4. **Spec sync is one-directional and CI-gated.** The core
   `crates/api/spec.proto` is authoritative. A change flows:
   core proto → mirror to `spec/spec.proto` → regenerate/hand-update
   bindings → CI. The mirror diff must stay inside an explicit
   allowlist (package name, `option` lines, and RPCs deliberately not
   surfaced to bindings, e.g. `BuildProgram`/`ExecArtifact` today).
   Current known drift: the core registers `KclService.ListDepFiles`,
   which is intentionally *not* mirrored — item A subsumes it.

5. **Every binding change is machine-checked.** AST decoder and RPC
   wrapper changes must be covered by an L3 check — static (field
   shapes) or behavioral (golden outputs) — before merge. A new
   binding is not "added" until it is wired into both.

## 3. Mapping of the pending work items

| Item | Layer | Notes |
|------|-------|-------|
| A. Extend `LoadPackageResult` with `imports` / `kcl_mod` / `apps` fields, replacing `ListDep*` | L0 + L1, then L2 regen | Core impl in `crates/api`; delete the Python `_run_cli_listing` hack in L2; wrap up in the bindings |
| B. `GenerateKcl` / `GenerateProto` / `GenerateOpenAPI` / `GenerateDoc` / `GenerateToml` RPCs | L0 + L1, then thin L2 wrappers | Implementation reuses `crates/tools` / core generators; bindings add one client method each |
| C. `FormatTestReport` RPC (incl. PrettyReporter) | L0 + L1, then thin L2 wrappers | Reporter lives in core so all languages emit byte-identical reports |
| D. AST `New*` constructors for Python / Kotlin / Node / .NET | L2 only | Ergonomics per rule 2; shapes checked by L3 |
| E. Cross-language consistency integration test suite | L3 | Behavioral goldens over shared `testdata/` |
| F. Cross-language diff + unified CI scheduler | L3 | One workflow/matrix replacing the per-language silos for consistency runs |
| G. Scala / Elixir / R / PHP bindings | L2, following the five sub-parts template | Not "done" until wired into L3 checks |

## 4. Alternatives considered and rejected

- **A shared per-language-agnostic binding core** (e.g. one C++ layer
  every binding wraps). Rejected: the universal `call_native`
  dispatcher already provides a single ABI, and the remaining per-language
  work is DTO/ergonomics that no shared layer can remove.
- **AST constructors backed by a core RPC**. Rejected: constructors
  carry no behavior; an RPC round-trip would make building an AST in
  memory slower and non-idiomatic for no consistency gain — the L3
  shape checks already guarantee consistency.
- **Surfacing `ListDepFiles` as a binding RPC**. Rejected: dependency
  information belongs in the package model the caller already loads;
  one enriched `LoadPackageResult` removes both the RPC and the
  Python-side workaround.
