'use strict'

// High-level facade mirroring the ergonomic surface of kcl-go's `pkg/kcl`
// (and the Python/Java/Kotlin/.NET facades of this repo) on top of the
// low-level napi-rs RPC bindings exported by `./index.js`.
//
// Design notes (JavaScript-first, not a kcl-go transliteration):
// * `Kcl.run(code, options?)` / `Kcl.runFiles(paths, options?)` are static
//   and synchronous, matching the underlying binding. `new Kcl()` also works
//   (instances are stateless delegates) but the static form is canonical.
// * Options are a single plain object (`KclOptions`) instead of functional
//   options or a builder.
// * Failures raise `KclError` (an `Error` subclass) instead of returning
//   `(result, err)` tuples.
// * `kcl.yaml` settings are resolved through the native `loadSettingsFiles`
//   RPC — no YAML parsing happens in JavaScript and no YAML dependency is
//   introduced. Settings values form the base; explicit option keys win.

const native = require('./index.js')

/** Error raised by every facade entry point when a run fails. */
class KclError extends Error {
  constructor(message, cause) {
    super(message)
    this.name = 'KclError'
    if (cause !== undefined) {
      this.cause = cause
    }
    // Runtime diagnostics carry an error code ("E1001", ...); surface it.
    const match = /\bE\d{4}\b/.exec(message || '')
    if (match) {
      this.code = match[0]
    }
  }
}

function toKclError(err) {
  if (err instanceof KclError) {
    return err
  }
  return new KclError((err && err.message) || String(err), err)
}

// ---------------------------------------------------------------------------
// Options plumbing
// ---------------------------------------------------------------------------

const BOOLEAN_OPTION_KEYS = [
  'disableNone',
  'sortKeys',
  'showHidden',
  'includeSchemaTypePath',
  'strictRangeCheck',
  'fastEval',
]

function assertStringArray(value, name) {
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string')) {
    throw new KclError(`options.${name} must be an array of strings`)
  }
}

function normalizeExternalPkgs(value) {
  if (Array.isArray(value)) {
    for (const pkg of value) {
      if (!pkg || typeof pkg.pkgName !== 'string' || typeof pkg.pkgPath !== 'string') {
        throw new KclError('options.externalPkgs entries must be { pkgName, pkgPath } objects')
      }
    }
    return value.map((pkg) => ({ pkgName: pkg.pkgName, pkgPath: pkg.pkgPath }))
  }
  if (value && typeof value === 'object') {
    // Convenience form: a plain { name: path } map (the `-E` flag).
    return Object.keys(value).map((name) => ({ pkgName: name, pkgPath: value[name] }))
  }
  throw new KclError('options.externalPkgs must be an array of { pkgName, pkgPath } or a name-to-path object')
}

// Base bag populated from the settings RPC, then overlaid with explicit
// options. Mirrors kcl-go's `Option.Merge` semantics: repeated fields append,
// explicit scalars overwrite (last wins). Unlike kcl-go, JavaScript options
// can express `false`, so explicit booleans always win over the file.
function emptyBase() {
  return {
    paths: [],
    sources: [],
    args: [],
    overrides: [],
    selectors: [],
    externalPkgs: [],
    workDir: undefined,
    strictRangeCheck: undefined,
    disableNone: undefined,
    verbose: undefined,
    debug: undefined,
    sortKeys: undefined,
    showHidden: undefined,
    includeSchemaTypePath: undefined,
    fastEval: undefined,
    errorFormat: undefined,
    format: undefined,
  }
}

