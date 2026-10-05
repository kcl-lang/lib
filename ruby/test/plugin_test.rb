# frozen_string_literal: true

require "json"
require "minitest/autorun"

require "kcl_lib"

# Tests for the KCL plugin registry (`lib/kcl_lib/plugin.rb`).
#
# The registry has two halves and both are exercised here. `call_method` is
# the Ruby half of the C handler on its own: the name lookup, the argument
# decoding and the panic-info reply are all pure Ruby and can be driven
# directly. The `KclLib::Kcl.run` cases go through the whole path — the
# Fiddle trampoline, the address handed to `call_with_plugin_agent`, and the
# runtime dispatching an actual `kcl_plugin.*` import.
#
# The registry is process-wide, so every test starts and ends from a clean
# one: a plugin left behind here would otherwise be reachable from a case
# that expects a method not to exist.
class PluginTest < Minitest::Test
  def setup
    KclLib::PluginContext.reset!
  end

  def teardown
    # `reset!` only runs the plugins' hooks, so the registry itself has to be
    # cleared to keep the cases independent.
    KclLib::PluginContext.clear!
  end

  def register(name, methods, **rest)
    KclLib::PluginContext.register_plugin(KclLib::Plugin.new(name: name, methods: methods, **rest))
  end

  def run_kcl(code)
    KclLib::Kcl.run(code).first
  end

  # ------------------------------------------------------------------ #
  # Registry
  # ------------------------------------------------------------------ #

  def test_registers_under_the_qualified_name
    register("my_plugin", { "add" => ->(args) { args.arg(0) + args.arg(1) } })

    assert_equal ["my_plugin"], KclLib::PluginContext.plugin_names
    spec = KclLib::PluginContext.get_method_spec("kcl_plugin.my_plugin.add")
    assert_kind_of KclLib::MethodSpec, spec
    assert_equal 3, spec.call(KclLib::MethodArgs.new([1, 2]))
    assert_nil KclLib::PluginContext.get_plugin("other")
  end

  def test_method_result_is_unwrapped_but_a_bare_value_is_not
    register("my_plugin", { "wrapped" => ->(_args) { KclLib::MethodResult.new(7) } })

    assert_equal "7", KclLib::PluginContext.call_method("kcl_plugin.my_plugin.wrapped")
  end

  def test_declared_type_does_not_change_the_call
    # `MethodType` documents a method; it never validates one. A body that
    # takes no arguments is still called with the argument object.
    spec = KclLib::MethodSpec.new(
      body: ->(_args) { "ok" },
      type: KclLib::MethodType.new(args_type: ["int"], result_type: "str")
    )
    register("my_plugin", { "typed" => spec })

    assert_equal ["int"], spec.type.args_type
    assert_equal '"ok"', KclLib::PluginContext.call_method("kcl_plugin.my_plugin.typed", "[1]", "")
  end

  def test_reset_runs_every_plugin_hook
    calls = []
    register("a", { "noop" => ->(_args) { nil } }, reset: -> { calls << :a })
    register("b", { "noop" => ->(_args) { nil } }, reset: -> { calls << :b })

    KclLib::PluginContext.reset!

    assert_equal %i[a b], calls
  end

  def test_re_registering_a_plugin_replaces_its_methods
    register("my_plugin", { "a" => ->(_args) { 1 }, "b" => ->(_args) { 2 } })
    register("my_plugin", { "a" => ->(_args) { 9 } })

    assert_equal ["my_plugin"], KclLib::PluginContext.plugin_names
    assert_equal 9, KclLib::PluginContext.call_method("kcl_plugin.my_plugin.a", "", "").to_i
    # "b" was given up by the second registration and must stop answering
    # rather than keep running the first registration's body.
    assert_nil KclLib::PluginContext.get_method_spec("kcl_plugin.my_plugin.b")
    assert_includes KclLib::PluginContext.call_method("kcl_plugin.my_plugin.b"), "__kcl_PanicInfo__"
  end

  def test_clear_takes_the_client_off_the_plugin_path_again
    register("my_plugin", { "add" => ->(args) { args.arg(0) } })
    assert_operator KclLib::PluginContext.agent_addr, :>, 0

    KclLib::PluginContext.clear!

    assert_empty KclLib::PluginContext.plugin_names
    assert_nil KclLib::PluginContext.get_method_spec("kcl_plugin.my_plugin.add")
    refute KclLib::PluginContext.methods?
    assert_equal 0, KclLib::PluginContext.agent_addr
  end

  def test_empty_plugin_name_is_rejected
    assert_raises(ArgumentError) { KclLib::Plugin.new(name: "", methods: {}) }
  end

  # ------------------------------------------------------------------ #
  # Arguments
  # ------------------------------------------------------------------ #

  def test_positional_and_keyword_arguments
    seen = nil
    register("probe", { "args" => ->(args) { seen = args } })

    KclLib::PluginContext.call_method("kcl_plugin.probe.args", '["a", 2]', '{"b": true}')

    assert_equal ["a", 2], seen.args
    assert_equal({ "b" => true }, seen.kwargs)
    # A keyword wins over the position it could have come from, which is what
    # lets one body read a call written either way.
    assert_equal true, seen.call_arg(0, "b")
    assert_equal "a", seen.call_arg(0, "a")
    assert_nil seen.call_arg(9, "missing")
  end

  def test_empty_payloads_mean_no_arguments
    seen = nil
    register("probe", { "args" => ->(args) { seen = args } })

    KclLib::PluginContext.call_method("kcl_plugin.probe.args")

    assert_empty seen.args
    assert_empty seen.kwargs
  end

  def test_typed_accessors_convert
    seen = nil
    register("probe", { "args" => ->(args) { seen = args } })

    KclLib::PluginContext.call_method(
      "kcl_plugin.probe.args",
      '["3", 1.5, "x", [1], {"k": "v"}]',
      '{"n": "4", "f": "2.5", "s": "y", "l": [2], "m": {"z": 1}}'
    )

    assert_equal 3, seen.int_arg(0)
    assert_in_delta 1.5, seen.float_arg(1)
    assert_equal "x", seen.str_arg(2)
    assert_equal [1], seen.list_arg(3)
    assert_equal({ "k" => "v" }, seen.map_arg(4))
    assert_equal 4, seen.int_kwarg("n")
    assert_in_delta 2.5, seen.float_kwarg("f")
    assert_equal "y", seen.str_kwarg("s")
    assert_equal [2], seen.list_kwarg("l")
    assert_equal({ "z" => 1 }, seen.map_kwarg("m"))
  end

  # ------------------------------------------------------------------ #
  # Failures are data
  # ------------------------------------------------------------------ #

  def test_unknown_method_reports_a_panic_info
    register("my_plugin", { "add" => ->(args) { args.arg(0) } })

    reply = JSON.parse(KclLib::PluginContext.call_method("kcl_plugin.my_plugin.nope", "[1]", ""))

    assert_equal ["__kcl_PanicInfo__"], reply.keys
    assert_includes reply["__kcl_PanicInfo__"], "kcl_plugin.my_plugin.nope"
  end

  def test_empty_method_name_reports_a_panic_info
    register("my_plugin", { "add" => ->(args) { args.arg(0) } })

    reply = JSON.parse(KclLib::PluginContext.call_method(""))

    assert_includes reply["__kcl_PanicInfo__"], "empty method"
  end

  def test_a_raising_body_reports_a_panic_info
    register("my_plugin", { "boom" => ->(_args) { raise "plugin error" } })

    reply = JSON.parse(KclLib::PluginContext.call_method("kcl_plugin.my_plugin.boom"))

    assert_equal "plugin error", reply["__kcl_PanicInfo__"]
  end

  def test_a_malformed_payload_reports_a_panic_info
    register("my_plugin", { "add" => ->(args) { args.arg(0) } })

    not_json = JSON.parse(KclLib::PluginContext.call_method("kcl_plugin.my_plugin.add", "not json", ""))
    assert_includes not_json["__kcl_PanicInfo__"], "not json"

    # A well-formed JSON document of the wrong shape is a different failure
    # and says so, rather than reaching the body as a positional list.
    wrong_shape = JSON.parse(
      KclLib::PluginContext.call_method("kcl_plugin.my_plugin.add", '{"a": 1}', "")
    )
    assert_includes wrong_shape["__kcl_PanicInfo__"], "must be a JSON array"
  end

  # ------------------------------------------------------------------ #
  # Through the C trampoline
  # ------------------------------------------------------------------ #

  # With nothing registered the client must stay on the stateless
  # dispatcher, because the runtime only enables plugin loading for a
  # non-zero agent. A fresh context stands in for a process that has never
  # registered anything: the singleton in this process has already built its
  # trampoline and, being process-wide, keeps it.
  def test_an_empty_registry_leaves_the_client_on_the_plain_dispatcher
    assert_equal 0, KclLib::PluginContext.new.agent_addr
  end

  def test_the_agent_address_is_stable
    register("my_plugin", { "add" => ->(args) { args.arg(0) } })
    first = KclLib::API.new.plugin_agent

    assert_operator first, :>, 0
    # Two clients, and a second call, must agree: the runtime keeps this
    # address in a global, so it cannot be rebuilt per client.
    assert_equal first, KclLib::API.new.plugin_agent
    assert_equal first, KclLib::PluginContext.agent_addr
  end

  def test_explicit_agent_wins
    register("my_plugin", { "add" => ->(args) { args.arg(0) } })

    assert_equal 1234, KclLib::API.new(plugin_agent: 1234).plugin_agent
  end

  def test_routes_a_kcl_call_into_a_registered_ruby_method
    register("my_plugin", { "add" => ->(args) { args.arg(0) + args.arg(1) } })

    result = run_kcl("import kcl_plugin.my_plugin\nresult = my_plugin.add(1, 2)\n")

    assert_equal 3, result.get("result")
  end

  def test_receives_keyword_arguments_from_kcl
    seen = nil
    register("probe", { "echo" => ->(args) { seen = args; [args.arg(0), args.kwarg("b")] } })

    result = run_kcl("import kcl_plugin.probe\nresult = probe.echo(\"a\", b = 2)\n")

    assert_equal ["a"], seen.args
    assert_equal 2, seen.kwargs["b"]
    assert_equal ["a", 2], result.get("result")
  end

  def test_an_unknown_method_surfaces_as_a_kcl_error
    register("my_plugin", { "add" => ->(args) { args.arg(0) } })
    api = KclLib::API.new

    result = api.exec_program(
      KclLib::ExecProgramArgs.new(k_code_list: ["import kcl_plugin.my_plugin\nresult = my_plugin.nope()"])
    )

    assert_includes result.err_message, "kcl_plugin.my_plugin.nope"
  end

  def test_a_raising_body_surfaces_as_a_kcl_error
    register("my_plugin", { "boom" => ->(_args) { raise "plugin error" } })
    api = KclLib::API.new

    result = api.exec_program(
      KclLib::ExecProgramArgs.new(k_code_list: ["import kcl_plugin.my_plugin\nresult = my_plugin.boom()"])
    )

    assert_includes result.err_message, "plugin error"
  end

  # The runtime stores the handler address in a global the first time a
  # plugin is reached, so emptying the registry must not invalidate the C
  # pointer — a later registration has to be reachable through the very same
  # trampoline.
  def test_the_trampoline_outlives_the_registration_that_built_it
    register("my_plugin", { "add" => ->(args) { args.arg(0) + args.arg(1) } })
    addr = KclLib::PluginContext.agent_addr
    teardown
    register("other", { "double" => ->(args) { args.arg(0) * 2 } })

    assert_equal addr, KclLib::PluginContext.agent_addr
    result = run_kcl("import kcl_plugin.other\nresult = other.double(21)\n")

    assert_equal 42, result.get("result")
  end
end
