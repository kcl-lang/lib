"""High-level Python SDK facade mirroring ``kcl-lang.io/kcl-go``'s public API.

The thin ``kcl_lib.api.service.API`` class only exposes protobuf-shaped RPC
wrappers that force callers to construct ``ExecProgramArgs`` and decode
``yaml_result`` strings by hand. This module sits on top of that layer and
provides the same ergonomic surface as the Go SDK:

* top-level entry points :func:`run`, :func:`run_files`, :func:`must_run`
* functional options via ``with_*`` factories
* convenience wrappers (:func:`format_code`, :func:`format_path`,
  :func:`validate`, :func:`validate_code`, :func:`test`, ...)
* :class:`KCLResult` / :class:`KCLResultList` helpers that parse YAML,
  support dotted-key ``get`` access and ``to_dict`` conversion.

It is a pure-Python layer that does **not** modify :class:`API` or the
underlying pyo3 runtime; the only existing third-party dependency is
``protobuf`` (already declared in ``pyproject.toml``).
"""

from __future__ import annotations

import json as _json
import pathlib
from dataclasses import dataclass, field
from typing import Any, List, Optional, Sequence, Tuple, Union

from .api.service import API
from .api.spec_pb2 import (
    ExecProgramArgs,
    ExecProgramResult,
    ExternalPkg,
    FormatCodeArgs,
    FormatPathArgs,
    GetSchemaTypeMappingArgs,
    GetVersionArgs,
    GetVersionResult,
    ListVariablesArgs,
    LoadPackageArgs,
    LoadPackageResult,
    LoadSettingsFilesArgs,
    LoadSettingsFilesResult,
    ListOptionsResult,
    OverrideFileArgs,
    ParseProgramArgs,
    ParseProgramResult,
    PingArgs,
    RenameArgs,
    RenameCodeArgs,
    RenameCodeResult,
    RenameResult,
    TestArgs,
    TestResult,
    UpdateDependenciesArgs,
    UpdateDependenciesResult,
    ValidateCodeArgs,
    ValidateCodeResult,
)
from . import plugin as _plugin

__all__ = [
    "KCLResult",
    "KCLResultList",
    "Option",
    "with_code",
    "with_k_filenames",
    "with_overrides",
    "with_selectors",
    "with_settings",
    "with_work_dir",
    "with_external_pkgs",
    "with_disable_none",
    "with_sort_keys",
    "with_output_format",
    "with_include_schema_type_path",
    "with_show_hidden",
    "with_logger",
    "with_plugin_agent",
    "run",
    "run_files",
    "must_run",
    "format_code",
    "format_path",
    "override_file",
    "validate_code",
    "validate",
    "test",
    "get_schema_type",
    "list_dep_files",
    "list_upstream_files",
    "list_downstream_files",
    "get_version",
    "ping",
    "parse_program",
    "load_package",
    "list_variables",
    "list_options",
    "update_dependencies",
    "rename",
    "rename_code",
    "load_settings_files",
]


# ---------------------------------------------------------------------------
# Internal options plumbing
# ---------------------------------------------------------------------------


@dataclass
class ExecProgramOptions:
    """Mutable bag of options used to build ``ExecProgramArgs``.

    Mirrors the union of fields that the Go SDK's ``Option`` struct can
    populate. The dataclass is private; users build options via the
    ``with_*`` factories below.
    """

    work_dir: Optional[str] = None
    k_filename_list: List[str] = field(default_factory=list)
    k_code_list: List[str] = field(default_factory=list)
    overrides: List[str] = field(default_factory=list)
    selectors: List[str] = field(default_factory=list)
    external_pkgs: List[ExternalPkg] = field(default_factory=list)
    disable_none: Optional[bool] = None
    sort_keys: Optional[bool] = None
    show_hidden: Optional[bool] = None
    include_schema_type_path: Optional[bool] = None
    # Output format selector ("json", "yaml"). Not a real proto field in
    # the Python ``ExecProgramArgs``; stored here so result helpers can
    # pick the right representation. When ``output_format == "json"`` we
    # also set ``disable_yaml_result`` so the Rust runtime emits JSON.
    output_format: Optional[str] = None
    # Settings file path. The Python ``ExecProgramArgs`` does not yet
    # expose ``settings_file``; stored for future use and exposed via
    # :func:`load_settings_files`.
    settings_file: Optional[str] = None
    # File-like sink for log messages. We only store it because the
    # Go API takes one; there is currently no plumbing in Python to
    # forward runtime logs to it.
    logger: Any = None
    # Integer handle for the plugin agent pointer.
    plugin_agent: Optional[int] = None


