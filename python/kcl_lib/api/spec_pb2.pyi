from google.protobuf.internal import containers as _containers
from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from typing import (
    ClassVar as _ClassVar,
    Iterable as _Iterable,
    Mapping as _Mapping,
    Optional as _Optional,
    Union as _Union,
)

DESCRIPTOR: _descriptor.FileDescriptor

class ExternalPkg(_message.Message):
    __slots__ = ("pkg_name", "pkg_path")
    PKG_NAME_FIELD_NUMBER: _ClassVar[int]
    PKG_PATH_FIELD_NUMBER: _ClassVar[int]
    pkg_name: str
    pkg_path: str
    def __init__(
        self, pkg_name: _Optional[str] = ..., pkg_path: _Optional[str] = ...
    ) -> None: ...

class Argument(_message.Message):
    __slots__ = ("name", "value")
    NAME_FIELD_NUMBER: _ClassVar[int]
    VALUE_FIELD_NUMBER: _ClassVar[int]
    name: str
    value: str
    def __init__(
        self, name: _Optional[str] = ..., value: _Optional[str] = ...
    ) -> None: ...

class Error(_message.Message):
    __slots__ = ("level", "code", "messages")
    LEVEL_FIELD_NUMBER: _ClassVar[int]
    CODE_FIELD_NUMBER: _ClassVar[int]
    MESSAGES_FIELD_NUMBER: _ClassVar[int]
    level: str
    code: str
    messages: _containers.RepeatedCompositeFieldContainer[Message]
    def __init__(
        self,
        level: _Optional[str] = ...,
        code: _Optional[str] = ...,
        messages: _Optional[_Iterable[_Union[Message, _Mapping]]] = ...,
    ) -> None: ...

class Message(_message.Message):
    __slots__ = ("msg", "pos")
    MSG_FIELD_NUMBER: _ClassVar[int]
    POS_FIELD_NUMBER: _ClassVar[int]
    msg: str
    pos: Position
    def __init__(
        self,
        msg: _Optional[str] = ...,
        pos: _Optional[_Union[Position, _Mapping]] = ...,
    ) -> None: ...

class Ping_Args(_message.Message):
    __slots__ = ("value",)
    VALUE_FIELD_NUMBER: _ClassVar[int]
    value: str
    def __init__(self, value: _Optional[str] = ...) -> None: ...

class Ping_Result(_message.Message):
    __slots__ = ("value",)
    VALUE_FIELD_NUMBER: _ClassVar[int]
    value: str
    def __init__(self, value: _Optional[str] = ...) -> None: ...

class GetVersion_Args(_message.Message):
    __slots__ = ()
    def __init__(self) -> None: ...

class GetVersion_Result(_message.Message):
    __slots__ = ("version", "checksum", "git_sha", "version_info")
    VERSION_FIELD_NUMBER: _ClassVar[int]
    CHECKSUM_FIELD_NUMBER: _ClassVar[int]
    GIT_SHA_FIELD_NUMBER: _ClassVar[int]
    VERSION_INFO_FIELD_NUMBER: _ClassVar[int]
    version: str
    checksum: str
    git_sha: str
    version_info: str
    def __init__(
        self,
        version: _Optional[str] = ...,
        checksum: _Optional[str] = ...,
        git_sha: _Optional[str] = ...,
        version_info: _Optional[str] = ...,
    ) -> None: ...

class ListMethod_Args(_message.Message):
    __slots__ = ()
    def __init__(self) -> None: ...

class ListMethod_Result(_message.Message):
    __slots__ = ("method_name_list",)
    METHOD_NAME_LIST_FIELD_NUMBER: _ClassVar[int]
    method_name_list: _containers.RepeatedScalarFieldContainer[str]
    def __init__(self, method_name_list: _Optional[_Iterable[str]] = ...) -> None: ...

class ParseFile_Args(_message.Message):
    __slots__ = ("path", "source", "external_pkgs")
    PATH_FIELD_NUMBER: _ClassVar[int]
    SOURCE_FIELD_NUMBER: _ClassVar[int]
    EXTERNAL_PKGS_FIELD_NUMBER: _ClassVar[int]
    path: str
    source: str
    external_pkgs: _containers.RepeatedCompositeFieldContainer[ExternalPkg]
    def __init__(
        self,
        path: _Optional[str] = ...,
        source: _Optional[str] = ...,
        external_pkgs: _Optional[_Iterable[_Union[ExternalPkg, _Mapping]]] = ...,
    ) -> None: ...

class ParseFile_Result(_message.Message):
    __slots__ = ("ast_json", "deps", "errors")
    AST_JSON_FIELD_NUMBER: _ClassVar[int]
    DEPS_FIELD_NUMBER: _ClassVar[int]
    ERRORS_FIELD_NUMBER: _ClassVar[int]
    ast_json: str
    deps: _containers.RepeatedScalarFieldContainer[str]
    errors: _containers.RepeatedCompositeFieldContainer[Error]
    def __init__(
        self,
        ast_json: _Optional[str] = ...,
        deps: _Optional[_Iterable[str]] = ...,
        errors: _Optional[_Iterable[_Union[Error, _Mapping]]] = ...,
    ) -> None: ...

class ParseProgram_Args(_message.Message):
    __slots__ = ("paths", "sources", "external_pkgs")
    PATHS_FIELD_NUMBER: _ClassVar[int]
    SOURCES_FIELD_NUMBER: _ClassVar[int]
    EXTERNAL_PKGS_FIELD_NUMBER: _ClassVar[int]
    paths: _containers.RepeatedScalarFieldContainer[str]
    sources: _containers.RepeatedScalarFieldContainer[str]
    external_pkgs: _containers.RepeatedCompositeFieldContainer[ExternalPkg]
    def __init__(
        self,
        paths: _Optional[_Iterable[str]] = ...,
        sources: _Optional[_Iterable[str]] = ...,
        external_pkgs: _Optional[_Iterable[_Union[ExternalPkg, _Mapping]]] = ...,
    ) -> None: ...

