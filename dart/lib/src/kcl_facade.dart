// High-level facade for the KCL language core.
//
// This mirrors the ergonomic surface of kcl-go's `pkg/kcl` (and the
// Python / Ruby / Java / Kotlin / .NET / Node.js facades of this repo) on top
// of the typed RPC wrappers in `kcl_lib.dart`. Where `kcl_lib.dart` is a thin
// protobuf-shaped layer — one Dart call per `spec.proto` RPC — the facade is
// the layer a caller actually wants:
//
//   * `run(code, options: ...)` / `runFiles(paths, options: ...)` build the
//     `ExecProgramArgs` payload for you instead of spelling out 22 fields.
//   * The multi-document YAML/JSON stream the runtime emits is split into
//     `KclResult` values, with YAML and JSON renderings paired by position.
//
// Design notes (Dart-first, not a kcl-go transliteration):
//   * Options are one immutable [KclOptions] value object with named fields,
//     passed as `options:` — no builder, no positional options.
//   * Failures throw [KclError], the same exception the typed wrappers raise.
//   * `kcl.yaml` settings are resolved through the native
//     `loadSettingsFiles` RPC — no YAML parsing happens in Dart and no YAML
//     dependency is introduced. Settings form the base; explicit option keys
//     win, mirroring kcl-go's `Option.Merge`.
//
// Everything here is built on the public wrappers, so a change to the ABI
// surfaces in one place.

import 'dart:collection';
import 'dart:convert';

import 'kcl_lib.dart';

// ---------------------------------------------------------------------------
// Options
// ---------------------------------------------------------------------------

/// Options accepted by [run] and [runFiles].
///
/// Every field is optional and `null` means "not specified": unspecified
/// fields fall back to whatever a `kcl.yaml` settings file supplied (see
/// [settings]) and then to the runtime's own default. Passing an explicit
/// `false` is meaningful and overrides a `true` coming from a settings file.
class KclOptions {
  /// Path or paths of `kcl.yaml` settings file(s) to load before running.
  ///
  /// Accepts a single path, a `List<String>` of paths, or a
  /// `Map<String, String>` of external package name to package path — the
  /// `-E` flag. Settings are resolved by the native `loadSettingsFiles` RPC.
  final Object? settings;

  /// Working directory the core resolves relative paths against. Defaults to
  /// the settings RPC's own default of `.`.
  final String? workDir;

  /// `--override` specs, e.g. `['a.b=1', 'c="x"']`. Appended to any overrides
  /// coming from a settings file, in that order.
  final List<String>? overrides;

  /// `--select` path selectors, e.g. `['app.replicas']`.
  final List<String>? selectors;

  /// External packages available to the program, as `-E name=path` pairs.
  final List<ExternalPkg>? externalPkgs;

  final bool? disableNone;
  final bool? sortKeys;
  final bool? showHidden;
  final bool? includeSchemaTypePath;
  final bool? strictRangeCheck;
  final bool? fastEval;

  /// Verbosity level (`-v`); `verbose >= 1` prints the execution trace.
  final int? verbose;

  /// Non-zero enables debug output (`--debug`).
  final int? debug;

  /// `--error-format`, e.g. `json`.
  final String? errorFormat;

  /// Output format, e.g. `json` or `yaml`. Leaving this null keeps both
  /// renderings, which is what makes [KclResult.get] usable.
  final String? format;

  const KclOptions({
    this.settings,
    this.workDir,
    this.overrides,
    this.selectors,
    this.externalPkgs,
    this.disableNone,
    this.sortKeys,
    this.showHidden,
    this.includeSchemaTypePath,
    this.strictRangeCheck,
    this.fastEval,
    this.verbose,
    this.debug,
    this.errorFormat,
    this.format,
  });

  /// The external packages in the convenience `-E name=path` map form.
  ///
  /// Returns `null` when [settings] is not a map, so callers can tell "no
  /// settings map" apart from "an empty settings map".
  Map<String, String>? get settingsPackageMap {
    final s = settings;
    return s is Map<String, String> ? s : null;
  }

