# End-to-end tests for the KclLib Julia binding.
#
# Run from the julia/ directory with `make test` (or `Pkg.test()`). Fixtures
# live in ../test_data (copied from python/tests/test_data).

using Test
using KclLib

const TEST_DATA = abspath(joinpath(@__DIR__, "..", "test_data"))
const SCHEMA_K = joinpath(TEST_DATA, "schema.k")

# ghcr.io rate limiting and transient network failures surface as registry /
# fetch errors from the OCI client; genuine kcl.mod mistakes must still fail.
function _is_registry_flake(message::AbstractString)::Bool
    return occursin(r"Registry error|rate.?limit|429|too many requests|failed to (fetch|download|resolve)|connection (refused|reset)|timeout|i/o timeout"i, message)
end

@testset "KclLib" begin

    @testset "libkcl is resolvable" begin
        @test isfile(KclLib.LibKcl.lib_path())
    end

    @testset "ping" begin
        result = ping(PingArgs(value="Hello, KCL!"))
        @test result.value == "Hello, KCL!"
    end

    @testset "get_version" begin
        result = get_version()
        @test !isempty(result.version)
        @test occursin("Version", result.version_info)
        @test occursin("GitCommit", result.version_info)
    end

    @testset "exec_program" begin
        result = exec_program(ExecProgramArgs(k_filename_list=[SCHEMA_K]))
        @test result.err_message == ""
        @test result.yaml_result == "app:\n  replicas: 2"
        @test occursin("\"app\"", result.json_result)

        inline = exec_program(ExecProgramArgs(k_code_list=["alice = {age = 18}"]))
        @test inline.err_message == ""
        @test occursin("age: 18", inline.yaml_result)
    end

    @testset "exec_program error raises KclError" begin
        err = try
            exec_program(ExecProgramArgs(k_filename_list=["file_not_found"]))
            nothing
        catch e
            e
        end
        @test err isa KclError
        @test occursin("Cannot find the kcl file", err.message)
    end

    # The facade entry points live at KclLib.run/run_files/must_run: `run` in
    # particular is deliberately not exported because Base.run owns the name.
    @testset "facade: run with inline code" begin
        result = KclLib.run(code="a = 1")
        @test result isa KCLResult
        @test yaml_string(result) == "a: 1"
        @test occursin("\"a\": 1", json_string(result))
        @test to_dict(result)["a"] == 1
        @test get(result, "a") == 1
    end

    @testset "facade: dotted-path get" begin
        result = KclLib.run(code="a = {b = {c = 42, msg = \"hi\"}}")
        @test get(result, "a.b.c") == 42
        @test get(result, "a.b.msg") == "hi"
        @test get(result, "a.b") == Dict("c" => 42, "msg" => "hi")
        @test get(result, "a.x.y") === nothing
        @test get(result, "a.x", "fallback") == "fallback"
        @test get(result, "", 7) == 7
    end

    @testset "facade: run_files" begin
        mktempdir() do dir
            file = joinpath(dir, "main.k")
            write(file, "app = {replicas = 2}\n")
            result = KclLib.run_files([file])
            @test yaml_string(result) == "app:\n  replicas: 2"
            @test get(result, "app.replicas") == 2
        end
    end

    @testset "facade: overrides, args and path_selector" begin
        overridden = KclLib.run(code="a = 1", overrides=["a=2"])
        @test get(overridden, "a") == 2

        with_option = KclLib.run(code="env = option(\"env\")", args=["env=prod"])
        @test get(with_option, "env") == "prod"

        with_argument_objs = KclLib.run(code="env = option(\"env\")", args=[Argument(name="env", value="dev")])
        @test get(with_argument_objs, "env") == "dev"

        selected = KclLib.run(code="a = {b = 1}\nc = 2", path_selector=["a"])
        @test get(selected, "b") == 1
        @test get(selected, "c") === nothing
    end

    @testset "facade: run without code or files raises" begin
        @test_throws ArgumentError KclLib.run()
        @test_throws ArgumentError KclLib.run_files(String[]; overrides=["a=1"])
    end

    @testset "facade: run error raises KclError" begin
        err = try
            KclLib.run(code="a = = 1")
            nothing
        catch e
            e
        end
        @test err isa KclError
        @test !isempty(err.message)

        @test_throws KclError KclLib.run(code="a = = 1")
    end

    @testset "facade: must_run" begin
        result = KclLib.must_run(code="a = 1")
        @test result isa KCLResult
        @test get(result, "a") == 1

        mktempdir() do dir
            file = joinpath(dir, "main.k")
            write(file, "b = 2\n")
            from_file = KclLib.must_run([file])
            @test yaml_string(from_file) == "b: 2"
            single = KclLib.must_run(file)
            @test get(single, "b") == 2
        end

        @test_throws KclError KclLib.must_run(code="a = = 1")
    end

    @testset "facade: validate_code" begin
        schema = "schema Person:\n    name: str\n    age: int\n\n    check:\n        0 < age < 120\n"
        @test validate_code("{\"name\": \"Alice\", \"age\": 10}", schema; format="json")
        @test !validate_code("{\"name\": \"Alice\", \"age\": 1110}", schema; format="json")
    end

    @testset "parse_program" begin
        result = parse_program(ParseProgramArgs(paths=[SCHEMA_K]))
        @test length(result.paths) == 1
        @test isempty(result.errors)
        @test !isempty(result.ast_json)
    end

    @testset "parse_file" begin
        result = parse_file(ParseFileArgs(path=SCHEMA_K))
        @test isempty(result.deps)
        @test isempty(result.errors)
        @test !isempty(result.ast_json)
    end

    @testset "load_package" begin
        result = load_package(LoadPackageArgs(
            parse_args=ParseProgramArgs(paths=[SCHEMA_K]),
            resolve_ast=true,
        ))
        @test isempty(result.parse_errors)
        @test isempty(result.type_errors)
        @test occursin("AppConfig", result.program)
        syms = collect(values(result.symbols))
        @test any(s -> s.ty.schema_name == "AppConfig", syms)
    end

    @testset "list_options" begin
        result = list_options(ParseProgramArgs(paths=[joinpath(TEST_DATA, "option", "main.k")]))
        @test length(result.options) == 3
        @test result.options[1].name == "key1"
        @test result.options[2].name == "key2"
        @test result.options[3].name == "metadata-key"
    end

    @testset "list_variables" begin
        result = list_variables(ListVariablesArgs(files=[SCHEMA_K]))
        @test isempty(result.parse_errors)
        @test result.variables["app"].variables[1].value == "AppConfig {\n    replicas: 2\n}"
    end

    @testset "override_file" begin
        mktempdir() do dir
            file = joinpath(dir, "main.k")
            write(file, read(joinpath(TEST_DATA, "override_file", "main.bak")))
            result = override_file(OverrideFileArgs(file=file, specs=["b.a=2"]))
            @test result.result
            @test isempty(result.parse_errors)
            @test read(file, String) == "a = 1\nb = {\n    \"a\": 2\n    \"b\": 2\n}\n"
        end
    end

    @testset "get_schema_type_mapping" begin
        result = get_schema_type_mapping(GetSchemaTypeMappingArgs(
            exec_args=ExecProgramArgs(k_filename_list=[SCHEMA_K]),
        ))
        app = result.schema_type_mapping["app"]
        @test app.properties["replicas"].type_ == "int"
        @test app.properties["my_func"].type_ == "function"
        maps = app.properties["maps"]
        @test maps.type_ == "schema"
        @test maps.index_signature.key_name == "name"
        @test maps.index_signature.key.type_ == "str"
        @test maps.index_signature.val.type_ == "schema"
        @test maps.index_signature.val.properties["name"].type_ == "str"
    end

    @testset "get_schema_type_mapping_under_path" begin
        root = joinpath(TEST_DATA, "get_schema_ty_under_path")
        result = get_schema_type_mapping_under_path(GetSchemaTypeMappingArgs(
            exec_args=ExecProgramArgs(
                k_filename_list=[joinpath(root, "aaa")],
                external_pkgs=[ExternalPkg(pkg_name="bbb", pkg_path=joinpath(root, "bbb"))],
            ),
        ))
        @test haskey(result.schema_type_mapping, "__main__")
        @test haskey(result.schema_type_mapping, "bbb")
        bbb = Dict(s.schema_name => s for s in result.schema_type_mapping["bbb"].schema_type)
        @test haskey(bbb, "Base")
        @test haskey(bbb, "B")
        @test bbb["Base"].pkg_path == "bbb"
        @test bbb["B"].pkg_path == "bbb"
        @test bbb["B"].base_schema.schema_name == "Base"
        @test bbb["B"].base_schema.pkg_path == "bbb"
    end

    @testset "format_code" begin
        source = "schema Person:\n    name:   str\n    age:    int\n\n    check:\n        0 <   age <   120\n"
        result = format_code(FormatCodeArgs(source=source))
        # `formatted` is the proto `bytes` field, i.e. a Vector{UInt8}.
        @test String(result.formatted) ==
            "schema Person:\n    name: str\n    age: int\n\n    check:\n        0 < age < 120\n"
    end

    @testset "format_path" begin
        mktempdir() do dir
            file = joinpath(dir, "test.k")
            write(file, "a=1\n")
            result = format_path(FormatPathArgs(path=file))
            @test length(result.changed_paths) == 1
            @test endswith(result.changed_paths[1], "test.k")
            @test occursin("a = 1", read(file, String))
        end
    end

    @testset "lint_path" begin
        result = lint_path(LintPathArgs(paths=[joinpath(TEST_DATA, "lint_path", "test-lint.k")]))
        @test any(msg -> occursin("imported but unused", msg), result.results)
    end

    @testset "validate_code" begin
        code = "schema Person:\n    name: str\n    age: int\n\n    check:\n        0 < age < 120\n"
        ok = validate_code(ValidateCodeArgs(
            code=code, data="{\"name\": \"Alice\", \"age\": 10}", format="json"))
        @test ok.success
        @test ok.err_message == ""

        bad = validate_code(ValidateCodeArgs(
            code=code, data="{\"name\": \"Alice\", \"age\": 1110}", format="json"))
        @test !bad.success
        @test !isempty(bad.err_message)
    end

    @testset "load_settings_files" begin
        result = load_settings_files(LoadSettingsFilesArgs(
            work_dir=TEST_DATA,
            files=[joinpath(TEST_DATA, "settings", "kcl.yaml")],
        ))
        @test result.kcl_cli_configs.strict_range_check
        @test length(result.kcl_options) == 1
        @test result.kcl_options[1].key == "key"
        @test occursin("value", result.kcl_options[1].value)
    end

    @testset "rename" begin
        mktempdir() do dir
            file = joinpath(dir, "main.k")
            write(file, read(joinpath(TEST_DATA, "rename", "main.bak")))
            result = rename(RenameArgs(
                package_root=dir,
                symbol_path="a",
                file_paths=[file],
                new_name="a2",
            ))
            @test length(result.changed_files) == 1
            @test endswith(result.changed_files[1], "main.k")
            content = read(file, String)
            @test occursin("a2 = 1", content)
            @test occursin("b = a2", content)
        end
    end

    @testset "rename_code" begin
        result = rename_code(RenameCodeArgs(
            package_root="/mock/path",
            symbol_path="a",
            source_codes=Dict("/mock/path/main.k" => "a = 1\nb = a"),
            new_name="a2",
        ))
        @test result.changed_codes["/mock/path/main.k"] == "a2 = 1\nb = a2"
    end

    @testset "test" begin
        result = test(TestArgs(pkg_list=[joinpath(TEST_DATA, "testing", "module", "...")]))
        @test length(result.info) == 2
        @test all(info -> info.error == "", result.info)
    end

    @testset "test with coverage" begin
        result = test(TestArgs(
            pkg_list=[joinpath(TEST_DATA, "testing", "module", "...")],
            coverage=true,
        ))
        @test length(result.info) == 2
        # Coverage collection was added to the runtime after the prebuilt
        # libkcl v0.13.0 binary; only assert the report when the runtime
        # emits one, but the call itself must always succeed.
        if result.coverage !== nothing
            @test !isempty(result.coverage.files)
            @test result.coverage.summary.executable > 0
        end
    end

    @testset "format_test_report" begin
        result = test(TestArgs(pkg_list=[joinpath(TEST_DATA, "testing", "module", "...")]))
        report = format_test_report(FormatTestReportArgs(result))
        # FormatTestReport landed in the runtime after the prebuilt libkcl
        # v0.13.0 binary, whose dispatcher answers with an empty payload;
        # accept that and only assert the report format when the runtime
        # actually formats one.
        if !isempty(report.report)
            @test endswith(report.report, "\n")
            @test occursin("PASS: 2/2", report.report)
            @test count(==('-'), report.report) >= 80
        end
    end

    @testset "update_dependencies (dependency-free module)" begin
        mktempdir() do dir
            write(joinpath(dir, "kcl.mod"), "[package]\nname = \"tmp_mod\"\nedition = \"0.0.1\"\nversion = \"0.0.1\"\n")
            result = update_dependencies(UpdateDependenciesArgs(manifest_path=dir))
            @test isempty(result.external_pkgs)
        end
    end

    @testset "update_dependencies (oci + git deps)" begin
        # Pulling ghcr.io/kcl-lang/helloworld is rate-limited in CI; a
        # registry flake must skip, not fail (mirrors the other bindings'
        # update_dependencies_or_skip helper).
        result = try
            update_dependencies(UpdateDependenciesArgs(
                manifest_path=joinpath(TEST_DATA, "update_dependencies")))
        catch e
            if e isa KclError && _is_registry_flake(e.message)
                @test_skip "ghcr.io registry rate limit: $(first(split(e.message, '\n')))"
                nothing
            else
                rethrow()
            end
        end
        if result !== nothing
            pkg_names = [pkg.pkg_name for pkg in result.external_pkgs]
            @test length(pkg_names) == 2
            @test "helloworld" in pkg_names
            @test "flask" in pkg_names
        end
    end

    @testset "list_method (dispatches to BuiltinService)" begin
        # Routed through BuiltinService.ListMethod: the core registers it
        # there, not under KclService. Assert unconditionally — an empty table
        # means the wrapper picked the wrong service name again, which is
        # exactly the bug this pins down.
        result = list_method()
        @test "KclService.ExecProgram" in result.method_name_list
        @test "KclService.Ping" in result.method_name_list
        @test "BuiltinService.ListMethod" in result.method_name_list
    end

    @testset "raw call escape hatch" begin
        # Hand-encoded PingArgs{value: "hello-kcl"}: field 1, 9-byte string.
        raw = KclLib.call("KclService.Ping", UInt8[0x0a, 0x09, UInt8.(collect("hello-kcl"))...])
        @test startswith(String(raw), "\x0a\x09hello-kcl")

        # The escape hatch shares the ERROR: convention with the wrappers.
        # Hand-encoded ExecProgramArgs{k_filename_list: ["file_not_found"]}:
        # field 2 (repeated string), 14-byte value.
        payload = UInt8[0x12, 0x0e, UInt8.(collect("file_not_found"))...]
        err = try
            KclLib.call("KclService.ExecProgram", payload)
            nothing
        catch e
            e
        end
        @test err isa KclError
        @test occursin("Cannot find the kcl file", err.message)
    end

    @testset "plugins" begin
        # A method that ignores its arguments needs no JSON parser at all: the
        # result is handed back as raw JSON.
        KclLib.register_plugin("strings", "join", (args, kwargs) -> "\"KCL.KCL.123\"")
        @test has_plugins()
        @test plugin_registered("strings", "join")
        @test !plugin_registered("strings", "missing")

        result = KclLib.run(code = "import kcl_plugin.strings\nresult = strings.join(\"KCL\", \"KCL\", 123)\n")
        @test get(result, "result") == "KCL.KCL.123"
    end

    @testset "plugin arguments arrive as JSON" begin
        seen = Ref{Any}(nothing)
        KclLib.register_plugin("strings", "args", function (args, kwargs)
            seen[] = (args, kwargs)
            # Re-emitting the raw JSON is enough — the runtime decodes it, so
            # the KCL side sees a real list and a real dict.
            return "{\"args\":" * args * ",\"kwargs\":" * kwargs * "}"
        end)

        result = KclLib.run(code = "import kcl_plugin.strings\nresult = strings.args(\"a\", b = 2)\n")
        @test seen[][1] == "[\"a\"]"
        @test seen[][2] == "{\"b\": 2}"
        @test get(result, "result.args") == ["a"]
        @test get(result, "result.kwargs.b") == 2
    end

    @testset "an unknown plugin method is a KCL diagnostic, not a crash" begin
        KclLib.register_plugin("strings", "join", (args, kwargs) -> "\"unused\"")
        err = try
            KclLib.run(code = "import kcl_plugin.strings\nresult = strings.nope()\n")
            nothing
        catch e
            e
        end
        @test err isa KclError
        @test occursin("nope", err.message)
    end

    @testset "a throwing plugin method is a KCL diagnostic" begin
        KclLib.register_plugin("strings", "boom", (args, kwargs) -> error("boom went off"))
        err = try
            KclLib.run(code = "import kcl_plugin.strings\nresult = strings.boom()\n")
            nothing
        catch e
            e
        end
        @test err isa KclError
        @test occursin("boom went off", err.message)
    end

    @testset "evaluation still works after disable_plugins" begin
        KclLib.register_plugin("strings", "join", (args, kwargs) -> error("must not be called"))
        disable_plugins()
        @test !has_plugins()
        @test !plugin_registered("strings", "join")
        @test get(KclLib.run(code = "a = 1\n"), "a") == 1
    end
