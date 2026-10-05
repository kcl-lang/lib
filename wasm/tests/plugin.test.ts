import { afterEach, expect, test } from "@jest/globals";

import {
  execProgram,
  getPlugin,
  hasPlugin,
  invokePluginJson,
  jsonError,
  load,
  parseMethodArgs,
  pluginMethodNames,
  pluginRegistered,
  registerPlugin,
  resetPlugin,
} from "../src";

afterEach(() => {
  resetPlugin();
});

const JOIN_SOURCE = 'import kcl_plugin.strings\n\nresult = strings.join("KCL", "KCL", 123)\n';
const ARGS_SOURCE =
  'import kcl_plugin.strings\n\nresult = strings.args("KCL", sep="-")\n';

test("registerPlugin keys methods under kcl_plugin.<name>.<method>", () => {
  registerPlugin({
    name: "strings",
    version: "1.0.0",
    methods: { join: { body: () => "joined" } },
  });

  expect(hasPlugin()).toBe(true);
  expect(pluginRegistered("strings", "join")).toBe(true);
  expect(pluginRegistered("strings", "missing")).toBe(false);
  expect(pluginRegistered("other", "join")).toBe(false);
  expect(pluginMethodNames()).toEqual(["kcl_plugin.strings.join"]);
  expect(getPlugin("strings")?.version).toBe("1.0.0");
  expect(getPlugin("nope")).toBeUndefined();
});

test("registerPlugin rejects an empty plugin name", () => {
  expect(() => registerPlugin({ name: "", methods: {} })).toThrow(
    "invalid plugin: empty name"
  );
});

test("resetPlugin empties the registry and runs the reset hooks", () => {
  const seen: string[] = [];
  registerPlugin({
    name: "a",
    resetFunc: () => seen.push("a"),
    methods: { m: { body: () => null } },
  });
  registerPlugin({
    name: "b",
    resetFunc: () => seen.push("b"),
    methods: { m: { body: () => null } },
  });

  resetPlugin();

  expect(hasPlugin()).toBe(false);
  expect(pluginMethodNames()).toEqual([]);
  expect(seen.sort()).toEqual(["a", "b"]);
});

test("parseMethodArgs treats an empty payload as empty", () => {
  expect(parseMethodArgs("", "")).toEqual({ args: [], kwargs: {} });
  expect(parseMethodArgs('["a", 1]', '{"b": true}')).toEqual({
    args: ["a", 1],
    kwargs: { b: true },
  });
});

test("invokePluginJson JSON-encodes the result", () => {
  registerPlugin({
    name: "strings",
    methods: {
      join: { body: (args) => args.args.join(".") },
      echo: { body: (args) => args },
    },
  });

  expect(invokePluginJson("kcl_plugin.strings.join", '["a","b"]', "")).toBe(
    '"a.b"'
  );
  expect(invokePluginJson("kcl_plugin.strings.echo", '["a"]', '{"b":1}')).toBe(
    '{"args":["a"],"kwargs":{"b":1}}'
  );
});

test("invokePluginJson reports failures as the PanicInfo envelope", () => {
  registerPlugin({
    name: "strings",
    methods: {
      boom: {
        body: () => {
          throw new Error("kaboom");
        },
      },
    },
  });

  expect(invokePluginJson("kcl_plugin.strings.boom", "", "")).toBe(
    jsonError("kaboom")
  );
  expect(invokePluginJson("kcl_plugin.strings.nope", "", "")).toBe(
    jsonError("invalid method: kcl_plugin.strings.nope, not found")
  );
  expect(invokePluginJson("", "", "")).toBe(jsonError("empty method"));
  expect(jsonError("x")).toBe('{"__kcl_PanicInfo__":"x"}');
});

test("KCL code reaches a registered plugin method", async () => {
  registerPlugin({
    name: "strings",
    version: "1.0.0",
    methods: {
      join: {
        type: { argsType: ["str", "str", "int"], resultType: "str" },
        body: (args) => args.args.join("."),
      },
    },
  });

  const instance = await load();
  const result = execProgram(instance, { kCodeList: [JOIN_SOURCE] });

  expect(result.errMessage).toBe("");
  expect(result.yamlResult).toBe("result: KCL.KCL.123");
});

test("a plugin method sees the exact positional and keyword arguments", async () => {
  let seen: { args: unknown[]; kwargs: Record<string, unknown> } | undefined;
  registerPlugin({
    name: "strings",
    methods: {
      args: {
        body: (args) => {
          seen = args;
          return `${args.args[0]}-${args.kwargs["sep"]}`;
        },
      },
    },
  });

  const instance = await load();
  const result = execProgram(instance, { kCodeList: [ARGS_SOURCE] });

  expect(seen).toEqual({ args: ["KCL"], kwargs: { sep: "-" } });
  expect(result.yamlResult).toBe("result: KCL--");
});

test("an unregistered method aborts the instance via the PanicInfo panic", async () => {
  registerPlugin({
    name: "strings",
    methods: { join: { body: () => "joined" } },
  });

  // The `__kcl_PanicInfo__` envelope makes the KCL evaluator `panic!`, and
  // this module is built with `panic=abort`, so the diagnostic cannot be
  // recovered into `errMessage` the way it is on the other bindings — it
  // surfaces as a wasm trap. Each test therefore needs a fresh instance.
  const instance = await load();
  expect(() =>
    execProgram(instance, {
      kCodeList: ['import kcl_plugin.strings\n\nresult = strings.missing()\n'],
    })
  ).toThrow(/KCL WASM trap/);
});

test("a throwing plugin method aborts the instance too", async () => {
  registerPlugin({
    name: "strings",
    methods: {
      join: {
        body: () => {
          throw new Error("plugin exploded");
        },
      },
    },
  });

  const instance = await load();
  expect(() =>
    execProgram(instance, { kCodeList: [JOIN_SOURCE] })
  ).toThrow(/KCL WASM trap/);
});

test("without a registered plugin the plugin import is still not reached", async () => {
  // Nothing registered: the stateless `call_native` path is used and KCL
  // rejects the import up front, exactly as before plugin support existed.
  expect(hasPlugin()).toBe(false);
  const instance = await load();
  expect(() =>
    execProgram(instance, { kCodeList: [JOIN_SOURCE] })
  ).toThrow(/plugin package .* is not found/);
});
