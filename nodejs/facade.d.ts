/**
 * High-level facade over the low-level napi-rs RPC bindings, mirroring the
 * ergonomic surface of kcl-go's `pkg/kcl`: `Kcl.run` / `Kcl.runFiles` take
 * a plain options object, return a `KclResultList` and raise `KclError` on
 * any failure.
 *
 * ```ts
 * import { Kcl } from '@kcl-lib/native/facade.js'
 *
 * const result = Kcl.run('a = 1\nb = {c = 2}')
 * result.first().get('b.c') // 2
 * ```
 */

/** Error raised by every facade entry point when a run fails. */
export class KclError extends Error {
  /** Runtime diagnostic code when present, e.g. `"E1001"`. */
  code?: string
  /** Original error when the facade wraps a lower-level failure. */
  cause?: unknown
  constructor(message?: string, options?: { cause?: unknown })
}

/** Options accepted by {@link Kcl.run} / {@link Kcl.runFiles}. */
export interface KclOptions {
  /**
   * Working directory for the evaluation. Also used to resolve relative
   * `settings` files and relative `files` entries inside them.
   */
  workDir?: string
  /** Override specs (the `-O` flag), appended to any settings-file overrides. */
  overrides?: string[]
  /** Path selectors (the `-S` flag), appended to any settings-file selectors. */
  selectors?: string[]
  /** Toggle `disable_none` (the `-n` flag); explicit value wins over the settings file. */
  disableNone?: boolean
  /** Toggle `sort_keys` (the `-k` flag); explicit value wins over the settings file. */
  sortKeys?: boolean
  /** Toggle `show_hidden` (the `-H` flag); explicit value wins over the settings file. */
  showHidden?: boolean
  /** Toggle `include_schema_type_path`; explicit value wins over the settings file. */
  includeSchemaTypePath?: boolean
  /** Toggle `strict_range_check`; explicit value wins over the settings file. */
  strictRangeCheck?: boolean
  /** Verbose level; explicit value wins over the settings file. */
  verbose?: number
  /** Debug flag (mapped to the runtime's 0/1 field); explicit value wins over the settings file. */
  debug?: boolean
  /** Diagnostic output format (`"pretty"`, `"short"`, `"arcanist"`, `"sarif"`). */
  errorFormat?: string
  /** Output format: `"json"` (JSON-only) or `"yaml"` (YAML-only). Defaults to both. */
  format?: 'json' | 'yaml' | string
  /**
   * External packages (the `-E` flag), either native `{ pkgName, pkgPath }`
   * entries or a plain name-to-path object.
   */
  externalPkgs?: Array<{ pkgName: string; pkgPath: string }> | Record<string, string>
  /**
   * `kcl.yaml` settings file path(s). Resolved through the native
   * `loadSettingsFiles` RPC (no YAML parsing in JS); the parsed values form
   * the base and explicit option keys win. When `code` is passed to
   * {@link Kcl.run}, the settings-provided `files` are superseded by it
   * (only `kcl_options`, overrides and flags still apply). Note:
   * `package_maps` entries in settings files are not visible through the RPC
   * and are ignored, and `${PWD}` placeholders in `files` are not expanded
   * by the native loader.
   */
  settings?: string | string[]
}

/** One evaluated configuration document. */
export class KclResult {
  /** The parsed document value (plain object / array / scalar), or `undefined` when the run was YAML-only. */
  readonly value?: unknown
  /** The YAML rendering of this document as emitted by the runtime ("" when the run was JSON-only). */
  readonly yamlString: string
  /** The JSON rendering of this document's value. */
  readonly jsonString: string
  constructor(value?: unknown, yamlDocument?: string, jsonDocument?: string)
  /**
   * Look up `dottedPath` in the parsed document: dots navigate nested maps
   * (`"a.b.c"`), integer segments index into lists (`"a.0.b"`). Returns
   * `undefined` when any segment is missing.
   */
  get(dottedPath?: string): unknown
  /** The document as a plain object; throws `KclError` when it is not a map. */
  toMap(): Record<string, unknown>
  /** The document as an array; throws `KclError` when it is not a list. */
  toList(): unknown[]
}

/**
 * The documents produced by a run. Array semantics (`length`, indexing,
 * iteration, spread) over {@link KclResult} items; derived arrays (`map`,
 * `filter`, ...) are plain `Array`s.
 */
export class KclResultList extends Array<KclResult> {
  constructor(results?: KclResult[], raw?: unknown)
  /** First document, or `undefined` when empty. */
  first(): KclResult | undefined
  /** Last document, or `undefined` when empty. */
  last(): KclResult | undefined
  /** Document at `index`, or `undefined` when out of range. */
  get(index: number): KclResult | undefined
  /** The raw `json_result` string emitted by the runtime ("" when unavailable). */
  getRawJsonResult(): string
  /** The raw `yaml_result` string emitted by the runtime ("" when unavailable). */
  getRawYamlResult(): string
  /** Log output produced by the run, if any. */
  readonly logMessage: string
}

/** High-level KCL facade. */
export class Kcl {
  /**
   * Evaluate in-memory KCL `code` and return the parsed documents.
   * Throws {@link KclError} on any failure (compile/eval error, transport
   * error or non-empty runtime `err_message`).
   */
  static run(code: string, options?: KclOptions): KclResultList
  /** Evaluate the KCL file(s) at `paths` (a string or array). Throws {@link KclError} on any failure. */
  static runFiles(paths: string | string[], options?: KclOptions): KclResultList
  /** Instance form of {@link Kcl.run}; identical behaviour (the facade is stateless). */
  run(code: string, options?: KclOptions): KclResultList
  /** Instance form of {@link Kcl.runFiles}; identical behaviour. */
  runFiles(paths: string | string[], options?: KclOptions): KclResultList
}

/** Functional alias of `Kcl.run`. */
export function run(code: string, options?: KclOptions): KclResultList
/** Functional alias of `Kcl.runFiles`. */
export function runFiles(paths: string | string[], options?: KclOptions): KclResultList

/**
 * Split a YAML stream into its documents on `---` separator lines (trailing
 * whitespace or `#` comments allowed), mirroring kcl-go's exported
 * `SplitDocuments`. Anything else on the separator line raises `KclError`.
 */
export function splitDocuments(text: string): string[]