  /// The settings file paths, or an empty list when none were given.
  List<String> get settingsFiles {
    final s = settings;
    if (s is String) {
      if (s.isEmpty) {
        throw KclError('options.settings must be a non-empty string');
      }
      return [s];
    }
    if (s is List<String>) {
      if (s.isEmpty || s.any((f) => f.isEmpty)) {
        throw KclError(
            'options.settings must be a non-empty string or a list of strings');
      }
      return s;
    }
    if (s is Map<String, String>) return const [];
    if (s == null) return const [];
    throw KclError(
        'options.settings must be a string, a List<String> or a Map<String, String>');
  }
}

/// Internal option bag, populated from the settings RPC and then overlaid with
/// the explicit [KclOptions]. Repeated fields append; scalars overwrite.
class _Base {
  final List<String> paths = [];
  final List<String> sources = [];
  final List<Argument> args = [];
  final List<String> overrides = [];
  final List<String> selectors = [];
  final List<ExternalPkg> externalPkgs = [];

  String? workDir;
  bool? disableNone;
  bool? sortKeys;
  bool? showHidden;
  bool? includeSchemaTypePath;
  bool? strictRangeCheck;
  bool? fastEval;
  int? verbose;
  int? debug;
  String? errorFormat;
  String? format;

  ExecProgramArgs materialize() => ExecProgramArgs(
        kFilenameList: paths,
        kCodeList: sources,
        args: args,
        overrides: overrides,
        externalPkgs: externalPkgs,
        workDir: workDir ?? '',
        strictRangeCheck: strictRangeCheck,
        disableNone: disableNone,
        verbose: verbose ?? 0,
        debug: debug ?? 0,
        sortKeys: sortKeys,
        includeSchemaTypePath: includeSchemaTypePath,
        showHidden: showHidden,
        pathSelector: selectors,
        fastEval: fastEval,
        errorFormat: errorFormat ?? '',
        format: format ?? '',
      );
}

/// Overlays the explicitly-set options on the bag. A `null` option means
/// "inherit from the settings file, else the runtime default", so only the
/// non-null ones are assigned.
void _overlayOptions(_Base base, KclOptions opts) {
  if (opts.workDir != null) base.workDir = opts.workDir;
  if (opts.overrides != null) base.overrides.addAll(opts.overrides!);
  if (opts.selectors != null) base.selectors.addAll(opts.selectors!);
  if (opts.externalPkgs != null) {
    base.externalPkgs.addAll(_normalizeExternalPkgs(opts.externalPkgs));
  }
  if (opts.disableNone != null) base.disableNone = opts.disableNone;
  if (opts.sortKeys != null) base.sortKeys = opts.sortKeys;
  if (opts.showHidden != null) base.showHidden = opts.showHidden;
  if (opts.includeSchemaTypePath != null) {
    base.includeSchemaTypePath = opts.includeSchemaTypePath;
  }
  if (opts.strictRangeCheck != null) {
    base.strictRangeCheck = opts.strictRangeCheck;
  }
  if (opts.fastEval != null) base.fastEval = opts.fastEval;
  if (opts.verbose != null) base.verbose = opts.verbose;
  if (opts.debug != null) base.debug = opts.debug;
  if (opts.errorFormat != null) base.errorFormat = opts.errorFormat;
  if (opts.format != null) base.format = opts.format;
}

