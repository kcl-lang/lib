"""Generate the cross-language consistency manifest (cases.json).

Defines hermetic test cases (args + which result fields to pin), executes
them against the KCL core through the python binding, and writes the golden
expectations to ``tests/consistency/cases.json``.

Regenerate deterministically with:

    source python/venv/bin/activate && python tests/consistency/generate_cases.py

Do not hand-edit cases.json; change the case definitions here instead.
"""

import json
import os
import shutil
import tempfile
from pathlib import Path

import kcl_lib.api as api

MANIFEST = Path(__file__).resolve().parent / "cases.json"
REPO_ROOT = Path(__file__).resolve().parent.parent.parent

PERSON_SCHEMA = "schema Person:\n    name: str\n    check:\n        len(name) > 0"

# Schema fixture shared by the GenerateOpenAPI/GenerateProto/GenerateDoc
# cases. It is referenced by repo-relative path in the manifest; every
# runner resolves entries under tests/consistency/ against the repository
# root (the parent of the directory holding cases.json).
SCHEMA_FIXTURE = "tests/consistency/testdata/gen_openapi/main.k"

# A whole package — module, manifest and a test file — for the RPCs that take a
# package root rather than a single file. It is a fixture rather than a
# temporary directory because `LoadPackage` and `Test` are the RPCs whose
# *result* is a property of the package layout, and a generated directory would
# pin a path that stops existing.
PKG_FIXTURE = "tests/consistency/testdata/pkg"

# A package with a `kcl.yaml`, for `LoadSettingsFiles`. Separate from PKG_FIXTURE
# on purpose: settings are applied to every RPC that runs in a work dir, so
# folding one into the shared package would quietly change what `LoadPackage`,
# `Test` and `FormatPath` see.
SETTINGS_FIXTURE = "tests/consistency/testdata/settings"

# The source `ListVariables` reads. It has to be a file: `ListVariablesArgs`
# takes `files`, not `sources`, so there is no inline form to use.
VARIABLES_FIXTURE = "tests/consistency/testdata/variables/main.k"

# `PARSE_SOURCE` as a package on disk, for `GetSchemaTypeMappingUnderPath`, which
# takes a work dir rather than inline source. Held separately from
# `VARIABLES_FIXTURE` even though both are two-line files: the point of this one
# is that it declares the *same* `Person` schema as the inline case, so the two
# schema-mapping cases can be compared by eye.
SCHEMA_PKG_FIXTURE = "tests/consistency/testdata/schema"

# A note on what an `extract` may pin, since most of the RPCs added for item E
# return documents far too large to put in a manifest.
#
# A case that pinned a whole `ast_json` would be a multi-megabyte line and a
# restatement of `hack/ast_diff.rb`, which already diffs that document across
# every binding against the same capture. What is left for a manifest to say is
# the thing the AST diff cannot: *shape and count*. "The parser produced a tree
# with four top-level statements and no errors" is a contract a binding breaks
# by dropping one field, and it is three integers rather than a document.
#
# So the extractors below project, and the manifest holds plain values. That
# keeps every runner's job the same shape it already has -- compare what the RPC
# returned against pinned JSON -- and needs no schema change to say it. Pinning
# the raw output is still right wherever the whole output *is* the contract:
# `generate_doc_md` and `generate_openapi_v3` do exactly that, and so does
# `get_schema_type_mapping`, whose document is ~250 bytes.


# The sources the cases below share, kept here rather than inline so the pin and
# the fixture cannot drift apart.

# One statement per construct the parse RPCs have to be able to attach: a
# schema, a config expression, a quantified comprehension and a plain
# assignment. Four top-level statements, which is the number `parse_file` and
# `parse_program` pin.
PARSE_SOURCE = """schema Person:
    name: str
    age?: int = 18

alice = Person {name = "Alice"}
nums = [i * 2 for i in [1, 2, 3]]
total = sum(nums)
"""

# Two `option()` calls, one optional and one required. `ListOptions` reports the
# option names and the required flag and nothing else -- the `type` and
# `default_value` fields come back empty for an untyped option, which is why
# neither is pinned: there is no difference between two bindings to catch.
OPTIONS_SOURCE = """a = option("key1")
b = option("key2", required=True)
"""

# A program whose top-level names are `a` and `b`, of two different types, for
# `ListVariables`. The dict one is a multi-line rendering of its value, so the
# pinned value text covers a string field, a nested structure and KCL's own
# indentation -- three things a binding gets wrong in different ways.
VARIABLES_SOURCE = """a = 1
b = {c = 2}
"""



def _scratch(name):
    """A path inside a template that a runner copies before calling.

    `scratch:<rest>` means: copy the directory `tests/consistency/testdata/<rest
    up to the first slash>` to a fresh writable location, and use `<copy>/<rest
    after the first slash>` as the path. So `scratch:override/main.k` names a
    file inside a copied tree and `scratch:lint` names the copied directory
    itself.

    The marker is what lets a runner recognise the cases that need a writable
    copy without a second list to keep in step, and it is why these cases are
    the only ones whose pinned result must not contain a path: the copy is
    somewhere different on every machine and under every runner's temp
    directory.
    """
    return f"scratch:{name}"