class Option:
    """Base class for functional options (mirrors kcl-go's ``Option``).

    Each ``with_*`` factory returns an :class:`Option` whose ``__call__``
    mutates an :class:`ExecProgramOptions` instance in place. This keeps
    the construction style identical to kcl-go:

    .. code-block:: python

        run(path, with_overrides(["name=\\"bob\\""]), with_disable_none(True))
    """

    def __call__(self, opts: ExecProgramOptions) -> None:
        raise NotImplementedError


def _apply(opts: ExecProgramOptions, options: Sequence[Option]) -> None:
    """Apply each :class:`Option` to ``opts`` in order."""
    for opt in options:
        opt(opts)


def _apply_settings(args: ExecProgramArgs, settings_file: str) -> None:
    """Populate ``args`` from a ``kcl.yaml`` settings file.

    Mirrors kcl-go's :func:`settings.SettingsFile.To_ExecProgramArgs`. Only
    fields that the caller has not already set are populated, so user
    ``with_*`` options naturally take precedence over file defaults.
    """
    try:
        text = pathlib.Path(settings_file).read_text(encoding="utf-8")
    except OSError:
        return
    parsed = _load_yaml(text)
    if not isinstance(parsed, dict):
        return
    config = parsed.get("kcl_cli_configs") or {}
    if not isinstance(config, dict):
        config = {}

    work_dir = args.work_dir or "."

    # ``file`` / ``files`` → k_filename_list (with ${PWD} substitution).
    files: List[str] = []
    for key in ("file", "files"):
        vals = config.get(key) or []
        if isinstance(vals, list):
            files.extend(str(v) for v in vals if v)
    for s in files:
        s = s.replace("${PWD}", work_dir)
        if s.startswith("."):
            args.k_filename_list.append(str(pathlib.Path(work_dir) / s))
        elif not s.startswith("${") and not pathlib.PurePath(s).is_absolute():
            args.k_filename_list.append(str(pathlib.Path(work_dir) / s))
        else:
            args.k_filename_list.append(s)

    # ``output`` → ``format`` (yaml / json).
    output = config.get("output")
    if output:
        args.format = str(output)

    # ``overrides`` and ``path_selector``.
    overrides = config.get("overrides")
    if isinstance(overrides, list):
        for o in overrides:
            if o:
                args.overrides.append(str(o))
    selector = config.get("path_selector")
    if isinstance(selector, list):
        for p in selector:
            if p:
                args.path_selector.append(str(p))

    # Booleans.
    if config.get("strict_range_check"):
        args.strict_range_check = True
    if config.get("disable_none"):
        args.disable_none = True
    if config.get("sort_keys"):
        args.sort_keys = True
    if config.get("show_hidden"):
        args.show_hidden = True
    if config.get("include_schema_type_path"):
        args.include_schema_type_path = True

    # ``verbose`` (int) and ``debug`` (bool → 0/1).
    verbose = config.get("verbose")
    if verbose is not None:
        try:
            args.verbose = int(verbose)
        except (TypeError, ValueError):
            pass
    if config.get("debug"):
        args.debug = 1

    # ``package_maps`` → ``external_pkgs``.
    pkg_maps = config.get("package_maps") or {}
    if isinstance(pkg_maps, dict):
        for name, path in pkg_maps.items():
            pkg = args.external_pkgs.add()
            pkg.pkg_name = str(name)
            pkg.pkg_path = str(path)

    # ``kcl_options`` is a list of ``{key, value}`` → ``args`` (Argument list).
    options = parsed.get("kcl_options")
    if isinstance(options, list):
        for opt in options:
            if not isinstance(opt, dict):
                continue
            key = opt.get("key")
            if key is None:
                continue
            value = opt.get("value")
            arg = args.args.add()
            arg.name = str(key)
            if value is None:
                arg.value = ""
            elif isinstance(value, (dict, list)):
                arg.value = _json.dumps(value)
            else:
                arg.value = str(value)