// Map a LoadSettingsFilesResult (see index.d.ts) onto the base bag. Field
// correspondences:
//   kclCliConfigs.files                -> paths (resolved natively against the
//                                         RPC workDir; "${PWD}" is NOT expanded
//                                         by the native loader)
//   kclCliConfigs.output               -> format ("json" / "yaml")
//   kclCliConfigs.overrides            -> overrides
//   kclCliConfigs.pathSelector         -> selectors
//   kclCliConfigs.strictRangeCheck     -> strictRangeCheck
//   kclCliConfigs.disableNone          -> disableNone
//   kclCliConfigs.verbose              -> verbose
//   kclCliConfigs.debug                -> debug (0/1)
//   kclCliConfigs.sortKeys             -> sortKeys
//   kclCliConfigs.showHidden           -> showHidden
//   kclCliConfigs.includeSchemaTypePath-> includeSchemaTypePath
//   kclCliConfigs.fastEval             -> fastEval
//   kclOptions [{key, value}]          -> args (Argument list; values already
//                                         serialized as KCL literals natively)
// Not mappable through the RPC: kcl_cli_configs.package_maps — the proto
// CliConfig message carries no packageMaps field, so external packages from
// settings files are silently dropped (same limitation as the other facades
// that parse via the RPC).
function applySettings(base, loaded) {
  const cfg = loaded.kclCliConfigs
  if (cfg) {
    for (const file of cfg.files) {
      if (file) {
        base.paths.push(file)
      }
    }
    if (cfg.output) {
      base.format = cfg.output
    }
    for (const override of cfg.overrides) {
      if (override) {
        base.overrides.push(override)
      }
    }
    for (const selector of cfg.pathSelector) {
      if (selector) {
        base.selectors.push(selector)
      }
    }
    for (const key of BOOLEAN_OPTION_KEYS) {
      if (cfg[key]) {
        base[key] = true
      }
    }
    if (cfg.verbose) {
      base.verbose = cfg.verbose
    }
    if (cfg.debug) {
      base.debug = 1
    }
  }
  for (const option of loaded.kclOptions) {
    if (option && typeof option.key === 'string' && option.key !== '') {
      base.args.push({ name: option.key, value: option.value == null ? '' : String(option.value) })
    }
  }
}

function resolveSettings(base, settings, workDir) {
  const files = Array.isArray(settings) ? settings : [settings]
  if (files.length === 0 || files.some((file) => typeof file !== 'string' || file === '')) {
    throw new KclError('options.settings must be a non-empty string or an array of strings')
  }
  const rpcWorkDir = typeof workDir === 'string' && workDir !== '' ? workDir : '.'
  let loaded
  try {
    loaded = native.loadSettingsFiles(new native.LoadSettingsFilesArgs(rpcWorkDir, files))
  } catch (err) {
    throw toKclError(err)
  }
  applySettings(base, loaded)
}

function overlayOptions(base, options, paths, sources) {
  base.paths.push(...paths)
  base.sources.push(...sources)
  if (options.workDir !== undefined) {
    base.workDir = options.workDir
  }
  if (options.overrides !== undefined) {
    assertStringArray(options.overrides, 'overrides')
    base.overrides.push(...options.overrides)
  }
  if (options.selectors !== undefined) {
    assertStringArray(options.selectors, 'selectors')
    base.selectors.push(...options.selectors)
  }
  if (options.externalPkgs !== undefined) {
    base.externalPkgs.push(...normalizeExternalPkgs(options.externalPkgs))
  }
  for (const key of BOOLEAN_OPTION_KEYS) {
    if (options[key] !== undefined) {
      base[key] = Boolean(options[key])
    }
  }
  if (options.verbose !== undefined) {
    base.verbose = Number(options.verbose)
  }
  if (options.debug !== undefined) {
    base.debug = options.debug ? 1 : 0
  }
  if (options.errorFormat !== undefined) {
    base.errorFormat = String(options.errorFormat)
  }
  if (options.format !== undefined) {
    base.format = String(options.format)
  }
}

function materialize(base) {
  return new native.ExecProgramArgs(
    base.paths,
    base.sources.length > 0 ? base.sources : null,
    base.workDir !== undefined ? base.workDir : null,
    base.args.length > 0 ? base.args : null,
    base.overrides.length > 0 ? base.overrides : null,
    null, // disableYamlResult
    null, // printOverrideAst
    base.strictRangeCheck !== undefined ? base.strictRangeCheck : null,
    base.disableNone !== undefined ? base.disableNone : null,
    base.verbose !== undefined ? base.verbose : null,
    base.debug !== undefined ? base.debug : null,
    base.sortKeys !== undefined ? base.sortKeys : null,
    base.externalPkgs.length > 0 ? base.externalPkgs : null,
    base.includeSchemaTypePath !== undefined ? base.includeSchemaTypePath : null,
    null, // compileOnly
    base.showHidden !== undefined ? base.showHidden : null,
    base.selectors.length > 0 ? base.selectors : null,
    base.fastEval !== undefined ? base.fastEval : null,
    base.errorFormat !== undefined ? base.errorFormat : null,
    base.format !== undefined ? base.format : null,
    null, // sourcemapOutput
  )
}

// ---------------------------------------------------------------------------
// Result helpers
// ---------------------------------------------------------------------------

/**
 * Split a YAML stream into its documents on `---` separator lines (trailing
 * whitespace or `#` comments allowed), mirroring kcl-go's exported
 * `SplitDocuments`. Anything else on the separator line raises `KclError`.
 */