class ParseProgram_Result(_message.Message):
    __slots__ = ("ast_json", "paths", "errors")
    AST_JSON_FIELD_NUMBER: _ClassVar[int]
    PATHS_FIELD_NUMBER: _ClassVar[int]
    ERRORS_FIELD_NUMBER: _ClassVar[int]
    ast_json: str
    paths: _containers.RepeatedScalarFieldContainer[str]
    errors: _containers.RepeatedCompositeFieldContainer[Error]
    def __init__(
        self,
        ast_json: _Optional[str] = ...,
        paths: _Optional[_Iterable[str]] = ...,
        errors: _Optional[_Iterable[_Union[Error, _Mapping]]] = ...,
    ) -> None: ...

class LoadPackage_Args(_message.Message):
    __slots__ = ("parse_args", "resolve_ast", "load_builtin", "with_ast_index")
    PARSE_ARGS_FIELD_NUMBER: _ClassVar[int]
    RESOLVE_AST_FIELD_NUMBER: _ClassVar[int]
    LOAD_BUILTIN_FIELD_NUMBER: _ClassVar[int]
    WITH_AST_INDEX_FIELD_NUMBER: _ClassVar[int]
    parse_args: ParseProgram_Args
    resolve_ast: bool
    load_builtin: bool
    with_ast_index: bool
    def __init__(
        self,
        parse_args: _Optional[_Union[ParseProgram_Args, _Mapping]] = ...,
        resolve_ast: bool = ...,
        load_builtin: bool = ...,
        with_ast_index: bool = ...,
    ) -> None: ...

class LoadPackage_Result(_message.Message):
    __slots__ = (
        "program",
        "paths",
        "parse_errors",
        "type_errors",
        "scopes",
        "symbols",
        "node_symbol_map",
        "symbol_node_map",
        "fully_qualified_name_map",
        "pkg_scope_map",
    )

    class ScopesEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: Scope
        def __init__(
            self,
            key: _Optional[str] = ...,
            value: _Optional[_Union[Scope, _Mapping]] = ...,
        ) -> None: ...

    class SymbolsEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: Symbol
        def __init__(
            self,
            key: _Optional[str] = ...,
            value: _Optional[_Union[Symbol, _Mapping]] = ...,
        ) -> None: ...

    class NodeSymbolMapEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: SymbolIndex
        def __init__(
            self,
            key: _Optional[str] = ...,
            value: _Optional[_Union[SymbolIndex, _Mapping]] = ...,
        ) -> None: ...

    class SymbolNodeMapEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(
            self, key: _Optional[str] = ..., value: _Optional[str] = ...
        ) -> None: ...

    class FullyQualifiedNameMapEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: SymbolIndex
        def __init__(
            self,
            key: _Optional[str] = ...,
            value: _Optional[_Union[SymbolIndex, _Mapping]] = ...,
        ) -> None: ...

    class PkgScopeMapEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: ScopeIndex
        def __init__(
            self,
            key: _Optional[str] = ...,
            value: _Optional[_Union[ScopeIndex, _Mapping]] = ...,
        ) -> None: ...

    PROGRAM_FIELD_NUMBER: _ClassVar[int]
    PATHS_FIELD_NUMBER: _ClassVar[int]
    PARSE_ERRORS_FIELD_NUMBER: _ClassVar[int]
    TYPE_ERRORS_FIELD_NUMBER: _ClassVar[int]
    SCOPES_FIELD_NUMBER: _ClassVar[int]
    SYMBOLS_FIELD_NUMBER: _ClassVar[int]
    NODE_SYMBOL_MAP_FIELD_NUMBER: _ClassVar[int]
    SYMBOL_NODE_MAP_FIELD_NUMBER: _ClassVar[int]
    FULLY_QUALIFIED_NAME_MAP_FIELD_NUMBER: _ClassVar[int]
    PKG_SCOPE_MAP_FIELD_NUMBER: _ClassVar[int]
    program: str
    paths: _containers.RepeatedScalarFieldContainer[str]
    parse_errors: _containers.RepeatedCompositeFieldContainer[Error]
    type_errors: _containers.RepeatedCompositeFieldContainer[Error]
    scopes: _containers.MessageMap[str, Scope]
    symbols: _containers.MessageMap[str, Symbol]
    node_symbol_map: _containers.MessageMap[str, SymbolIndex]
    symbol_node_map: _containers.ScalarMap[str, str]
    fully_qualified_name_map: _containers.MessageMap[str, SymbolIndex]
    pkg_scope_map: _containers.MessageMap[str, ScopeIndex]
    def __init__(
        self,
        program: _Optional[str] = ...,
        paths: _Optional[_Iterable[str]] = ...,
        parse_errors: _Optional[_Iterable[_Union[Error, _Mapping]]] = ...,
        type_errors: _Optional[_Iterable[_Union[Error, _Mapping]]] = ...,
        scopes: _Optional[_Mapping[str, Scope]] = ...,
        symbols: _Optional[_Mapping[str, Symbol]] = ...,
        node_symbol_map: _Optional[_Mapping[str, SymbolIndex]] = ...,
        symbol_node_map: _Optional[_Mapping[str, str]] = ...,
        fully_qualified_name_map: _Optional[_Mapping[str, SymbolIndex]] = ...,
        pkg_scope_map: _Optional[_Mapping[str, ScopeIndex]] = ...,
    ) -> None: ...