def _to_args(opts: ExecProgramOptions) -> Tuple[ExecProgramArgs, str]:
    """Materialise :class:`ExecProgramOptions` into an ``ExecProgramArgs`` proto.

    Returns the ``(args, output_format)`` tuple so the caller can pick the
    right document representation in :func:`_wrap_response` without having
    to smuggle state through the proto.

    When ``opts.settings_file`` is set, the file is parsed and used as the
    base set of fields. Anything the caller explicitly populated via the
    ``with_*`` options overrides the file defaults — matching kcl-go's
    layered ``Option``/``SettingsFile`` semantics.
    """
    args = ExecProgramArgs()

    # 1. Pull defaults from the settings file (if any).
    if opts.settings_file:
        _apply_settings(args, opts.settings_file)

    # 2. Overlay fields the caller explicitly provided.
    if opts.work_dir:
        args.work_dir = opts.work_dir
    if opts.k_filename_list:
        del args.k_filename_list[:]
        args.k_filename_list.extend(opts.k_filename_list)
    if opts.k_code_list:
        del args.k_code_list[:]
        args.k_code_list.extend(opts.k_code_list)
    if opts.overrides:
        del args.overrides[:]
        args.overrides.extend(opts.overrides)
    if opts.selectors:
        del args.path_selector[:]
        args.path_selector.extend(opts.selectors)
    if opts.external_pkgs:
        del args.external_pkgs[:]
        args.external_pkgs.extend(opts.external_pkgs)
    if opts.disable_none is not None:
        args.disable_none = opts.disable_none
    if opts.sort_keys is not None:
        args.sort_keys = opts.sort_keys
    if opts.show_hidden is not None:
        args.show_hidden = opts.show_hidden
    if opts.include_schema_type_path is not None:
        args.include_schema_type_path = opts.include_schema_type_path

    output_format = opts.output_format or "yaml"
    if opts.output_format:
        # Forward the user's requested format directly via the proto; the
        # runtime uses ``format`` to decide whether to populate ``yaml_result``,
        # ``json_result``, or both. No more ``disable_yaml_result`` proxy.
        args.format = opts.output_format
    return args, output_format


# ---------------------------------------------------------------------------
# ``with_*`` option factories
# ---------------------------------------------------------------------------


class _Code(Option):
    def __init__(self, code: Union[bytes, bytearray, str]) -> None:
        if isinstance(code, (bytes, bytearray)):
            self.code = bytes(code).decode("utf-8")
        else:
            self.code = code

    def __call__(self, opts: ExecProgramOptions) -> None:
        opts.k_code_list.append(self.code)


def with_code(code: Union[bytes, bytearray, str]) -> Option:
    """Append an in-memory KCL source ``code`` to the program."""
    return _Code(code)


class _KFilenames(Option):
    def __init__(self, paths: Sequence[str]) -> None:
        self.paths = list(paths)

    def __call__(self, opts: ExecProgramOptions) -> None:
        opts.k_filename_list.extend(self.paths)


def with_k_filenames(paths: Sequence[str]) -> Option:
    """Append a list of file paths to ``k_filename_list``."""
    return _KFilenames(paths)


class _Overrides(Option):
    def __init__(self, specs: Sequence[str]) -> None:
        self.specs = list(specs)

    def __call__(self, opts: ExecProgramOptions) -> None:
        opts.overrides.extend(self.specs)


def with_overrides(specs: Sequence[str]) -> Option:
    """Set override specs (``-O`` equivalent)."""
    return _Overrides(specs)


class _Selectors(Option):
    def __init__(self, selectors: Sequence[str]) -> None:
        self.selectors = list(selectors)

    def __call__(self, opts: ExecProgramOptions) -> None:
        opts.selectors.extend(self.selectors)


def with_selectors(selectors: Sequence[str]) -> Option:
    """Set path selectors (``-S`` equivalent)."""
    return _Selectors(selectors)


class _Settings(Option):
    def __init__(self, settings: str) -> None:
        self.settings = settings

    def __call__(self, opts: ExecProgramOptions) -> None:
        opts.settings_file = self.settings


