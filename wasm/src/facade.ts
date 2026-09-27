// High-level facade mirroring the ergonomic surface of kcl-go's `pkg/kcl`
// (and the Python/.NET/Node.js facades of this repo) on top of the typed
// WASM RPC wrappers in `./api`.
//
// Design notes (matching the constraints of the WASM binding):
// * Every entry point takes the `WebAssembly.Instance` first, like the
//   low-level wrappers. The WASM binding is not a process-wide singleton —
//   each instance carries its own WASI sandbox — so the facade is
//   explicitly instance-scoped. `new Kcl(instance)` exposes the same
//   entry points as instance methods.
// * `run` / `runFiles` are synchronous, following the low-level wrappers.
// * Failures raise `KclError` (an `Error` subclass); a non-empty runtime
//   `err_message` becomes the exception message, mirroring kcl-go's
//   `ExecResultToKCLResult`.
// * Execution goes through the typed `ExecProgram` RPC (the method is
//   registered in the WASM artifact even though the package historically
//   exposed only the string-based `invokeKCLRun` for execution), so
//   options like `format`, selectors and settings merging work end to end.
//   `invokeKCLRun` remains the leanest path for a single file with no
//   options.
// * `kcl.yaml` settings are resolved through the `LoadSettingsFiles` RPC
//   against the sandbox filesystem — no YAML parsing happens in
//   TypeScript and no YAML dependency is introduced. Settings values form
//   the base; explicit option keys win.
// * The Go `_type` rewrite hook (`hook.go`) is applied to the parsed value
//   view (`get` / `toObject`), not to the raw `yamlResult` / `jsonResult`
//   strings: re-rendering YAML in JS would require a YAML serializer, and
//   the runtime already emits schema names unqualified in single-package
//   programs, so the raw strings are left exactly as emitted.

import {
  Argument,
  ExecProgramArgs,
  ExecProgramResult,
  ExternalPkg,
  LoadSettingsFilesResult,
  execProgram,
  loadSettingsFiles,
  validateCode,
} from "./api";

/** Error raised by every facade entry point when a run fails. */
export class KclError extends Error {
  /** Runtime diagnostic code when present, e.g. `"E1001"`. */
  readonly code?: string;
  constructor(message?: string, options?: { cause?: unknown }) {
    super(message, options);
    this.name = "KclError";
    const match = /\bE\d{4}\b/.exec(message ?? "");
    if (match) {
      this.code = match[0];
    }
  }
}

/** Options accepted by {@link run} / {@link runFiles}. */
export interface RunOptions {
  /**
   * Working directory forwarded to the RPC. Note that inside the WASI
   * sandbox relative file paths resolve against the sandbox root (the
   * preopen), not against this field — prefer sandbox-absolute paths in
   * `paths` / `settings`.
   */
  workDir?: string;
  /**
   * CLI-style arguments (the `-D name=value` flag), e.g.
   * `["env=prod", 'replicas=3']`. Values are KCL literals, so strings
   * need quotes: `'name="bob"'`.
   */
  args?: string[];
  /** Override specs (the `-O` flag), appended to any settings-file overrides. */
  overrides?: string[];
  /** Path selectors (the `-S` flag), appended to any settings-file selectors. */
  selectors?: string[];
  /**
   * External packages (the `-E` flag), either `{ pkgName, pkgPath }`
   * entries or a plain name-to-path object.
   */
  externalPkgs?:
    | Array<{ pkgName: string; pkgPath: string }>
    | Record<string, string>;
  /**
   * `kcl.yaml` settings file path(s), resolved through the
   * `LoadSettingsFiles` RPC against the sandbox filesystem. The parsed
   * values form the base and explicit option keys win. When `code` is
   * passed to {@link run}, the settings-provided `files` are superseded
   * by it (only `kcl_options`, overrides and flags still apply).
   */
  settings?: string | string[];
  /** Toggle `disable_none` (the `-n` flag); explicit value wins over the settings file. */
  disableNone?: boolean;
  /** Include schema type paths in the rendered result; enables the `_type` rewrite (see {@link RunOptions.fullTypePath}). */
  includeSchemaTypePath?: boolean;
  /**
   * Keep `_type` values fully qualified (e.g. `"pkg.Person"`). Defaults
   * to `false`: when {@link RunOptions.includeSchemaTypePath} is enabled,
   * `_type` is rewritten to the bare schema name (last path segment),
   * mirroring kcl-go's `typeAttributeHook`. The rewrite applies to the
   * parsed value view (`get` / `toObject`); raw `yamlResult` /
   * `jsonResult` strings are returned exactly as the runtime emitted them.
   */
  fullTypePath?: boolean;
  /** Toggle `sort_keys` (the `-k` flag); explicit value wins over the settings file. */
  sortKeys?: boolean;
  /** Toggle `show_hidden` (the `-H` flag); explicit value wins over the settings file. */
  showHidden?: boolean;
  /** Diagnostic output format (`"pretty"`, `"short"`, `"arcanist"`, `"sarif"`). */
  errorFormat?: string;
  /**
   * Output format selector: `"json"` (JSON only) or `"yaml"` (YAML only).
   * When unset the runtime emits both. `get` / `toObject` require the JSON
   * result, so `format: "yaml"` restricts the facade to the raw
   * `yamlResult` string.
   */
  format?: string;
  /** Toggle `strict_range_check`; explicit value wins over the settings file. */
  strictRangeCheck?: boolean;
  /** Verbose level; explicit value wins over the settings file. */
  verbose?: number;
  /** Debug level (`boolean` maps to 1/0); explicit value wins over the settings file. */
  debug?: number | boolean;
  /** Print the override AST (mirrors kcl-go's `WithPrintOverridesAST`). */
  printOverrideAst?: boolean;
  /** Toggle `fast_eval`; explicit value wins over the settings file. */
  fastEval?: boolean;
}