def _kcl_types(mapping):
    """A `map<string, KclType>` or `map<string, SchemaTypes>` as plain JSON.

    `KclType` is 18 fields and recursive through `union_types`, `properties`,
    `key`, `item` and `base_schema`, so a per-field projection would be a
    recursive walk written once per language -- exactly the kind of dispatch that
    agrees with itself and disagrees with the core. The canonical protobuf JSON
    of each value is the one representation all of them can reach, because
    producing it is part of decoding a protobuf message at all.

    Both of the two schema-mapping RPCs go through here, and they do not return
    the same thing: `GetSchemaTypeMapping` maps a schema name to one `KclType`,
    while `GetSchemaTypeMappingUnderPath` maps a *package* name to a
    `SchemaTypes` wrapper holding a list. The two shapes are the reason both
    cases exist -- a binding that ran one method's result through the other's
    message type is the failure neither case would catch alone.

    The round trip through `sort_keys=True` is load-bearing, not tidiness. Two
    of `KclType`'s fields are protobuf maps, and map iteration order is not
    defined -- regenerating the manifest without it produces a different file
    from identical input, and a golden file that churns is a golden file
    contributors learn to ignore. Sorting is done by going through JSON text
    rather than by sorting dicts in Python, because `KclType` nests: a
    top-level sort would leave `properties` and `examples` unordered one level
    down. A runner reproducing this sorts every object it emits at every depth,
    which is the same rule every language's map type already needs for its own
    output to be stable.

    The dialect is protobuf JSON's *default*: a field the core left unset is
    absent, not rendered as `""`, `0`, `[]`, `{}` or `null`. `MessageToDict` can
    be told to render unset fields too (`always_print_fields_with_no_presence`),
    and that was the first thing tried here, but it buys nothing a runner needs
    and costs every one of them a private serializer: Go's `protojson` has no
    equivalent flag, because `EmitUnpopulated` additionally renders unset
    *message* fields as `null` and leaving it off omits empty repeated and map
    fields, so Go matches neither way. Every protobuf runtime -- Python's
    `MessageToDict`, Go's `protojson`, Ruby's `to_json` -- already emits
    exactly this form by default, so the manifest is pinned to it and the other
    fourteen runners inherit it for free. Nothing observable is lost: a field
    one binding populates and another does not still shows up as a mismatch,
    because the expected document carries the key and the actual does not.
    """
    from google.protobuf.json_format import MessageToDict

    document = {
        name: MessageToDict(value, preserving_proto_field_name=True)
        for name, value in mapping.items()
    }
    return _without_local_paths(json.loads(json.dumps(document, sort_keys=True)))


# `KclType.filename` is the absolute path of the file a type was declared in, so
# it differs on every machine and under every runner. It is dropped at every
# depth: the top-level `KclType` carries one, and a schema's *properties* do not,
# so a one-level strip would be exactly the kind of rule that works until
# someone writes a schema inline. `pkg_path` is kept -- it is a KCL package path
# like `__main__`, not a filesystem one, and it is what makes the under-path
# result's outer key meaningful.
_LOCAL_PATH_FIELDS = ("filename",)


def _without_local_paths(node):
    if isinstance(node, dict):
        return {
            k: _without_local_paths(v) for k, v in node.items() if k not in _LOCAL_PATH_FIELDS
        }
    if isinstance(node, list):
        return [_without_local_paths(v) for v in node]
    return node


def _tree_shape(ast_json, errors, deps):
    """The part of a parse result that is a contract, as plain values.

    The document itself is not pinned: it is what `hack/ast_diff.rb` diffs
    across every binding against a capture that exercises every node shape,
    and a second copy of it here would test the same thing more slowly. What a
    manifest can add is the count of top-level statements and the absence of
    diagnostics, which is what a binding that decoded the tree but hung none
    of it off the result looks like.
    """
    return {
        "body_count": len(json.loads(ast_json)["body"]) if ast_json else 0,
        "error_count": len(errors),
        "deps": list(deps),
    }


def _main_package_modules(ast_json):
    """How many files `ParseProgram` put under the `__main__` package.

    `ParseProgramResult.ast_json` is a `pkgs` document, not a module: it holds
    one `Module` per file, keyed by package path. `ParseFile` returns a bare
    `Module` with a `body` at the top level instead. Reading the same JSON
    through both accessors is how a binding that decoded only one of the two
    shapes shows up -- one raises, the other reports zero -- so the two cases
    pin different numbers on purpose and neither number is a statement count.
    """
    return len(json.loads(ast_json)["pkgs"]["__main__"]) if ast_json else 0


def _semver(version):
    """A version reduced to its shape, so a release does not change the manifest.

    Only the first two components are kept, so a patch release does not churn
    the manifest while a major or minor one still does. Anything that is not
    dot-separated numbers becomes the empty string, which is a pin that fails
    loudly on a version the core actually changed rather than one a release tag
    merely moved.
    """
    parts = version.split(".")
    if len(parts) < 2 or not all(p.split("-")[0].isdigit() for p in parts[:2]):
        return ""
    return ".".join(parts[:2])