def with_settings(settings: str) -> Option:
    """Record a ``kcl.yaml`` settings file path."""
    return _Settings(settings)


class _WorkDir(Option):
    def __init__(self, work_dir: str) -> None:
        self.work_dir = work_dir

    def __call__(self, opts: ExecProgramOptions) -> None:
        opts.work_dir = self.work_dir


def with_work_dir(work_dir: str) -> Option:
    """Set the working directory for the KCL evaluation."""
    return _WorkDir(work_dir)


class _ExternalPkgs(Option):
    def __init__(self, pkgs: Sequence[ExternalPkg]) -> None:
        self.pkgs = list(pkgs)

    def __call__(self, opts: ExecProgramOptions) -> None:
        opts.external_pkgs.extend(self.pkgs)


def with_external_pkgs(pkgs: Sequence[ExternalPkg]) -> Option:
    """Attach pre-resolved external KCL packages."""
    return _ExternalPkgs(pkgs)


class _BoolOption(Option):
    """Toggle a boolean flag on :class:`ExecProgramOptions`.

    Subclasses set ``_field`` to the dataclass attribute they want to
    toggle; this keeps the surface small for the many ``with_*(b: bool)``
    factories.
    """

    _field: str = ""  # populated by subclasses

    def __init__(self, value: bool) -> None:
        self.value = value

    def __call__(self, opts: ExecProgramOptions) -> None:
        setattr(opts, self._field, self.value)


def with_disable_none(b: bool) -> Option:
    """Toggle ``disable_none`` (``-n``)."""
    opt = _BoolOption(b)
    opt._field = "disable_none"
    return opt


def with_sort_keys(b: bool) -> Option:
    """Toggle ``sort_keys`` (``-k``)."""
    opt = _BoolOption(b)
    opt._field = "sort_keys"
    return opt


def with_show_hidden(b: bool) -> Option:
    """Toggle ``show_hidden`` (``-H``)."""
    opt = _BoolOption(b)
    opt._field = "show_hidden"
    return opt


def with_include_schema_type_path(b: bool) -> Option:
    """Include schema type path in the rendered result."""
    opt = _BoolOption(b)
    opt._field = "include_schema_type_path"
    return opt


class _OutputFormat(Option):
    def __init__(self, fmt: str) -> None:
        self.fmt = fmt

    def __call__(self, opts: ExecProgramOptions) -> None:
        opts.output_format = self.fmt


def with_output_format(fmt: str) -> Option:
    """Request a specific output format (``"json"`` or ``"yaml"``)."""
    return _OutputFormat(fmt)


class _Logger(Option):
    def __init__(self, logger: Any) -> None:
        self.logger = logger

    def __call__(self, opts: ExecProgramOptions) -> None:
        opts.logger = self.logger


def with_logger(logger: Any) -> Option:
    """Attach a logger (Python file-like object)."""
    return _Logger(logger)


class _PluginAgent(Option):
    def __init__(self, addr: int) -> None:
        self.addr = addr

    def __call__(self, opts: ExecProgramOptions) -> None:
        opts.plugin_agent = self.addr


def with_plugin_agent(addr: int) -> Option:
    """Set the plugin agent address used by the runtime."""
    return _PluginAgent(addr)


# ---------------------------------------------------------------------------
# Result helpers
# ---------------------------------------------------------------------------


def _load_yaml(text: str) -> Any:
    """Parse a YAML document using PyYAML if available.

    PyYAML is **not** a declared dependency of ``kcl_lib`` (only
    ``protobuf`` is). The runtime, however, always emits a JSON mirror in
    :attr:`ExecProgramResult.json_result`, so the only time PyYAML is
    genuinely required is when callers request ``to_dict()`` /
    :meth:`KCLResult.get` on a result that lacks ``json_result``. In that
    case we fall back to a tiny pure-stdlib YAML reader that handles the
    subset of YAML KCL emits (mappings, sequences and scalars indented
    with spaces, ``---`` document separators). Anything more exotic
    raises :class:`RuntimeError` with installation instructions.
    """
    try:
        import yaml  # type: ignore
        return yaml.safe_load(text)
    except ImportError:
        return _minimal_yaml_load(text)