// ---------------------------------------------------------------------------
// Options plumbing
// ---------------------------------------------------------------------------

interface ResolvedOptions {
  paths: string[];
  sources: string[];
  args: Argument[];
  overrides: string[];
  selectors: string[];
  externalPkgs: ExternalPkg[];
  workDir?: string;
  strictRangeCheck?: boolean;
  disableNone?: boolean;
  verbose?: number;
  debug?: number;
  sortKeys?: boolean;
  showHidden?: boolean;
  includeSchemaTypePath?: boolean;
  fullTypePath?: boolean;
  fastEval?: boolean;
  errorFormat?: string;
  format?: string;
  printOverrideAst?: boolean;
}

const BOOLEAN_OPTION_KEYS = [
  "disableNone",
  "sortKeys",
  "showHidden",
  "includeSchemaTypePath",
  "strictRangeCheck",
  "fastEval",
] as const;

function emptyBase(): ResolvedOptions {
  return {
    paths: [],
    sources: [],
    args: [],
    overrides: [],
    selectors: [],
    externalPkgs: [],
  };
}

function assertStringArray(value: string[], name: string): void {
  if (!Array.isArray(value) || value.some((item) => typeof item !== "string")) {
    throw new KclError(`options.${name} must be an array of strings`);
  }
}

function normalizeExternalPkgs(
  value: RunOptions["externalPkgs"]
): ExternalPkg[] {
  if (Array.isArray(value)) {
    for (const pkg of value) {
      if (
        !pkg ||
        typeof pkg.pkgName !== "string" ||
        typeof pkg.pkgPath !== "string"
      ) {
        throw new KclError(
          "options.externalPkgs entries must be { pkgName, pkgPath } objects"
        );
      }
    }
    return value.map((pkg) => ({ pkgName: pkg.pkgName, pkgPath: pkg.pkgPath }));
  }
  if (value && typeof value === "object") {
    // Convenience form: a plain { name: path } map (the `-E` flag).
    return Object.keys(value).map((name) => ({
      pkgName: name,
      pkgPath: (value as Record<string, string>)[name],
    }));
  }
  throw new KclError(
    "options.externalPkgs must be an array of { pkgName, pkgPath } or a name-to-path object"
  );
}