def build_cases():
    """Return the ordered case definitions.

    Each case is a dict:

        name    unique case name
        rpc     fully-qualified RPC name, e.g. "KclService.ExecProgram"
        new_core  True if the RPC only exists on cores that also expose the
                  Generate*/FormatTestReport RPCs; runners skip these when
                  the loaded core does not list the RPC.
        build_args(api_module) -> protobuf args message
        extract(result) -> dict of expect-field -> golden value (JSON-able)
    """
    cases = []

    def case(name, rpc, new_core, build_args, extract):
        cases.append(
            {
                "name": name,
                "rpc": rpc,
                "new_core": new_core,
                "build_args": build_args,
                "extract": extract,
            }
        )

    # 1. ping
    case(
        "ping",
        "KclService.Ping",
        False,
        lambda a: a.PingArgs(value="consistency"),
        lambda r: {"value": r.value},
    )

    # 2. exec_program_basic
    case(
        "exec_program_basic",
        "KclService.ExecProgram",
        False,
        lambda a: a.ExecProgramArgs(k_code_list=["alice = {age = 18}"]),
        lambda r: {"yaml_result": r.yaml_result, "json_result": r.json_result},
    )

    # 3. exec_program_overrides
    case(
        "exec_program_overrides",
        "KclService.ExecProgram",
        False,
        lambda a: a.ExecProgramArgs(
            k_code_list=["alice = {age = 1}"], overrides=["alice.age=18"]
        ),
        lambda r: {"yaml_result": r.yaml_result},
    )

    # 4. format_code
    case(
        "format_code",
        "KclService.FormatCode",
        False,
        lambda a: a.FormatCodeArgs(source="a=1\n"),
        lambda r: {"formatted": bytes(r.formatted).decode("utf-8")},
    )

    # 5. validate_code_ok
    case(
        "validate_code_ok",
        "KclService.ValidateCode",
        False,
        lambda a: a.ValidateCodeArgs(
            code=PERSON_SCHEMA, data='{"name": "Alice"}'
        ),
        lambda r: {"success": r.success, "err_message": r.err_message},
    )

    # 6. validate_code_invalid — a schema check that fails. The diagnostic text
    #    itself is not pinnable: it carries ANSI colour escapes, a random temp
    #    path and a temp filename, so every machine produces a different string.
    #    What is pinnable is that there *is* a diagnostic, which is what makes
    #    the case non-vacuous -- pinning only `success: false` would let a
    #    binding that returned an empty result pass.
    case(
        "validate_code_invalid",
        "KclService.ValidateCode",
        False,
        lambda a: a.ValidateCodeArgs(code=PERSON_SCHEMA, data='{"name": ""}'),
        lambda r: {"success": r.success, "has_error_message": bool(r.err_message)},
    )

    # 7. generate_kcl_json — key quoting, null->None, float rendering,
    #    empty-format inference from the filename extension.
    case(
        "generate_kcl_json",
        "KclService.GenerateKcl",
        True,
        lambda a: a.GenerateKclArgs(
            source='{"a": {"b": 1}, "c": [1, 2.5, true, null], "d-e": "x"}',
            filename="data.json",
            format="",
        ),
        lambda r: {"kcl": r.kcl},
    )

    # 8. generate_kcl_yaml
    case(
        "generate_kcl_yaml",
        "KclService.GenerateKcl",
        True,
        lambda a: a.GenerateKclArgs(
            source="a: 1\nb:\n  - x\n  - y\n",
            filename="data.yaml",
            format="",
        ),
        lambda r: {"kcl": r.kcl},
    )

    # 9. generate_toml
    case(
        "generate_toml",
        "KclService.GenerateToml",
        True,
        lambda a: a.GenerateTomlArgs(
            exec_args=a.ExecProgramArgs(
                k_code_list=[
                    'app = {name = "demo", ports = [80, 443], tls = {enabled = True}}'
                ]
            )
        ),
        lambda r: {"toml": r.toml},
    )

    # 10. format_test_report — µs->ms truncation, separator line and tallies.
    def build_format_test_report_args(a):
        def info(name, error, duration, log_message):
            return a.TestCaseInfo(
                name=name, error=error, duration=duration, log_message=log_message
            )

        return a.FormatTestReportArgs(
            result=a.TestResult(
                info=[
                    info("test_pass", "", 1500, ""),
                    info("test_log", "", 2500, "hello log"),
                    info("test_fail", "Error: assert failed", 1000, ""),
                ]
            )
        )

    case(
        "format_test_report",
        "KclService.FormatTestReport",
        True,
        build_format_test_report_args,
        lambda r: {"report": r.report},
    )

    # 11. generate_openapi_v3 — schema fixture: v3 document flavor, Base ref
    #    through allOf, native oneOf unions.
    case(
        "generate_openapi_v3",
        "KclService.GenerateOpenAPI",
        True,
        lambda a: a.GenerateOpenAPIArgs(
            parse_args=a.ParseProgramArgs(paths=[SCHEMA_FIXTURE]),
            version="v3",
        ),
        lambda r: {"spec": r.spec},
    )

    # 12. generate_proto — package clause, snake-cased fields, struct.proto
    #    import for union/any values.
    case(
        "generate_proto",
        "KclService.GenerateProto",
        True,
        lambda a: a.GenerateProtoArgs(
            parse_args=a.ParseProgramArgs(paths=[SCHEMA_FIXTURE]),
            package="example.v1",
        ),
        lambda r: {"proto": r.proto},
    )

    # 13. generate_doc_md — Markdown document flavor with the table header.
    case(
        "generate_doc_md",
        "KclService.GenerateDoc",
        True,
        lambda a: a.GenerateDocArgs(
            parse_args=a.ParseProgramArgs(paths=[SCHEMA_FIXTURE]),
            format="md",
        ),
        lambda r: {"content": r.content},
    )

    # 14. parse_file — inline source, so the case needs no file on disk and
    #     cannot be broken by someone editing a fixture. The projection is the
    #     statement count and the absence of errors and deps: a binding that
    #     decoded the tree but attached none of it reports zeros here.
    case(
        "parse_file",
        "KclService.ParseFile",
        False,
        lambda a: a.ParseFileArgs(source=PARSE_SOURCE, path="main.k"),
        lambda r: _tree_shape(r.ast_json, r.errors, r.deps),
    )

    # 15. parse_program — the same source through the program entry point, which
    #     wraps it in a `pkgs` document rather than returning a bare module. The
    #     two cases together are what catch a binding that implemented one
    #     accessor and reused it for both.
    case(
        "parse_program",
        "KclService.ParseProgram",
        False,
        lambda a: a.ParseProgramArgs(sources=[PARSE_SOURCE]),
        lambda r: {
            "module_count": _main_package_modules(r.ast_json),
            "error_count": len(r.errors),
            "paths": [os.path.basename(p) for p in r.paths],
        },
    )

    # 16. list_options — the two `option()` calls, by name and required flag.
    #     `type` and `default_value` come back empty for an untyped option, so
    #     there is nothing in them for two bindings to disagree about; the
    #     required flag is the one bool that is actually decided here.
    case(
        "list_options",
        "KclService.ListOptions",
        False,
        lambda a: a.ParseProgramArgs(sources=[OPTIONS_SOURCE]),
        lambda r: {
            "option_count": len(r.options),
            "options": sorted((o.name, o.required) for o in r.options),
        },
    )

    # 17. list_variables — the result is a map from *spec* to the value that
    #     spec resolves to, so the pinned projection is spec -> value text. This
    #     is the RPC an LSP completion provider calls, and it is the one whose
    #     result is a map inside a repeated field inside a message: three
    #     levels of nesting, each of which a binding can flatten to nothing.
    #
    #     `type_name` is not pinned because the core leaves it empty for a plain
    #     assignment, and an empty string is the same answer a binding that
    #     dropped the field would give.
    case(
        "list_variables",
        "KclService.ListVariables",
        False,
        lambda a: a.ListVariablesArgs(files=[VARIABLES_FIXTURE], specs=["a", "b"]),
        lambda r: {
            "values": {
                spec: [v.value for v in vl.variables]
                for spec, vl in sorted(r.variables.items())
            },
            "unsupported_codes": list(r.unsupported_codes),
            "parse_error_count": len(r.parse_errors),
        },
    )

    # 18. load_package — the package layout itself: which paths it found, that
    #     it reported no type or parse errors, and the size of the symbol and
    #     scope tables. The tables are not pinned, only counted: they are
    #     enormous and their contents are the core's, not the binding's.
    #     `resolve_ast=True` because without it both tables come back empty,
    #     which would make the counts a pin on a flag rather than on decoding.
    #     `kcl_mod`/`apps`/`imports` are the fields that go red on a binding
    #     built against an `kcl-api` older than CORE_REVISION, and that is
    #     deliberate: see the note beside it.
    case(
        "load_package",
        "KclService.LoadPackage",
        False,
        lambda a: a.LoadPackageArgs(
            parse_args=a.ParseProgramArgs(paths=[PKG_FIXTURE]), resolve_ast=True
        ),
        lambda r: {
            "path_count": len(r.paths),
            "type_error_count": len(r.type_errors),
            "parse_error_count": len(r.parse_errors),
            "symbol_count": len(r.symbols),
            "scope_count": len(r.scopes),
            "has_kcl_mod": r.kcl_mod is not None,
            "kcl_mod_name": r.kcl_mod.package.name if r.kcl_mod is not None else "",
            "app_count": len(r.apps),
            "import_count": len(r.imports),
        },
    )

    # 19. get_schema_type_mapping — the whole document, pinned as JSON. It is
    #     ~250 bytes, it is the entire point of the RPC, and the recursive
    #     `KclType` is 18 fields deep, so a per-field projection would be 18
    #     lines of dispatch a manifest edit could not catch.
    case(
        "get_schema_type_mapping",
        "KclService.GetSchemaTypeMapping",
        False,
        lambda a: a.GetSchemaTypeMappingArgs(
            exec_args=a.ExecProgramArgs(k_code_list=[PARSE_SOURCE]),
            schema_name="Person",
        ),
        lambda r: {"type_mapping": _kcl_types(r.schema_type_mapping)},
    )

    # 20. get_schema_type_mapping_under_path — the same schema, reached through
    #     the entry point that exists to keep a dependency's schemas under their
    #     own package (kcl#1546). Two properties make it worth its own case and
    #     they are both differences from case 19: it takes a *work dir* rather
    #     than inline source, and it returns a different result message. A
    #     binding that wired this method to the other one would produce case
    #     19's answer here, and neither case alone would notice.
    #
    #     `k_filename_list` is relative to `work_dir` because that is the only
    #     form that survives on another machine; the core rejects a `work_dir`
    #     with no file list outright.
    case(
        "get_schema_type_mapping_under_path",
        "KclService.GetSchemaTypeMappingUnderPath",
        False,
        lambda a: a.GetSchemaTypeMappingArgs(
            exec_args=a.ExecProgramArgs(
                work_dir=SCHEMA_PKG_FIXTURE, k_filename_list=["main.k"]
            ),
            schema_name="Person",
        ),
        lambda r: {"type_mapping": _kcl_types(r.schema_type_mapping)},
    )

    # 21. get_version — pinned as a *shape*, not as a string. The version moves
    #     with every release and pinning it would make the manifest a second
    #     place to update on every bump. What is a cross-language contract is
    #     that all four fields are populated and that the version is semver, and
    #     the four `has_*` flags are what a binding that returned an empty
    #     message looks like.
    case(
        "get_version",
        "KclService.GetVersion",
        False,
        lambda a: a.GetVersionArgs(),
        lambda r: {
            "version": _semver(r.version),
            "has_checksum": bool(r.checksum),
            "has_git_sha": bool(r.git_sha),
            "has_version_info": bool(r.version_info),
        },
    )

    # 22. list_method — the RPC surface, asserted structurally rather than by
    #     list. The list moves whenever the core gains an RPC, and a case that
    #     broke on that would train contributors to regenerate the manifest
    #     without reading it. What is pinned is that the two entry points a
    #     client discovers by name are present, that the two services are
    #     distinguishable, and that no name is empty -- the last of which is
    #     what a binding that decoded the repeated field but not its elements
    #     would look like.
    case(
        "list_method",
        "BuiltinService.ListMethod",
        False,
        lambda a: a.ListMethodArgs(),
        lambda r: {
            "has_kclservice_ping": "KclService.Ping" in r.method_name_list,
            "has_kclservice_parse_program": "KclService.ParseProgram" in r.method_name_list,
            "has_builtinservice_list_method": "BuiltinService.ListMethod" in r.method_name_list,
            "method_count": len(r.method_name_list),
            "has_empty_name": any(not n for n in r.method_name_list),
        },
    )

    # 23. lint_path_clean — a package the linter has nothing to say about. The
    #     message text is the linter's, so only the count is pinned, and zero is
    #     the whole assertion: a binding that dropped every result from a clean
    #     file reports the same thing, but one that dropped the field entirely
    #     does not, because an unset repeated field is also empty.
    case(
        "lint_path_clean",
        "KclService.LintPath",
        False,
        lambda a: a.LintPathArgs(paths=[PKG_FIXTURE]),
        lambda r: {"result_count": len(r.results)},
    )

    # 24. lint_path_with_errors — a file with one unused import. The presence of
    #     a result, not its wording, is the contract; the wording is the
    #     linter's and moves with the linter.
    case(
        "lint_path_with_errors",
        "KclService.LintPath",
        False,
        lambda a: a.LintPathArgs(paths=[_scratch("lint")]),
        lambda r: {"has_result": len(r.results) > 0},
    )

    # 25. format_path_dry_run — `dry_run` is the only mode of this RPC that
    #     touches nothing, and it is the mode a manifest can pin: the same file
    #     formatted twice must report the same changed set both times, so
    #     re-running the case is what proves the first run wrote nothing. The
    #     names are basenames because the paths are absolute and machine-local.
    case(
        "format_path_dry_run",
        "KclService.FormatPath",
        False,
        lambda a: a.FormatPathArgs(path=PKG_FIXTURE, dry_run=True),
        lambda r: {
            "changed_count": len(r.changed_paths),
            "changed": sorted(os.path.basename(p) for p in r.changed_paths),
        },
    )

    # 26. test_run — the tester's own result: one passing case, so the name is
    #     pinned and the error list is pinned empty. Durations are not pinned;
    #     they are wall-clock and would make the case fail at random.
    case(
        "test_run",
        "KclService.Test",
        False,
        lambda a: a.TestArgs(pkg_list=[PKG_FIXTURE]),
        lambda r: {
            "names": sorted(i.name for i in r.info),
            "failed": sorted(i.name for i in r.info if i.error),
        },
    )

    # 27. override_file — a spec override applied to a scratch copy. Scoped to
    #     `scratch:` so the case cannot write to the repository: the manifest
    #     names a template, each runner copies it somewhere writable, and the
    #     RPC's own answer is pinned rather than the path it landed in.
    #
    #     `result` is the only thing this RPC says, and it is worth pinning
    #     precisely because it does not mean "the file changed": it is true for
    #     a spec that rewrites the file and for one that sets it to the value it
    #     already had, and false only when `specs` is empty. So `true` is an
    #     assertion that the spec list reached the core at all, which is the
    #     failure mode worth catching -- a binding that dropped `specs` on the
    #     way through gets `false` and disagrees here.
    case(
        "override_file",
        "KclService.OverrideFile",
        False,
        lambda a: a.OverrideFileArgs(
            file=_scratch("override/main.k"), specs=["app.name=overridden"]
        ),
        lambda r: {
            "result": r.result,
            "parse_error_count": len(r.parse_errors),
        },
    )

    # 28. load_settings_files — one `kcl.yaml` holding both halves of the
    #     settings format. The `kcl_options` values are pinned JSON-encoded,
    #     because the loader parses each value as a KCL expression and renders
    #     the parsed form back: a binding that passed the raw YAML string
    #     through is exactly the bug this catches.
    #
    #     `work_dir` is a scratch reference too, not just `files`. The two have
    #     to be the same copy -- the loader resolves a settings file's own
    #     relative references against `work_dir` -- and pointing one at the
    #     repository and the other at a temp directory works today only because
    #     this fixture has no relative references to resolve.
    case(
        "load_settings_files",
        "KclService.LoadSettingsFiles",
        False,
        lambda a: a.LoadSettingsFilesArgs(
            work_dir=_scratch("settings"), files=[_scratch("settings/kcl.yaml")]
        ),
        lambda r: {
            "options": sorted((o.key, o.value) for o in r.kcl_options),
            "output": r.kcl_cli_configs.output,
            "overrides": list(r.kcl_cli_configs.overrides),
            "strict_range_check": r.kcl_cli_configs.strict_range_check,
            "verbose": r.kcl_cli_configs.verbose,
        },
    )

    # 29. update_dependencies_no_deps — a package whose manifest declares no
    #     dependencies, so the call resolves nothing and needs no network. The
    #     point is the empty list: a binding that returned the *manifest's*
    #     dependencies rather than the resolver's would return a non-empty one
    #     here, and a manifest that had to reach out to be exercised would not be
    #     a hermetic case at all.
    #
    #     `manifest_path` is named for a file but the core treats it as a
    #     package *root* and finds the `kcl.mod` itself; passing the manifest
    #     path raises "Not a directory". So this case passes the directory, and
    #     that is the form every runner has to use.
    case(
        "update_dependencies_no_deps",
        "KclService.UpdateDependencies",
        False,
        lambda a: a.UpdateDependenciesArgs(manifest_path=_scratch("update_dependencies")),
        lambda r: {"external_pkg_count": len(r.external_pkgs)},
    )
    return cases