def _minimal_yaml_load(text: str) -> Any:
    """Parse the subset of YAML emitted by KCL using only the stdlib."""
    docs: List[Any] = []
    current: List[str] = []
    for line in text.splitlines():
        if line.strip() == "---":
            docs.append(_yaml_block_to_obj("\n".join(current)))
            current = []
        else:
            current.append(line)
    if current:
        docs.append(_yaml_block_to_obj("\n".join(current)))
    if len(docs) == 1:
        return docs[0]
    return docs


def _yaml_block_to_obj(text: str) -> Any:
    """Parse a single YAML document block into Python data."""
    lines = [l for l in text.splitlines() if l.strip()]
    if not lines:
        return None
    if len(lines) == 1 and ":" not in lines[0]:
        return _yaml_scalar(lines[0].strip())
    stack: List[Tuple[int, Any]] = [(-1, {})]
    for line in lines:
        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()
        if stripped.startswith("- "):
            value = stripped[2:].strip()
            while stack and stack[-1][0] >= indent:
                stack.pop()
            parent_indent, parent = stack[-1]
            if not isinstance(parent, list):
                parent = []
                stack[-1] = (parent_indent, parent)
                if len(stack) >= 2:
                    grandparent_indent, grandparent = stack[-2]
                    if isinstance(grandparent, dict):
                        keys = list(grandparent.keys())
                        if keys:
                            grandparent[keys[-1]] = parent
                    elif isinstance(grandparent, list):
                        grandparent.append(parent)
                stack.append((indent, parent))
            stack.append((indent + 2, None))
            if ":" in value:
                k, _, v = value.partition(":")
                k = k.strip()
                v = v.strip()
                item: Any = {}
                if v:
                    item[k] = _yaml_scalar(v)
                else:
                    item[k] = None
                parent.append(item)
                stack.append((indent + 2, item))
            else:
                parent.append(_yaml_scalar(value))
                stack.pop()
        elif ":" in stripped:
            key, _, value = stripped.partition(":")
            key = key.strip()
            value = value.strip()
            while stack and stack[-1][0] >= indent:
                stack.pop()
            _, parent = stack[-1]
            if not isinstance(parent, dict):
                raise RuntimeError(
                    "Unrecognised YAML structure; install PyYAML for full "
                    "support: `pip install pyyaml`."
                )
            if value:
                parent[key] = _yaml_scalar(value)
            else:
                parent[key] = None
                stack.append((indent, parent))
                stack.append((indent + 2, parent[key]))
        else:
            raise RuntimeError(
                "Unrecognised YAML line {!r}; install PyYAML for full "
                "support: `pip install pyyaml`.".format(line)
            )
    return stack[0][1]


def _yaml_scalar(value: str) -> Any:
    """Decode a YAML scalar into its most likely Python type."""
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1]
    if value.startswith("'") and value.endswith("'"):
        return value[1:-1]
    if value in ("null", "~", ""):
        return None
    if value == "true":
        return True
    if value == "false":
        return False
    try:
        if value.startswith("0") and value != "0" and not value.startswith("0."):
            raise ValueError
        return int(value)
    except ValueError:
        pass
    try:
        return float(value)
    except ValueError:
        return value


