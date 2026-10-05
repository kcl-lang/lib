# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"

require "kcl_lib"

TEST_FILE = "./test_data/schema.k"

class ApiTest < Minitest::Test
  def test_exec_api
    # Execute KCL file with arguments and return the JSON/YAML result.
    args = KclLib::ExecProgramArgs.new(k_filename_list: [TEST_FILE])
    api = KclLib::API.new
    result = api.exec_program(args)
    assert_equal "app:\n  replicas: 2", result.yaml_result
  end

  def test_exec_api_with_code
    # Execute in-memory KCL source via `k_code_list`.
    args = KclLib::ExecProgramArgs.new(k_code_list: ["alice = {age = 18}"])
    api = KclLib::API.new
    result = api.exec_program(args)
    assert_equal "alice:\n  age: 18", result.yaml_result
  end

  def test_exec_api_failed
    api = KclLib::API.new
    error = assert_raises(KclLib::KclError) do
      api.exec_program(KclLib::ExecProgramArgs.new(k_filename_list: ["file_not_found"]))
    end
    assert_includes error.message, "Cannot find the kcl file"
  end

  def test_ping_api
    # Ping the KCL service and return the same value.
    api = KclLib::API.new
    result = api.ping(KclLib::PingArgs.new(value: "Hello, KCL!"))
    assert_equal "Hello, KCL!", result.value
  end

  def test_get_version_api
    # Return the KCL service version information.
    api = KclLib::API.new
    result = api.get_version
    assert_includes result.version_info, "Version"
    assert_includes result.version_info, "GitCommit"
  end

  def test_parse_program_api
    # Parse KCL program with entry files and return the AST JSON string.
    api = KclLib::API.new
    result = api.parse_program(KclLib::ParseProgramArgs.new(paths: [TEST_FILE]))
    assert_equal 1, result.paths.length
    assert_empty result.errors
  end

  def test_parse_file_api
    # Parse KCL single file to Module AST JSON string with import
    # dependencies and parse errors.
    api = KclLib::API.new
    result = api.parse_file(KclLib::ParseFileArgs.new(path: TEST_FILE))
    assert_empty result.deps
    assert_empty result.errors
  end

  def test_load_package_api
    # Parse KCL program and return the semantic model information including
    # symbols, types, definitions, etc.
    api = KclLib::API.new
    args = KclLib::LoadPackageArgs.new(
      parse_args: KclLib::ParseProgramArgs.new(paths: [TEST_FILE]),
      resolve_ast: true
    )
    result = api.load_package(args)
    assert result.symbols.values.any? { |s| s.ty.schema_name == "AppConfig" }
  end

  def test_list_options_api
    # Parse KCL program and get all option information.
    api = KclLib::API.new
    result = api.list_options(KclLib::ParseProgramArgs.new(paths: ["./test_data/option/main.k"]))
    assert_equal 3, result.options.length
    assert_equal "key1", result.options[0].name
    assert_equal "key2", result.options[1].name
    assert_equal "metadata-key", result.options[2].name
  end

  def test_list_variables_api
    # Parse KCL program and get all variables by specs.
    api = KclLib::API.new
    result = api.list_variables(KclLib::ListVariablesArgs.new(files: [TEST_FILE]))
    assert_equal "AppConfig {\n    replicas: 2\n}", result.variables["app"].variables[0].value
  end

  def test_get_schema_type_mapping_api
    # Get schema type mapping defined in the program.
    api = KclLib::API.new
    exec_args = KclLib::ExecProgramArgs.new(k_filename_list: [TEST_FILE])
    args = KclLib::GetSchemaTypeMappingArgs.new(exec_args: exec_args)
    result = api.get_schema_type_mapping(args)
    assert_equal "int", result.schema_type_mapping["app"].properties["replicas"].type
    assert_equal "function", result.schema_type_mapping["app"].properties["my_func"].type
    maps = result.schema_type_mapping["app"].properties["maps"]
    assert_equal "schema", maps.type
    assert_equal "name", maps.index_signature.key_name
    assert_equal "str", maps.index_signature.key.type
    assert_equal "schema", maps.index_signature.val.type
    assert_equal "str", maps.index_signature.val.properties["name"].type
  end

  def test_get_schema_type_mapping_under_path_api
    # Schemas from external packages keep their own pkgpath and base schema.
    root = File.expand_path("./test_data/get_schema_ty_under_path", Dir.pwd)
    exec_args = KclLib::ExecProgramArgs.new(
      k_filename_list: [File.join(root, "aaa")],
      external_pkgs: [KclLib::ExternalPkg.new(pkg_name: "bbb", pkg_path: File.join(root, "bbb"))]
    )
    api = KclLib::API.new
    result = api.get_schema_type_mapping_under_path(KclLib::GetSchemaTypeMappingArgs.new(exec_args: exec_args))

    assert_includes result.schema_type_mapping.keys, "__main__"
    assert_includes result.schema_type_mapping.keys, "bbb"

    bbb_schemas = result.schema_type_mapping["bbb"].schema_type.to_h { |s| [s.schema_name, s] }
    assert bbb_schemas.key?("Base") && bbb_schemas.key?("B")
    assert_equal "bbb", bbb_schemas["Base"].pkg_path
    assert_equal "bbb", bbb_schemas["B"].pkg_path
    refute_nil bbb_schemas["B"].base_schema
    assert_equal "Base", bbb_schemas["B"].base_schema.schema_name
    assert_equal "bbb", bbb_schemas["B"].base_schema.pkg_path
  end

  def test_override_file_api
    # Override KCL file with arguments.
    test_file = "./test_data/override_file/main.k"
    FileUtils.cp("./test_data/override_file/main.bak", test_file)

    api = KclLib::API.new
    result = api.override_file(KclLib::OverrideFileArgs.new(file: test_file, specs: ["b.a=2"]))
    assert_empty result.parse_errors
    assert result.result
    assert_equal <<~KCL, File.read(test_file)
      a = 1
      b = {
          "a": 2
          "b": 2
      }
    KCL
  end

  def test_format_code_api
    # Format the code source.
    source_code = <<~KCL
      schema Person:
          name:   str
          age:    int

          check:
              0 <   age <   120
    KCL

    api = KclLib::API.new
    result = api.format_code(KclLib::FormatCodeArgs.new(source: source_code))
    assert_equal <<~KCL, result.formatted.dup.force_encoding(Encoding::UTF_8)
      schema Person:
          name: str
          age: int

          check:
              0 < age < 120
    KCL
  end

  def test_format_path_api
    # Format KCL file or directory path and return the changed file paths.
    test_path = "./test_data/format_path/test.k"
    File.binwrite(test_path, "a = 1\n")

    api = KclLib::API.new
    result = api.format_path(KclLib::FormatPathArgs.new(path: test_path))
    assert_empty result.changed_paths
  end

  def test_lint_path_api
    # Lint files and return error messages including errors and warnings.
    api = KclLib::API.new
    result = api.lint_path(KclLib::LintPathArgs.new(paths: ["./test_data/lint_path/test-lint.k"]))
    assert_includes result.results, "Module 'math' imported but unused"
  end

  def test_validate_code_api
    # Validate code using schema and JSON/YAML data strings.
    code = <<~KCL
      schema Person:
          name: str
          age: int

          check:
              0 < age < 120
    KCL
    data = '{"name": "Alice", "age": 10}'

    api = KclLib::API.new
    result = api.validate_code(KclLib::ValidateCodeArgs.new(code: code, data: data, format: "json"))
    assert result.success
    assert_empty result.err_message
  end

  def test_load_settings_files_api
    # Load the setting file config defined in `kcl.yaml`.
    api = KclLib::API.new
    result = api.load_settings_files(
      KclLib::LoadSettingsFilesArgs.new(work_dir: "./test_data", files: ["./test_data/settings/kcl.yaml"])
    )
    assert_empty result.kcl_cli_configs.files
    assert result.kcl_cli_configs.strict_range_check
    assert_equal "key", result.kcl_options[0].key
    assert_equal '"value"', result.kcl_options[0].value
  end

  def test_rename_api
    # Rename all the occurrences of the target symbol in the files and return
    # the file paths that got changed.
    test_file = "./test_data/rename/main.k"
    FileUtils.cp("./test_data/rename/main.bak", test_file)

    api = KclLib::API.new
    result = api.rename(
      KclLib::RenameArgs.new(
        package_root: "./test_data/rename",
        symbol_path: "a",
        file_paths: [test_file],
        new_name: "a2"
      )
    )
    assert_includes result.changed_files[0], "test_data/rename/main.k"
  end

  def test_rename_code_api
    # Rename all the occurrences of the target symbol and return the modified
    # code without rewriting files.
    api = KclLib::API.new
    result = api.rename_code(
      KclLib::RenameCodeArgs.new(
        package_root: "/mock/path",
        symbol_path: "a",
        source_codes: { "/mock/path/main.k" => "a = 1\nb = a" },
        new_name: "a2"
      )
    )
    assert_equal "a2 = 1\nb = a2", result.changed_codes["/mock/path/main.k"]
  end

  def test_testing_api
    # Test KCL packages with test arguments.
    api = KclLib::API.new
    result = api.test(KclLib::TestArgs.new(pkg_list: ["./test_data/testing/..."]))
    assert_equal 2, result.info.length
  end

  def test_generate_rpc_dispatch_tables
    # The typed wrappers are only useful if the raw `call` escape hatch can
    # reach the same RPCs, and it reaches them through these two tables.
    # A wrapper without its table entries decodes into a zero-valued message
    # instead of failing, so pin the classes rather than just the presence.
    expected = {
      "GenerateToml" => [KclLib::GenerateTomlArgs, KclLib::GenerateTomlResult],
      "GenerateKcl" => [KclLib::GenerateKclArgs, KclLib::GenerateKclResult],
      "GenerateOpenAPI" => [KclLib::GenerateOpenAPIArgs, KclLib::GenerateOpenAPIResult],
      "GenerateProto" => [KclLib::GenerateProtoArgs, KclLib::GenerateProtoResult],
      "GenerateDoc" => [KclLib::GenerateDocArgs, KclLib::GenerateDocResult],
      "FormatTestReport" => [KclLib::FormatTestReportArgs, KclLib::FormatTestReportResult]
    }
    expected.each do |method, (req, resp)|
      # The request table hands back an empty instance to dispatch with; the
      # response table hands back the class, which `call` decodes into.
      assert_instance_of req, KclLib::API.create_method_req_message(method)
      assert_instance_of req, KclLib::API.create_method_req_message("KclService.#{method}")
      assert_equal resp, KclLib::API.create_method_resp_message(method)
      assert_equal resp, KclLib::API.create_method_resp_message("KclService.#{method}")
    end
  end

  def test_format_test_report_api
    # The report is the one kcl-go's `PrettyReporter` produces: one line per
    # case, the log message of a case that has one on the following line, the
    # error text of a failed case, an 80-dash separator, and the per-status
    # counts.
    skip "core does not list KclService.FormatTestReport" unless
      KclLib::API.new.list_method.method_name_list.include?("KclService.FormatTestReport")

    result = KclLib::TestResult.new(
      info: [
        KclLib::TestCaseInfo.new(name: "test_pass", duration: 1500),
        KclLib::TestCaseInfo.new(name: "test_log", duration: 2500, log_message: "hello log"),
        KclLib::TestCaseInfo.new(name: "test_fail", duration: 1000, error: "Error: assert failed")
      ]
    )
    api = KclLib::API.new
    report = api.format_test_report(KclLib::FormatTestReportArgs.new(result: result)).report

    assert_equal(
      "test_pass: PASS (1ms)\n" \
      "test_log: PASS (2ms)\n" \
      "hello log\n" \
      "test_fail: FAIL (1ms)\n" \
      "Error: assert failed\n" \
      "#{"-" * 80}\n" \
      "PASS: 2/3\n" \
      "FAIL: 1/3\n",
      report.dup.force_encoding(Encoding::UTF_8)
    )
  end

  def test_format_test_report_of_empty_result
    # An empty result carries no counts at all, so the separator and the
    # summary lines are dropped for it.
    skip "core does not list KclService.FormatTestReport" unless
      KclLib::API.new.list_method.method_name_list.include?("KclService.FormatTestReport")

    api = KclLib::API.new
    report = api.format_test_report(
      KclLib::FormatTestReportArgs.new(result: KclLib::TestResult.new)
    ).report

    assert_equal "no test files\n", report.dup.force_encoding(Encoding::UTF_8)
  end

  def test_update_dependencies_api
    # Download and update dependencies defined in the `kcl.mod` file and
    # return the external package name and location list.
    api = KclLib::API.new
    result = api.update_dependencies(
      KclLib::UpdateDependenciesArgs.new(manifest_path: "./test_data/update_dependencies")
    )
    pkg_names = result.external_pkgs.map(&:pkg_name)
    assert_equal 2, pkg_names.length
    assert_includes pkg_names, "helloworld"
    assert_includes pkg_names, "flask"
  end

  def test_exec_api_with_external_dependencies
    # The local kcl.mod declares both deps as `path = "../_mocks/..."`, but
    # `update_dependencies` always returns `pkg_path = <manifest>/<dep_name>`
    # (it ignores the `path` directive), so we hand-build `external_pkgs`
    # pointing at the actual mock locations.
    api = KclLib::API.new
    exec_args = KclLib::ExecProgramArgs.new(
      k_filename_list: ["./test_data/update_dependencies/main.k"],
      external_pkgs: [
        KclLib::ExternalPkg.new(pkg_name: "helloworld", pkg_path: "./test_data/_mocks/helloworld"),
        KclLib::ExternalPkg.new(pkg_name: "flask", pkg_path: "./test_data/_mocks/flask")
      ]
    )
    result = api.exec_program(exec_args)
    assert_equal "a: Hello World!", result.yaml_result
  end

  def test_list_method_api
    # List all the methods supported by the KCL service.
    api = KclLib::API.new
    result = api.list_method
    refute_empty result.method_name_list
  end

  def test_raw_call
    # The raw escape hatch: any RPC name can be invoked with a request
    # message and returns the decoded response message.
    api = KclLib::API.new
    result = api.call("KclService.Ping", KclLib::PingArgs.new(value: "raw"))
    assert_kind_of KclLib::PingResult, result
    assert_equal "raw", result.value
  end

  def test_raw_call_error
    # Error replies keep the "ERROR:" convention and raise KclError.
    api = KclLib::API.new
    error = assert_raises(KclLib::KclError) do
      api.call("KclService.ExecProgram", KclLib::ExecProgramArgs.new(k_filename_list: ["file_not_found"]))
    end
    assert_includes error.message, "Cannot find the kcl file"
  end
end