# The two RPCs of the 27 that no case covers, and why.
#
# `spec.proto` declares 28 rpc lines over two services; 27 distinct methods are
# reachable through a client. The 28th, `BuiltinService.Ping`, is listed by the
# core's own `ListMethod` but rejected by every binding's dispatcher as an
# unknown method, so there is nothing for a runner to compare against.
#
# `Rename` and `RenameCode` are the two that are reachable and still not covered.
# On the core this manifest is generated against (v0.13.0) both resolve a symbol
# only through `select_symbol`, which walks attributes off the `__main__` scope
# of a package loaded from a VFS; no spelling of `symbol_path` this generator
# could construct produces a non-empty result, and most spellings raise
# `get symbol from symbol path failed` instead. Pinning "returns nothing" would
# pin a core bug, and a case that breaks the day the core is fixed is worse than
# no case: it fails in all thirteen runners for a reason that has nothing to do
# with them. They are listed here so the gap is a decision on the record rather
# than an oversight, and so a future version can add them by deleting two lines.
UNCOVERED_RPCS = {
    "BuiltinService.Ping": "listed by ListMethod but not dispatchable by any binding",
    "KclService.Rename": "core resolves no symbol path; see above",
    "KclService.RenameCode": "core resolves no symbol path; see above",
}


# The bindings must all run the same `kcl-api`, and this manifest is why that
# is enforced rather than assumed. `kcl-api` is a git dependency, so "which
# revision" is a choice: `ruby/Cargo.lock` pinned `931e6a9` and `c/Cargo.toml`
# pinned `rev = "842b02b"`, both of which predate the six RPCs added after
# `FormatTestReport` (`GenerateToml`, `GenerateKcl`, `GenerateOpenAPI`,
# `GenerateProto`, `GenerateDoc`, `FormatTestReport`). Every other binding
# resolved the branch head, which is what this manifest is generated against.
#
# So `list_method` pins `method_count` and `load_package` pins `kcl_mod`,
# `apps` and `imports`, and a runner built against either old pin fails both.
# That is the intent: these two cases are the ones that go red when a binding
# drifts off the shared core, which is otherwise a failure nobody notices until
# a user calls an RPC that binding cannot dispatch at all. The RPCs themselves
# are covered the softer way, through `new_core` and a skip, because an old
# core genuinely has no answer to give for them.
#
# If you bump `kcl-api` in one binding, run `cargo update -p kcl-api` in the
# rest and regenerate this file in the same commit. Do not widen the tolerance
# in the runners instead -- that is the failure mode this note exists to stop.
CORE_REVISION = "3ec296a910e811945b384f2958ab352f148b571a"