class KCLResult:
    """Wrapper around :class:`ExecProgramResult` for ergonomic access.

    Mirrors kcl-go's :class:`KCLResult` by exposing ``get`` (dotted key),
    ``to_dict`` (raw parsed mapping), ``json_string`` / ``yaml_string``
    helpers and dictionary-style ``__getitem__`` access.
    """

    def __init__(self, raw: ExecProgramResult, output_format: Optional[str] = None) -> None:
        self.raw = raw
        self._output_format = output_format or "yaml"
        self._dict_cache: Optional[dict] = None

    def yaml_string(self) -> str:
        """Return the raw YAML string emitted by the runtime."""
        return self.raw.yaml_result

    def json_string(self) -> str:
        """Return the JSON representation of the first document.

        Prefers the runtime-emitted ``json_result`` when present (the Go
        SDK relies on it too) and falls back to converting ``yaml_result``
        via :func:`json.dumps`.
        """
        if self.raw.json_result:
            return self.raw.json_result
        return _json.dumps(self.to_dict(), indent=2, default=str)

    def to_dict(self) -> dict:
        """Parse the YAML/JSON result into a plain Python ``dict``."""
        if self._dict_cache is not None:
            return self._dict_cache
        value: Any = None
        if self.raw.json_result:
            try:
                value = _json.loads(self.raw.json_result)
            except _json.JSONDecodeError:
                value = None
        if value is None and self.raw.yaml_result:
            loaded = _load_yaml(self.raw.yaml_result)
            if isinstance(loaded, list) and loaded:
                loaded = loaded[0]
            value = loaded
        value = value if isinstance(value, dict) else {}
        self._dict_cache = value
        return value

    def get(self, key: str, target: Any = None) -> Any:
        """Look up ``key`` (dotted path supported) in the parsed dict.

        When ``target`` is supplied, attempts a typed conversion:

        * ``str`` / ``int`` / ``float`` / ``bool`` — coerced in place.
        * ``dict`` / ``list`` — populated when the value has the right shape.
        """
        value: Any = self.to_dict()
        for part in key.split("."):
            if isinstance(value, dict) and part in value:
                value = value[part]
            else:
                return None
        if target is None:
            return value
        return _coerce(value, target)

    def __getitem__(self, key: str) -> Any:
        value = self.get(key)
        if value is None and key not in self.to_dict():
            raise KeyError(key)
        return value

    def __contains__(self, key: str) -> bool:
        return self.get(key) is not None


class KCLResultList:
    """Collection of :class:`KCLResult` items produced by a run."""

    def __init__(
        self,
        results: Sequence[KCLResult],
        raw: Optional[ExecProgramResult] = None,
    ) -> None:
        self._results: List[KCLResult] = list(results)
        # Keep a reference to the underlying proto so callers can fall
        # back to the raw fields (mirrors kcl-go's GetRawJsonResult /
        # GetRawYamlResult).
        self._raw = raw

    def __len__(self) -> int:
        return len(self._results)

    def __iter__(self):
        return iter(self._results)

    def __getitem__(self, index: Union[int, str]) -> KCLResult:
        if isinstance(index, str):
            for r in self._results:
                if index in r:
                    return r
            raise KeyError(index)
        return self._results[index]

    def first(self) -> Optional[KCLResult]:
        return self._results[0] if self._results else None

    def get(self, index: int) -> Optional[KCLResult]:
        if 0 <= index < len(self._results):
            return self._results[index]
        return None

    def to_dict(self) -> dict:
        """Return the first result as a dict (or ``{}`` when empty)."""
        first = self.first()
        return first.to_dict() if first is not None else {}

    def json_string(self) -> str:
        first = self.first()
        return first.json_string() if first is not None else ""

    def yaml_string(self) -> str:
        first = self.first()
        return first.yaml_string() if first is not None else ""

    def get_raw_json_result(self) -> str:
        return self._raw.json_result if self._raw is not None else ""

    def get_raw_yaml_result(self) -> str:
        return self._raw.yaml_result if self._raw is not None else ""


def _coerce(value: Any, target: Any) -> Any:
    """Best-effort conversion of ``value`` into the shape of ``target``."""
    if target is None or value is None:
        return value
    if target is str:
        return value if isinstance(value, str) else str(value)
    if target is int:
        try:
            return int(value)
        except (TypeError, ValueError):
            return None
    if target is float:
        try:
            return float(value)
        except (TypeError, ValueError):
            return None
    if target is bool:
        return bool(value)
    if isinstance(target, list):
        return value if isinstance(value, list) else None
    if isinstance(target, dict):
        return value if isinstance(value, dict) else None
    return value


# ---------------------------------------------------------------------------
# Top-level entry points
# ---------------------------------------------------------------------------


def _exec(
    args: ExecProgramArgs, plugin_agent: int, output_format: str
) -> Tuple[KCLResultList, Optional[Exception]]:
    """Call :meth:`API.exec_program` and package the response.

    Returns ``(KCLResultList, None)`` on success or
    ``(empty_KCLResultList, exception)`` on failure — mirroring kcl-go's
    ``Run`` signature.
    """
    api = API(plugin_agent=plugin_agent)
    try:
        resp = api.exec_program(args)
    except Exception as err:  # propagate as the second tuple item
        return KCLResultList([], raw=None), err
    return _wrap_response(resp, output_format=output_format), None


