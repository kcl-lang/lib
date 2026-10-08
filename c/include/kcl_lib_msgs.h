/*
 * kcl_lib_msgs.h — Shared result structs and protobuf encode/decode
 * helpers used by the typed wrappers in kcl_lib.h.
 *
 * Shallow repeated messages are decoded into arrays of the plain C
 * structs declared here. Deeply nested or recursive message fields
 * (KclType trees, scope/symbol maps, variable maps, error lists) are
 * rendered to compact JSON text through struct KclJsonSink; this mirrors
 * how the binding already surfaces program/AST payloads as JSON strings.
 */

#ifndef KCL_LIB_MSGS_H
#define KCL_LIB_MSGS_H

#include <pb.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/* Plain result structs for shallow messages                           */
/* ------------------------------------------------------------------ */

struct KclOptionHelp {
    char name[128];
    char type[64];
    bool required;
    char default_value[256];
    char help[512];
};

struct KclExternalPkgInfo {
    char pkg_name[128];
    char pkg_path[512];
};

struct KclKeyValuePair {
    char key[256];
    char value[1024];
};

struct KclCliConfig {
    char files[2048]; /* '\n'-joined */
    char output[256];
    char overrides[2048]; /* '\n'-joined */
    char path_selector[1024]; /* '\n'-joined */
    bool strict_range_check;
    bool disable_none;
    int64_t verbose;
    bool debug;
    bool sort_keys;
    bool show_hidden;
    bool include_schema_type_path;
    bool fast_eval;
};

struct KclTestCaseInfo {
    char name[256];
    char error[1024];
    uint64_t duration;
    char log_message[1024];
};

/* Result container for kcl_load_package. Every buffer must be
 * zero-initialized (or hold a valid writable region) and is filled by
 * the wrapper; string/list fields are empty when the service did not
 * send them. */
struct KclLoadPackageResult {
    char* program;
    size_t program_size;
    char* paths;
    size_t paths_size;
    char* parse_errors;
    size_t parse_errors_size;
    char* type_errors;
    size_t type_errors_size;
    char* scopes;
    size_t scopes_size;
    char* symbols;
    size_t symbols_size;
    char* node_symbol_map;
    size_t node_symbol_map_size;
    char* symbol_node_map;
    size_t symbol_node_map_size;
    char* fully_qualified_name_map;
    size_t fully_qualified_name_map_size;
    char* pkg_scope_map;
    size_t pkg_scope_map_size;
    /* kcl.mod manifest of the package root: has_kcl_mod mirrors the
     * message's presence on the wire and kcl_mod_name carries the
     * package section's name ("" when either is absent). */
    bool has_kcl_mod;
    char kcl_mod_name[128];
    /* Number of entries in the apps list and the imports map. */
    size_t app_count;
    size_t import_count;
};

struct KclListVariablesResult {
    char* variables;
    size_t variables_size;
    char* unsupported_codes;
    size_t unsupported_codes_size;
    char* parse_errors;
    size_t parse_errors_size;
};

struct KclLoadSettingsFilesResult {
    struct KclCliConfig kcl_cli_configs;
    struct KclKeyValuePair* kcl_options;
    size_t kcl_options_size;
    size_t kcl_option_count;
};

/* ------------------------------------------------------------------ */
/* Encoder context for string -> string map fields                     */
/* ------------------------------------------------------------------ */

struct KclStringPair {
    const char* key;
    const char* value;
};

struct KclStringPairList {
    const struct KclStringPair* items;
    size_t count;
    size_t index;
};

/* ------------------------------------------------------------------ */
/* Request structs for the wrappers that nest ExecProgramArgs or      */
/* ParseProgramArgs (GenerateToml, GenerateOpenAPI, GenerateProto,     */
/* GenerateDoc)                                                       */
/* ------------------------------------------------------------------ */

/* Plain-C view of ExecProgramArgs. Only the fields the typed wrappers
 * surface are listed; everything else stays at its proto3 default.
 * `external_pkgs` pairs a package name with its path. */
struct KclExecProgramArgs {
    const char* work_dir;
    const char* const* k_code_list;
    size_t k_code_count;
    const char* const* k_filename_list;
    size_t k_filename_count;
    const char* const* overrides;
    size_t override_count;
    const struct KclStringPair* external_pkgs;
    size_t external_pkg_count;
    bool sort_keys;
};