# Every field of every args message that holds a repo-relative or `scratch:`
# path, as (field name, kind). Hand-written rather than reflected over the
# descriptor because the reflection is the same in all thirteen languages and
# the runner needs a *table* it can port: a runner reads this list and rewrites
# those fields, it does not re-derive it.
#
# The kinds: `Path`/`Paths` are rewritten relative to the repository root,
# `ScratchPath`/`ScratchPaths` may additionally hold a `scratch:` reference and
# are the only ones a template is allowed in, `RelPaths` are resolved against the
# message's own `work_dir`, `Source` is a repeated field of KCL text rather than
# paths and is left alone, and `Nested` recurses into a sub-message. The five
# are not redundant with each other: marking only the `Scratch*` pair is what
# lets a `scratch:` reference in a field nobody declared fail loudly instead of
# being passed to the core as a literal filename, and `RelPaths` is the one kind
# whose base is not the repository root.
#
# `RelPaths` exists because `ExecProgramArgs.k_filename_list` is resolved
# against the *process* working directory by the core, not against `work_dir`
# beside it, so the manifest's repo-relative form has to be turned into
# work_dir-relative before it is turned into anything else. `kcl mod` documents
# the pair as `work_dir: ./src/testdata, k_filename_list: ["main.k"]`, which
# only holds when the caller happens to be in the package's parent.
PATH_FIELDS = {
    "ExecProgramArgs": [("work_dir", "Path"), ("k_filename_list", "RelPaths")],
    "ParseProgramArgs": [("paths", "Paths"), ("sources", "Source")],
    "GetSchemaTypeMappingArgs": [("exec_args", "Nested")],
    "LoadPackageArgs": [("parse_args", "Nested")],
    "LoadSettingsFilesArgs": [("work_dir", "ScratchPath"), ("files", "ScratchPaths")],
    "LintPathArgs": [("paths", "ScratchPaths")],
    "FormatPathArgs": [("path", "Path")],
    "OverrideFileArgs": [("file", "ScratchPath")],
    "UpdateDependenciesArgs": [("manifest_path", "ScratchPath")],
    "ListVariablesArgs": [("files", "Paths")],
    "TestArgs": [("pkg_list", "Paths")],
    "GenerateOpenAPIArgs": [("parse_args", "Nested")],
    "GenerateProtoArgs": [("parse_args", "Nested")],
    "GenerateDocArgs": [("parse_args", "Nested")],
}