// Map a LoadSettingsFilesResult onto the base bag. Field correspondences:
//   kclCliConfigs.files            -> paths
//   kclCliConfigs.output           -> format ("json" / "yaml")
//   kclCliConfigs.overrides        -> overrides
//   kclCliConfigs.pathSelector     -> selectors
//   kclCliConfigs.<boolean flags>  -> strictRangeCheck, disableNone, sortKeys,
//                                     showHidden, includeSchemaTypePath, fastEval
//   kclCliConfigs.verbose          -> verbose
//   kclCliConfigs.debug            -> debug (0/1)
//   kclOptions [{key, value}]      -> args (values already serialized as
//                                     KCL literals by the runtime)
// Not mappable through the RPC: kcl_cli_configs.package_maps — the proto
// CliConfig message carries no packageMaps field, so external packages
// from settings files are silently dropped (same limitation as the other
// facades that parse via the RPC).
function applySettings(
  base: ResolvedOptions,
  loaded: LoadSettingsFilesResult
): void {
  const cfg = loaded.kclCliConfigs;
  for (const file of cfg.files) {
    if (file) {
      base.paths.push(file);
    }
  }
  if (cfg.output) {
    base.format = cfg.output;
  }
  for (const override of cfg.overrides) {
    if (override) {
      base.overrides.push(override);
    }
  }
  for (const selector of cfg.pathSelector) {
    if (selector) {
      base.selectors.push(selector);
    }
  }
  for (const key of BOOLEAN_OPTION_KEYS) {
    if (cfg[key]) {
      base[key] = true;
    }
  }
  if (cfg.verbose) {
    base.verbose = cfg.verbose;
  }
  if (cfg.debug) {
    base.debug = 1;
  }
  for (const option of loaded.kclOptions) {
    if (option && typeof option.key === "string" && option.key !== "") {
      base.args.push({ name: option.key, value: option.value ?? "" });
    }
  }
}

function resolveSettings(
  instance: WebAssembly.Instance,
  base: ResolvedOptions,
  settings: string | string[],
  workDir?: string
): void {
  const files = Array.isArray(settings) ? settings : [settings];
  if (
    files.length === 0 ||
    files.some((file) => typeof file !== "string" || file === "")
  ) {
    throw new KclError(
      "options.settings must be a non-empty string or an array of strings"
    );
  }
  const rpcWorkDir =
    typeof workDir === "string" && workDir !== "" ? workDir : ".";
  let loaded: LoadSettingsFilesResult;
  try {
    loaded = loadSettingsFiles(instance, {
      workDir: rpcWorkDir,
      files,
    });
  } catch (err) {
    throw toKclError(err);
  }
  applySettings(base, loaded);
}

function overlayOptions(
  base: ResolvedOptions,
  options: RunOptions,
  paths: string[],
  sources: string[]
): void {
  base.paths.push(...paths);
  base.sources.push(...sources);
  if (options.workDir !== undefined) {
    base.workDir = options.workDir;
  }
  if (options.args !== undefined) {
    assertStringArray(options.args, "args");
    for (const kv of options.args) {
      const index = kv.indexOf("=");
      if (index > 0) {
        base.args.push({
          name: kv.slice(0, index),
          value: kv.slice(index + 1),
        });
      }
    }
  }
  if (options.overrides !== undefined) {
    assertStringArray(options.overrides, "overrides");
    base.overrides.push(...options.overrides);
  }
  if (options.selectors !== undefined) {
    assertStringArray(options.selectors, "selectors");
    base.selectors.push(...options.selectors);
  }
  if (options.externalPkgs !== undefined) {
    base.externalPkgs.push(...normalizeExternalPkgs(options.externalPkgs));
  }
  for (const key of BOOLEAN_OPTION_KEYS) {
    if (options[key] !== undefined) {
      base[key] = Boolean(options[key]);
    }
  }
  if (options.fullTypePath !== undefined) {
    base.fullTypePath = Boolean(options.fullTypePath);
  }
  if (options.verbose !== undefined) {
    base.verbose = Number(options.verbose);
  }
  if (options.debug !== undefined) {
    base.debug =
      typeof options.debug === "number" ? options.debug : options.debug ? 1 : 0;
  }
  if (options.errorFormat !== undefined) {
    base.errorFormat = String(options.errorFormat);
  }
  if (options.format !== undefined) {
    base.format = String(options.format);
  }
  if (options.printOverrideAst !== undefined) {
    base.printOverrideAst = Boolean(options.printOverrideAst);
  }
}

function materialize(base: ResolvedOptions): {
  args: ExecProgramArgs;
  fullTypePath: boolean;
} {
  return {
    args: {
      workDir: base.workDir,
      kFilenameList: base.paths.length > 0 ? base.paths : undefined,
      kCodeList: base.sources.length > 0 ? base.sources : undefined,
      args: base.args.length > 0 ? base.args : undefined,
      overrides: base.overrides.length > 0 ? base.overrides : undefined,
      pathSelector: base.selectors.length > 0 ? base.selectors : undefined,
      externalPkgs:
        base.externalPkgs.length > 0 ? base.externalPkgs : undefined,
      strictRangeCheck: base.strictRangeCheck,
      disableNone: base.disableNone,
      verbose: base.verbose,
      debug: base.debug,
      sortKeys: base.sortKeys,
      showHidden: base.showHidden,
      includeSchemaTypePath: base.includeSchemaTypePath,
      fastEval: base.fastEval,
      errorFormat: base.errorFormat,
      format: base.format,
      printOverrideAst: base.printOverrideAst,
    },
    fullTypePath: base.fullTypePath ?? false,
  };
}

