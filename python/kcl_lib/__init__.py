from ._kcl_lib import *
from . import api, ast, plugin
from .api.service import API
from .ast import Module, Node, Pos, parse_module, parse_program
from .kcl import (
    KCLResult,
    KCLResultList,
    Option,
    TestOptions,
    format_code,
    format_path,
    get_full_schema_type,
    get_full_schema_type_mapping,
    get_full_schema_type_mapping_under_path,
    get_schema_type,
    get_version,
    lint_path,
    list_dep_files,
    list_downstream_files,
    list_options,
    list_upstream_files,
    list_variables,
    load_package,
    load_settings_files,
    must_run,
    override_file,
    ping,
    rename,
    rename_code,
    run,
    run_files,
    test,
    update_dependencies,
    validate,
    validate_code,
    with_code,
    with_disable_none,
    with_error_format,
    with_external_pkgs,
    with_include_schema_type_path,
    with_k_filenames,
    with_logger,
    with_options,
    with_output_format,
    with_overrides,
    with_plugin_agent,
    with_selectors,
    with_settings,
    with_show_hidden,
    with_sort_keys,
    with_work_dir,
)

# ``Position`` is the PascalCase alias matching kcl-go/Java/Node.js exports.
Position = Pos

# Re-bind ``parse_program`` to the typed AST package. ``kcl.parse_program``
# (the raw-proto wrapper) is still reachable as ``kcl_lib.kcl.parse_program``
# for callers who explicitly want it.
parse_program = ast.parse_program