/* Plain-C view of ParseProgramArgs, the `parse_args` field shared by
 * GenerateOpenAPI / GenerateProto / GenerateDoc. */
struct KclParseProgramArgs {
    const char* const* paths;
    size_t path_count;
    const char* const* sources;
    size_t source_count;
    const struct KclStringPair* external_pkgs;
    size_t external_pkg_count;
};

/* ------------------------------------------------------------------ */
/* JSON sink for complex message fields                                */
/* ------------------------------------------------------------------ */

struct KclJsonFrame {
    bool is_array;
    bool has_items;
};

struct KclJsonSink {
    char* buffer;
    size_t size;
    size_t length;
    bool overflow;
    struct KclJsonFrame frames[12];
    int depth;
    /* Set by the caller before pb_decode for sinks fed by a top-level
     * list/map decoder: entries are wrapped in one JSON array, closed by
     * kcl_json_sink_finish(); an empty field renders as "[]". */
    bool auto_array;
    bool auto_array_open;
    /* Set when the last output was an object member name; the next
     * container/value opening must not repeat the parent separator. */
    bool after_member;
};

void kcl_json_sink_init(struct KclJsonSink* sink, char* buffer, size_t size);
bool kcl_json_sink_finish(struct KclJsonSink* sink);

/* ------------------------------------------------------------------ */
/* Collectors: repeated message -> array of plain structs              */
/* ------------------------------------------------------------------ */

struct KclOptionHelpCollector {
    struct KclOptionHelp* items;
    size_t max_count;
    size_t count;
};

struct KclTestCaseCollector {
    struct KclTestCaseInfo* items;
    size_t max_count;
    size_t count;
};

struct KclExternalPkgCollector {
    struct KclExternalPkgInfo* items;
    size_t max_count;
    size_t count;
};

struct KclKeyValueCollector {
    struct KclKeyValuePair* items;
    size_t max_count;
    size_t count;
};

/* Fixed-size string slot for bounded decode callbacks (the collectors
 * below, and one-off captures such as the kcl.mod package name inside
 * LoadPackageResult). */
struct KclStringSlot {
    char* buffer;
    size_t size;
};

/* Copy one string field into the caller's slot, truncating to the slot
 * size. arg = struct KclStringSlot*. */
bool kcl_decode_copy_string(pb_istream_t* stream, const pb_field_t* field, void** arg);

/* Count one repeated/map entry without decoding its payload.
 * arg = size_t*. */
bool kcl_decode_count_only(pb_istream_t* stream, const pb_field_t* field, void** arg);

bool kcl_decode_option_help_list(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_test_case_info_list(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_external_pkg_list(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_key_value_pair_list(pb_istream_t* stream, const pb_field_t* field, void** arg);

/* ------------------------------------------------------------------ */
/* JSON decoders for complex message fields (arg = struct KclJsonSink*) */
/* ------------------------------------------------------------------ */

/* repeated Error -> JSON array */
bool kcl_decode_error_list_json(pb_istream_t* stream, const pb_field_t* field, void** arg);

/* map<string, KclType> entries (GetSchemaTypeMapping) -> JSON objects */
bool kcl_decode_kcltype_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg);

/* map<string, SchemaTypes> entries (GetSchemaTypeMappingUnderPath) */
bool kcl_decode_schema_types_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg);

/* LoadPackage map fields */
bool kcl_decode_scope_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_symbol_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_symbol_index_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_fully_qualified_name_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_scope_index_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_string_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg);

/* map<string, string> entries (RenameCode changed_codes) */
bool kcl_decode_string_string_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg);

/* map<string, VariableList> entries (ListVariables) */
bool kcl_decode_variable_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg);

/* KclType nested members */
bool kcl_decode_kcltype_properties_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_kcltype_json(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_decorator_list_json(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_example_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_function_type_json(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_index_signature_json(pb_istream_t* stream, const pb_field_t* field, void** arg);
bool kcl_decode_parameter_list_json(pb_istream_t* stream, const pb_field_t* field, void** arg);

/* Encoder for map<string, string> request fields (RenameCode
 * source_codes). arg = struct KclStringPairList*. */
bool kcl_encode_string_map_entries(pb_ostream_t* stream, const pb_field_t* field, void* const* arg);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* KCL_LIB_MSGS_H */
