# frozen_string_literal: true

require "json"

module KclLib
  # High-level entry points mirroring kcl-go's `pkg/kcl` package.
  #
  # ## Examples
  #
  # ```ruby
  # require "kcl_lib"
  #
  # result = KclLib::Kcl.run("a = 1")
  # result.get("a")          # => 1
  #
  # KclLib::Kcl.run_files(["main.k", "base.k"], overrides: ["replicas=3"])
  # ```
  module Kcl
    # Evaluate the in-memory KCL source `code`.
    #
    # @param code [String] KCL source to evaluate
    # @param options [Hash] option overrides (see {KclLib::Options})
    # @return [KclLib::KclResultList]
    # @raise [KclLib::KclError] when the run reports a non-empty `err_message`
    def self.run(code, **options)
      exec(code: code, **options)
    end

    # Multi-file variant of {.run} (kcl-go `RunFiles`).
    #
    # @param paths [Array<String>, String] KCL files to evaluate
    # @param options [Hash] option overrides (see {KclLib::Options})
    # @return [KclLib::KclResultList]
    # @raise [KclLib::KclError] when the run reports a non-empty `err_message`
    def self.run_files(paths, **options)
      exec(files: paths, **options)
    end

    # Validate `data` (JSON/YAML string) against the schema `code`.
    #
    # @param code [String] KCL schema source, e.g. `"schema Person:\n    name: str\n"`
    # @param data [String] the data to validate, JSON or YAML per `format`
    # @param format [String] `"json"` (default) or `"yaml"`
    # @return [Boolean] `true` when validation passes
    # @raise [KclLib::KclError] when validation fails
    def self.validate(code, data, format: "json")
      result = API.new.validate_code(
        Com::Kcl::Api::ValidateCodeArgs.new(code: code, data: data, format: format)
      )
      raise KclError, result.err_message unless result.success

      true
    end

    # Split a YAML stream into its documents on `---` separator lines,
    # mirroring kcl-go's exported `SplitDocuments`. Trailing whitespace or `#`
    # comments are allowed on the separator line; anything else raises.
    #
    # @param text [String] YAML stream
    # @return [Array<String>] non-empty documents
    # @raise [KclLib::KclError] when a separator line carries content
    def self.split_documents(text)
      return [] if text.nil? || text.empty?

      docs = []
      current = []
      text.split("\n", -1).each do |raw_line|
        # Normalize CRLF up front so document bodies keep the same "\n"
        # join as the LF input, matching kcl-go's line-oriented scan.
        line = raw_line.end_with?("\r") ? raw_line[0..-2] : raw_line
        if line.start_with?("---")
          rest = line[3..].to_s.strip
          raise KclError, "invalid document separator: #{line.strip}" unless rest.empty? || rest.start_with?("#")

          docs << current.join("\n")
          current = []
        else
          current << line
        end
      end
      docs << current.join("\n")
      # Drop empty documents (e.g. a leading separator) and trailing newlines.
      docs.map { |doc| doc.gsub(/\n+\z/, "") }.reject { |doc| doc.strip.empty? }
    end

    # Parse the runtime's JSON *stream* output: one compact JSON value per
    # line (serde_json never emits literal newlines inside strings, so line
    # splitting is safe).
    #
    # @param json [String] the `json_result` payload
    # @return [Array<Array(Object, String)>] `[value, source_line]` pairs
    # @raise [KclLib::KclError] when a line is not valid JSON
    def self.parse_json_stream(json)
      values = []
      json.to_s.split("\n").each do |line|
        next if line.strip.empty?

        begin
          values << [JSON.parse(line), line]
        rescue JSON::ParserError => e
          raise KclError, "failed to parse KCL JSON result: #{e.message}"
        end
      end
      values
    end

    # Build an `ExecProgramArgs` from keyword options and execute it.
    #
    # @api private
    # @return [KclLib::KclResultList]
    def self.exec(code: nil, files: nil, **options)
      args = Options.build(
        code: code,
        files: files,
        **options
      )
      wrap_result(API.new.exec_program(args))
    end

    # Port of kcl-go's `ExecResultToKCLResult`: raise on `err_message`, pair
    # YAML documents (split on `---`) with the JSON stream values by position.
    #
    # @api private
    # @param resp [Com::Kcl::Api::ExecProgramResult]
    # @return [KclLib::KclResultList]
    def self.wrap_result(resp)
      raise KclError, resp.err_message unless resp.err_message.to_s.empty?

      yaml_result = resp.yaml_result || ""
      json_result = resp.json_result || ""
      return KclResultList.new([]) if yaml_result.strip.empty? && json_result.strip.empty?

      documents = split_documents(yaml_result)
      values = parse_json_stream(json_result)
      count = [documents.length, values.length].max
      results = []
      count.times do |i|
        document = i < documents.length ? documents[i] : ""
        next if document.strip.empty? && i >= values.length

        value = i < values.length ? values[i][0] : nil
        json_document = i < values.length ? values[i][1] : nil
        results << KclResult.new(value, document, json_document)
      end
      KclResultList.new(results)
    end
  end

  # One evaluated configuration document.
  class KclResult
    # @param value [Object] the parsed JSON value (nil when JSON-only output
    #   was suppressed, e.g. `format: "yaml"`)
    # @param yaml_document [String] the YAML rendering of this document
    # @param json_document [String, nil] the raw JSON line this value came from
    def initialize(value, yaml_document, json_document)
      @value = value
      @yaml_document = yaml_document
      @json_document = json_document
    end

    # The YAML rendering of this document as emitted by the runtime.
    # @return [String]
    attr_reader :yaml_document

    # The raw JSON line this document's value was parsed from.
    # @return [String, nil]
    attr_reader :json_document

    # The parsed JSON value, or nil when the run emitted YAML only.
    # @return [Object, nil]
    attr_reader :value

    # Dotted-path lookup over the parsed value, mirroring kcl-go's
    # `KCLResult.Get`. Integer segments index into lists.
    #
    # ```ruby
    # result.get("app.replicas")   # => 3
    # result.get("items.0.name")   # => "web"
    # ```
    #
    # @param path [String] dot-separated path
    # @param default [Object] returned when the path does not resolve
    # @return [Object]
    def get(path, default = nil)
      return default if @value.nil?

      current = @value
      path.to_s.split(".").each do |segment|
        case current
        when Hash
          return default unless current.key?(segment)

          current = current[segment]
        when Array
          index = Integer(segment, exception: false)
          return default if index.nil? || index >= current.length

          current = current[index]
        else
          return default
        end
      end
      current
    end

    # Convert the value to a Hash, raising when it is not a map.
    # @return [Hash]
    # @raise [KclLib::KclError]
    def to_map
      raise KclError, "failed to convert result to map: #{type_name}" unless @value.is_a?(Hash)

      @value
    end

    # Convert the value to an Array, raising when it is not a list.
    # @return [Array]
    # @raise [KclLib::KclError]
    def to_list
      raise KclError, "failed to convert result to list: #{type_name}" unless @value.is_a?(Array)

      @value
    end

    # Dotted-path lookup with strict type conversion, mirroring kcl-go's
    # `KCLResult.Get(key, &target)`. Unlike {#get} this raises rather than
    # returning a default when the path is missing or the type does not match.
    #
    # ```ruby
    # result.get_as("app.replicas", Integer)   # => 3
    # result.get_as("app.name", String)        # => "web"
    # ```
    #
    # @param path [String] dot-separated path
    # @param type [Class, Array<Class>] the expected Ruby class(es)
    # @raise [KclLib::KclError] when the path is missing or the type differs
    # @return [Object] the value, when it matches `type`
    def get_as(path, type)
      unless path_exists?(path)
        raise KclError, "failed to get #{path.inspect}: no such path in result"
      end

      value = resolve(path)
      types = Array(type)
      unless types.any? { |t| value.is_a?(t) }
        raise KclError,
              "failed to convert #{path.inspect} to #{types.join(" | ")}: got #{type_name_of(value)}"
      end

      value
    end

    # Dotted-path lookup returning an Integer.
    # @raise [KclLib::KclError] when missing or not an Integer
    # @return [Integer]
    def get_int(path)
      get_as(path, Integer)
    end

    # Dotted-path lookup returning a Float. Integers are widened.
    # @raise [KclLib::KclError] when missing or not numeric
    # @return [Float]
    def get_float(path)
      get_as(path, Numeric).to_f
    end

    # Dotted-path lookup returning a String.
    # @raise [KclLib::KclError] when missing or not a String
    # @return [String]
    def get_str(path)
      get_as(path, String)
    end

    # Dotted-path lookup returning a boolean.
    # @raise [KclLib::KclError] when missing or not a boolean
    # @return [Boolean]
    def get_bool(path)
      get_as(path, [TrueClass, FalseClass])
    end

    # @return [String] a human-readable description of the document value's type
    def type_name
      type_name_of(@value)
    end

    private

    # Walk the dotted path, returning nil as soon as a segment is missing.
    def resolve(path)
      current = @value
      path.to_s.split(".").each do |segment|
        case current
        when Hash
          return nil unless current.key?(segment)

          current = current[segment]
        when Array
          index = Integer(segment, exception: false)
          return nil if index.nil? || index >= current.length

          current = current[index]
        else
          return nil
        end
      end
      current
    end

    # Distinguish "path resolves to nil" from "path does not exist", which
    # `resolve` alone cannot express.
    def path_exists?(path)
      segments = path.to_s.split(".")
      current = @value
      segments.each do |segment|
        case current
        when Hash
          return false unless current.key?(segment)

          current = current[segment]
        when Array
          index = Integer(segment, exception: false)
          return false if index.nil? || index >= current.length

          current = current[index]
        else
          return false
        end
      end
      true
    end

    def type_name_of(value)
      case value
      when nil then "nil"
      when Hash then "map"
      when Array then "list"
      when String then "string"
      when Integer then "int"
      when Float then "float"
      when true, false then "bool"
      else value.class.name
      end
    end
  end

  # The documents produced by a run. Array semantics (`length`, indexing,
  # iteration, `map`) over {KclResult} items.
  class KclResultList < Array
    # The first document, or nil when the run produced none.
    # @return [KclLib::KclResult, nil]
    def first
      self[0]
    end

    # The last document, or nil when the run produced none.
    # @return [KclLib::KclResult, nil]
    def last
      self[-1]
    end
  end

  # Option bag translated into an `ExecProgramArgs`.
  #
  # Keys mirror the proto field names in snake_case:
  # `:work_dir, :code, :files, :args, :overrides, :path_selector, :format,
  # :error_format, :sort_keys, :disable_none, :show_hidden,
  # :include_schema_type_path, :strict_range_check, :compile_only,
  # :print_override_ast, :verbose, :debug, :external_pkgs`
  class Options
    # Build an `ExecProgramArgs` from keyword options.
    #
    # @param code [String, Array<String>, nil] in-memory KCL source
    # @param files [String, Array<String>, nil] KCL files to evaluate
    # @return [Com::Kcl::Api::ExecProgramArgs]
    def self.build(code: nil, files: nil, **options)
      args = Com::Kcl::Api::ExecProgramArgs.new
      apply_code(args, code)
      apply_files(args, files)
      apply_options(args, options)
      args
    end

    # @api private
    def self.apply_code(args, code)
      case code
      when nil then nil
      when String then args.k_code_list << code
      when Array then args.k_code_list.concat(code)
      else raise KclError, "options.code must be a String or an Array of String, got #{code.class}"
      end
    end

    # @api private
    def self.apply_files(args, files)
      case files
      when nil then nil
      when String then args.k_filename_list << files
      when Array then args.k_filename_list.concat(files)
      else raise KclError, "options.files must be a String or an Array of String, got #{files.class}"
      end
    end

    # @api private
    def self.apply_options(args, options)
      args.work_dir = options[:work_dir] if options.key?(:work_dir)
      args.overrides.concat(options[:overrides]) if options[:overrides]
      args.path_selector.concat(options[:path_selector]) if options[:path_selector]
      args.format = options[:format] if options[:format]
      args.error_format = options[:error_format] if options[:error_format]
      args.sort_keys = options[:sort_keys] if options.key?(:sort_keys)
      args.disable_none = options[:disable_none] if options.key?(:disable_none)
      args.show_hidden = options[:show_hidden] if options.key?(:show_hidden)
      args.include_schema_type_path = options[:include_schema_type_path] if options.key?(:include_schema_type_path)
      args.strict_range_check = options[:strict_range_check] if options.key?(:strict_range_check)
      args.compile_only = options[:compile_only] if options.key?(:compile_only)
      args.print_override_ast = options[:print_override_ast] if options.key?(:print_override_ast)
      args.verbose = options[:verbose] if options[:verbose]
      args.debug = options[:debug] if options[:debug]
      apply_args(args, options[:args])
      apply_external_pkgs(args, options[:external_pkgs])
    end

    # Normalize `-D name=value` specs and `{name:, value:}` hashes into the
    # proto `Argument` list.
    #
    # @api private
    def self.apply_args(args, list)
      return if list.nil?

      unless list.is_a?(Array)
        raise KclError, "options.args must be an Array, got #{list.class}"
      end

      list.each do |item|
        case item
        when String
          # Mirrors kcl-go's `strings.Index(kv, "=") > 0` guard.
          index = item.index("=")
          next if index.nil? || index.zero?

          args.args << Com::Kcl::Api::Argument.new(
            name: item[0...index], value: item[(index + 1)..]
          )
        when Hash
          args.args << Com::Kcl::Api::Argument.new(
            name: item[:name] || item["name"] || "",
            value: (item[:value] || item["value"] || "").to_s
          )
        when Com::Kcl::Api::Argument
          args.args << item
        else
          raise KclError,
                "options.args entries must be String, Hash or Argument, got #{item.class}"
        end
      end
    end

    # Normalize `-E name=path` specs and `{pkg_name:, pkg_path:}` hashes into
    # the proto `ExternalPkg` list.
    #
    # @api private
    def self.apply_external_pkgs(args, list)
      return if list.nil?

      unless list.is_a?(Array)
        raise KclError, "options.external_pkgs must be an Array, got #{list.class}"
      end

      list.each do |item|
        case item
        when String
          index = item.index("=")
          next if index.nil? || index.zero?

          args.external_pkgs << Com::Kcl::Api::ExternalPkg.new(
            pkg_name: item[0...index], pkg_path: item[(index + 1)..]
          )
        when Hash
          args.external_pkgs << Com::Kcl::Api::ExternalPkg.new(
            pkg_name: item[:pkg_name] || item["pkg_name"] || "",
            pkg_path: item[:pkg_path] || item["pkg_path"] || ""
          )
        when Com::Kcl::Api::ExternalPkg
          args.external_pkgs << item
        else
          raise KclError,
                "options.external_pkgs entries must be String, Hash or ExternalPkg, got #{item.class}"
        end
      end
    end
  end
end