def _wrap_response(resp: ExecProgramResult, output_format: str) -> KCLResultList:
    """Turn a single ``ExecProgramResult`` into a list of :class:`KCLResult`."""
    if not getattr(resp, "yaml_result", "") and not getattr(resp, "json_result", ""):
        return KCLResultList([], raw=resp)
    documents: List[str]
    if output_format == "json" and resp.json_result:
        documents = [resp.json_result]
    elif resp.yaml_result:
        documents = [d for d in resp.yaml_result.split("\n---\n") if d.strip()]
    else:
        documents = []
    results = []
    for doc in documents:
        sub = ExecProgramResult()
        if resp.json_result:
            sub.json_result = resp.json_result
        sub.yaml_result = doc
        results.append(KCLResult(sub, output_format=output_format))
    if not results:
        results.append(KCLResult(resp, output_format=output_format))
    return KCLResultList(results, raw=resp)


def run(path: str, *opts: Option) -> Tuple[KCLResultList, Optional[Exception]]:
    """Evaluate ``path`` with optional ``opts`` and return ``(results, error)``.

    Mirrors ``kcl.Run``.
    """
    options = ExecProgramOptions(k_filename_list=[path])
    _apply(options, opts)
    args, output_format = _to_args(options)
    agent = options.plugin_agent if options.plugin_agent is not None else _plugin.plugin_agent_addr
    return _exec(args, agent, output_format)


def run_files(paths: Sequence[str], *opts: Option) -> Tuple[KCLResultList, Optional[Exception]]:
    """Multi-file variant of :func:`run`. Mirrors ``kcl.RunFiles``."""
    options = ExecProgramOptions(k_filename_list=list(paths))
    _apply(options, opts)
    args, output_format = _to_args(options)
    agent = options.plugin_agent if options.plugin_agent is not None else _plugin.plugin_agent_addr
    return _exec(args, agent, output_format)


def must_run(path: str, *opts: Option) -> KCLResultList:
    """Like :func:`run` but raises the first error it encounters.

    Mirrors ``kcl.MustRun``. Returns the :class:`KCLResultList` on success.
    """
    result, err = run(path, *opts)
    if err is not None:
        raise err
    return result


# ---------------------------------------------------------------------------
# Convenience methods
# ---------------------------------------------------------------------------


def format_code(code: Union[bytes, bytearray, str]) -> bytes:
    """Format an in-memory KCL source. Returns the formatted ``bytes``."""
    source = bytes(code).decode("utf-8") if isinstance(code, (bytes, bytearray)) else code
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    resp = api.format_code(FormatCodeArgs(source=source))
    return bytes(resp.formatted)


def format_path(path: str) -> List[str]:
    """Format KCL file(s) under ``path``. Returns the list of changed paths."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    resp = api.format_path(FormatPathArgs(path=path))
    return list(resp.changed_paths)


def override_file(
    file: str,
    specs: Sequence[str],
    import_paths: Sequence[str],
) -> bool:
    """Rewrite ``file`` with override ``specs``."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    resp = api.override_file(
        OverrideFileArgs(file=file, specs=list(specs), import_paths=list(import_paths))
    )
    return bool(resp.result)


def validate_code(
    data: Union[bytes, bytearray, str],
    code: Union[bytes, bytearray, str],
    format: str = "yaml",
) -> bool:
    """Validate ``data`` against schema ``code`` in memory."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    args = ValidateCodeArgs(
        data=bytes(data).decode("utf-8") if isinstance(data, (bytes, bytearray)) else data,
        code=bytes(code).decode("utf-8") if isinstance(code, (bytes, bytearray)) else code,
        format=format,
    )
    resp: ValidateCodeResult = api.validate_code(args)
    return bool(resp.success)


def validate(data_file: str, code_file: str) -> bool:
    """Validate the data in ``data_file`` against the schema in ``code_file``."""
    data = pathlib.Path(data_file).read_bytes()
    code = pathlib.Path(code_file).read_bytes()
    return validate_code(data, code)


def test(test_opts: TestArgs) -> TestResult:
    """Run KCL unit tests."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    return api.test(test_opts)


