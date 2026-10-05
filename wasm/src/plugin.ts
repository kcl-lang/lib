/**
 * KCL plugin support for the WASM binding.
 *
 * KCL source calls host functions through the `kcl_plugin.<plugin>.<method>`
 * name space:
 *
 * ```kcl
 * import kcl_plugin.strings
 *
 * result = strings.join("KCL", "KCL", 123)
 * ```
 *
 * The runtime resolves the call to the absolute method name
 * `kcl_plugin.strings.join`, hands the host the method name plus the
 * JSON-encoded positional and keyword arguments, and reads back a
 * JSON-encoded result (docs/abi.md §7). Register the method once at
 * start-up — the same shape as Go's `plugin.RegisterPlugin` from `init()`
 * — and every KCL evaluation afterwards can reach it:
 *
 * ```ts
 * import { load, registerPlugin } from "@kcl-lib/wasm";
 *
 * registerPlugin({
 *   name: "strings",
 *   version: "1.0.0",
 *   methods: {
 *     join: { body: (args) => args.args.join(".") },
 *   },
 * });
 *
 * const instance = await load();
 * execProgram(instance, { kCodeList: [kclSource] });
 * ```
 *
 * Two properties are worth calling out:
 *
 * - **Arguments and results are JSON, not KCL values.** A method that
 *   ignores its arguments needs no parsing at all. The typed accessors on
 *   {@link MethodArgs} are a convenience, not a requirement.
 * - **Errors are data, not crashes.** A method that is not registered, or
 *   one that throws, answers with a
 *   `{"__kcl_PanicInfo__": "<message>"}` object, which the KCL runtime
 *   turns into a clean evaluator panic. The KCL program then fails with
 *   that message in its `errMessage` instead of crashing the host.
 *
 * Registering the first method switches the typed API from the stateless
 * `call_native` entry point to the service-handle path that can carry the
 * plugin agent, exactly like the C binding. With nothing registered the
 * stateless path is used, so programs that do not use plugins are
 * unaffected.
 */

/**
 * The single key the KCL runtime inspects on a plugin reply. A reply
 * carrying it is turned into an evaluator panic with the value as its
 * message, so it must only ever be produced for genuine failures.
 */
export const PANIC_INFO_KEY = "__kcl_PanicInfo__";

/** Prefix the KCL module names are resolved under. */
const PLUGIN_MODULE_PREFIX = "kcl_plugin.";

/** The argument payload a plugin method receives. */
export interface MethodArgs {
  /** Positional arguments, in call order. */
  args: unknown[];
  /** Keyword arguments, keyed by name. */
  kwargs: Record<string, unknown>;
}

/** Declared shape of a plugin method, for hosts that want to validate. */
export interface MethodType {
  /** KCL type names of the positional arguments, e.g. `["str", "str"]`. */
  argsType?: string[];
  /** KCL type names of the keyword arguments, keyed by name. */
  kwArgsType?: Record<string, string>;
  /** KCL type name of the result. */
  resultType?: string;
}

/** One registered method of a plugin. */
export interface MethodSpec {
  /** Optional declaration of the method's KCL types. */
  type?: MethodType;
  /**
   * The method implementation. Its return value is JSON-encoded and handed
   * back to the KCL runtime; throwing reports the error to the KCL program
   * as a panic message.
   */
  body: (args: MethodArgs) => unknown;
}

/** A registered plugin: a name, a version and its methods. */
export interface Plugin {
  /** Name of the plugin, the second component of `kcl_plugin.<name>`. */
  name: string;
  /** Version of the plugin, for hosts that report it. */
  version?: string;
  /** Optional hook run by {@link resetPlugin}. */
  resetFunc?: () => void;
  /** Methods keyed by the third component of the absolute method name. */
  methods: Record<string, MethodSpec>;
}

const plugins = new Map<string, Plugin>();
const methodSpecs = new Map<string, MethodSpec>();

/**
 * Register a KCL plugin, adding a `kcl_plugin.<plugin.name>.<method>`
 * entry for each of its methods. Re-registering a plugin name replaces the
 * previous one, method by method.
 */
export function registerPlugin(plugin: Plugin): void {
  if (!plugin.name) {
    throw new Error("invalid plugin: empty name");
  }
  plugins.set(plugin.name, plugin);
  for (const [methodName, methodSpec] of Object.entries(plugin.methods)) {
    methodSpecs.set(PLUGIN_MODULE_PREFIX + plugin.name + "." + methodName, methodSpec);
  }
}

/** Get a registered plugin by name. */
export function getPlugin(name: string): Plugin | undefined {
  return plugins.get(name);
}

/** Get a registered method spec by its absolute method name. */
export function getMethodSpec(methodName: string): MethodSpec | undefined {
  return methodSpecs.get(methodName);
}

/**
 * Whether `kcl_plugin.<plugin>.<method>` resolves to a registered method.
 * Mirrors `kcl_plugin_registered` in the C binding.
 */
export function pluginRegistered(pluginName: string, methodName: string): boolean {
  return methodSpecs.has(PLUGIN_MODULE_PREFIX + pluginName + "." + methodName);
}