function splitDocuments(text) {
  const docs = []
  if (!text) {
    return docs
  }
  let current = []
  const lines = text.split('\n')
  for (const rawLine of lines) {
    const line = rawLine.endsWith('\r') ? rawLine.slice(0, -1) : rawLine
    if (line.startsWith('---')) {
      const rest = line.slice(3).trim()
      if (rest !== '' && !rest.startsWith('#')) {
        throw new KclError(`invalid document separator: ${line.trim()}`)
      }
      docs.push(current.join('\n'))
      current = []
    } else {
      current.push(rawLine)
    }
  }
  docs.push(current.join('\n'))
  // Drop empty documents (e.g. a leading separator) and trailing newlines.
  return docs.map((doc) => doc.replace(/\n+$/, '')).filter((doc) => doc.trim() !== '')
}

// The runtime emits a JSON *stream* for multi-document results: one compact
// JSON value per line (JSON_STREAM_SEP is "\n"; serde_json never emits
// literal newlines inside strings), so line splitting is safe.
function parseJsonStream(json) {
  const values = []
  const lines = []
  for (const line of json.split('\n')) {
    if (line.trim() === '') {
      continue
    }
    try {
      values.push(JSON.parse(line))
      lines.push(line)
    } catch (err) {
      throw new KclError(`failed to parse KCL JSON result: ${err.message}`, err)
    }
  }
  return { values, lines }
}

function typeNameOf(value) {
  if (value === undefined) {
    return 'no parsed value'
  }
  if (value === null) {
    return 'null'
  }
  if (Array.isArray(value)) {
    return 'list'
  }
  return typeof value === 'object' ? 'map' : typeof value
}

const NO_JSON_HINT =
  'the runtime emitted YAML only (format "yaml"); value access requires the JSON result — ' +
  'drop `format: "yaml"` from the options or read `yamlString` instead'

/** One evaluated configuration document. */
class KclResult {
  constructor(value, yamlDocument, jsonDocument) {
    this.value = value
    this._yamlDocument = yamlDocument
    this._jsonDocument = jsonDocument
  }

  /** The YAML rendering of this document as emitted by the runtime ("" when the run was JSON-only). */
  get yamlString() {
    return this._yamlDocument
  }

  /** The JSON rendering of this document's value. */
  get jsonString() {
    if (this._jsonDocument !== undefined) {
      return this._jsonDocument
    }
    return this.value === undefined ? '' : JSON.stringify(this.value)
  }

  /**
   * Look up `dottedPath` in the parsed document: dots navigate nested maps
   * (`"a.b.c"`), integer segments index into lists (`"a.0.b"`). Returns
   * `undefined` when any segment is missing.
   */
  get(dottedPath) {
    if (dottedPath === undefined || dottedPath === null) {
      return this.value
    }
    let current = this.value
    for (const segment of String(dottedPath).split('.')) {
      if (Array.isArray(current)) {
        const index = Number(segment)
        if (!Number.isInteger(index) || index < 0 || index >= current.length) {
          return undefined
        }
        current = current[index]
      } else if (current !== null && typeof current === 'object') {
        if (!Object.prototype.hasOwnProperty.call(current, segment)) {
          return undefined
        }
        current = current[segment]
      } else {
        return undefined
      }
    }
    return current
  }

  /** The document as a plain object; throws `KclError` when it is not a map. */
  toMap() {
    if (
      this.value !== undefined &&
      this.value !== null &&
      typeof this.value === 'object' &&
      !Array.isArray(this.value)
    ) {
      return this.value
    }
    if (this.value === undefined) {
      throw new KclError(`failed to convert result to map: ${NO_JSON_HINT}`)
    }
    throw new KclError(`failed to convert result to map: got ${typeNameOf(this.value)}`)
  }

  /** The document as an array; throws `KclError` when it is not a list. */
  toList() {
    if (Array.isArray(this.value)) {
      return this.value
    }
    if (this.value === undefined) {
      throw new KclError(`failed to convert result to list: ${NO_JSON_HINT}`)
    }
    throw new KclError(`failed to convert result to list: got ${typeNameOf(this.value)}`)
  }
}

// Keep the raw ExecProgramResult out of the enumerable surface: `KclResultList`
// extends Array, and an own `_raw` property would show up in Object.keys().
const rawResults = new WeakMap()

/**
 * The documents produced by a run. Array semantics (`length`, indexing,
 * iteration, spread) over `KclResult` items. `Symbol.species` is pinned to
 * `Array` so derived arrays (`map`, `filter`, ...) are plain arrays, not
 * `KclResultList` instances built through this constructor.
 */