class ListOptions_Result(_message.Message):
    __slots__ = ("options",)
    OPTIONS_FIELD_NUMBER: _ClassVar[int]
    options: _containers.RepeatedCompositeFieldContainer[OptionHelp]
    def __init__(
        self, options: _Optional[_Iterable[_Union[OptionHelp, _Mapping]]] = ...
    ) -> None: ...

class OptionHelp(_message.Message):
    __slots__ = ("name", "type", "required", "default_value", "help")
    NAME_FIELD_NUMBER: _ClassVar[int]
    TYPE_FIELD_NUMBER: _ClassVar[int]
    REQUIRED_FIELD_NUMBER: _ClassVar[int]
    DEFAULT_VALUE_FIELD_NUMBER: _ClassVar[int]
    HELP_FIELD_NUMBER: _ClassVar[int]
    name: str
    type: str
    required: bool
    default_value: str
    help: str
    def __init__(
        self,
        name: _Optional[str] = ...,
        type: _Optional[str] = ...,
        required: bool = ...,
        default_value: _Optional[str] = ...,
        help: _Optional[str] = ...,
    ) -> None: ...

class Symbol(_message.Message):
    __slots__ = ("ty", "name", "owner", "attrs", "is_global")
    TY_FIELD_NUMBER: _ClassVar[int]
    NAME_FIELD_NUMBER: _ClassVar[int]
    OWNER_FIELD_NUMBER: _ClassVar[int]
    DEF_FIELD_NUMBER: _ClassVar[int]
    ATTRS_FIELD_NUMBER: _ClassVar[int]
    IS_GLOBAL_FIELD_NUMBER: _ClassVar[int]
    ty: KclType
    name: str
    owner: SymbolIndex
    attrs: _containers.RepeatedCompositeFieldContainer[SymbolIndex]
    is_global: bool
    def __init__(
        self,
        ty: _Optional[_Union[KclType, _Mapping]] = ...,
        name: _Optional[str] = ...,
        owner: _Optional[_Union[SymbolIndex, _Mapping]] = ...,
        attrs: _Optional[_Iterable[_Union[SymbolIndex, _Mapping]]] = ...,
        is_global: bool = ...,
        **kwargs
    ) -> None: ...

class Scope(_message.Message):
    __slots__ = ("kind", "parent", "owner", "children", "defs")
    KIND_FIELD_NUMBER: _ClassVar[int]
    PARENT_FIELD_NUMBER: _ClassVar[int]
    OWNER_FIELD_NUMBER: _ClassVar[int]
    CHILDREN_FIELD_NUMBER: _ClassVar[int]
    DEFS_FIELD_NUMBER: _ClassVar[int]
    kind: str
    parent: ScopeIndex
    owner: SymbolIndex
    children: _containers.RepeatedCompositeFieldContainer[ScopeIndex]
    defs: _containers.RepeatedCompositeFieldContainer[SymbolIndex]
    def __init__(
        self,
        kind: _Optional[str] = ...,
        parent: _Optional[_Union[ScopeIndex, _Mapping]] = ...,
        owner: _Optional[_Union[SymbolIndex, _Mapping]] = ...,
        children: _Optional[_Iterable[_Union[ScopeIndex, _Mapping]]] = ...,
        defs: _Optional[_Iterable[_Union[SymbolIndex, _Mapping]]] = ...,
    ) -> None: ...

class SymbolIndex(_message.Message):
    __slots__ = ("i", "g", "kind")
    I_FIELD_NUMBER: _ClassVar[int]
    G_FIELD_NUMBER: _ClassVar[int]
    KIND_FIELD_NUMBER: _ClassVar[int]
    i: int
    g: int
    kind: str
    def __init__(
        self,
        i: _Optional[int] = ...,
        g: _Optional[int] = ...,
        kind: _Optional[str] = ...,
    ) -> None: ...

class ScopeIndex(_message.Message):
    __slots__ = ("i", "g", "kind")
    I_FIELD_NUMBER: _ClassVar[int]
    G_FIELD_NUMBER: _ClassVar[int]
    KIND_FIELD_NUMBER: _ClassVar[int]
    i: int
    g: int
    kind: str
    def __init__(
        self,
        i: _Optional[int] = ...,
        g: _Optional[int] = ...,
        kind: _Optional[str] = ...,
    ) -> None: ...

