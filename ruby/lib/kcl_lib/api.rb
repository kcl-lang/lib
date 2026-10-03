# frozen_string_literal: true

require_relative "spec_pb"

module KclLib
  # Raised when the KCL runtime returns an error reply. The Rust dispatcher
  # prefixes every error payload with "ERROR:" (the Rust source of truth is
  # `crates/api/src/service/capi.rs` in the KCL repo; see also
  # `docs/abi.md` section 4 in this repository).
  class KclError < StandardError; end

  # KCL APIs
  #
  # ## Examples
  #
  # ```ruby
  # require "kcl_lib"
  #
  # args = KclLib::ExecProgramArgs.new(k_filename_list: ["a.k"])
  # api = KclLib::API.new
  # result = api.exec_program(args)
  # puts result.yaml_result
  # ```
  class API
    # Error prefix prepended to every error reply by the Rust dispatcher.
    ERROR_PREFIX = "ERROR:"
    ERROR_PREFIX_BYTES = ERROR_PREFIX.bytesize

    def initialize(plugin_agent: 0)
      @plugin_agent = plugin_agent
    end

    # Ping the KCL service and return the same value.
    def ping(args)
      call("KclService.Ping", args)
    end

    # Parse KCL program with entry files and return the AST JSON string.
    #
    # The content of `schema.k` is
    #
    # ```python
    # schema AppConfig:
    #    replicas: int
    # app: AppConfig {
    #    replicas: 2
    # }
    # ```
    #
    # ```ruby
    # require "kcl_lib"
    #
    # args = KclLib::ParseProgramArgs.new(paths: ["schema.k"])
    # api = KclLib::API.new
    # result = api.parse_program(args)
    # raise "parse failed" unless result.errors.empty?
    # ```
    def parse_program(args)
      call("KclService.ParseProgram", args)
    end

    # Parse KCL single file to Module AST JSON string with import
    # dependencies and parse errors.
    def parse_file(args)
      call("KclService.ParseFile", args)
    end

    # Load the package and return the semantic model information including
    # symbols, types, definitions, etc.
    def load_package(args)
      call("KclService.LoadPackage", args)
    end

    # Parse KCL program and get all option information.
    def list_options(args)
      call("KclService.ListOptions", args)
    end

    # Parse KCL program and get all variables by specs.
    def list_variables(args)
      call("KclService.ListVariables", args)
    end

    # Execute KCL file with arguments and return the JSON/YAML result.
    #
    # ```ruby
    # require "kcl_lib"
    #
    # args = KclLib::ExecProgramArgs.new(k_filename_list: ["schema.k"])
    # api = KclLib::API.new
    # result = api.exec_program(args)
    # puts result.yaml_result
    # ```
    #
    # A case with the file not found error
    #
    # ```ruby
    # require "kcl_lib"
    #
    # begin
    #   args = KclLib::ExecProgramArgs.new(k_filename_list: ["file_not_found"])
    #   api = KclLib::API.new
    #   api.exec_program(args)
    #   raise "expected KclLib::KclError"
    # rescue KclLib::KclError => e
    #   raise unless e.message.include?("Cannot find the kcl file")
    # end
    # ```
    def exec_program(args)
      call("KclService.ExecProgram", args)
    end

    # Override KCL file with arguments. See
    # https://www.kcl-lang.io/docs/user_docs/guides/automation for more
    # override spec guide.
    def override_file(args)
      call("KclService.OverrideFile", args)
    end

    # Get schema type mapping defined in the program.
    def get_schema_type_mapping(args)
      call("KclService.GetSchemaTypeMapping", args)
    end

    # Get the schema type mapping of the program rooted at the input paths
    # and all of their external dependency packages. Different from
    # `get_schema_type_mapping`, the result is keyed by package name (e.g.
    # `"__main__"`, `"mymod.v1"`) and each value holds that package's schema
    # list.
    def get_schema_type_mapping_under_path(args)
      call("KclService.GetSchemaTypeMappingUnderPath", args)
    end

    # Format the code source.
    def format_code(args)
      call("KclService.FormatCode", args)
    end

    # Format KCL file or directory path contains KCL files and returns the
    # changed file paths.
    def format_path(args)
      call("KclService.FormatPath", args)
    end

    # Lint files and return error messages including errors and warnings.
    def lint_path(args)
      call("KclService.LintPath", args)
    end

    # Validate code using schema and JSON/YAML data strings.
    def validate_code(args)
      call("KclService.ValidateCode", args)
    end

    # Load the setting file config defined in `kcl.yaml`.
    def load_settings_files(args)
      call("KclService.LoadSettingsFiles", args)
    end

    # Rename all the occurrences of the target symbol in the files. This API
    # will rewrite files if they contain symbols to be renamed. Return the
    # file paths that got changed.
    def rename(args)
      call("KclService.Rename", args)
    end

    # Rename all the occurrences of the target symbol and return the
    # modified code if any code has been changed. This API won't rewrite
    # files but return the changed code.
    def rename_code(args)
      call("KclService.RenameCode", args)
    end

    # Test KCL packages with test arguments.
    def test(args)
      call("KclService.Test", args)
    end

    # Format a test result into a human-readable report.
    #
    # The report is byte-identical to the kcl-go `PrettyReporter` format and
    # is deterministic for a given result. Every line, including the last
    # one, ends with "\n":
    #
    # - One line per case in result order: `{name}: {STATUS} ({duration_ms}ms)`
    #   where STATUS is PASS or FAIL and the duration is the case duration
    #   in microseconds truncated to whole milliseconds, so 1500us renders as
    #   `1ms`. A case with a non-empty log message gets the log on the next
    #   line; otherwise a failed case appends its error string as-is.
    # - A separator line of exactly 80 `-` characters.
    # - Only for non-zero counts, in this order: `PASS: {p}/{total}`,
    #   `FAIL: {f}/{total}`, `SKIPPED: {s}/{total}`.
    # - An empty result (no cases, no coverage) renders `no test files`.
    def format_test_report(args)
      call("KclService.FormatTestReport", args)
    end

    # Download and update dependencies defined in the `kcl.mod` file and
    # return the external package name and location list.
    def update_dependencies(args)
      call("KclService.UpdateDependencies", args)
    end

    # Return the KCL service version information.
    def get_version
      call("KclService.GetVersion", Com::Kcl::Api::GetVersionArgs.new)
    end

    # List the KCL service method names supported by the underlying runtime.
    def list_method
      # ListMethodArgs is an empty proto message; the runtime still expects
      # the encoded (zero-byte) payload for the universal dispatcher.
      call("BuiltinService.ListMethod", Com::Kcl::Api::ListMethodArgs.new)
    end

    # Call KCL API with the API name and argument protobuf message. This is
    # the public raw escape hatch: any RPC name understood by the runtime
    # can be invoked directly and the decoded response message is returned.
    def call(name, args)
      payload = KclLib.call_with_plugin_agent(name, args.to_proto, @plugin_agent).b
      if payload.start_with?(ERROR_PREFIX)
        raise KclError, payload.byteslice(ERROR_PREFIX_BYTES..-1).force_encoding(Encoding::UTF_8)
      end
      self.class.create_method_resp_message(name).decode(payload)
    end

    # Look up the request message class for the given RPC method name.
    def self.create_method_req_message(method)
      req = {
        "Ping" => Com::Kcl::Api::PingArgs,
        "ExecProgram" => Com::Kcl::Api::ExecProgramArgs,
        "ParseFile" => Com::Kcl::Api::ParseFileArgs,
        "ParseProgram" => Com::Kcl::Api::ParseProgramArgs,
        "LoadPackage" => Com::Kcl::Api::LoadPackageArgs,
        "ListOptions" => Com::Kcl::Api::ParseProgramArgs,
        "ListVariables" => Com::Kcl::Api::ListVariablesArgs,
        "FormatCode" => Com::Kcl::Api::FormatCodeArgs,
        "FormatPath" => Com::Kcl::Api::FormatPathArgs,
        "LintPath" => Com::Kcl::Api::LintPathArgs,
        "OverrideFile" => Com::Kcl::Api::OverrideFileArgs,
        "GetSchemaTypeMapping" => Com::Kcl::Api::GetSchemaTypeMappingArgs,
        "GetSchemaTypeMappingUnderPath" => Com::Kcl::Api::GetSchemaTypeMappingArgs,
        "ValidateCode" => Com::Kcl::Api::ValidateCodeArgs,
        "LoadSettingsFiles" => Com::Kcl::Api::LoadSettingsFilesArgs,
        "Rename" => Com::Kcl::Api::RenameArgs,
        "RenameCode" => Com::Kcl::Api::RenameCodeArgs,
        "Test" => Com::Kcl::Api::TestArgs,
        "FormatTestReport" => Com::Kcl::Api::FormatTestReportArgs,
        "UpdateDependencies" => Com::Kcl::Api::UpdateDependenciesArgs,
        "GetVersion" => Com::Kcl::Api::GetVersionArgs,
      }
      key = method.split(".").last
      raise "unknown method: #{method}" unless req.key?(key)

      req[key].new
    end

    # Look up the response message class for the given RPC method name.
    def self.create_method_resp_message(method)
      resp = {
        "Ping" => Com::Kcl::Api::PingResult,
        "ExecProgram" => Com::Kcl::Api::ExecProgramResult,
        "ParseFile" => Com::Kcl::Api::ParseFileResult,
        "ParseProgram" => Com::Kcl::Api::ParseProgramResult,
        "LoadPackage" => Com::Kcl::Api::LoadPackageResult,
        "ListOptions" => Com::Kcl::Api::ListOptionsResult,
        "ListVariables" => Com::Kcl::Api::ListVariablesResult,
        "FormatCode" => Com::Kcl::Api::FormatCodeResult,
        "FormatPath" => Com::Kcl::Api::FormatPathResult,
        "LintPath" => Com::Kcl::Api::LintPathResult,
        "OverrideFile" => Com::Kcl::Api::OverrideFileResult,
        "GetSchemaTypeMapping" => Com::Kcl::Api::GetSchemaTypeMappingResult,
        "GetSchemaTypeMappingUnderPath" => Com::Kcl::Api::GetSchemaTypeMappingUnderPathResult,
        "ValidateCode" => Com::Kcl::Api::ValidateCodeResult,
        "LoadSettingsFiles" => Com::Kcl::Api::LoadSettingsFilesResult,
        "Rename" => Com::Kcl::Api::RenameResult,
        "RenameCode" => Com::Kcl::Api::RenameCodeResult,
        "Test" => Com::Kcl::Api::TestResult,
        "FormatTestReport" => Com::Kcl::Api::FormatTestReportResult,
        "UpdateDependencies" => Com::Kcl::Api::UpdateDependenciesResult,
        "GetVersion" => Com::Kcl::Api::GetVersionResult,
        "ListMethod" => Com::Kcl::Api::ListMethodResult,
      }
      key = method.split(".").last
      raise "unknown method: #{method}" unless resp.key?(key)

      resp[key]
    end
  end
end
