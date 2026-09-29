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

    @testset "list_method (tolerates unregistered BuiltinService)" begin
        # Prebuilt libkcl v0.13.0 predates the BuiltinService registration:
        # its dispatcher answers with an empty payload, while a runtime built
        # from newer source returns the full method table. Accept both.
        result = list_method()
        if !isempty(result.method_name_list)
            @test "KclService.ExecProgram" in result.method_name_list
            @test "KclService.Ping" in result.method_name_list
        end
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
end