class ExecProgram_Args(_message.Message):
    __slots__ = (
        "work_dir",
        "k_filename_list",
        "k_code_list",
        "args",
        "overrides",
        "disable_yaml_result",
        "print_override_ast",
        "strict_range_check",
        "disable_none",
        "verbose",
        "debug",
        "sort_keys",
        "external_pkgs",
        "include_schema_type_path",
        "compile_only",
        "show_hidden",
        "path_selector",
        "fast_eval",
    )
    WORK_DIR_FIELD_NUMBER: _ClassVar[int]
    K_FILENAME_LIST_FIELD_NUMBER: _ClassVar[int]
    K_CODE_LIST_FIELD_NUMBER: _ClassVar[int]
    ARGS_FIELD_NUMBER: _ClassVar[int]
    OVERRIDES_FIELD_NUMBER: _ClassVar[int]
    DISABLE_YAML_RESULT_FIELD_NUMBER: _ClassVar[int]
    PRINT_OVERRIDE_AST_FIELD_NUMBER: _ClassVar[int]
    STRICT_RANGE_CHECK_FIELD_NUMBER: _ClassVar[int]
    DISABLE_NONE_FIELD_NUMBER: _ClassVar[int]
    VERBOSE_FIELD_NUMBER: _ClassVar[int]
    DEBUG_FIELD_NUMBER: _ClassVar[int]
    SORT_KEYS_FIELD_NUMBER: _ClassVar[int]
    EXTERNAL_PKGS_FIELD_NUMBER: _ClassVar[int]
    INCLUDE_SCHEMA_TYPE_PATH_FIELD_NUMBER: _ClassVar[int]
    COMPILE_ONLY_FIELD_NUMBER: _ClassVar[int]
    SHOW_HIDDEN_FIELD_NUMBER: _ClassVar[int]
    PATH_SELECTOR_FIELD_NUMBER: _ClassVar[int]
    FAST_EVAL_FIELD_NUMBER: _ClassVar[int]
    work_dir: str
    k_filename_list: _containers.RepeatedScalarFieldContainer[str]
    k_code_list: _containers.RepeatedScalarFieldContainer[str]
    args: _containers.RepeatedCompositeFieldContainer[Argument]
    overrides: _containers.RepeatedScalarFieldContainer[str]
    disable_yaml_result: bool
    print_override_ast: bool
    strict_range_check: bool
    disable_none: bool
    verbose: int
    debug: int
    sort_keys: bool
    external_pkgs: _containers.RepeatedCompositeFieldContainer[ExternalPkg]
    include_schema_type_path: bool
    compile_only: bool
    show_hidden: bool
    path_selector: _containers.RepeatedScalarFieldContainer[str]
    fast_eval: bool
    def __init__(
        self,
        work_dir: _Optional[str] = ...,
        k_filename_list: _Optional[_Iterable[str]] = ...,
        k_code_list: _Optional[_Iterable[str]] = ...,
        args: _Optional[_Iterable[_Union[Argument, _Mapping]]] = ...,
        overrides: _Optional[_Iterable[str]] = ...,
        disable_yaml_result: bool = ...,
        print_override_ast: bool = ...,
        strict_range_check: bool = ...,
        disable_none: bool = ...,
        verbose: _Optional[int] = ...,
        debug: _Optional[int] = ...,
        sort_keys: bool = ...,
        external_pkgs: _Optional[_Iterable[_Union[ExternalPkg, _Mapping]]] = ...,
        include_schema_type_path: bool = ...,
        compile_only: bool = ...,
        show_hidden: bool = ...,
        path_selector: _Optional[_Iterable[str]] = ...,
        fast_eval: bool = ...,
    ) -> None: ...

class ExecProgram_Result(_message.Message):
    __slots__ = ("json_result", "yaml_result", "log_message", "err_message")
    JSON_RESULT_FIELD_NUMBER: _ClassVar[int]
    YAML_RESULT_FIELD_NUMBER: _ClassVar[int]
    LOG_MESSAGE_FIELD_NUMBER: _ClassVar[int]
    ERR_MESSAGE_FIELD_NUMBER: _ClassVar[int]
    json_result: str
    yaml_result: str
    log_message: str
    err_message: str
    def __init__(
        self,
        json_result: _Optional[str] = ...,
        yaml_result: _Optional[str] = ...,
        log_message: _Optional[str] = ...,
        err_message: _Optional[str] = ...,
    ) -> None: ...

class BuildProgram_Args(_message.Message):
    __slots__ = ("exec_args", "output")
    EXEC_ARGS_FIELD_NUMBER: _ClassVar[int]
    OUTPUT_FIELD_NUMBER: _ClassVar[int]
    exec_args: ExecProgram_Args
    output: str
    def __init__(
        self,
        exec_args: _Optional[_Union[ExecProgram_Args, _Mapping]] = ...,
        output: _Optional[str] = ...,
    ) -> None: ...

class BuildProgram_Result(_message.Message):
    __slots__ = ("path",)
    PATH_FIELD_NUMBER: _ClassVar[int]
    path: str
    def __init__(self, path: _Optional[str] = ...) -> None: ...

class ExecArtifact_Args(_message.Message):
    __slots__ = ("path", "exec_args")
    PATH_FIELD_NUMBER: _ClassVar[int]
    EXEC_ARGS_FIELD_NUMBER: _ClassVar[int]
    path: str
    exec_args: ExecProgram_Args
    def __init__(
        self,
        path: _Optional[str] = ...,
        exec_args: _Optional[_Union[ExecProgram_Args, _Mapping]] = ...,
    ) -> None: ...

class FormatCode_Args(_message.Message):
    __slots__ = ("source",)
    SOURCE_FIELD_NUMBER: _ClassVar[int]
    source: str
    def __init__(self, source: _Optional[str] = ...) -> None: ...

class FormatCode_Result(_message.Message):
    __slots__ = ("formatted",)
    FORMATTED_FIELD_NUMBER: _ClassVar[int]
    formatted: bytes
    def __init__(self, formatted: _Optional[bytes] = ...) -> None: ...

class FormatPath_Args(_message.Message):
    __slots__ = ("path",)
    PATH_FIELD_NUMBER: _ClassVar[int]
    path: str
    def __init__(self, path: _Optional[str] = ...) -> None: ...

class FormatPath_Result(_message.Message):
    __slots__ = ("changed_paths",)
    CHANGED_PATHS_FIELD_NUMBER: _ClassVar[int]
    changed_paths: _containers.RepeatedScalarFieldContainer[str]
    def __init__(self, changed_paths: _Optional[_Iterable[str]] = ...) -> None: ...

class LintPath_Args(_message.Message):
    __slots__ = ("paths",)
    PATHS_FIELD_NUMBER: _ClassVar[int]
    paths: _containers.RepeatedScalarFieldContainer[str]
    def __init__(self, paths: _Optional[_Iterable[str]] = ...) -> None: ...

class LintPath_Result(_message.Message):
    __slots__ = ("results",)
    RESULTS_FIELD_NUMBER: _ClassVar[int]
    results: _containers.RepeatedScalarFieldContainer[str]
    def __init__(self, results: _Optional[_Iterable[str]] = ...) -> None: ...