SCRATCH_PREFIX = "scratch:"
TESTDATA = REPO_ROOT / "tests" / "consistency" / "testdata"


def _scratch_copy(rest):
    """Copy a `scratch:` template and return the path inside the copy.

    `scratch:a/b.k` means "the file b.k inside the template directory a". The
    copy goes to a fresh temporary directory so two cases -- or two runners --
    never see each other's writes, and so the repository is never the target of
    an RPC that rewrites files.
    """
    template, _, tail = rest.partition("/")
    src = TESTDATA / template
    if not src.is_dir():
        raise SystemExit(f"scratch template is not a directory: {src}")
    dest = Path(tempfile.mkdtemp(prefix="kcl-consistency-")) / template
    shutil.copytree(src, dest)
    return str(dest / tail) if tail else str(dest)


def _resolve_path(value, kind):
    """Turn one manifest path into a path the local core will accept."""
    if not value:
        return value
    if value.startswith(SCRATCH_PREFIX):
        if kind not in ("ScratchPath", "ScratchPaths"):
            raise SystemExit(
                f"{value!r} is a scratch reference in a field that is not declared "
                f"as one; add it to PATH_FIELDS as a Scratch* field"
            )
        return _scratch_copy(value[len(SCRATCH_PREFIX) :])
    if kind == "Source":
        return value
    return value if os.path.isabs(value) else str(REPO_ROOT / value)


