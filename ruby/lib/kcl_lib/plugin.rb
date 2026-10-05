# frozen_string_literal: true

require "fiddle"
require "json"
require "monitor"

module KclLib
  # KCL plugins: Ruby callables a KCL program reaches by name.
  #
  # A program imports a plugin module and calls its method unqualified:
  #
  # ```kcl
  # import kcl_plugin.my_plugin
  #
  # result = my_plugin.add(1, 2)
  # ```
  #
  # The runtime resolves that to a `kcl_plugin.my_plugin.add` call into the
  # host, hands the agent the fully-qualified name plus the arguments as
  # JSON, and expects a JSON result back. The API shape mirrors Go's
  # `go/plugin` (see `go/plugin/api.go` and `go/plugin/spec.go`): a plugin
  # owns a map of method specifications, and each specification is a body
  # that takes a {MethodArgs} and yields a result.
  #
  # ## Examples
  #
  # ```ruby
  # require "kcl_lib"
  #
  # KclLib::PluginContext.register_plugin(
  #   KclLib::Plugin.new(
  #     name: "my_plugin",
  #     methods: { "add" => ->(args) { args.arg(0) + args.arg(1) } }
  #   )
  # )
  #
  # result = KclLib::Kcl.run("import kcl_plugin.my_plugin\nresult = my_plugin.add(1, 2)\n")
  # result.get("result")   # => 3
  # ```
  #
  # {KclLib::API} picks the agent up on its own, so no further wiring is
  # needed; pass `plugin_agent:` explicitly only to point at a handler this
  # registry did not build.
  #
  # ## Errors are data
  #
  # The agent runs on a C frame the runtime called into, so a Ruby exception
  # must never unwind across it. Every failure — an unregistered method, a
  # malformed argument payload, a body that raised — is reported as
  # `{"__kcl_PanicInfo__": "..."}` instead, which is the shape the runtime
  # turns into a KCL-level diagnostic (see `kcl_plugin_invoke` in
  # `crates/runtime/src/stdlib/plugin.rs`). Go's `plugin.JSONError` and Lua's
  # `panic_info` produce the same object.
  class PluginContext
    # The prefix a plugin import path must carry, so a method is reachable
    # at `kcl_plugin.<plugin>.<method>` — exactly the name the runtime sends.
    PLUGIN_PREFIX = "kcl_plugin."

    # The key the runtime looks for in a plugin result to turn it into a
    # diagnostic instead of a value.
    PANIC_INFO_KEY = "__kcl_PanicInfo__"

    # The name the runtime sends for `method` of `plugin`.
    #
    # @param plugin [String] the plugin name
    # @param method [String] the method name
    # @return [String]
    def self.qualified_name(plugin, method)
      "#{PLUGIN_PREFIX}#{plugin}.#{method}"
    end

    # The handler's C signature. The runtime declares
    # `extern "C-unwind" fn(*const c_char, *const c_char, *const c_char) -> *const c_char`
    # (`kcl_plugin_init` in `crates/runtime/src/stdlib/plugin.rs`), so every
    # parameter and the return value is a pointer.
    AGENT_SIGNATURE = [
      Fiddle::TYPE_VOIDP, # method
      Fiddle::TYPE_VOIDP, # args_json
      Fiddle::TYPE_VOIDP  # kwargs_json
    ].freeze

    class << self
      # The process-wide registry.
      #
      # @return [KclLib::PluginContext]
      def instance
        @instance ||= new
      end

      # Add or replace a plugin. Its methods become reachable at
      # `kcl_plugin.<name>.<method>`.
      #
      # @param plugin [Plugin]
      # @return [Plugin] the registered plugin
      def register_plugin(plugin)
        instance.register_plugin(plugin)
      end

      # @param name [String]
      # @return [Plugin, nil]
      def get_plugin(name)
        instance.get_plugin(name)
      end

      # @param method [String] a fully-qualified `kcl_plugin.<plugin>.<method>` name
      # @return [MethodSpec, nil]
      def get_method_spec(method)
        instance.get_method_spec(method)
      end

      # @return [Array<String>] the registered plugin names
      def plugin_names
        instance.plugin_names
      end

      # Run every registered plugin's reset hook. The registry itself is left
      # intact, matching Go's `plugin.ResetPlugin`.
      def reset!
        instance.reset!
      end

      # Forget every registered plugin. This is what puts {#agent_addr} back
      # to `0` and takes the client off the plugin path again — the escape
      # hatch a test uses to start from a clean registry, and what Lua's
      # `kcl_lib.disable_plugins()` does.
      def clear!
        instance.clear!
      end

      # Whether any plugin method is currently registered.
      #
      # @return [Boolean]
      def methods?
        !instance.method_specs.empty?
      end

      # Address of the C handler to hand to `call_with_plugin_agent`, or `0`
      # when nothing is registered. The runtime skips plugin loading entirely
      # for a zero agent (`load_plugins: plugin_agent > 0` in
      # `crates/runner/src/runner.rs`), which is what keeps a binding with no
      # plugins on the plain dispatcher.
      #
      # The trampoline is built once and then kept for the life of the
      # process: the runtime stores it in a global on first use and keeps
      # calling it, so freeing it would leave a dangling pointer behind.
      #
      # @return [Integer] the handler address, or `0`
      def agent_addr
        instance.agent_addr
      end

      # Dispatch one plugin call and return the JSON reply. This is the Ruby
      # half of the C handler, exposed so a caller can drive the registry
      # without a KCL program in the way.
      #
      # @param method [String] a fully-qualified `kcl_plugin.<plugin>.<method>` name
      # @param args_json [String] JSON array of positional arguments
      # @param kwargs_json [String] JSON object of keyword arguments
      # @return [String] the JSON result, or a panic-info object
      def call_method(method, args_json = "", kwargs_json = "")
        instance.dispatch(method, args_json, kwargs_json)
      end

      # The `{ "__kcl_PanicInfo__" => message }` object every failure is
      # reported as.
      #
      # @param message [#to_s]
      # @return [String] the JSON document
      def build_panic_info(message)
        JSON.generate(PANIC_INFO_KEY => message.to_s)
      end
    end

    def initialize
      @lock = Monitor.new
      @plugins = {}
      @method_specs = {}
      # The reply buffer and the trampoline are both per-instance and stay
      # reachable from here for the life of the process; see {#agent_addr}.
      @reply = nil
      @agent = nil
    end

    # @see KclLib::PluginContext.register_plugin
    def register_plugin(plugin)
      raise ArgumentError, "invalid plugin: expected a KclLib::Plugin, got #{plugin.class}" unless plugin.is_a?(Plugin)

      @lock.synchronize do
        # Re-registering a name replaces it outright: the old method specs
        # are dropped, so a plugin re-registered with fewer methods stops
        # answering for the ones it gave up.
        previous = @plugins[plugin.name]
        previous&.methods&.each_key do |method|
          @method_specs.delete(PluginContext.qualified_name(plugin.name, method))
        end

        @plugins[plugin.name] = plugin
        plugin.methods.each do |method, spec|
          @method_specs[PluginContext.qualified_name(plugin.name, method)] = spec
        end
      end
      plugin
    end

    # @see KclLib::PluginContext.get_plugin
    def get_plugin(name)
      @lock.synchronize { @plugins[name.to_s] }
    end

    # @see KclLib::PluginContext.get_method_spec
    def get_method_spec(method)
      @lock.synchronize { @method_specs[method.to_s] }
    end

    # @see KclLib::PluginContext.plugin_names
    def plugin_names
      @lock.synchronize { @plugins.keys }
    end

    # @api private
    # @return [Hash{String => MethodSpec}]
    def method_specs
      @lock.synchronize { @method_specs.dup }
    end

    # @see KclLib::PluginContext.reset!
    def reset!
      @lock.synchronize { @plugins.each_value(&:reset!) }
    end

    # @see KclLib::PluginContext.clear!
    def clear!
      @lock.synchronize do
        @plugins = {}
        @method_specs = {}
      end
    end

    # @see KclLib::PluginContext.agent_addr
    def agent_addr
      @lock.synchronize do
        # A zero agent is the "no plugins" signal, so an empty registry must
        # not build a trampoline at all. Going back to zero after a
        # registration is cleared is safe: the runtime holds the previous
        # address in a global and the trampoline is never freed, so a later
        # `kcl_plugin.*` import still lands in `dispatch` and gets a
        # "not found" reply rather than a dangling pointer.
        return 0 if @method_specs.empty?

        @agent ||= Fiddle::Closure::BlockCaller.new(Fiddle::TYPE_VOIDP, AGENT_SIGNATURE) do |method, args, kwargs|
          # The block runs on a C frame the runtime called into, so it has
          # to hand back a pointer rather than a Ruby value: `write_reply`
          # publishes the JSON and returns the address the runtime reads it
          # from before the next call overwrites the buffer.
          write_reply(dispatch(read_cstr(method), read_cstr(args), read_cstr(kwargs)))
        end
        @agent.to_i
      end
    end

    # @see KclLib::PluginContext.call_method
    def dispatch(method, args_json = "", kwargs_json = "")
      JSON.generate(invoke(method, args_json, kwargs_json))
    rescue Exception => e # rubocop:disable Lint/RescueException
      # `Exception`, not `StandardError`: this runs on a C frame the runtime
      # called into, and letting a non-StandardError (a `ScriptError` from a
      # syntax-erroring plugin file, say) unwind past it would be undefined
      # behaviour rather than a raised exception.
      PluginContext.build_panic_info(e.message)
    end

    private

    def invoke(method, args_json, kwargs_json)
      raise ArgumentError, "empty method" if method.nil? || method.empty?

      spec = get_method_spec(method)
      raise ArgumentError, "invalid method: #{method} is not found" if spec.nil?

      spec.call(MethodArgs.parse(args_json, kwargs_json))
    end

    # A NUL-terminated copy of a C string, or "" for a null pointer. The
    # runtime passes a real string for all three, but a null must not reach
    # `Fiddle::Pointer#to_s`, which raises on it.
    def read_cstr(pointer)
      pointer.nil? ? "" : pointer.to_s
    end

    # Publish `text` as a NUL-terminated C string and return the pointer to
    # it. The buffer is reused across calls and only grows, so a plugin
    # method must not hold on to a previous result — the same contract
    # Python's and Lua's agents have.
    def write_reply(text)
      bytes = text.to_s.b
      size = bytes.bytesize + 1
      @reply = Fiddle::Pointer.malloc(size) if @reply.nil? || @reply.size < size
      @reply[0, bytes.bytesize] = bytes
      @reply[bytes.bytesize] = 0
      @reply
    end
  end

  # A named group of plugin methods.
  class Plugin
    # @param name [String] the plugin name a KCL program imports
    # @param methods [Hash{String => MethodSpec, #call}] method name to
    #   specification; a bare callable is wrapped in a {MethodSpec}
    # @param version [String, nil] an arbitrary version string
    # @param reset [#call, nil] invoked by {PluginContext.reset!}
    def initialize(name:, methods:, version: nil, reset: nil)
      raise ArgumentError, "invalid plugin: empty name" if name.to_s.empty?
      raise ArgumentError, "invalid plugin #{name}: methods must be a Hash" unless methods.is_a?(Hash)

      @name = name.to_s
      @version = version
      @reset = reset
      @methods = methods.each_with_object({}) do |(method, body), acc|
        acc[method.to_s] = body.is_a?(MethodSpec) ? body : MethodSpec.new(body: body)
      end
    end

    # @return [String]
    attr_reader :name

    # @return [String, nil]
    attr_reader :version

    # @return [Hash{String => MethodSpec}]
    attr_reader :methods

    # Run the plugin's reset hook, if it has one.
    def reset!
      @reset&.call
    end
  end

  # The arguments a KCL plugin method was called with: the positional list
  # and the keyword map the runtime serialized to JSON.
  #
  # Accessors come in positional and keyword flavours, mirroring Go's
  # `MethodArgs` (`go/plugin/spec.go`). The typed ones convert, so a KCL
  # number that arrived as a JSON string still reads as an Integer.
  class MethodArgs
    # @param args [Array<Object>] the positional arguments
    # @param kwargs [Hash{String => Object}] the keyword arguments
    def initialize(args = [], kwargs = {})
      @args = args
      @kwargs = kwargs
    end

    # @return [Array<Object>]
    attr_reader :args

    # @return [Hash{String => Object}]
    attr_reader :kwargs

    # Decode the two JSON payloads the runtime sends. An empty payload means
    # "no arguments", which is distinct from a payload that failed to parse.
    #
    # @api private
    # @param args_json [String] JSON array of positional arguments
    # @param kwargs_json [String] JSON object of keyword arguments
    # @return [KclLib::MethodArgs]
    # @raise [ArgumentError] when a payload is not JSON of the expected shape
    def self.parse(args_json, kwargs_json)
      args = args_json.to_s.empty? ? [] : JSON.parse(args_json)
      unless args.is_a?(Array)
        raise ArgumentError, "plugin positional arguments must be a JSON array, got #{args_json}"
      end

      kwargs = kwargs_json.to_s.empty? ? {} : JSON.parse(kwargs_json)
      unless kwargs.is_a?(Hash)
        raise ArgumentError, "plugin keyword arguments must be a JSON object, got #{kwargs_json}"
      end

      new(args, kwargs)
    end

    # @param index [Integer] position in the positional list
    # @return [Object, nil]
    def arg(index)
      @args[index]
    end

    # @param name [String, Symbol] keyword argument name
    # @return [Object, nil]
    def kwarg(name)
      @kwargs[name.to_s]
    end

    # Look an argument up by keyword first and by position second, so a
    # method reads the same whichever way the caller spelled it. This is Go's
    # `GetCallArg`.
    #
    # @param index [Integer] position in the positional list
    # @param name [String, Symbol] keyword argument name
    # @return [Object, nil]
    def call_arg(index, name)
      key = name.to_s
      return @kwargs[key] if @kwargs.key?(key)

      arg(index)
    end

    # The positional argument at `index` as an Integer.
    # @return [Integer]
    def int_arg(index)
      Integer(arg(index))
    end

    # The positional argument at `index` as a Float.
    # @return [Float]
    def float_arg(index)
      Float(arg(index))
    end

    # The positional argument at `index` as a String.
    # @return [String]
    def str_arg(index)
      arg(index).to_s
    end

    # The positional argument at `index` as a list.
    # @return [Array]
    def list_arg(index)
      arg(index)
    end

    # The positional argument at `index` as a map.
    # @return [Hash]
    def map_arg(index)
      arg(index)
    end

    # The keyword argument `name` as an Integer.
    # @return [Integer]
    def int_kwarg(name)
      Integer(kwarg(name))
    end

    # The keyword argument `name` as a Float.
    # @return [Float]
    def float_kwarg(name)
      Float(kwarg(name))
    end

    # The keyword argument `name` as a String.
    # @return [String]
    def str_kwarg(name)
      kwarg(name).to_s
    end

    # The keyword argument `name` as a list.
    # @return [Array]
    def list_kwarg(name)
      kwarg(name)
    end

    # The keyword argument `name` as a map.
    # @return [Hash]
    def map_kwarg(name)
      kwarg(name)
    end
  end

  # The value a plugin method produced. Wrapping it keeps the result
  # distinguishable from the "no result" case, exactly as Go's
  # `plugin.MethodResult` does — though a body is free to return the value
  # directly and {MethodSpec#call} unwraps this for it.
  class MethodResult
    # @param value [Object] any JSON-encodable value
    def initialize(value = nil)
      @value = value
    end

    # @return [Object]
    attr_reader :value
  end

  # The declared shape of a plugin method. This is documentation for the
  # author of the plugin rather than a contract the runtime enforces — the
  # arguments arrive as JSON and the body sees them untyped, so `type` is
  # never used to validate a call.
  class MethodType
    # @param args_type [Array<String>] the positional argument type names
    # @param kwargs_type [Hash{String => String}] keyword name to type name
    # @param result_type [String] the result type name
    def initialize(args_type: [], kwargs_type: {}, result_type: nil)
      @args_type = args_type
      @kwargs_type = kwargs_type
      @result_type = result_type
    end

    # @return [Array<String>]
    attr_reader :args_type

    # @return [Hash{String => String}]
    attr_reader :kwargs_type

    # @return [String, nil]
    attr_reader :result_type
  end

  # One plugin method: the Ruby callable that implements it, plus the
  # optional declared shape.
  class MethodSpec
    # @param body [#call] receives a {MethodArgs}; its return value is the
    #   result (a {MethodResult} is unwrapped, anything else used as-is)
    # @param type [MethodType, nil] the declared argument and result types
    def initialize(body:, type: nil)
      raise ArgumentError, "plugin method body must respond to #call" unless body.respond_to?(:call)

      @body = body
      @type = type
    end

    # @return [MethodType, nil]
    attr_reader :type

    # @param args [MethodArgs]
    # @return [Object] the result value, with a {MethodResult} unwrapped
    def call(args)
      result = @body.call(args)
      result.is_a?(MethodResult) ? result.value : result
    end
  end
end