class OverrideFile_Args(_message.Message):
    __slots__ = ("file", "specs", "import_paths")
    FILE_FIELD_NUMBER: _ClassVar[int]
    SPECS_FIELD_NUMBER: _ClassVar[int]
    IMPORT_PATHS_FIELD_NUMBER: _ClassVar[int]
    file: str
    specs: _containers.RepeatedScalarFieldContainer[str]
    import_paths: _containers.RepeatedScalarFieldContainer[str]
    def __init__(
        self,
        file: _Optional[str] = ...,
        specs: _Optional[_Iterable[str]] = ...,
        import_paths: _Optional[_Iterable[str]] = ...,
    ) -> None: ...

class OverrideFile_Result(_message.Message):
    __slots__ = ("result", "parse_errors")
    RESULT_FIELD_NUMBER: _ClassVar[int]
    PARSE_ERRORS_FIELD_NUMBER: _ClassVar[int]
    result: bool
    parse_errors: _containers.RepeatedCompositeFieldContainer[Error]
    def __init__(
        self,
        result: bool = ...,
        parse_errors: _Optional[_Iterable[_Union[Error, _Mapping]]] = ...,
    ) -> None: ...

class ListVariables_Options(_message.Message):
    __slots__ = ("merge_program",)
    MERGE_PROGRAM_FIELD_NUMBER: _ClassVar[int]
    merge_program: bool
    def __init__(self, merge_program: bool = ...) -> None: ...

class VariableList(_message.Message):
    __slots__ = ("variables",)
    VARIABLES_FIELD_NUMBER: _ClassVar[int]
    variables: _containers.RepeatedCompositeFieldContainer[Variable]
    def __init__(
        self, variables: _Optional[_Iterable[_Union[Variable, _Mapping]]] = ...
    ) -> None: ...

class ListVariables_Args(_message.Message):
    __slots__ = ("files", "specs", "options")
    FILES_FIELD_NUMBER: _ClassVar[int]
    SPECS_FIELD_NUMBER: _ClassVar[int]
    OPTIONS_FIELD_NUMBER: _ClassVar[int]
    files: _containers.RepeatedScalarFieldContainer[str]
    specs: _containers.RepeatedScalarFieldContainer[str]
    options: ListVariables_Options
    def __init__(
        self,
        files: _Optional[_Iterable[str]] = ...,
        specs: _Optional[_Iterable[str]] = ...,
        options: _Optional[_Union[ListVariables_Options, _Mapping]] = ...,
    ) -> None: ...

class ListVariables_Result(_message.Message):
    __slots__ = ("variables", "unsupported_codes", "parse_errors")

    class VariablesEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: VariableList
        def __init__(
            self,
            key: _Optional[str] = ...,
            value: _Optional[_Union[VariableList, _Mapping]] = ...,
        ) -> None: ...

    VARIABLES_FIELD_NUMBER: _ClassVar[int]
    UNSUPPORTED_CODES_FIELD_NUMBER: _ClassVar[int]
    PARSE_ERRORS_FIELD_NUMBER: _ClassVar[int]
    variables: _containers.MessageMap[str, VariableList]
    unsupported_codes: _containers.RepeatedScalarFieldContainer[str]
    parse_errors: _containers.RepeatedCompositeFieldContainer[Error]
    def __init__(
        self,
        variables: _Optional[_Mapping[str, VariableList]] = ...,
        unsupported_codes: _Optional[_Iterable[str]] = ...,
        parse_errors: _Optional[_Iterable[_Union[Error, _Mapping]]] = ...,
    ) -> None: ...

class Variable(_message.Message):
    __slots__ = ("value", "type_name", "op_sym", "list_items", "dict_entries")
    VALUE_FIELD_NUMBER: _ClassVar[int]
    TYPE_NAME_FIELD_NUMBER: _ClassVar[int]
    OP_SYM_FIELD_NUMBER: _ClassVar[int]
    LIST_ITEMS_FIELD_NUMBER: _ClassVar[int]
    DICT_ENTRIES_FIELD_NUMBER: _ClassVar[int]
    value: str
    type_name: str
    op_sym: str
    list_items: _containers.RepeatedCompositeFieldContainer[Variable]
    dict_entries: _containers.RepeatedCompositeFieldContainer[MapEntry]
    def __init__(
        self,
        value: _Optional[str] = ...,
        type_name: _Optional[str] = ...,
        op_sym: _Optional[str] = ...,
        list_items: _Optional[_Iterable[_Union[Variable, _Mapping]]] = ...,
        dict_entries: _Optional[_Iterable[_Union[MapEntry, _Mapping]]] = ...,
    ) -> None: ...

class MapEntry(_message.Message):
    __slots__ = ("key", "value")
    KEY_FIELD_NUMBER: _ClassVar[int]
    VALUE_FIELD_NUMBER: _ClassVar[int]
    key: str
    value: Variable
    def __init__(
        self,
        key: _Optional[str] = ...,
        value: _Optional[_Union[Variable, _Mapping]] = ...,
    ) -> None: ...

class GetSchemaTypeMapping_Args(_message.Message):
    __slots__ = ("exec_args", "schema_name")
    EXEC_ARGS_FIELD_NUMBER: _ClassVar[int]
    SCHEMA_NAME_FIELD_NUMBER: _ClassVar[int]
    exec_args: ExecProgram_Args
    schema_name: str
    def __init__(
        self,
        exec_args: _Optional[_Union[ExecProgram_Args, _Mapping]] = ...,
        schema_name: _Optional[str] = ...,
    ) -> None: ...

class GetSchemaTypeMapping_Result(_message.Message):
    __slots__ = ("schema_type_mapping",)

    class SchemaTypeMappingEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: KclType
        def __init__(
            self,
            key: _Optional[str] = ...,
            value: _Optional[_Union[KclType, _Mapping]] = ...,
        ) -> None: ...

    SCHEMA_TYPE_MAPPING_FIELD_NUMBER: _ClassVar[int]
    schema_type_mapping: _containers.MessageMap[str, KclType]
    def __init__(
        self, schema_type_mapping: _Optional[_Mapping[str, KclType]] = ...
    ) -> None: ...