class KclResultList extends Array {
  static get [Symbol.species]() {
    return Array
  }

  constructor(results = [], raw = null) {
    super(...results)
    rawResults.set(this, raw)
  }

  first() {
    return this.length > 0 ? this[0] : undefined
  }

  last() {
    return this.length > 0 ? this[this.length - 1] : undefined
  }

  get(index) {
    return this[index]
  }

  /** The raw `json_result` string emitted by the runtime ("" when unavailable). */
  getRawJsonResult() {
    const raw = rawResults.get(this)
    return raw ? raw.jsonResult : ''
  }

  /** The raw `yaml_result` string emitted by the runtime ("" when unavailable). */
  getRawYamlResult() {
    const raw = rawResults.get(this)
    return raw ? raw.yamlResult : ''
  }

  /** Log output produced by the run, if any. */
  get logMessage() {
    const raw = rawResults.get(this)
    return raw ? raw.logMessage : ''
  }
}

// Port of kcl-go's ExecResultToKCLResult: raise err_message, pair YAML
// documents (split on "---") with the JSON stream values by position.
function wrapResult(resp) {
  if (resp.errMessage) {
    throw new KclError(resp.errMessage)
  }
  const yamlResult = resp.yamlResult || ''
  const jsonResult = resp.jsonResult || ''
  if (yamlResult.trim() === '' && jsonResult.trim() === '') {
    return new KclResultList([], resp)
  }
  const documents = splitDocuments(yamlResult)
  const { values, lines } = parseJsonStream(jsonResult)
  const count = Math.max(documents.length, values.length)
  const results = []
  for (let i = 0; i < count; i++) {
    const document = i < documents.length ? documents[i] : ''
    if (document.trim() === '' && i >= values.length) {
      continue
    }
    const value = i < values.length ? values[i] : undefined
    const jsonDocument = i < lines.length ? lines[i] : undefined
    results.push(new KclResult(value, document, jsonDocument))
  }
  return new KclResultList(results, resp)
}

// ---------------------------------------------------------------------------
// Entry points
// ---------------------------------------------------------------------------

function runInternal(sources, paths, options) {
  if (options !== undefined && (options === null || typeof options !== 'object' || Array.isArray(options))) {
    throw new KclError('options must be a plain object')
  }
  const opts = options || {}
  const base = emptyBase()
  if (opts.settings !== undefined) {
    resolveSettings(base, opts.settings, opts.workDir)
  }
  overlayOptions(base, opts, paths, sources)
  if (base.sources.length > 0) {
    // Inline sources take precedence over settings-provided files. Mixing
    // k_code_list with k_filename_list makes the runtime treat the code as
    // the (replacement) content of those files — never what a caller of
    // run() wants. Everything else the settings file provided (kcl_options,
    // overrides, flags) still applies to the code.
    base.paths = []
  }
  if (base.paths.length === 0 && base.sources.length === 0) {
    throw new KclError('kcl.Run: no kcl file or code')
  }
  let resp
  try {
    resp = native.execProgram(materialize(base))
  } catch (err) {
    throw toKclError(err)
  }
  return wrapResult(resp)
}

function normalizePaths(paths) {
  const list = typeof paths === 'string' ? [paths] : paths
  if (!Array.isArray(list) || list.some((path) => typeof path !== 'string')) {
    throw new KclError('paths must be a string or an array of strings')
  }
  return list.slice()
}

/**
 * High-level KCL facade. Static and instance methods behave identically; the
 * native binding is stateless, so instances carry no configuration.
 */
class Kcl {
  /**
   * Evaluate in-memory KCL `code` and return the parsed documents.
   * Throws `KclError` on any failure.
   */
  static run(code, options) {
    if (typeof code !== 'string') {
      throw new KclError('code must be a string')
    }
    return runInternal([code], [], options)
  }

  /** Evaluate the KCL file(s) at `paths` (a string or array). Throws `KclError` on any failure. */
  static runFiles(paths, options) {
    return runInternal([], normalizePaths(paths), options)
  }

  run(code, options) {
    return Kcl.run(code, options)
  }

  runFiles(paths, options) {
    return Kcl.runFiles(paths, options)
  }
}

const run = Kcl.run
const runFiles = Kcl.runFiles

module.exports = {
  Kcl,
  KclError,
  KclResult,
  KclResultList,
  splitDocuments,
  run,
  runFiles,
}