// ---------------------------------------------------------------------------
// Result helpers
// ---------------------------------------------------------------------------

const NO_JSON_HINT =
  'the runtime emitted YAML only (format "yaml"); value access requires the JSON result — ' +
  'drop `format: "yaml"` from the options or read `yamlResult` instead';

// Port of kcl-go's `modifyType` (hook.go): rewrite `_type` values to their
// last path segment in place. Applied to the parsed JSON value view.
function rewriteTypeAttributes(value: unknown): void {
  if (Array.isArray(value)) {
    for (const item of value) {
      rewriteTypeAttributes(item);
    }
    return;
  }
  if (value !== null && typeof value === "object") {
    const map = value as Record<string, unknown>;
    for (const key of Object.keys(map)) {
      if (key === "_type" && typeof map[key] === "string") {
        const parts = (map[key] as string).split(".");
        map[key] = parts[parts.length - 1];
      } else {
        rewriteTypeAttributes(map[key]);
      }
    }
  }
}

/** One evaluated configuration document. */
export class KclResult {
  private parsedValue: unknown;
  private parsed = false;

  constructor(
    private readonly raw: ExecProgramResult,
    private readonly fullTypePath: boolean
  ) {}

  /** The raw `yaml_result` string emitted by the runtime ("" when the run was JSON-only). */
  get yamlResult(): string {
    return this.raw.yamlResult;
  }

  /** The raw `json_result` string emitted by the runtime ("" when the run was YAML-only). */
  get jsonResult(): string {
    return this.raw.jsonResult;
  }

  /** Log output produced by the run, if any. */
  get logMessage(): string {
    return this.raw.logMessage;
  }

  /** The runtime error message ("" on success). Non-empty values are raised as {@link KclError} by {@link run} / {@link runFiles} before a result is returned. */
  get errMessage(): string {
    return this.raw.errMessage;
  }

  private parseValue(): unknown {
    if (this.parsed) {
      return this.parsedValue;
    }
    if (!this.raw.jsonResult) {
      throw new KclError(NO_JSON_HINT);
    }
    let value: unknown;
    try {
      value = JSON.parse(this.raw.jsonResult);
    } catch (err) {
      throw new KclError(
        `failed to parse KCL JSON result: ${
          err instanceof Error ? err.message : String(err)
        }`,
        { cause: err }
      );
    }
    // kcl-go's typeAttributeHook: with `include_schema_type_path` on and
    // `full_type_path` off (the default), strip `_type` to its last
    // segment. See the module header for why the raw strings are not
    // rewritten.
    if (!this.fullTypePath) {
      rewriteTypeAttributes(value);
    }
    this.parsedValue = value;
    this.parsed = true;
    return value;
  }

  /**
   * Look up `dottedPath` in the parsed document: dots navigate nested maps
   * (`"a.b.c"`), integer segments index into lists (`"a.0.b"`). Returns
   * `undefined` when any segment is missing. With no argument, returns the
   * whole document value.
   */
  get(dottedPath?: string): unknown {
    const value = this.parseValue();
    if (dottedPath === undefined || dottedPath === null) {
      return value;
    }
    let current = value;
    for (const segment of String(dottedPath).split(".")) {
      if (Array.isArray(current)) {
        const index = Number(segment);
        if (!Number.isInteger(index) || index < 0 || index >= current.length) {
          return undefined;
        }
        current = current[index];
      } else if (current !== null && typeof current === "object") {
        if (!Object.prototype.hasOwnProperty.call(current, segment)) {
          return undefined;
        }
        current = (current as Record<string, unknown>)[segment];
      } else {
        return undefined;
      }
    }
    return current;
  }

  /**
   * The document as a plain object; throws {@link KclError} when it is not
   * a map.
   */
  toObject(): Record<string, unknown> {
    const value = this.parseValue();
    if (value !== null && typeof value === "object" && !Array.isArray(value)) {
      return value as Record<string, unknown>;
    }
    throw new KclError(
      `failed to convert result to map: got ${
        Array.isArray(value) ? "list" : value === null ? "null" : typeof value
      }`
    );
  }
}