class ValidateCode_Args(_message.Message):
    __slots__ = (
        "datafile",
        "data",
        "file",
        "code",
        "schema",
        "attribute_name",
        "format",
    )
    DATAFILE_FIELD_NUMBER: _ClassVar[int]
    DATA_FIELD_NUMBER: _ClassVar[int]
    FILE_FIELD_NUMBER: _ClassVar[int]
    CODE_FIELD_NUMBER: _ClassVar[int]
    SCHEMA_FIELD_NUMBER: _ClassVar[int]
    ATTRIBUTE_NAME_FIELD_NUMBER: _ClassVar[int]
    FORMAT_FIELD_NUMBER: _ClassVar[int]
    datafile: str
    data: str
    file: str
    code: str
    schema: str
    attribute_name: str
    format: str
    def __init__(
        self,
        datafile: _Optional[str] = ...,
        data: _Optional[str] = ...,
        file: _Optional[str] = ...,
        code: _Optional[str] = ...,
        schema: _Optional[str] = ...,
        attribute_name: _Optional[str] = ...,
        format: _Optional[str] = ...,
    ) -> None: ...

class ValidateCode_Result(_message.Message):
    __slots__ = ("success", "err_message")
    SUCCESS_FIELD_NUMBER: _ClassVar[int]
    ERR_MESSAGE_FIELD_NUMBER: _ClassVar[int]
    success: bool
    err_message: str
    def __init__(
        self, success: bool = ..., err_message: _Optional[str] = ...
    ) -> None: ...

class Position(_message.Message):
    __slots__ = ("line", "column", "filename")
    LINE_FIELD_NUMBER: _ClassVar[int]
    COLUMN_FIELD_NUMBER: _ClassVar[int]
    FILENAME_FIELD_NUMBER: _ClassVar[int]
    line: int
    column: int
    filename: str
    def __init__(
        self,
        line: _Optional[int] = ...,
        column: _Optional[int] = ...,
        filename: _Optional[str] = ...,
    ) -> None: ...

class ListDepFiles_Args(_message.Message):
    __slots__ = ("work_dir", "use_abs_path", "include_all", "use_fast_parser")
    WORK_DIR_FIELD_NUMBER: _ClassVar[int]
    USE_ABS_PATH_FIELD_NUMBER: _ClassVar[int]
    INCLUDE_ALL_FIELD_NUMBER: _ClassVar[int]
    USE_FAST_PARSER_FIELD_NUMBER: _ClassVar[int]
    work_dir: str
    use_abs_path: bool
    include_all: bool
    use_fast_parser: bool
    def __init__(
        self,
        work_dir: _Optional[str] = ...,
        use_abs_path: bool = ...,
        include_all: bool = ...,
        use_fast_parser: bool = ...,
    ) -> None: ...

class ListDepFiles_Result(_message.Message):
    __slots__ = ("pkgroot", "pkgpath", "files")
    PKGROOT_FIELD_NUMBER: _ClassVar[int]
    PKGPATH_FIELD_NUMBER: _ClassVar[int]
    FILES_FIELD_NUMBER: _ClassVar[int]
    pkgroot: str
    pkgpath: str
    files: _containers.RepeatedScalarFieldContainer[str]
    def __init__(
        self,
        pkgroot: _Optional[str] = ...,
        pkgpath: _Optional[str] = ...,
        files: _Optional[_Iterable[str]] = ...,
    ) -> None: ...

class LoadSettingsFiles_Args(_message.Message):
    __slots__ = ("work_dir", "files")
    WORK_DIR_FIELD_NUMBER: _ClassVar[int]
    FILES_FIELD_NUMBER: _ClassVar[int]
    work_dir: str
    files: _containers.RepeatedScalarFieldContainer[str]
    def __init__(
        self, work_dir: _Optional[str] = ..., files: _Optional[_Iterable[str]] = ...
    ) -> None: ...

class LoadSettingsFiles_Result(_message.Message):
    __slots__ = ("kcl_cli_configs", "kcl_options")
    KCL_CLI_CONFIGS_FIELD_NUMBER: _ClassVar[int]
    KCL_OPTIONS_FIELD_NUMBER: _ClassVar[int]
    kcl_cli_configs: CliConfig
    kcl_options: _containers.RepeatedCompositeFieldContainer[KeyValuePair]
    def __init__(
        self,
        kcl_cli_configs: _Optional[_Union[CliConfig, _Mapping]] = ...,
        kcl_options: _Optional[_Iterable[_Union[KeyValuePair, _Mapping]]] = ...,
    ) -> None: ...