def get_schema_type(filename: str, src: Union[bytes, bytearray, str], schema_name: str):
    """Return schema types from a KCL file or in-memory source."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    source = bytes(src).decode("utf-8") if isinstance(src, (bytes, bytearray)) else src
    exec_args = ExecProgramArgs(
        k_filename_list=[filename],
        k_code_list=[source] if source else [],
    )
    args = GetSchemaTypeMappingArgs(exec_args=exec_args, schema_name=schema_name)
    resp = api.get_schema_type_mapping(args)
    if not schema_name:
        return list(resp.schema_type_mapping.values())
    target = resp.schema_type_mapping.get(schema_name)
    return [target] if target is not None else []


def list_dep_files(path: str) -> List[str]:
    """List dependency files reachable from ``path``.

    Mirrors kcl-go's :func:`ListDepFiles` by invoking the runtime with
    the ``kcl_cli`` argument and reading back ``log_message``.
    """
    return _run_cli_listing(path, "list_dep_files")


def list_upstream_files(path: str) -> List[str]:
    """List upstream (imported) files reachable from ``path``."""
    return _run_cli_listing(path, "list_upstream_files")


def list_downstream_files(path: str) -> List[str]:
    """List downstream files that import ``path``."""
    return _run_cli_listing(path, "list_downstream_files")


def _run_cli_listing(path: str, subcommand: str) -> List[str]:
    """Run ``kcl --kcl_cli <subcommand>`` against ``path`` and parse the log."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    args = ExecProgramArgs(k_filename_list=[path])
    arg = args.args.add()
    arg.name = "kcl_cli"
    arg.value = subcommand
    try:
        resp = api.exec_program(args)
    except Exception:
        return []
    files = [line.strip() for line in (resp.log_message or "").splitlines() if line.strip()]
    return files


def get_version() -> GetVersionResult:
    """Return the underlying KCL runtime version."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    return api.get_version()


def ping(value: str) -> str:
    """Round-trip a value through the runtime."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    resp = api.call("KclService.Ping", PingArgs(value=value))
    return resp.value


def parse_program(
    src: Union[bytes, bytearray, str],
    path: str = "",
) -> ParseProgramResult:
    """Parse a KCL program into an AST JSON string."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    source = bytes(src).decode("utf-8") if isinstance(src, (bytes, bytearray)) else src
    # ``ParseProgramArgs`` carries an in-memory source list (``sources``,
    # repeated) rather than a singular ``source`` field — the latter
    # would be silently rejected by the proto descriptor.
    args = ParseProgramArgs(paths=[path] if path else [], sources=[source])
    return api.parse_program(args)


def load_package(args: LoadPackageArgs) -> LoadPackageResult:
    """Load a KCL package and return its semantic model."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    return api.load_package(args)


def list_variables(args: ListVariablesArgs):
    """List variables defined in the program."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    return api.list_variables(args)


def list_options(args: ParseProgramArgs) -> ListOptionsResult:
    """List ``option(...)`` declarations."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    return api.list_options(args)


def update_dependencies(args: UpdateDependenciesArgs) -> UpdateDependenciesResult:
    """Download and update dependencies declared in ``kcl.mod``."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    return api.update_dependencies(args)


def rename(
    package_root: str,
    symbol_path: str,
    file_paths: Sequence[str],
    new_name: str,
) -> RenameResult:
    """Rename ``symbol_path`` across ``file_paths``."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    args = RenameArgs(
        package_root=package_root,
        symbol_path=symbol_path,
        file_paths=list(file_paths),
        new_name=new_name,
    )
    return api.rename(args)


def rename_code(
    package_root: str,
    symbol_path: str,
    source_codes: dict,
    new_name: str,
) -> RenameCodeResult:
    """Rename a symbol inside ``source_codes`` (no files touched)."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    args = RenameCodeArgs(
        package_root=package_root,
        symbol_path=symbol_path,
        source_codes=dict(source_codes),
        new_name=new_name,
    )
    return api.rename_code(args)


def load_settings_files(
    work_dir: str,
    files: Sequence[str],
) -> LoadSettingsFilesResult:
    """Load ``kcl.yaml`` settings files into a merged config."""
    api = API(plugin_agent=_plugin.plugin_agent_addr)
    args = LoadSettingsFilesArgs(work_dir=work_dir, files=list(files))
    return api.load_settings_files(args)