// Port of kcl-go's ExecResultToKCLResult: raise err_message, wrap the raw
// result for ergonomic access.
function wrapResult(resp: ExecProgramResult, fullTypePath: boolean): KclResult {
  if (resp.errMessage) {
    throw new KclError(resp.errMessage);
  }
  return new KclResult(resp, fullTypePath);
}

// ---------------------------------------------------------------------------
// Entry points
// ---------------------------------------------------------------------------

function runInternal(
  instance: WebAssembly.Instance,
  sources: string[],
  paths: string[],
  options?: RunOptions
): KclResult {
  if (
    options !== undefined &&
    (options === null || typeof options !== "object" || Array.isArray(options))
  ) {
    throw new KclError("options must be a plain object");
  }
  const opts = options ?? {};
  const base = emptyBase();
  if (opts.settings !== undefined) {
    resolveSettings(instance, base, opts.settings, opts.workDir);
  }
  overlayOptions(base, opts, paths, sources);
  if (base.sources.length > 0) {
    // Inline sources take precedence over settings-provided files. Mixing
    // k_code_list with k_filename_list makes the runtime treat the code as
    // the (replacement) content of those files — never what a caller of
    // run() wants. Everything else the settings file provided
    // (kcl_options, overrides, flags) still applies to the code.
    base.paths = [];
  }
  if (base.paths.length === 0 && base.sources.length === 0) {
    throw new KclError("kcl.Run: no kcl file or code");
  }
  const { args, fullTypePath } = materialize(base);
  let resp: ExecProgramResult;
  try {
    resp = execProgram(instance, args);
  } catch (err) {
    throw toKclError(err);
  }
  return wrapResult(resp, fullTypePath);
}

function normalizePaths(paths: string | string[]): string[] {
  const list = typeof paths === "string" ? [paths] : paths;
  if (!Array.isArray(list) || list.some((path) => typeof path !== "string")) {
    throw new KclError("paths must be a string or an array of strings");
  }
  return list.slice();
}

function toKclError(err: unknown): KclError {
  if (err instanceof KclError) {
    return err;
  }
  return new KclError(err instanceof Error ? err.message : String(err), {
    cause: err,
  });
}

/**
 * Evaluate in-memory KCL `code` and return the parsed document.
 * Throws {@link KclError} on any failure (compile/eval error, transport
 * error or non-empty runtime `err_message`).
 */
export function run(
  instance: WebAssembly.Instance,
  code: string,
  options?: RunOptions
): KclResult {
  if (typeof code !== "string") {
    throw new KclError("code must be a string");
  }
  return runInternal(instance, [code], [], options);
}

/**
 * Evaluate the KCL file(s) at `paths` (a sandbox path or array of paths,
 * e.g. `"/work/main.k"` with a `MemFS` sandbox). Throws {@link KclError} on
 * any failure.
 */
export function runFiles(
  instance: WebAssembly.Instance,
  paths: string | string[],
  options?: RunOptions
): KclResult {
  return runInternal(instance, [], normalizePaths(paths), options);
}

/**
 * Validate `data` (a YAML or JSON string) against the schema in `code`.
 * Returns `true` when the data conforms. Mirrors the Python facade's
 * `validate_code`.
 */
export function validate(
  instance: WebAssembly.Instance,
  code: string,
  data: string,
  format = "yaml"
): boolean {
  if (typeof code !== "string") {
    throw new KclError("code must be a string");
  }
  if (typeof data !== "string") {
    throw new KclError("data must be a string");
  }
  let resp: { success: boolean; errMessage: string };
  try {
    resp = validateCode(instance, { code, data, format });
  } catch (err) {
    throw toKclError(err);
  }
  return resp.success;
}

/**
 * Instance-scoped facade: `new Kcl(inst)` exposes {@link run},
 * {@link runFiles} and {@link validate} as methods. The instance is
 * supplied once at construction; all methods are synchronous.
 */
export class Kcl {
  constructor(private readonly instance: WebAssembly.Instance) {}

  /** Instance form of {@link run}; identical behaviour. */
  run(code: string, options?: RunOptions): KclResult {
    return run(this.instance, code, options);
  }

  /** Instance form of {@link runFiles}; identical behaviour. */
  runFiles(paths: string | string[], options?: RunOptions): KclResult {
    return runFiles(this.instance, paths, options);
  }

  /** Instance form of {@link validate}; identical behaviour. */
  validate(code: string, data: string, format?: string): boolean {
    return validate(this.instance, code, data, format);
  }
}