def _resolve_args(args):
    """Resolve every declared path field of an args message, in place.

    The manifest keeps paths repo-relative and templates marked as `scratch:`
    so a case file means the same thing on a contributor's laptop, in CI and
    inside a runner's own temp directory. This is the one place that turns
    either form into something the core can open.
    """
    for field, kind in PATH_FIELDS.get(type(args).__name__, ()):
        if kind == "Source":
            continue
        if kind == "Nested":
            _resolve_args(getattr(args, field))
        elif kind == "RelPaths":
            base = getattr(args, "work_dir", "")
            values = getattr(args, field)
            values[:] = [os.path.join(base, v) if not os.path.isabs(v) else v for v in values]
        elif kind.endswith("Paths"):
            values = getattr(args, field)
            values[:] = [_resolve_path(v, kind) for v in values]
        else:
            setattr(args, field, _resolve_path(getattr(args, field), kind))
    return args


def main():
    cases = build_cases()
    # Before anything is called, so a table that has drifted reports the drift
    # rather than a KeyError from whichever case happened to run first.
    _check_coverage(cases)
    instance = api.API()
    manifest_cases = []
    for c in cases:
        args = c["build_args"](api)
        # Serialize the manifest args before resolving paths, so cases.json
        # stays machine-independent: it records the repo-relative form and the
        # `scratch:` marker, never a temporary directory.
        manifest_args = _args_to_json(args)
        result = _call(instance, c["rpc"], _resolve_args(args))
        manifest_cases.append(
            {
                "name": c["name"],
                "rpc": c["rpc"],
                "new_core": c["new_core"],
                "args": manifest_args,
                "expect": c["extract"](result),
            }
        )
    _check_not_vacuous(manifest_cases)
    manifest = {
        "version": 1,
        "generated_by": "tests/consistency/generate_cases.py",
        "cases": manifest_cases,
    }
    MANIFEST.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(
        f"wrote {MANIFEST} with {len(manifest_cases)} cases "
        f"covering {len({c['rpc'] for c in manifest_cases})} RPCs"
    )


# The cases whose pinned answer really is "nothing". A case here asserts an
# *absence* -- no lint results, no dependencies to resolve -- and a binding that
# dropped the field entirely reports the same thing, which is a real limit of
# what an empty result can prove. They are listed rather than detected, because
# a detector cannot tell "this case means empty" from "this case regressed into
# meaning empty", and the second is exactly the failure the check exists to
# catch. Any *new* all-falsy case has to be added here on purpose.
EMPTY_BY_DESIGN = {
    "lint_path_clean": "the linter has nothing to say about a clean package",
    "update_dependencies_no_deps": "a manifest with no dependencies resolves none",
}


def _check_not_vacuous(manifest_cases):
    """Fail if a case's whole expectation is falsy and it is not one of the two
    cases whose answer really is empty.

    A case that expects `{}`, `[]`, `""` and `0` passes against a binding that
    returned nothing at all, so it is not a test -- it is a line in a file that
    looks like a test. `hack/ast_diff.rb` guards the same failure the same way,
    with an expected object count; here the guard is per case, because the
    manifest has cases and that is the unit a runner reports on.
    """
    vacuous = {
        c["name"] for c in manifest_cases if not any(c["expect"].values())
    }
    unexplained = vacuous - set(EMPTY_BY_DESIGN)
    if unexplained:
        raise SystemExit(
            "these cases expect nothing at all, so they would pass against a "
            f"binding that returned an empty result: {sorted(unexplained)}.\n"
            "Fix the extractor, or add the case to EMPTY_BY_DESIGN if an empty "
            "answer is genuinely what it is asserting."
        )
    stale = set(EMPTY_BY_DESIGN) - vacuous
    if stale:
        raise SystemExit(
            f"EMPTY_BY_DESIGN names cases that no longer expect nothing: {sorted(stale)}"
        )