/// Copy a [LoadSettingsFilesResult] onto the base bag.
///
/// Field correspondences:
///   * `kclCliConfigs.files` → `k_filename_list`, resolved natively against
///     the RPC `work_dir` (`${PWD}` is *not* expanded by the native loader)
///   * `kclCliConfigs.output` → `format` (`json` / `yaml`)
///   * `kclCliConfigs.overrides` → `overrides`
///   * `kclCliConfigs.pathSelector` → `path_selector`
///   * `kclCliConfigs.strictRangeCheck` / `disableNone` / `verbose` / `debug`
///     / `sortKeys` / `showHidden` / `includeSchemaTypePath` / `fastEval`
///     → the same-named options
///   * `kclOptions[{key, value}]` → `args`; the values arrive already
///     serialized as KCL literals
///
/// Not mappable through the RPC: `kcl_cli_configs.package_maps`. The proto
/// `CliConfig` message carries no `packageMaps` field, so external packages
/// declared only in a settings file are dropped — the same limitation every
/// other facade that parses settings through the RPC has.
void _applySettings(_Base base, LoadSettingsFilesResult loaded) {
  final cfg = loaded.kclCliConfigs;
  if (cfg.files.isNotEmpty) {
    base.paths.addAll(cfg.files.where((f) => f.isNotEmpty));
  }
  if (cfg.output.isNotEmpty) {
    base.format = cfg.output;
  }
  base.overrides.addAll(cfg.overrides.where((o) => o.isNotEmpty));
  base.selectors.addAll(cfg.pathSelector.where((s) => s.isNotEmpty));
  base.strictRangeCheck = _orTrue(base.strictRangeCheck, cfg.strictRangeCheck);
  base.disableNone = _orTrue(base.disableNone, cfg.disableNone);
  base.showHidden = _orTrue(base.showHidden, cfg.showHidden);
  base.includeSchemaTypePath =
      _orTrue(base.includeSchemaTypePath, cfg.includeSchemaTypePath);
  base.fastEval = _orTrue(base.fastEval, cfg.fastEval);
  base.sortKeys = _orTrue(base.sortKeys, cfg.sortKeys);
  base.verbose = cfg.verbose.toInt();
  if (cfg.debug) {
    base.debug = 1;
  }
  for (final option in loaded.kclOptions) {
    if (option.key.isNotEmpty) {
      base.args.add(Argument(name: option.key, value: option.value));
    }
  }
}

bool? _orTrue(bool? current, bool flag) => flag ? true : current;