class CliConfig(_message.Message):
    __slots__ = (
        "files",
        "output",
        "overrides",
        "path_selector",
        "strict_range_check",
        "disable_none",
        "verbose",
        "debug",
        "sort_keys",
        "show_hidden",
        "include_schema_type_path",
        "fast_eval",
    )
    FILES_FIELD_NUMBER: _ClassVar[int]
    OUTPUT_FIELD_NUMBER: _ClassVar[int]
    OVERRIDES_FIELD_NUMBER: _ClassVar[int]
    PATH_SELECTOR_FIELD_NUMBER: _ClassVar[int]
    STRICT_RANGE_CHECK_FIELD_NUMBER: _ClassVar[int]
    DISABLE_NONE_FIELD_NUMBER: _ClassVar[int]
    VERBOSE_FIELD_NUMBER: _ClassVar[int]
    DEBUG_FIELD_NUMBER: _ClassVar[int]
    SORT_KEYS_FIELD_NUMBER: _ClassVar[int]
    SHOW_HIDDEN_FIELD_NUMBER: _ClassVar[int]
    INCLUDE_SCHEMA_TYPE_PATH_FIELD_NUMBER: _ClassVar[int]
    FAST_EVAL_FIELD_NUMBER: _ClassVar[int]
    files: _containers.RepeatedScalarFieldContainer[str]
    output: str
    overrides: _containers.RepeatedScalarFieldContainer[str]
    path_selector: _containers.RepeatedScalarFieldContainer[str]
    strict_range_check: bool
    disable_none: bool
    verbose: int
    debug: bool
    sort_keys: bool
    show_hidden: bool
    include_schema_type_path: bool
    fast_eval: bool
    def __init__(
        self,
        files: _Optional[_Iterable[str]] = ...,
        output: _Optional[str] = ...,
        overrides: _Optional[_Iterable[str]] = ...,
        path_selector: _Optional[_Iterable[str]] = ...,
        strict_range_check: bool = ...,
        disable_none: bool = ...,
        verbose: _Optional[int] = ...,
        debug: bool = ...,
        sort_keys: bool = ...,
        show_hidden: bool = ...,
        include_schema_type_path: bool = ...,
        fast_eval: bool = ...,
    ) -> None: ...

class KeyValuePair(_message.Message):
    __slots__ = ("key", "value")
    KEY_FIELD_NUMBER: _ClassVar[int]
    VALUE_FIELD_NUMBER: _ClassVar[int]
    key: str
    value: str
    def __init__(
        self, key: _Optional[str] = ..., value: _Optional[str] = ...
    ) -> None: ...

class Rename_Args(_message.Message):
    __slots__ = ("package_root", "symbol_path", "file_paths", "new_name")
    PACKAGE_ROOT_FIELD_NUMBER: _ClassVar[int]
    SYMBOL_PATH_FIELD_NUMBER: _ClassVar[int]
    FILE_PATHS_FIELD_NUMBER: _ClassVar[int]
    NEW_NAME_FIELD_NUMBER: _ClassVar[int]
    package_root: str
    symbol_path: str
    file_paths: _containers.RepeatedScalarFieldContainer[str]
    new_name: str
    def __init__(
        self,
        package_root: _Optional[str] = ...,
        symbol_path: _Optional[str] = ...,
        file_paths: _Optional[_Iterable[str]] = ...,
        new_name: _Optional[str] = ...,
    ) -> None: ...

class Rename_Result(_message.Message):
    __slots__ = ("changed_files",)
    CHANGED_FILES_FIELD_NUMBER: _ClassVar[int]
    changed_files: _containers.RepeatedScalarFieldContainer[str]
    def __init__(self, changed_files: _Optional[_Iterable[str]] = ...) -> None: ...

class RenameCode_Args(_message.Message):
    __slots__ = ("package_root", "symbol_path", "source_codes", "new_name")

    class SourceCodesEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(
            self, key: _Optional[str] = ..., value: _Optional[str] = ...
        ) -> None: ...

    PACKAGE_ROOT_FIELD_NUMBER: _ClassVar[int]
    SYMBOL_PATH_FIELD_NUMBER: _ClassVar[int]
    SOURCE_CODES_FIELD_NUMBER: _ClassVar[int]
    NEW_NAME_FIELD_NUMBER: _ClassVar[int]
    package_root: str
    symbol_path: str
    source_codes: _containers.ScalarMap[str, str]
    new_name: str
    def __init__(
        self,
        package_root: _Optional[str] = ...,
        symbol_path: _Optional[str] = ...,
        source_codes: _Optional[_Mapping[str, str]] = ...,
        new_name: _Optional[str] = ...,
    ) -> None: ...

class RenameCode_Result(_message.Message):
    __slots__ = ("changed_codes",)

    class ChangedCodesEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(
            self, key: _Optional[str] = ..., value: _Optional[str] = ...
        ) -> None: ...

    CHANGED_CODES_FIELD_NUMBER: _ClassVar[int]
    changed_codes: _containers.ScalarMap[str, str]
    def __init__(self, changed_codes: _Optional[_Mapping[str, str]] = ...) -> None: ...

class Test_Args(_message.Message):
    __slots__ = ("exec_args", "pkg_list", "run_regexp", "fail_fast")
    EXEC_ARGS_FIELD_NUMBER: _ClassVar[int]
    PKG_LIST_FIELD_NUMBER: _ClassVar[int]
    RUN_REGEXP_FIELD_NUMBER: _ClassVar[int]
    FAIL_FAST_FIELD_NUMBER: _ClassVar[int]
    exec_args: ExecProgram_Args
    pkg_list: _containers.RepeatedScalarFieldContainer[str]
    run_regexp: str
    fail_fast: bool
    def __init__(
        self,
        exec_args: _Optional[_Union[ExecProgram_Args, _Mapping]] = ...,
        pkg_list: _Optional[_Iterable[str]] = ...,
        run_regexp: _Optional[str] = ...,
        fail_fast: bool = ...,
    ) -> None: ...

class Test_Result(_message.Message):
    __slots__ = ("info",)
    INFO_FIELD_NUMBER: _ClassVar[int]
    info: _containers.RepeatedCompositeFieldContainer[TestCaseInfo]
    def __init__(
        self, info: _Optional[_Iterable[_Union[TestCaseInfo, _Mapping]]] = ...
    ) -> None: ...

class TestCaseInfo(_message.Message):
    __slots__ = ("name", "error", "duration", "log_message")
    NAME_FIELD_NUMBER: _ClassVar[int]
    ERROR_FIELD_NUMBER: _ClassVar[int]
    DURATION_FIELD_NUMBER: _ClassVar[int]
    LOG_MESSAGE_FIELD_NUMBER: _ClassVar[int]
    name: str
    error: str
    duration: int
    log_message: str
    def __init__(
        self,
        name: _Optional[str] = ...,
        error: _Optional[str] = ...,
        duration: _Optional[int] = ...,
        log_message: _Optional[str] = ...,
    ) -> None: ...