def _check_coverage(cases):
    """Fail if a case names an RPC the proto does not declare, or the reverse.

    A typo in an `rpc` string would otherwise produce a case that no runner can
    dispatch and that never fails, because there is no runner for it to fail in.
    This runs before any case executes, so the failure is this message rather
    than a `KeyError` from the method table, and it runs on every regeneration
    rather than only in CI.

    Three tables have to agree: the methods `spec.proto` declares, the
    attributes `kcl_lib.api.API` exposes, and the cases. The middle one is
    checked here rather than left to the first call because a method that no
    case reaches is exactly the thing a binding can quietly stop implementing.
    """
    declared = _declared_rpcs()
    covered = {c["rpc"] for c in cases}

    unknown = covered - declared
    if unknown:
        raise SystemExit(f"cases name RPCs that spec.proto does not declare: {unknown}")
    missing = declared - covered - set(UNCOVERED_RPCS)
    if missing:
        raise SystemExit(
            f"{len(missing)} declared RPC(s) have no case and are not in "
            f"UNCOVERED_RPCS: {sorted(missing)}"
        )
    stale = set(UNCOVERED_RPCS) - declared
    if stale:
        raise SystemExit(f"UNCOVERED_RPCS names RPCs that no longer exist: {stale}")
    unreachable = declared - set(_METHOD_ATTR) - set(UNCOVERED_RPCS)
    if unreachable:
        raise SystemExit(
            "these declared RPCs have no entry in _METHOD_ATTR, so no case can "
            f"call them: {sorted(unreachable)}"
        )
    undispatchable = set(_METHOD_ATTR) - declared
    if undispatchable:
        raise SystemExit(
            f"_METHOD_ATTR names RPCs that spec.proto does not declare: {sorted(undispatchable)}"
        )


def _declared_rpcs():
    """The `Service.Method` strings spec.proto declares, from its own text.

    Parsed rather than taken from a generated descriptor so the check has no
    dependency on the thing it is checking: a binding's protobuf runtime is
    built from the same `spec.proto`, so asking it which methods exist would be
    asking the thing under test to grade itself.
    """
    spec = (REPO_ROOT / "spec" / "spec.proto").read_text()
    return {
        f"{service}.{method}"
        for service, block in _service_blocks(spec)
        for method in _rpc_names(block)
    }


def _service_blocks(spec):
    """Yield (service name, body) for each `service X { ... }` in spec.proto."""
    name, inside, body = None, False, []
    for line in spec.splitlines():
        stripped = line.strip()
        if not inside and stripped.startswith("service "):
            name, inside, body = stripped.split()[1].rstrip("{").strip(), True, []
        elif inside and stripped == "}":
            yield name, "\n".join(body)
            inside = False
        elif inside:
            body.append(line)


def _rpc_names(block):
    """The method names in one service block, without the argument list.

    `rpc Rename(RenameArgs) returns (RenameResult);` -> `Rename`. Splitting on
    the open paren rather than taking a fixed token index keeps it right if the
    argument is ever a multi-word or a qualified name.
    """
    return [
        line.strip().split()[1].split("(")[0]
        for line in block.splitlines()
        if line.strip().startswith("rpc ")
    ]


# The proto method name a case is written against -> the snake_case attribute
# `kcl_lib.api.API` exposes for it. Kept as an explicit table rather than
# derived by lowercasing: the four names where the two differ (GenerateKcl ->
# generate_kcl, and the three that are not KclService methods at all) are
# exactly the ones a naive rule would get wrong, so a table makes the
# exceptions visible instead of hiding them behind a regex. `_check_coverage`
# fails if spec.proto grows a method this table does not name.
_METHOD_ATTR = {
    "KclService.Ping": "ping",
    "KclService.ExecProgram": "exec_program",
    "KclService.ParseFile": "parse_file",
    "KclService.ParseProgram": "parse_program",
    "KclService.ListOptions": "list_options",
    "KclService.ListVariables": "list_variables",
    "KclService.LoadPackage": "load_package",
    "KclService.FormatCode": "format_code",
    "KclService.FormatPath": "format_path",
    "KclService.LintPath": "lint_path",
    "KclService.OverrideFile": "override_file",
    "KclService.GetSchemaTypeMapping": "get_schema_type_mapping",
    "KclService.GetSchemaTypeMappingUnderPath": "get_schema_type_mapping_under_path",
    "KclService.ValidateCode": "validate_code",
    "KclService.LoadSettingsFiles": "load_settings_files",
    "KclService.Rename": "rename",
    "KclService.RenameCode": "rename_code",
    "KclService.Test": "test",
    "KclService.FormatTestReport": "format_test_report",
    "KclService.GenerateToml": "generate_toml",
    "KclService.GenerateKcl": "generate_kcl",
    "KclService.GenerateOpenAPI": "generate_openapi",
    "KclService.GenerateProto": "generate_proto",
    "KclService.GenerateDoc": "generate_doc",
    "KclService.UpdateDependencies": "update_dependencies",
    "KclService.GetVersion": "get_version",
    "BuiltinService.ListMethod": "list_method",
}

# `get_version` and `list_method` take no Python argument even though the
# universal dispatcher still needs an encoded payload for them, so the service
# methods build the empty message themselves.
_NO_ARG_METHODS = {"get_version", "list_method"}


def _call(instance, rpc, args):
    method = _METHOD_ATTR[rpc]
    fn = getattr(instance, method)
    return fn() if method in _NO_ARG_METHODS else fn(args)


def _args_to_json(args):
    # The same dialect as `_kcl_types`: default protobuf JSON, so a field the
    # default builder left unset stays out of the manifest instead of being
    # written out as an explicit default. It also keeps the manifest readable --
    # `generate_toml`'s args are otherwise forty lines of defaults that say
    # nothing.
    from google.protobuf.json_format import MessageToDict

    return MessageToDict(args, preserving_proto_field_name=True)


if __name__ == "__main__":
    main()