/** Every registered absolute method name, in registration order. */
export function pluginMethodNames(): string[] {
  return [...methodSpecs.keys()];
}

/**
 * Whether any plugin method is registered. The typed API uses this to
 * decide between the stateless `call_native` path and the service-handle
 * path that can carry the plugin agent.
 */
export function hasPlugin(): boolean {
  return methodSpecs.size > 0;
}

/**
 * Drop every registered method (running each plugin's `resetFunc` first),
 * returning the binding to the stateless `call_native` dispatch. Mirrors
 * Go's `plugin.ResetPlugin` and the C binding's `kcl_plugin_disable`.
 */
export function resetPlugin(): void {
  for (const plugin of plugins.values()) {
    plugin.resetFunc?.();
  }
  plugins.clear();
  methodSpecs.clear();
}

/**
 * Render an error as the JSON envelope the KCL runtime turns into a
 * panic. Mirrors Go's `plugin.JSONError`.
 */
export function jsonError(message: string): string {
  return JSON.stringify({ [PANIC_INFO_KEY]: message });
}

/**
 * Parse the JSON-encoded positional and keyword arguments the runtime
 * passes to the plugin agent. An empty string yields an empty list /
 * object, matching the runtime's "no arguments" encoding.
 */
export function parseMethodArgs(argsJson: string, kwargsJson: string): MethodArgs {
  const args: unknown[] = argsJson ? (JSON.parse(argsJson) as unknown[]) : [];
  const kwargs: Record<string, unknown> = kwargsJson
    ? (JSON.parse(kwargsJson) as Record<string, unknown>)
    : {};
  return { args, kwargs };
}

/**
 * Look up `method` in the registry, run it with the decoded arguments and
 * return the JSON-encoded result — or the {@link jsonError} envelope when
 * the method is unknown or fails. Mirrors Go's `plugin.InvokeJson`.
 */
export function invokePluginJson(
  method: string,
  argsJson: string,
  kwargsJson: string
): string {
  try {
    if (!method) {
      return jsonError("empty method");
    }
    const methodSpec = getMethodSpec(method);
    if (!methodSpec) {
      return jsonError(`invalid method: ${method}, not found`);
    }
    const args = parseMethodArgs(argsJson, kwargsJson);
    return JSON.stringify(methodSpec.body(args) ?? null);
  } catch (error) {
    return jsonError(error instanceof Error ? error.message : String(error));
  }
}

/**
 * Retrieve an argument by index or by keyword name: the keyword wins when
 * the call passed it by name. Returns `undefined` when neither is present.
 */
export function getCallArg(
  args: MethodArgs,
  index: number,
  key: string
): unknown {
  if (key in args.kwargs) {
    return args.kwargs[key];
  }
  return args.args[index];
}

/** The positional argument at `index`. */
export function arg(args: MethodArgs, index: number): unknown {
  return args.args[index];
}

/** The keyword argument named `name`. */
export function kwArg(args: MethodArgs, name: string): unknown {
  return args.kwargs[name];
}

/** The positional argument at `index` as a string. */
export function strArg(args: MethodArgs, index: number): string {
  return String(args.args[index]);
}

/** The keyword argument named `name` as a string. */
export function strKwArg(args: MethodArgs, name: string): string {
  return String(args.kwargs[name]);
}

/** The positional argument at `index` as an integer. */
export function intArg(args: MethodArgs, index: number): number {
  return Number.parseInt(String(args.args[index]), 10);
}

/** The keyword argument named `name` as an integer. */
export function intKwArg(args: MethodArgs, name: string): number {
  return Number.parseInt(String(args.kwargs[name]), 10);
}

/** The positional argument at `index` as a float. */
export function floatArg(args: MethodArgs, index: number): number {
  return Number.parseFloat(String(args.args[index]));
}

/** The keyword argument named `name` as a float. */
export function floatKwArg(args: MethodArgs, name: string): number {
  return Number.parseFloat(String(args.kwargs[name]));
}

/** The positional argument at `index` as a boolean. */
export function boolArg(args: MethodArgs, index: number): boolean {
  const value = args.args[index];
  if (typeof value === "boolean") {
    return value;
  }
  const text = String(value).toLowerCase();
  return text === "true" || text === "1";
}

/** The keyword argument named `name` as a boolean. */
export function boolKwArg(args: MethodArgs, name: string): boolean {
  return boolArg({ args: [args.kwargs[name]], kwargs: {} }, 0);
}

/** The positional argument at `index` as a list. */
export function listArg(args: MethodArgs, index: number): unknown[] {
  return args.args[index] as unknown[];
}

/** The keyword argument named `name` as a list. */
export function listKwArg(args: MethodArgs, name: string): unknown[] {
  return args.kwargs[name] as unknown[];
}

/** The positional argument at `index` as a string-keyed object. */
export function mapArg(
  args: MethodArgs,
  index: number
): Record<string, unknown> {
  return args.args[index] as Record<string, unknown>;
}

/** The keyword argument named `name` as a string-keyed object. */
export function mapKwArg(
  args: MethodArgs,
  name: string
): Record<string, unknown> {
  return args.kwargs[name] as Record<string, unknown>;
}