class UpdateDependencies_Args(_message.Message):
    __slots__ = ("manifest_path", "vendor")
    MANIFEST_PATH_FIELD_NUMBER: _ClassVar[int]
    VENDOR_FIELD_NUMBER: _ClassVar[int]
    manifest_path: str
    vendor: bool
    def __init__(
        self, manifest_path: _Optional[str] = ..., vendor: bool = ...
    ) -> None: ...

class UpdateDependencies_Result(_message.Message):
    __slots__ = ("external_pkgs",)
    EXTERNAL_PKGS_FIELD_NUMBER: _ClassVar[int]
    external_pkgs: _containers.RepeatedCompositeFieldContainer[ExternalPkg]
    def __init__(
        self, external_pkgs: _Optional[_Iterable[_Union[ExternalPkg, _Mapping]]] = ...
    ) -> None: ...

class KclType(_message.Message):
    __slots__ = (
        "type",
        "union_types",
        "default",
        "schema_name",
        "schema_doc",
        "properties",
        "required",
        "key",
        "item",
        "line",
        "decorators",
        "filename",
        "pkg_path",
        "description",
        "examples",
        "base_schema",
    )

    class PropertiesEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: KclType
        def __init__(
            self,
            key: _Optional[str] = ...,
            value: _Optional[_Union[KclType, _Mapping]] = ...,
        ) -> None: ...

    class ExamplesEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: Example
        def __init__(
            self,
            key: _Optional[str] = ...,
            value: _Optional[_Union[Example, _Mapping]] = ...,
        ) -> None: ...

    TYPE_FIELD_NUMBER: _ClassVar[int]
    UNION_TYPES_FIELD_NUMBER: _ClassVar[int]
    DEFAULT_FIELD_NUMBER: _ClassVar[int]
    SCHEMA_NAME_FIELD_NUMBER: _ClassVar[int]
    SCHEMA_DOC_FIELD_NUMBER: _ClassVar[int]
    PROPERTIES_FIELD_NUMBER: _ClassVar[int]
    REQUIRED_FIELD_NUMBER: _ClassVar[int]
    KEY_FIELD_NUMBER: _ClassVar[int]
    ITEM_FIELD_NUMBER: _ClassVar[int]
    LINE_FIELD_NUMBER: _ClassVar[int]
    DECORATORS_FIELD_NUMBER: _ClassVar[int]
    FILENAME_FIELD_NUMBER: _ClassVar[int]
    PKG_PATH_FIELD_NUMBER: _ClassVar[int]
    DESCRIPTION_FIELD_NUMBER: _ClassVar[int]
    EXAMPLES_FIELD_NUMBER: _ClassVar[int]
    BASE_SCHEMA_FIELD_NUMBER: _ClassVar[int]
    type: str
    union_types: _containers.RepeatedCompositeFieldContainer[KclType]
    default: str
    schema_name: str
    schema_doc: str
    properties: _containers.MessageMap[str, KclType]
    required: _containers.RepeatedScalarFieldContainer[str]
    key: KclType
    item: KclType
    line: int
    decorators: _containers.RepeatedCompositeFieldContainer[Decorator]
    filename: str
    pkg_path: str
    description: str
    examples: _containers.MessageMap[str, Example]
    base_schema: KclType
    def __init__(
        self,
        type: _Optional[str] = ...,
        union_types: _Optional[_Iterable[_Union[KclType, _Mapping]]] = ...,
        default: _Optional[str] = ...,
        schema_name: _Optional[str] = ...,
        schema_doc: _Optional[str] = ...,
        properties: _Optional[_Mapping[str, KclType]] = ...,
        required: _Optional[_Iterable[str]] = ...,
        key: _Optional[_Union[KclType, _Mapping]] = ...,
        item: _Optional[_Union[KclType, _Mapping]] = ...,
        line: _Optional[int] = ...,
        decorators: _Optional[_Iterable[_Union[Decorator, _Mapping]]] = ...,
        filename: _Optional[str] = ...,
        pkg_path: _Optional[str] = ...,
        description: _Optional[str] = ...,
        examples: _Optional[_Mapping[str, Example]] = ...,
        base_schema: _Optional[_Union[KclType, _Mapping]] = ...,
    ) -> None: ...

class Decorator(_message.Message):
    __slots__ = ("name", "arguments", "keywords")

    class KeywordsEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(
            self, key: _Optional[str] = ..., value: _Optional[str] = ...
        ) -> None: ...

    NAME_FIELD_NUMBER: _ClassVar[int]
    ARGUMENTS_FIELD_NUMBER: _ClassVar[int]
    KEYWORDS_FIELD_NUMBER: _ClassVar[int]
    name: str
    arguments: _containers.RepeatedScalarFieldContainer[str]
    keywords: _containers.ScalarMap[str, str]
    def __init__(
        self,
        name: _Optional[str] = ...,
        arguments: _Optional[_Iterable[str]] = ...,
        keywords: _Optional[_Mapping[str, str]] = ...,
    ) -> None: ...

class Example(_message.Message):
    __slots__ = ("summary", "description", "value")
    SUMMARY_FIELD_NUMBER: _ClassVar[int]
    DESCRIPTION_FIELD_NUMBER: _ClassVar[int]
    VALUE_FIELD_NUMBER: _ClassVar[int]
    summary: str
    description: str
    value: str
    def __init__(
        self,
        summary: _Optional[str] = ...,
        description: _Optional[str] = ...,
        value: _Optional[str] = ...,
    ) -> None: ...