List<ExternalPkg> _normalizeExternalPkgs(Object? value) {
  if (value is List<ExternalPkg>) return value;
  if (value is Map<String, String>) {
    return value.entries
        .map((e) => ExternalPkg(pkgName: e.key, pkgPath: e.value))
        .toList();
  }
  throw KclError(
      'options.externalPkgs must be a List<ExternalPkg> or a '
      'Map<String, String> of name to path');
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

String _stripTrailingNewlines(String s) {
  var end = s.length;
  while (end > 0 && s.codeUnitAt(end - 1) == 0x0a) {
    end--;
  }
  return s.substring(0, end);
}

/// Splits a YAML stream into its documents on `---` separator lines.
///
/// A separator line may carry trailing whitespace or a `#` comment; anything
/// else on it throws [KclError]. Mirrors kcl-go's exported `SplitDocuments`.
/// Empty documents (e.g. from a leading separator) are dropped.
List<String> splitDocuments(String text) {
  final docs = <String>[];
  if (text.isEmpty) return docs;

  final current = <String>[];
  for (final rawLine in text.split('\n')) {
    final line =
        rawLine.endsWith('\r') ? rawLine.substring(0, rawLine.length - 1) : rawLine;
    if (line.startsWith('---')) {
      final rest = line.substring(3).trim();
      if (rest.isNotEmpty && !rest.startsWith('#')) {
        throw KclError('invalid document separator: ${line.trim()}');
      }
      docs.add(current.join('\n'));
      current.clear();
    } else {
      current.add(rawLine);
    }
  }
  docs.add(current.join('\n'));

  return docs
      .map(_stripTrailingNewlines)
      .where((doc) => doc.trim().isNotEmpty)
      .toList();
}

/// The runtime emits a JSON *stream* for multi-document results: one compact
/// JSON value per line, so splitting on newlines is safe.
List<Object?> parseJsonStream(String json) {
  final values = <Object?>[];
  for (final line in json.split('\n')) {
    if (line.trim().isEmpty) continue;
    try {
      values.add(jsonDecode(line));
    } on FormatException catch (e) {
      throw KclError('failed to parse KCL JSON result: ${e.message}');
    }
  }
  return values;
}

/// One evaluated configuration document.
///
/// [value] is the document decoded from the runtime's JSON stream: nested
/// `Map<String, Object?>` / `List<Object?>` with Dart scalars inside. It is
/// null when the run was YAML-only — see [jsonString].
class KclResult {
  /// The decoded document, or null when the run produced no JSON for it.
  final Object? value;

  final String _yamlDocument;
  final String? _jsonDocument;

  const KclResult(this.value, this._yamlDocument, this._jsonDocument);

  /// The YAML rendering of this document, exactly as the runtime emitted it.
  ///
  /// Empty when the run was JSON-only.
  String get yamlString => _yamlDocument;

  /// The JSON rendering of this document's value.
  ///
  /// When the runtime emitted no JSON for this document, falls back to
  /// re-encoding [value]; when the run was YAML-only this returns `''`.
  String get jsonString {
    final document = _jsonDocument;
    if (document != null) return document;
    final v = value;
    return v == null ? '' : jsonEncode(v);
  }

  /// Looks up a dotted path in the parsed document.
  ///
  /// Dots navigate nested maps (`'a.b.c'`) and integer segments index into
  /// lists (`'a.0.b'`). Returns null when any segment is missing, when a
  /// segment is not an index of a list, or when the path is null.
  Object? get(String? dottedPath) {
    final v = value;
    if (dottedPath == null) return v;

    Object? current = v;
    for (final segment in dottedPath.split('.')) {
      if (current is List<Object?>) {
        final index = int.tryParse(segment);
        if (index == null || index < 0 || index >= current.length) return null;
        current = current[index];
      } else if (current is Map<Object?, Object?>) {
        if (!current.containsKey(segment)) return null;
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }

  /// The document as a map; throws [KclError] when it is not one.
  Map<Object?, Object?> toMap() {
    final v = value;
    if (v is Map<Object?, Object?>) return v;
    if (v == null) {
      throw KclError('failed to convert result to map: $_noJsonHint');
    }
    throw KclError('failed to convert result to map: got ${_typeNameOf(v)}');
  }

  /// The document as a list; throws [KclError] when it is not one.
  List<Object?> toList() {
    final v = value;
    if (v is List<Object?>) return v;
    if (v == null) {
      throw KclError('failed to convert result to list: $_noJsonHint');
    }
    throw KclError('failed to convert result to list: got ${_typeNameOf(v)}');
  }

  @override
  String toString() => 'KclResult($jsonString)';
}

const _noJsonHint =
    'the runtime emitted YAML only (options.format == "yaml"); value access '
    'requires the JSON result — drop `format` from the options or read '
    'yamlString instead';

String _typeNameOf(Object? value) {
  if (value == null) return 'null';
  if (value is List) return 'list';
  if (value is Map) return 'map';
  return value.runtimeType.toString();
}

/// The documents produced by a run.
///
/// Extends [UnmodifiableListView], so `first`, `last`, `map`, `where`, `where`,
/// `length`, indexed access and iteration all work out of the box, and the
/// run's output cannot be mutated through it. [first] and [last] throw
/// [StateError] on an empty result, per the Dart convention.
class KclResultList extends UnmodifiableListView<KclResult> {
  final ExecProgramResult? _raw;

  KclResultList(List<KclResult> results, [this._raw])
      : super(List<KclResult>.unmodifiable(results));

  /// The document at `index`.
  @override
  KclResult operator [](int index) => super[index];

  /// The raw `json_result` string emitted by the runtime (`''` when absent).
  String get rawJsonResult => _raw?.jsonResult ?? '';

  /// The raw `yaml_result` string emitted by the runtime (`''` when absent).
  String get rawYamlResult => _raw?.yamlResult ?? '';

  /// Log output produced by the run (`''` when absent).
  String get logMessage => _raw?.logMessage ?? '';

  @override
  String toString() => 'KclResultList(${super.join(', ')})';
}

/// Port of kcl-go's `ExecResultToKCLResult`: raise `err_message`, then pair the
/// YAML documents (split on `---`) with the JSON stream values by position.
KclResultList _wrapResult(ExecProgramResult resp) {
  if (resp.errMessage.isNotEmpty) {
    throw KclError(resp.errMessage);
  }
  final yamlResult = resp.yamlResult;
  final jsonResult = resp.jsonResult;
  if (yamlResult.trim().isEmpty && jsonResult.trim().isEmpty) {
    return KclResultList(const [], resp);
  }

  final documents = splitDocuments(yamlResult);
  final lines = jsonResult
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  final values = parseJsonStream(jsonResult);
  final count =
      documents.length > values.length ? documents.length : values.length;

  final results = <KclResult>[];
  for (var i = 0; i < count; i++) {
    final document = i < documents.length ? documents[i] : '';
    if (document.trim().isEmpty && i >= values.length) continue;
    results.add(KclResult(
      i < values.length ? values[i] : null,
      document,
      i < lines.length ? lines[i] : null,
    ));
  }
  return KclResultList(results, resp);
}

// ---------------------------------------------------------------------------
// Entry points
// ---------------------------------------------------------------------------

KclResultList _runInternal(List<String> sources, List<String> paths,
    KclOptions? options) {
  final opts = options ?? const KclOptions();
  final base = _Base();

  final settingsPkgs = opts.settingsPackageMap;
  if (settingsPkgs != null) {
    base.externalPkgs.addAll(_normalizeExternalPkgs(settingsPkgs));
  }

  if (opts.settingsFiles.isNotEmpty) {
    final loaded = loadSettingsFiles(LoadSettingsFilesArgs(
      workDir: opts.workDir ?? '',
      files: opts.settingsFiles,
    ));
    _applySettings(base, loaded);
  }

  base.paths.addAll(paths);
  base.sources.addAll(sources);
  _overlayOptions(base, opts);

  if (base.sources.isNotEmpty) {
    // Inline sources take precedence over settings-provided files. Mixing
    // `k_code_list` with `k_filename_list` makes the runtime treat the code
    // as the (replacement) content of those files — never what a caller of
    // [run] wants. Everything else the settings file provided (`kcl_options`,
    // overrides, flags) still applies to the code.
    base.paths.clear();
  }
  if (base.paths.isEmpty && base.sources.isEmpty) {
    throw KclError('kcl.run: no KCL file or code');
  }

  return _wrapResult(execProgram(base.materialize()));
}

/// Evaluates in-memory KCL `code` and returns the parsed documents.
///
/// Throws [KclError] on any failure.
///
/// ```dart
/// final results = run('alice = {age = 18}');
/// print(results[0].get('alice.age')); // 18
/// ```
KclResultList run(String code, {KclOptions? options}) =>
    _runInternal([code], const [], options);

/// Evaluates the KCL file(s) at [paths] and returns the parsed documents.
///
/// Throws [KclError] on any failure.
KclResultList runFiles(List<String> paths, {KclOptions? options}) {
  _assertPaths(paths);
  return _runInternal(const [], paths, options);
}

void _assertPaths(List<String> paths) {
  if (paths.isEmpty || paths.any((p) => p.isEmpty)) {
    throw KclError('paths must be a non-empty list of non-empty strings');
  }
}

/// High-level KCL facade.
///
/// The native binding is stateless, so instances carry no configuration; [run]
/// and [runFiles] are exposed as top-level functions and this class exists so
/// that `Kcl.run(...)` reads the same way it does in the other bindings.
class Kcl {
  const Kcl._();

  /// See [run].
  static KclResultList run(String code, {KclOptions? options}) =>
      _runInternal([code], const [], options);

  /// See [runFiles].
  static KclResultList runFiles(List<String> paths, {KclOptions? options}) {
    _assertPaths(paths);
    return _runInternal(const [], paths, options);
  }
}