end

# ---------------------------------------------------------------------------
# Typed AST. The same fixture the Python, Node.js, .NET, WASM, C, C++, Lua,
# Zig and Dart bindings use, so the bindings stay comparable.
#
# The point of these tests is the *shape*: which nodes carry a `type`
# discriminator, which arrive untagged, and what the `Type` enum actually
# serializes to. Those are the details every binding has to get right and the
# ones most easily guessed wrong, so they are pinned here.
# ---------------------------------------------------------------------------

const AST_FIXTURE = """
type StrOrInt = str | int

schema Person:
    \"\"\"A person.\"\"\"

    @deprecated
    name: str = "anonymous"

    age: int = 0

    check:
        age >= 0 if age, "age must be non-negative"

x = Person {name = "Alice", age = 30}
adder = lambda a: int, b: int -> int {
    a + b
}
nums = [i * 2 for i in range(10) if i > 2]
greeting = "hi \${x.name}"
s: str = "a"
s += "b"
if s:
    y = 1
"""

# An `import` of a package that is not on disk. `parse_file` still produces the
# AST node for it, which is what this fixture is for.
const AST_IMPORT_FIXTURE = "import pkg1\n\na = 1\n"

function _ast_module()
    result = parse_file(ParseFileArgs(path = "main.k", source = AST_FIXTURE))
    @test isempty(result.errors)
    return parse_module(result.ast_json)
end

"""The first top-level statement of type `T`, or `nothing`."""
function _find_stmt(f::Type{T}, m) where {T <: KclStmt}
    for ref in m.body
        ref.node isa T && return ref.node
    end
    return nothing
end

"""The named schema attribute of the `Person` schema in the fixture."""
function _person_attr(m, attr_name::AbstractString)
    person = _find_stmt(SchemaStmt, m)
    person === nothing && error("fixture has no schema")
    for ref in person.body
        a = ref.node
        a isa SchemaAttr && a.name !== nothing && a.name.node == attr_name && return a
    end
    error("fixture has no attribute named $attr_name")
end

"""The value assigned to the top-level variable `name`."""
function _assigned_value(m, name::AbstractString)
    for ref in m.body
        s = ref.node
        s isa AssignStmt || continue
        first(s.targets) === nothing && continue
        t = first(s.targets).node
        t.name !== nothing && t.name.node == name && return s.value
    end
    error("fixture assigns nothing named $name")
end

@testset "AST" begin

    @testset "module filename and no pkg" begin
        m = _ast_module()
        @test endswith(m.filename, "main.k")
        @test !isempty(m.body)
        # The Rust `Module` struct has no `pkg` field; the Java and Go bindings
        # used to expose one and were aligned to drop it.
        @test !occursin("pkg", sprint(show, m))
    end

    @testset "every node carries its source position" begin
        m = _ast_module()
        for ref in m.body
            @test ref.pos !== nothing
            @test ref.pos.filename == "main.k"
        end
        schema_ref = first(filter(r -> r.node isa SchemaStmt, m.body))
        @test schema_ref.pos.line == 3
        @test _find_stmt(SchemaStmt, m).name.node == "Person"
    end

    @testset "Type is tagged with the payload in value" begin
        # This is the shape that differs from what most other bindings assume.
        # `ast::Type` is `#[serde(tag = "type", content = "value")]` and
        # `BasicType` is a fieldless enum, so a basic type serializes as
        # {"type": "Basic", "value": "Int"} - NOT {"type": "Int"}.
        ty = _person_attr(_ast_module(), "name").ty.node
        @test ty isa BasicType
        @test ty.name == "Str"
    end

    @testset "union type lists its elements under type_elements" begin
        alias = _find_stmt(TypeAliasStmt, _ast_module())
        @test alias.type_name.node.names[1].node == "StrOrInt"
        ty = alias.ty.node
        @test ty isa UnionType
        members = [t.node for t in ty.types]
        @test length(members) == 2
        @test all(m -> m isa BasicType, members)
        @test Set(m.name for m in members) == Set(["Str", "Int"])
    end

    @testset "schema decorators decode to untagged Decorator" begin
        # `SchemaAttr.decorators` is `Vec<NodeRef<CallExpr>>` and only the
        # `Expr` enum is `#[serde(tag = "type")]`, so a decorator arrives as a
        # bare {func, args, keywords} object with no discriminator. The Java
        # binding gives that untagged shape its own name, and so does this one.
        name = _person_attr(_ast_module(), "name")
        @test length(name.decorators) == 1
        deco = name.decorators[1].node
        @test deco isa Decorator
        @test deco.func.node isa IdentifierExpr
        @test deco.func.node.identifier.names[1].node == "deprecated"
    end

    @testset "schema checks decode to CheckExpr, the untagged struct" begin
        person = _find_stmt(SchemaStmt, _ast_module())
        @test length(person.checks) == 1
        check = person.checks[1].node
        # `CheckExpr` is a plain struct, so a `check:` body arrives untagged.
        # The `Expr::Check` variant is that same struct, so one type serves
        # both — which is also how the Java binding draws it.
        @test check isa CheckExpr
        @test check isa KclExpr
        @test check.test.node isa Compare
        @test check.test.node.ops == ["GtE"]
        @test check.if_cond.node isa IdentifierExpr
        @test check.msg.node isa StringLit
        @test check.msg.node.value == "age must be non-negative"
    end

    @testset "is_optional and doc survive on a schema attribute" begin
        m = _ast_module()
        age = _person_attr(m, "age")
        @test age.is_optional == false
        @test age.doc == ""
        # `SchemaAttr.ty` is a non-optional NodeRef<Type> in Rust.
        @test age.ty !== nothing
    end

    @testset "number literal carries a nested tagged value" begin
        # NumberLit.value is a `NumberLitValue`, itself tagged
        # `#[serde(tag = "type", content = "value")]` - so `0` arrives as
        # {"type": "Int", "value": 0}.
        lit = _person_attr(_ast_module(), "age").value.node
        @test lit isa NumberLit
        @test lit.value_tag == "Int"
        @test lit.value == 0
        @test lit.binary_suffix === nothing
    end

    @testset "config entries round-trip operation and shorthand" begin
        schema_expr = _assigned_value(_ast_module(), "x").node
        @test schema_expr isa SchemaExpr
        # SchemaExpr.name is a NodeRef<Identifier>, not an expression.
        @test schema_expr.name.node.names[1].node == "Person"

        config = schema_expr.config.node
        @test config isa ConfigExpr
        @test length(config.items) == 2
        for item in config.items
            @test item.node.key.node isa IdentifierExpr
            # `ConfigEntryOperation` is Union | Override | Insert. A plain
            # `{name = ...}` inside a schema instantiation is an Override; the
            # Union form comes from a `<<>>`-style merge.
            @test item.node.operation == "Override"
            # `skip_serializing_if = "is_false"` - absent on the wire, so false.
            @test item.node.is_shorthand == false
        end
    end

    @testset "lambda args are untagged identifiers with aligned lists" begin
        args = _assigned_value(_ast_module(), "adder").node.args.node
        @test length(args.args) == 2
        @test [a.node.names[1].node for a in args.args] == ["a", "b"]
        # `defaults` and `ty_list` are Vec<Option<...>> - same length as args.
        @test length(args.defaults) == 2
        @test all(isnothing, args.defaults)
        @test [t.node.name for t in args.ty_list] == ["Int", "Int"]
    end

    @testset "lambda body holds statements, not expressions" begin
        lambda = _assigned_value(_ast_module(), "adder").node
        @test lambda isa LambdaExpr
        @test length(lambda.body) == 1
        @test lambda.body[1].node isa ExprStmt
        binary = lambda.body[1].node.exprs[1].node
        @test binary isa BinaryExpr
        @test binary.op == "Add"
    end

    @testset "list comprehension decodes its CompClause" begin
        comp = _assigned_value(_ast_module(), "nums").node
        @test comp isa ListComp
        @test length(comp.generators) == 1
        # targets is a Vec<NodeRef<Identifier>> - untagged, like Arguments.args.
        gen = comp.generators[1].node
        @test length(gen.targets) == 1
        @test gen.targets[1].node.names[1].node == "i"
        @test length(gen.ifs) == 1
        @test gen.ifs[1].node isa Compare
    end

    @testset "import is flat, with path and asname as positioned strings" begin
        # `ImportStmt` is a flat struct: `path` and `asname` are `Node<String>`
        # with their own positions, while `rawpath`, `name` and `pkg_name` are
        # plain strings on the same node. Older bindings read them from a
        # nested `node` object, which the parser does not emit.
        m = parse_module(parse_file(ParseFileArgs(
            path = "main.k", source = AST_IMPORT_FIXTURE)).ast_json)
        imp = _find_stmt(ImportStmt, m)
        @test imp.rawpath == "pkg1"
        @test imp.name == "pkg1"
        @test imp.pkg_name == "__main__"
        @test imp.path !== nothing
        @test imp.path.pos !== nothing
        @test imp.as_name === nothing
    end

    @testset "aug-assign, if-statement and f-string" begin
        m = _ast_module()
        aug = _find_stmt(AugAssignStmt, m)
        @test aug.op == "Add"
        @test aug.target.node.name.node == "s"

        if_stmt = _find_stmt(IfStmt, m)
        @test if_stmt.cond !== nothing
        @test length(if_stmt.body) == 1

        joined = _assigned_value(m, "greeting").node
        @test joined isa JoinedString
        @test !isempty(joined.values)
    end

    @testset "an unknown tag degrades to a readable node" begin
        m = parse_module("{\"filename\":\"a.k\",\"body\":[{\"node\":{\"type\":\"Nope\"}}]}")
        @test m.body[1].node isa UnknownStmt
        @test node_type(m.body[1].node) == "Nope"
    end

    @testset "parse_program_ast returns a list of modules" begin
        result = parse_program(ParseProgramArgs(sources = [AST_FIXTURE]))
        @test isempty(result.errors)
        modules = parse_program_ast(result.ast_json)
        @test !isempty(modules)
        # parse_program synthesizes `__main__.k` for the entry-point module.
        @test endswith(modules[1].filename, ".k")
        @test !isempty(modules[1].body)
    end
end

# The other half of the AST contract: the same decoder, run against the golden
# parser capture in `testdata/ast/alignment.json` rather than a live fixture.
include("ast_alignment.jl")

# ---------------------------------------------------------------------------
# Cross-language consistency: the same golden cases every other language runner
# executes from `tests/consistency/cases.json`, driven through this binding.
# ---------------------------------------------------------------------------

include("consistency_test.jl")
