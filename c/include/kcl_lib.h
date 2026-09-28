#ifndef _KCL_LIB_H
#define _KCL_LIB_H

#ifdef __cplusplus
extern "C" {
#endif

#include <pb_decode.h>
#include <pb_encode.h>
#include <spec.pb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#include "kcl_ffi.h"
#include "kcl_lib_msgs.h"

#define BUFFER_SIZE (4 * 1024 * 1024)

// Single source of truth for the error prefix the Rust dispatcher prepends
// to every error reply. MUST stay in lockstep with the `"ERROR:..."`
// literals in `crates/api/src/service/capi.rs` (both the `call!` macro and
// the panic branch of `kcl_service_call_with_length`). See
// `/Users/timi/codes/lib/docs/abi.md` §4 for the full convention.
#define ERROR_PREFIX "ERROR:"
#define ERROR_PREFIX_LEN 6

struct Buffer {
    const char* buffer;
    size_t len;
};

// Repeated string carrier for the encode callback. `saved_index` is the
// start position the callback rewinds `index` to before every emit so the
// handler can be driven multiple times safely (nanopb's
// `kcl_encode_tagged_submsg` workaround wraps the same field in a sizing
// pass and a write pass, and some encoders invoke the callback once more
// for diagnostics during replay).
struct RepeatedString {
    struct Buffer** repeated;
    size_t index;
    size_t saved_index;
    size_t max_size;
};

// Encode callback function for setting string
bool encode_string(pb_ostream_t* stream, const pb_field_t* field, void* const* arg)
{
    if (!pb_encode_tag_for_field(stream, field))
        return false;
    return pb_encode_string(stream, (const uint8_t*)(*arg), strlen((const char*)*arg));
}

bool encode_str_list(pb_ostream_t* stream, const pb_field_t* field, void* const* arg)
{
    struct RepeatedString* req = *arg;
    // Rewind to the saved start position so subsequent invocations
    // re-emit the same payload (e.g. nanopb's two-pass submessage
    // encoding inside `kcl_encode_tagged_submsg`).
    req->index = req->saved_index;
    while (req->index < req->max_size) {
        struct Buffer* sreq = req->repeated[req->index];
        ++req->index;
        if (!pb_encode_tag(stream, PB_WT_STRING, field->tag)) {
            return false;
        }

        if (!pb_encode_string(stream, (const uint8_t*)sreq->buffer, sreq->len)) {
            return false;
        }
    }

    return true;
}

// Decode callback function for getting string.
// The decode destination (*arg) must point to a buffer of at least
// BUFFER_SIZE bytes.
bool decode_string(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    (void)field;
    size_t size = stream->bytes_left;
    if (size >= BUFFER_SIZE)
        return false;

    if (!pb_read(stream, (uint8_t*)*arg, size))
        return false;

    ((uint8_t*)*arg)[size] = '\0';
    return true;
}

bool check_error_prefix(uint8_t result_buffer[])
{
    // Use memcmp against the named constant so the check cannot drift away
    // from ERROR_PREFIX. See docs/abi.md §4.
    return memcmp(result_buffer, ERROR_PREFIX, ERROR_PREFIX_LEN) == 0;
}

struct KclVersion {
    char version[64];
    char checksum[64];
    char git_sha[80];
    char version_info[1024];
};

struct KclStringListCollector {
    char* buffer;
    size_t size;
    size_t length;
};

static inline void kcl_copy_string(char* dst, size_t dst_size, const uint8_t* src)
{
    size_t len;
    if (dst == NULL || dst_size == 0)
        return;
    len = strlen((const char*)src);
    if (len >= dst_size)
        len = dst_size - 1;
    memcpy(dst, src, len);
    dst[len] = '\0';
}

static inline size_t kcl_call(const char* api_str, const uint8_t* args, size_t args_len, uint8_t* result_buffer)
{
    size_t result_length = call_native((const uint8_t*)api_str, strlen(api_str), args, args_len, result_buffer);
    // Null-terminate so the error path can pass the buffer to kcl_copy_string
    // (which uses strlen on src). Rust's call_native does not append a NUL,
    // and the rest of the malloc'd result_buffer is uninitialised — on Linux
    // those bytes can be non-zero, making strlen read past the actual reply
    // and segfault when it runs off the allocation.
    if (result_length < BUFFER_SIZE)
        result_buffer[result_length] = '\0';
    else
        result_buffer[BUFFER_SIZE - 1] = '\0';
    return result_length;
}

static inline bool kcl_decode_string_list(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    (void)field;
    struct KclStringListCollector* collector = (struct KclStringListCollector*)(*arg);
    size_t size = stream->bytes_left;
    if (collector->length > 0 && collector->length < collector->size)
        collector->buffer[collector->length++] = '\n';
    if (size >= collector->size - collector->length)
        return false;
    if (!pb_read(stream, (uint8_t*)collector->buffer + collector->length, size))
        return false;
    collector->length += size;
    collector->buffer[collector->length] = '\0';
    return true;
}

// Encode a nested submessage field in a single pass: nanopb's own
// submessage encoder runs a sizing pass followed by a write pass, which
// breaks stateful encode callbacks (encode_str_list advances its index
// on the first pass, leaving nothing to emit on the second). Encoding
// into a scratch buffer first keeps each callback invocation single-pass
// so the length prefix and the payload always stay in lockstep on every
// platform (the two-pass substream approach works on macOS but the
// encoded buffer comes out truncated on Linux/gcc, which then segfaults
// the decoder downstream).
static inline bool kcl_encode_tagged_submsg(pb_ostream_t* stream, uint32_t field_tag, const pb_msgdesc_t* fields, const void* msg)
{
    uint8_t* inner = (uint8_t*)malloc(BUFFER_SIZE);
    bool status = false;
    if (inner == NULL)
        return false;
    pb_ostream_t inner_stream = pb_ostream_from_buffer(inner, BUFFER_SIZE);
    if (!pb_encode(&inner_stream, fields, msg))
        goto done;
    if (!pb_encode_tag(stream, PB_WT_STRING, field_tag))
        goto done;
    if (!pb_encode_varint(stream, inner_stream.bytes_written))
        goto done;
    if (!pb_write(stream, inner, inner_stream.bytes_written))
        goto done;
    status = true;
done:
    free(inner);
    return status;
}

// Encode a singular string field manually (used alongside
// kcl_encode_tagged_submsg when a message is encoded field by field).
static inline bool kcl_encode_tagged_string(pb_ostream_t* stream, uint32_t field_tag, const char* value)
{
    size_t len = strlen(value);
    if (!pb_encode_tag(stream, PB_WT_STRING, field_tag))
        return false;
    return pb_encode_string(stream, (const uint8_t*)value, len);
}

// Encode a true-valued proto3 bool field manually.
static inline bool kcl_encode_tagged_true(pb_ostream_t* stream, uint32_t field_tag)
{
    if (!pb_encode_tag(stream, PB_WT_VARINT, field_tag))
        return false;
    return pb_encode_varint(stream, 1);
}

// Ping KclService and copy the echoed value into out.
// Returns false and copies the error message into out on failure.
static inline bool kcl_ping(const char* value, char* out, size_t out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* value_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    bool status = false;
    if (buffer == NULL || result_buffer == NULL || value_buffer == NULL)
        goto done;

    PingArgs ping_args = PingArgs_init_zero;
    ping_args.value.funcs.encode = encode_string;
    ping_args.value.arg = (void*)value;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, PingArgs_fields, &ping_args))
        goto done;

    size_t result_length = kcl_call("KclService.Ping", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(out, out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    PingResult result = PingResult_init_default;
    result.value.funcs.decode = decode_string;
    result.value.arg = value_buffer;
    if (!pb_decode(&istream, PingResult_fields, &result))
        goto done;

    kcl_copy_string(out, out_size, value_buffer);
    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(value_buffer);
    return status;
}

// Get the KCL version information.
static inline bool kcl_get_version(struct KclVersion* version)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* version_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    uint8_t* checksum_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    uint8_t* git_sha_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    uint8_t* version_info_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    bool status = false;
    if (buffer == NULL || result_buffer == NULL || version_buffer == NULL || checksum_buffer == NULL || git_sha_buffer == NULL || version_info_buffer == NULL)
        goto done;

    GetVersionArgs args = GetVersionArgs_init_zero;
    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, GetVersionArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("KclService.GetVersion", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer))
        goto done;

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    GetVersionResult result = GetVersionResult_init_default;
    result.version.funcs.decode = decode_string;
    result.version.arg = version_buffer;
    result.checksum.funcs.decode = decode_string;
    result.checksum.arg = checksum_buffer;
    result.git_sha.funcs.decode = decode_string;
    result.git_sha.arg = git_sha_buffer;
    result.version_info.funcs.decode = decode_string;
    result.version_info.arg = version_info_buffer;
    if (!pb_decode(&istream, GetVersionResult_fields, &result))
        goto done;

    kcl_copy_string(version->version, sizeof(version->version), version_buffer);
    kcl_copy_string(version->checksum, sizeof(version->checksum), checksum_buffer);
    kcl_copy_string(version->git_sha, sizeof(version->git_sha), git_sha_buffer);
    kcl_copy_string(version->version_info, sizeof(version->version_info), version_info_buffer);
    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(version_buffer);
    free(checksum_buffer);
    free(git_sha_buffer);
    free(version_info_buffer);
    return status;
}

// Execute KCL files and copy the YAML result and error message into
// yaml_out and err_out. Returns false on failure.
static inline bool kcl_exec_program(const char* const* filenames, size_t filename_count, char* yaml_out, size_t yaml_out_size, char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* yaml_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    uint8_t* err_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    struct Buffer* files = (struct Buffer*)malloc(filename_count * sizeof(struct Buffer));
    struct Buffer** file_ptrs = (struct Buffer**)malloc(filename_count * sizeof(struct Buffer*));
    bool status = false;
    if (buffer == NULL || result_buffer == NULL || yaml_buffer == NULL || err_buffer == NULL || files == NULL || file_ptrs == NULL)
        goto done;

    for (size_t i = 0; i < filename_count; ++i) {
        files[i].buffer = filenames[i];
        files[i].len = strlen(filenames[i]);
        file_ptrs[i] = &files[i];
    }
    struct RepeatedString strs = { .repeated = file_ptrs, .index = 0, .saved_index = 0, .max_size = filename_count };
    ExecProgramArgs args = ExecProgramArgs_init_zero;
    args.k_filename_list.funcs.encode = encode_str_list;
    args.k_filename_list.arg = &strs;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, ExecProgramArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("KclService.ExecProgram", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    ExecProgramResult result = ExecProgramResult_init_default;
    result.yaml_result.funcs.decode = decode_string;
    result.yaml_result.arg = yaml_buffer;
    result.err_message.funcs.decode = decode_string;
    result.err_message.arg = err_buffer;
    if (!pb_decode(&istream, ExecProgramResult_fields, &result))
        goto done;

    kcl_copy_string(yaml_out, yaml_out_size, yaml_buffer);
    kcl_copy_string(err_out, err_out_size, err_buffer);
    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(yaml_buffer);
    free(err_buffer);
    free(files);
    free(file_ptrs);
    return status;
}

// Validate data against the schema code. Copies the validation error
// message into err_out and sets success. Returns false on failure.
static inline bool kcl_validate_code(const char* code, const char* data, bool* success, char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* err_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    bool status = false;
    if (buffer == NULL || result_buffer == NULL || err_buffer == NULL)
        goto done;

    ValidateCodeArgs validate_args = ValidateCodeArgs_init_zero;
    validate_args.code.funcs.encode = encode_string;
    validate_args.code.arg = (void*)code;
    validate_args.data.funcs.encode = encode_string;
    validate_args.data.arg = (void*)data;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, ValidateCodeArgs_fields, &validate_args))
        goto done;

    size_t result_length = kcl_call("KclService.ValidateCode", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    ValidateCodeResult result = ValidateCodeResult_init_default;
    result.err_message.funcs.decode = decode_string;
    result.err_message.arg = err_buffer;
    if (!pb_decode(&istream, ValidateCodeResult_fields, &result))
        goto done;

    if (success != NULL)
        *success = result.success;
    kcl_copy_string(err_out, err_out_size, err_buffer);
    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(err_buffer);
    return status;
}

// Format KCL source code and copy the formatted code into out.
// Returns false and copies the error message into out on failure.
static inline bool kcl_format_code(const char* source, char* out, size_t out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* formatted_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    bool status = false;
    if (buffer == NULL || result_buffer == NULL || formatted_buffer == NULL)
        goto done;

    FormatCodeArgs format_args = FormatCodeArgs_init_zero;
    format_args.source.funcs.encode = encode_string;
    format_args.source.arg = (void*)source;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, FormatCodeArgs_fields, &format_args))
        goto done;

    size_t result_length = kcl_call("KclService.FormatCode", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(out, out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    FormatCodeResult result = FormatCodeResult_init_default;
    result.formatted.funcs.decode = decode_string;
    result.formatted.arg = formatted_buffer;
    if (!pb_decode(&istream, FormatCodeResult_fields, &result))
        goto done;

    kcl_copy_string(out, out_size, formatted_buffer);
    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(formatted_buffer);
    return status;
}

// Lint KCL files and copy the newline-separated lint results into out.
// Returns false and copies the error message into out on failure.
static inline bool kcl_lint_path(const char* const* paths, size_t path_count, char* out, size_t out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    struct Buffer* lint_paths = (struct Buffer*)malloc(path_count * sizeof(struct Buffer));
    struct Buffer** lint_path_ptrs = (struct Buffer**)malloc(path_count * sizeof(struct Buffer*));
    bool status = false;
    if (buffer == NULL || result_buffer == NULL || lint_paths == NULL || lint_path_ptrs == NULL)
        goto done;

    for (size_t i = 0; i < path_count; ++i) {
        lint_paths[i].buffer = paths[i];
        lint_paths[i].len = strlen(paths[i]);
        lint_path_ptrs[i] = &lint_paths[i];
    }
    struct RepeatedString strs = { .repeated = lint_path_ptrs, .index = 0, .saved_index = 0, .max_size = path_count };
    LintPathArgs lint_args = LintPathArgs_init_zero;
    lint_args.paths.funcs.encode = encode_str_list;
    lint_args.paths.arg = &strs;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, LintPathArgs_fields, &lint_args))
        goto done;

    size_t result_length = kcl_call("KclService.LintPath", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(out, out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    LintPathResult result = LintPathResult_init_default;
    struct KclStringListCollector collector = { .buffer = out, .size = out_size, .length = 0 };
    result.results.funcs.decode = kcl_decode_string_list;
    result.results.arg = &collector;
    if (!pb_decode(&istream, LintPathResult_fields, &result))
        goto done;

    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(lint_paths);
    free(lint_path_ptrs);
    return status;
}

// Parse a single KCL file and copy the resulting AST JSON into
// ast_out. Returns false and copies the error message into ast_out on
// failure. ast_out must point to at least ast_out_size bytes.
static inline bool kcl_parse_file(const char* filename, char* ast_out, size_t ast_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* ast_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    bool status = false;
    if (buffer == NULL || result_buffer == NULL || ast_buffer == NULL)
        goto done;

    ParseFileArgs args = ParseFileArgs_init_zero;
    args.path.funcs.encode = encode_string;
    args.path.arg = (void*)filename;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, ParseFileArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("KclService.ParseFile", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(ast_out, ast_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    ParseFileResult result = ParseFileResult_init_default;
    result.ast_json.funcs.decode = decode_string;
    result.ast_json.arg = ast_buffer;
    if (!pb_decode(&istream, ParseFileResult_fields, &result))
        goto done;

    kcl_copy_string(ast_out, ast_out_size, ast_buffer);
    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(ast_buffer);
    return status;
}

// Parse a list of KCL files and copy the resulting program AST JSON
// envelope into ast_out. Returns false and copies the error message
// into ast_out on failure. ast_out must point to at least
// ast_out_size bytes.
static inline bool kcl_parse_program(const char* const* filenames, size_t filename_count, char* ast_out, size_t ast_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* ast_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    struct Buffer* files = (struct Buffer*)malloc(filename_count * sizeof(struct Buffer));
    struct Buffer** file_ptrs = (struct Buffer**)malloc(filename_count * sizeof(struct Buffer*));
    bool status = false;
    if (buffer == NULL || result_buffer == NULL || ast_buffer == NULL || files == NULL || file_ptrs == NULL)
        goto done;

    for (size_t i = 0; i < filename_count; ++i) {
        files[i].buffer = filenames[i];
        files[i].len = strlen(filenames[i]);
        file_ptrs[i] = &files[i];
    }
    struct RepeatedString strs = { .repeated = file_ptrs, .index = 0, .saved_index = 0, .max_size = filename_count };
    ParseProgramArgs args = ParseProgramArgs_init_zero;
    args.paths.funcs.encode = encode_str_list;
    args.paths.arg = &strs;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, ParseProgramArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("KclService.ParseProgram", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(ast_out, ast_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    ParseProgramResult result = ParseProgramResult_init_default;
    result.ast_json.funcs.decode = decode_string;
    result.ast_json.arg = ast_buffer;
    if (!pb_decode(&istream, ParseProgramResult_fields, &result))
        goto done;

    kcl_copy_string(ast_out, ast_out_size, ast_buffer);
    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(ast_buffer);
    free(files);
    free(file_ptrs);
    return status;
}

// List every method exposed by the native runtime (BuiltinService.ListMethod)
// and copy the newline-separated names into out. Returns false and copies
// the error message into out on failure.
static inline bool kcl_list_method(char* out, size_t out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    bool status = false;
    if (buffer == NULL || result_buffer == NULL)
        goto done;

    ListMethodArgs args = ListMethodArgs_init_zero;
    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, ListMethodArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("BuiltinService.ListMethod", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(out, out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    ListMethodResult result = ListMethodResult_init_default;
    struct KclStringListCollector collector = { .buffer = out, .size = out_size, .length = 0 };
    result.method_name_list.funcs.decode = kcl_decode_string_list;
    result.method_name_list.arg = &collector;
    if (!pb_decode(&istream, ListMethodResult_fields, &result))
        goto done;

    status = true;

done:
    free(buffer);
    free(result_buffer);
    return status;
}

// Load a KCL package (AST + scopes/symbols/type info) and fill the
// result buffers of `result`. Map and error fields are rendered as JSON
// arrays of {"key": ..., "value": ...} entries. Returns false and copies
// the error message into err_out on failure.
static inline bool kcl_load_package(const char* const* paths, size_t path_count,
    bool resolve_ast, bool load_builtin, bool with_ast_index,
    struct KclLoadPackageResult* result, char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* program_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    struct Buffer* files = NULL;
    struct Buffer** file_ptrs = NULL;
    bool status = false;
    if (buffer == NULL || result_buffer == NULL || program_buffer == NULL)
        goto done;

    // strs lives for the whole function: encode_str_list is invoked from
    // pb_encode (called by kcl_encode_tagged_submsg) after the `if` block
    // below has gone out of scope, so the struct must be hoisted to
    // function scope to avoid a stack-use-after-scope.
    struct RepeatedString strs = { 0 };
    LoadPackageArgs args = LoadPackageArgs_init_zero;
    args.resolve_ast = resolve_ast;
    args.load_builtin = load_builtin;
    args.with_ast_index = with_ast_index;
    if (path_count > 0) {
        files = (struct Buffer*)malloc(path_count * sizeof(struct Buffer));
        file_ptrs = (struct Buffer**)malloc(path_count * sizeof(struct Buffer*));
        if (files == NULL || file_ptrs == NULL)
            goto done;
        for (size_t i = 0; i < path_count; ++i) {
            files[i].buffer = paths[i];
            files[i].len = strlen(paths[i]);
            file_ptrs[i] = &files[i];
        }
        strs = (struct RepeatedString){ .repeated = file_ptrs, .index = 0, .saved_index = 0, .max_size = path_count };
        args.has_parse_args = true;
        args.parse_args.paths.funcs.encode = encode_str_list;
        args.parse_args.paths.arg = &strs;
    }

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    // LoadPackageArgs carries a static nested ParseProgramArgs; encode the
    // fields manually so the stateful encode_str_list callback stays
    // single-pass (see kcl_encode_tagged_submsg).
    if (args.has_parse_args
        && !kcl_encode_tagged_submsg(&stream, LoadPackageArgs_parse_args_tag, ParseProgramArgs_fields, &args.parse_args))
        goto done;
    if (args.resolve_ast && !kcl_encode_tagged_true(&stream, LoadPackageArgs_resolve_ast_tag))
        goto done;
    if (args.load_builtin && !kcl_encode_tagged_true(&stream, LoadPackageArgs_load_builtin_tag))
        goto done;
    if (args.with_ast_index && !kcl_encode_tagged_true(&stream, LoadPackageArgs_with_ast_index_tag))
        goto done;

    size_t result_length = kcl_call("KclService.LoadPackage", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    LoadPackageResult res = LoadPackageResult_init_default;
    struct KclStringListCollector paths_collector = { .buffer = result->paths, .size = result->paths_size, .length = 0 };
    struct KclJsonSink parse_errors_sink;
    struct KclJsonSink type_errors_sink;
    struct KclJsonSink scopes_sink;
    struct KclJsonSink symbols_sink;
    struct KclJsonSink node_symbol_map_sink;
    struct KclJsonSink symbol_node_map_sink;
    struct KclJsonSink fqn_map_sink;
    struct KclJsonSink pkg_scope_map_sink;

    kcl_json_sink_init(&parse_errors_sink, result->parse_errors, result->parse_errors_size);
    kcl_json_sink_init(&type_errors_sink, result->type_errors, result->type_errors_size);
    kcl_json_sink_init(&scopes_sink, result->scopes, result->scopes_size);
    kcl_json_sink_init(&symbols_sink, result->symbols, result->symbols_size);
    kcl_json_sink_init(&node_symbol_map_sink, result->node_symbol_map, result->node_symbol_map_size);
    kcl_json_sink_init(&symbol_node_map_sink, result->symbol_node_map, result->symbol_node_map_size);
    kcl_json_sink_init(&fqn_map_sink, result->fully_qualified_name_map, result->fully_qualified_name_map_size);
    kcl_json_sink_init(&pkg_scope_map_sink, result->pkg_scope_map, result->pkg_scope_map_size);
    parse_errors_sink.auto_array = true;
    type_errors_sink.auto_array = true;
    scopes_sink.auto_array = true;
    symbols_sink.auto_array = true;
    node_symbol_map_sink.auto_array = true;
    symbol_node_map_sink.auto_array = true;
    fqn_map_sink.auto_array = true;
    pkg_scope_map_sink.auto_array = true;

    res.program.funcs.decode = decode_string;
    res.program.arg = program_buffer;
    res.paths.funcs.decode = kcl_decode_string_list;
    res.paths.arg = &paths_collector;
    res.parse_errors.funcs.decode = kcl_decode_error_list_json;
    res.parse_errors.arg = &parse_errors_sink;
    res.type_errors.funcs.decode = kcl_decode_error_list_json;
    res.type_errors.arg = &type_errors_sink;
    res.scopes.funcs.decode = kcl_decode_scope_map_json;
    res.scopes.arg = &scopes_sink;
    res.symbols.funcs.decode = kcl_decode_symbol_map_json;
    res.symbols.arg = &symbols_sink;
    res.node_symbol_map.funcs.decode = kcl_decode_symbol_index_map_json;
    res.node_symbol_map.arg = &node_symbol_map_sink;
    res.symbol_node_map.funcs.decode = kcl_decode_string_map_json;
    res.symbol_node_map.arg = &symbol_node_map_sink;
    res.fully_qualified_name_map.funcs.decode = kcl_decode_fully_qualified_name_map_json;
    res.fully_qualified_name_map.arg = &fqn_map_sink;
    res.pkg_scope_map.funcs.decode = kcl_decode_scope_index_map_json;
    res.pkg_scope_map.arg = &pkg_scope_map_sink;

    if (!pb_decode(&istream, LoadPackageResult_fields, &res))
        goto done;
    if (!kcl_json_sink_finish(&parse_errors_sink)
        || !kcl_json_sink_finish(&type_errors_sink)
        || !kcl_json_sink_finish(&scopes_sink)
        || !kcl_json_sink_finish(&symbols_sink)
        || !kcl_json_sink_finish(&node_symbol_map_sink)
        || !kcl_json_sink_finish(&symbol_node_map_sink)
        || !kcl_json_sink_finish(&fqn_map_sink)
        || !kcl_json_sink_finish(&pkg_scope_map_sink))
        goto done;

    kcl_copy_string(result->program, result->program_size, program_buffer);
    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(program_buffer);
    free(files);
    free(file_ptrs);
    return status;
}

// List the option help information of the given KCL files. Decoded
// options are appended to `options` (up to max_options); the decoded
// count is stored in option_count. Returns false and copies the error
// message into err_out on failure.
static inline bool kcl_list_options(const char* const* paths, size_t path_count,
    struct KclOptionHelp* options, size_t max_options, size_t* option_count,
    char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    struct Buffer* files = NULL;
    struct Buffer** file_ptrs = NULL;
    bool status = false;
    if (buffer == NULL || result_buffer == NULL)
        goto done;

    // Hoisted out of the `if` block below — see kcl_load_package for the
    // rationale (stack-use-after-scope on Linux when the encode callback
    // runs after this block ends).
    struct RepeatedString strs = { 0 };
    ParseProgramArgs args = ParseProgramArgs_init_zero;
    if (path_count > 0) {
        files = (struct Buffer*)malloc(path_count * sizeof(struct Buffer));
        file_ptrs = (struct Buffer**)malloc(path_count * sizeof(struct Buffer*));
        if (files == NULL || file_ptrs == NULL)
            goto done;
        for (size_t i = 0; i < path_count; ++i) {
            files[i].buffer = paths[i];
            files[i].len = strlen(paths[i]);
            file_ptrs[i] = &files[i];
        }
        strs = (struct RepeatedString){ .repeated = file_ptrs, .index = 0, .saved_index = 0, .max_size = path_count };
        args.paths.funcs.encode = encode_str_list;
        args.paths.arg = &strs;
    }

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, ParseProgramArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("KclService.ListOptions", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    ListOptionsResult res = ListOptionsResult_init_default;
    struct KclOptionHelpCollector collector = { .items = options, .max_count = max_options, .count = 0 };
    res.options.funcs.decode = kcl_decode_option_help_list;
    res.options.arg = &collector;
    if (!pb_decode(&istream, ListOptionsResult_fields, &res))
        goto done;

    if (option_count != NULL)
        *option_count = collector.count;
    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(files);
    free(file_ptrs);
    return status;
}

// List variables of the given KCL files by specs. `result` buffers are
// filled with a JSON array of variable entries (variables), the
// newline-separated unsupported codes and a JSON array of parse errors.
// Returns false and copies the error message into err_out on failure.
static inline bool kcl_list_variables(const char* const* files, size_t file_count,
    const char* const* specs, size_t spec_count, bool merge_program,
    struct KclListVariablesResult* result, char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    struct Buffer* file_bufs = NULL;
    struct Buffer** file_ptrs = NULL;
    struct Buffer* spec_bufs = NULL;
    struct Buffer** spec_ptrs = NULL;
    bool status = false;
    if (buffer == NULL || result_buffer == NULL)
        goto done;

    // Hoisted out of the `if` blocks below — see kcl_load_package for the
    // rationale (stack-use-after-scope on Linux when the encode callback
    // runs after these blocks end).
    struct RepeatedString file_strs = { 0 };
    struct RepeatedString spec_strs = { 0 };
    ListVariablesArgs args = ListVariablesArgs_init_zero;
    if (file_count > 0) {
        file_bufs = (struct Buffer*)malloc(file_count * sizeof(struct Buffer));
        file_ptrs = (struct Buffer**)malloc(file_count * sizeof(struct Buffer*));
        if (file_bufs == NULL || file_ptrs == NULL)
            goto done;
        for (size_t i = 0; i < file_count; ++i) {
            file_bufs[i].buffer = files[i];
            file_bufs[i].len = strlen(files[i]);
            file_ptrs[i] = &file_bufs[i];
        }
        file_strs = (struct RepeatedString){ .repeated = file_ptrs, .index = 0, .saved_index = 0, .max_size = file_count };
        args.files.funcs.encode = encode_str_list;
        args.files.arg = &file_strs;
    }
    if (spec_count > 0) {
        spec_bufs = (struct Buffer*)malloc(spec_count * sizeof(struct Buffer));
        spec_ptrs = (struct Buffer**)malloc(spec_count * sizeof(struct Buffer*));
        if (spec_bufs == NULL || spec_ptrs == NULL)
            goto done;
        for (size_t i = 0; i < spec_count; ++i) {
            spec_bufs[i].buffer = specs[i];
            spec_bufs[i].len = strlen(specs[i]);
            spec_ptrs[i] = &spec_bufs[i];
        }
        spec_strs = (struct RepeatedString){ .repeated = spec_ptrs, .index = 0, .saved_index = 0, .max_size = spec_count };
        args.specs.funcs.encode = encode_str_list;
        args.specs.arg = &spec_strs;
    }
    args.has_options = true;
    args.options.merge_program = merge_program;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, ListVariablesArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("KclService.ListVariables", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    ListVariablesResult res = ListVariablesResult_init_default;
    struct KclStringListCollector unsupported_collector = { .buffer = result->unsupported_codes, .size = result->unsupported_codes_size, .length = 0 };
    struct KclJsonSink variables_sink;
    struct KclJsonSink parse_errors_sink;

    kcl_json_sink_init(&variables_sink, result->variables, result->variables_size);
    kcl_json_sink_init(&parse_errors_sink, result->parse_errors, result->parse_errors_size);
    variables_sink.auto_array = true;
    parse_errors_sink.auto_array = true;

    res.variables.funcs.decode = kcl_decode_variable_map_json;
    res.variables.arg = &variables_sink;
    res.unsupported_codes.funcs.decode = kcl_decode_string_list;
    res.unsupported_codes.arg = &unsupported_collector;
    res.parse_errors.funcs.decode = kcl_decode_error_list_json;
    res.parse_errors.arg = &parse_errors_sink;

    if (!pb_decode(&istream, ListVariablesResult_fields, &res))
        goto done;
    if (!kcl_json_sink_finish(&variables_sink) || !kcl_json_sink_finish(&parse_errors_sink))
        goto done;

    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(file_bufs);
    free(file_ptrs);
    free(spec_bufs);
    free(spec_ptrs);
    return status;
}

// Override the KCL file with the given spec list and set `overridden`.
// parse_errors is rendered as a JSON array into errors_out. Returns false
// and copies the error message into err_out on failure.
static inline bool kcl_override_file(const char* file,
    const char* const* specs, size_t spec_count,
    const char* const* import_paths, size_t import_path_count,
    bool* overridden, char* errors_out, size_t errors_out_size,
    char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    struct Buffer* spec_bufs = NULL;
    struct Buffer** spec_ptrs = NULL;
    struct Buffer* import_bufs = NULL;
    struct Buffer** import_ptrs = NULL;
    bool status = false;
    if (buffer == NULL || result_buffer == NULL)
        goto done;

    // Hoisted out of the `if` blocks below — see kcl_load_package for the
    // rationale (stack-use-after-scope on Linux when the encode callback
    // runs after these blocks end).
    struct RepeatedString spec_strs = { 0 };
    struct RepeatedString import_strs = { 0 };
    OverrideFileArgs args = OverrideFileArgs_init_zero;
    args.file.funcs.encode = encode_string;
    args.file.arg = (void*)file;
    if (spec_count > 0) {
        spec_bufs = (struct Buffer*)malloc(spec_count * sizeof(struct Buffer));
        spec_ptrs = (struct Buffer**)malloc(spec_count * sizeof(struct Buffer*));
        if (spec_bufs == NULL || spec_ptrs == NULL)
            goto done;
        for (size_t i = 0; i < spec_count; ++i) {
            spec_bufs[i].buffer = specs[i];
            spec_bufs[i].len = strlen(specs[i]);
            spec_ptrs[i] = &spec_bufs[i];
        }
        spec_strs = (struct RepeatedString){ .repeated = spec_ptrs, .index = 0, .saved_index = 0, .max_size = spec_count };
        args.specs.funcs.encode = encode_str_list;
        args.specs.arg = &spec_strs;
    }
    if (import_path_count > 0) {
        import_bufs = (struct Buffer*)malloc(import_path_count * sizeof(struct Buffer));
        import_ptrs = (struct Buffer**)malloc(import_path_count * sizeof(struct Buffer*));
        if (import_bufs == NULL || import_ptrs == NULL)
            goto done;
        for (size_t i = 0; i < import_path_count; ++i) {
            import_bufs[i].buffer = import_paths[i];
            import_bufs[i].len = strlen(import_paths[i]);
            import_ptrs[i] = &import_bufs[i];
        }
        import_strs = (struct RepeatedString){ .repeated = import_ptrs, .index = 0, .saved_index = 0, .max_size = import_path_count };
        args.import_paths.funcs.encode = encode_str_list;
        args.import_paths.arg = &import_strs;
    }

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, OverrideFileArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("KclService.OverrideFile", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    OverrideFileResult res = OverrideFileResult_init_default;
    struct KclJsonSink errors_sink;

    kcl_json_sink_init(&errors_sink, errors_out, errors_out_size);
    errors_sink.auto_array = true;

    res.parse_errors.funcs.decode = kcl_decode_error_list_json;
    res.parse_errors.arg = &errors_sink;

    if (!pb_decode(&istream, OverrideFileResult_fields, &res))
        goto done;
    if (!kcl_json_sink_finish(&errors_sink))
        goto done;

    if (overridden != NULL)
        *overridden = res.result;
    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(spec_bufs);
    free(spec_ptrs);
    free(import_bufs);
    free(import_ptrs);
    return status;
}

// Get the schema type mapping for the given files. The mapping is
// rendered as a JSON array of {"key": ..., "value": <KclType>} entries
// into mapping_out. Returns false and copies the error message into
// err_out on failure.
static inline bool kcl_get_schema_type_mapping(const char* work_dir,
    const char* const* filenames, size_t filename_count, const char* schema_name,
    char* mapping_out, size_t mapping_out_size, char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    struct Buffer* files = NULL;
    struct Buffer** file_ptrs = NULL;
    bool status = false;
    if (buffer == NULL || result_buffer == NULL)
        goto done;

    // Hoisted out of the `if` block below — see kcl_load_package for the
    // rationale (stack-use-after-scope on Linux when the encode callback
    // runs after this block ends).
    struct RepeatedString strs = { 0 };
    GetSchemaTypeMappingArgs args = GetSchemaTypeMappingArgs_init_zero;
    args.has_exec_args = true;
    if (work_dir != NULL) {
        args.exec_args.work_dir.funcs.encode = encode_string;
        args.exec_args.work_dir.arg = (void*)work_dir;
    }
    if (filename_count > 0) {
        files = (struct Buffer*)malloc(filename_count * sizeof(struct Buffer));
        file_ptrs = (struct Buffer**)malloc(filename_count * sizeof(struct Buffer*));
        if (files == NULL || file_ptrs == NULL)
            goto done;
        for (size_t i = 0; i < filename_count; ++i) {
            files[i].buffer = filenames[i];
            files[i].len = strlen(filenames[i]);
            file_ptrs[i] = &files[i];
        }
        strs = (struct RepeatedString){ .repeated = file_ptrs, .index = 0, .saved_index = 0, .max_size = filename_count };
        args.exec_args.k_filename_list.funcs.encode = encode_str_list;
        args.exec_args.k_filename_list.arg = &strs;
    }
    if (schema_name != NULL) {
        args.schema_name.funcs.encode = encode_string;
        args.schema_name.arg = (void*)schema_name;
    }

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    // Encode manually: the static nested ExecProgramArgs would otherwise
    // trigger nanopb's two-pass submessage encoding, which breaks the
    // stateful encode_str_list callback.
    if (args.has_exec_args
        && !kcl_encode_tagged_submsg(&stream, GetSchemaTypeMappingArgs_exec_args_tag, ExecProgramArgs_fields, &args.exec_args))
        goto done;
    if (schema_name != NULL
        && !kcl_encode_tagged_string(&stream, GetSchemaTypeMappingArgs_schema_name_tag, schema_name))
        goto done;

    size_t result_length = kcl_call("KclService.GetSchemaTypeMapping", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    GetSchemaTypeMappingResult res = GetSchemaTypeMappingResult_init_default;
    struct KclJsonSink mapping_sink;

    kcl_json_sink_init(&mapping_sink, mapping_out, mapping_out_size);
    mapping_sink.auto_array = true;

    res.schema_type_mapping.funcs.decode = kcl_decode_kcltype_map_json;
    res.schema_type_mapping.arg = &mapping_sink;

    if (!pb_decode(&istream, GetSchemaTypeMappingResult_fields, &res))
        goto done;
    if (!kcl_json_sink_finish(&mapping_sink))
        goto done;

    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(files);
    free(file_ptrs);
    return status;
}

// Get the schema type mapping under the input paths, keyed by package
// name. The mapping is rendered as a JSON array of {"key": pkg,
// "value": {"schema_type": [...]}} entries into mapping_out. Returns
// false and copies the error message into err_out on failure.
static inline bool kcl_get_schema_type_mapping_under_path(const char* work_dir,
    const char* const* filenames, size_t filename_count, const char* schema_name,
    char* mapping_out, size_t mapping_out_size, char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    struct Buffer* files = NULL;
    struct Buffer** file_ptrs = NULL;
    bool status = false;
    if (buffer == NULL || result_buffer == NULL)
        goto done;

    // Hoisted out of the `if` block below — see kcl_load_package for the
    // rationale (stack-use-after-scope on Linux when the encode callback
    // runs after this block ends).
    struct RepeatedString strs = { 0 };
    GetSchemaTypeMappingArgs args = GetSchemaTypeMappingArgs_init_zero;
    args.has_exec_args = true;
    if (work_dir != NULL) {
        args.exec_args.work_dir.funcs.encode = encode_string;
        args.exec_args.work_dir.arg = (void*)work_dir;
    }
    if (filename_count > 0) {
        files = (struct Buffer*)malloc(filename_count * sizeof(struct Buffer));
        file_ptrs = (struct Buffer**)malloc(filename_count * sizeof(struct Buffer*));
        if (files == NULL || file_ptrs == NULL)
            goto done;
        for (size_t i = 0; i < filename_count; ++i) {
            files[i].buffer = filenames[i];
            files[i].len = strlen(filenames[i]);
            file_ptrs[i] = &files[i];
        }
        strs = (struct RepeatedString){ .repeated = file_ptrs, .index = 0, .saved_index = 0, .max_size = filename_count };
        args.exec_args.k_filename_list.funcs.encode = encode_str_list;
        args.exec_args.k_filename_list.arg = &strs;
    }
    if (schema_name != NULL) {
        args.schema_name.funcs.encode = encode_string;
        args.schema_name.arg = (void*)schema_name;
    }

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    // Encode manually: the static nested ExecProgramArgs would otherwise
    // trigger nanopb's two-pass submessage encoding, which breaks the
    // stateful encode_str_list callback.
    if (args.has_exec_args
        && !kcl_encode_tagged_submsg(&stream, GetSchemaTypeMappingArgs_exec_args_tag, ExecProgramArgs_fields, &args.exec_args))
        goto done;
    if (schema_name != NULL
        && !kcl_encode_tagged_string(&stream, GetSchemaTypeMappingArgs_schema_name_tag, schema_name))
        goto done;

    size_t result_length = kcl_call("KclService.GetSchemaTypeMappingUnderPath", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    GetSchemaTypeMappingUnderPathResult res = GetSchemaTypeMappingUnderPathResult_init_default;
    struct KclJsonSink mapping_sink;

    kcl_json_sink_init(&mapping_sink, mapping_out, mapping_out_size);
    mapping_sink.auto_array = true;

    res.schema_type_mapping.funcs.decode = kcl_decode_schema_types_map_json;
    res.schema_type_mapping.arg = &mapping_sink;

    if (!pb_decode(&istream, GetSchemaTypeMappingUnderPathResult_fields, &res))
        goto done;
    if (!kcl_json_sink_finish(&mapping_sink))
        goto done;

    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(files);
    free(file_ptrs);
    return status;
}

// Format the KCL file or directory at path and copy the newline-separated
// changed file paths into changed_paths_out. Returns false and copies the
// error message into err_out on failure.
static inline bool kcl_format_path(const char* path, bool dry_run,
    char* changed_paths_out, size_t changed_paths_out_size,
    char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    bool status = false;
    if (buffer == NULL || result_buffer == NULL)
        goto done;

    FormatPathArgs args = FormatPathArgs_init_zero;
    args.path.funcs.encode = encode_string;
    args.path.arg = (void*)path;
    args.dry_run = dry_run;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, FormatPathArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("KclService.FormatPath", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    FormatPathResult res = FormatPathResult_init_default;
    struct KclStringListCollector collector = { .buffer = changed_paths_out, .size = changed_paths_out_size, .length = 0 };
    res.changed_paths.funcs.decode = kcl_decode_string_list;
    res.changed_paths.arg = &collector;
    if (!pb_decode(&istream, FormatPathResult_fields, &res))
        goto done;

    status = true;

done:
    free(buffer);
    free(result_buffer);
    return status;
}

// Load the settings files and fill `result`. String lists inside
// kcl_cli_configs are newline-joined into their buffers; kcl_options is
// decoded into the provided array. Returns false and copies the error
// message into err_out on failure.
static inline bool kcl_load_settings_files(const char* work_dir,
    const char* const* files, size_t file_count,
    struct KclLoadSettingsFilesResult* result, char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* output_buffer = (uint8_t*)calloc(1, BUFFER_SIZE);
    struct Buffer* file_bufs = NULL;
    struct Buffer** file_ptrs = NULL;
    bool status = false;
    if (buffer == NULL || result_buffer == NULL || output_buffer == NULL)
        goto done;

    // Hoisted out of the `if` block below — see kcl_load_package for the
    // rationale (stack-use-after-scope on Linux when the encode callback
    // runs after this block ends).
    struct RepeatedString strs = { 0 };
    LoadSettingsFilesArgs args = LoadSettingsFilesArgs_init_zero;
    if (work_dir != NULL) {
        args.work_dir.funcs.encode = encode_string;
        args.work_dir.arg = (void*)work_dir;
    }
    if (file_count > 0) {
        file_bufs = (struct Buffer*)malloc(file_count * sizeof(struct Buffer));
        file_ptrs = (struct Buffer**)malloc(file_count * sizeof(struct Buffer*));
        if (file_bufs == NULL || file_ptrs == NULL)
            goto done;
        for (size_t i = 0; i < file_count; ++i) {
            file_bufs[i].buffer = files[i];
            file_bufs[i].len = strlen(files[i]);
            file_ptrs[i] = &file_bufs[i];
        }
        strs = (struct RepeatedString){ .repeated = file_ptrs, .index = 0, .saved_index = 0, .max_size = file_count };
        args.files.funcs.encode = encode_str_list;
        args.files.arg = &strs;
    }

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, LoadSettingsFilesArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("KclService.LoadSettingsFiles", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    LoadSettingsFilesResult res = LoadSettingsFilesResult_init_default;
    struct KclStringListCollector files_collector = { .buffer = result->kcl_cli_configs.files, .size = sizeof(result->kcl_cli_configs.files), .length = 0 };
    struct KclStringListCollector overrides_collector = { .buffer = result->kcl_cli_configs.overrides, .size = sizeof(result->kcl_cli_configs.overrides), .length = 0 };
    struct KclStringListCollector selector_collector = { .buffer = result->kcl_cli_configs.path_selector, .size = sizeof(result->kcl_cli_configs.path_selector), .length = 0 };
    struct KclKeyValueCollector options_collector = { .items = result->kcl_options, .max_count = result->kcl_options_size, .count = 0 };

    res.kcl_cli_configs.files.funcs.decode = kcl_decode_string_list;
    res.kcl_cli_configs.files.arg = &files_collector;
    res.kcl_cli_configs.output.funcs.decode = decode_string;
    res.kcl_cli_configs.output.arg = output_buffer;
    res.kcl_cli_configs.overrides.funcs.decode = kcl_decode_string_list;
    res.kcl_cli_configs.overrides.arg = &overrides_collector;
    res.kcl_cli_configs.path_selector.funcs.decode = kcl_decode_string_list;
    res.kcl_cli_configs.path_selector.arg = &selector_collector;
    res.kcl_options.funcs.decode = kcl_decode_key_value_pair_list;
    res.kcl_options.arg = &options_collector;

    if (!pb_decode(&istream, LoadSettingsFilesResult_fields, &res))
        goto done;

    result->kcl_cli_configs.strict_range_check = res.kcl_cli_configs.strict_range_check;
    result->kcl_cli_configs.disable_none = res.kcl_cli_configs.disable_none;
    result->kcl_cli_configs.verbose = res.kcl_cli_configs.verbose;
    result->kcl_cli_configs.debug = res.kcl_cli_configs.debug;
    result->kcl_cli_configs.sort_keys = res.kcl_cli_configs.sort_keys;
    result->kcl_cli_configs.show_hidden = res.kcl_cli_configs.show_hidden;
    result->kcl_cli_configs.include_schema_type_path = res.kcl_cli_configs.include_schema_type_path;
    result->kcl_cli_configs.fast_eval = res.kcl_cli_configs.fast_eval;
    kcl_copy_string(result->kcl_cli_configs.output, sizeof(result->kcl_cli_configs.output), output_buffer);
    result->kcl_option_count = options_collector.count;
    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(output_buffer);
    free(file_bufs);
    free(file_ptrs);
    return status;
}

// Rename the symbol `symbol_path` to `new_name` in the given files and
// copy the newline-separated changed file paths into changed_files_out.
// Returns false and copies the error message into err_out on failure.
static inline bool kcl_rename(const char* package_root, const char* symbol_path,
    const char* const* file_paths, size_t file_path_count, const char* new_name,
    char* changed_files_out, size_t changed_files_out_size,
    char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    struct Buffer* path_bufs = NULL;
    struct Buffer** path_ptrs = NULL;
    bool status = false;
    if (buffer == NULL || result_buffer == NULL)
        goto done;

    // Hoisted out of the `if` block below — see kcl_load_package for the
    // rationale (stack-use-after-scope on Linux when the encode callback
    // runs after this block ends).
    struct RepeatedString strs = { 0 };
    RenameArgs args = RenameArgs_init_zero;
    args.package_root.funcs.encode = encode_string;
    args.package_root.arg = (void*)package_root;
    args.symbol_path.funcs.encode = encode_string;
    args.symbol_path.arg = (void*)symbol_path;
    args.new_name.funcs.encode = encode_string;
    args.new_name.arg = (void*)new_name;
    if (file_path_count > 0) {
        path_bufs = (struct Buffer*)malloc(file_path_count * sizeof(struct Buffer));
        path_ptrs = (struct Buffer**)malloc(file_path_count * sizeof(struct Buffer*));
        if (path_bufs == NULL || path_ptrs == NULL)
            goto done;
        for (size_t i = 0; i < file_path_count; ++i) {
            path_bufs[i].buffer = file_paths[i];
            path_bufs[i].len = strlen(file_paths[i]);
            path_ptrs[i] = &path_bufs[i];
        }
        strs = (struct RepeatedString){ .repeated = path_ptrs, .index = 0, .saved_index = 0, .max_size = file_path_count };
        args.file_paths.funcs.encode = encode_str_list;
        args.file_paths.arg = &strs;
    }

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, RenameArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("KclService.Rename", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    RenameResult res = RenameResult_init_default;
    struct KclStringListCollector collector = { .buffer = changed_files_out, .size = changed_files_out_size, .length = 0 };
    res.changed_files.funcs.decode = kcl_decode_string_list;
    res.changed_files.arg = &collector;
    if (!pb_decode(&istream, RenameResult_fields, &res))
        goto done;

    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(path_bufs);
    free(path_ptrs);
    return status;
}

// Rename the symbol `symbol_path` in the in-memory source codes and copy
// the JSON array of changed codes into changed_codes_out. Returns false
// and copies the error message into err_out on failure.
static inline bool kcl_rename_code(const char* package_root, const char* symbol_path,
    const struct KclStringPair* source_codes, size_t source_code_count,
    const char* new_name,
    char* changed_codes_out, size_t changed_codes_out_size,
    char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    bool status = false;
    if (buffer == NULL || result_buffer == NULL)
        goto done;

    // Hoisted out of the `if` block below — see kcl_load_package for the
    // rationale (stack-use-after-scope on Linux when the encode callback
    // runs after this block ends).
    struct KclStringPairList pair_list = { 0 };
    RenameCodeArgs args = RenameCodeArgs_init_zero;
    args.package_root.funcs.encode = encode_string;
    args.package_root.arg = (void*)package_root;
    args.symbol_path.funcs.encode = encode_string;
    args.symbol_path.arg = (void*)symbol_path;
    args.new_name.funcs.encode = encode_string;
    args.new_name.arg = (void*)new_name;
    if (source_code_count > 0) {
        pair_list = (struct KclStringPairList){ .items = source_codes, .count = source_code_count, .index = 0 };
        args.source_codes.funcs.encode = kcl_encode_string_map_entries;
        args.source_codes.arg = &pair_list;
    }

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, RenameCodeArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("KclService.RenameCode", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    RenameCodeResult res = RenameCodeResult_init_default;
    struct KclJsonSink changed_sink;

    kcl_json_sink_init(&changed_sink, changed_codes_out, changed_codes_out_size);
    changed_sink.auto_array = true;

    res.changed_codes.funcs.decode = kcl_decode_string_string_map_json;
    res.changed_codes.arg = &changed_sink;

    if (!pb_decode(&istream, RenameCodeResult_fields, &res))
        goto done;
    if (!kcl_json_sink_finish(&changed_sink))
        goto done;

    status = true;

done:
    free(buffer);
    free(result_buffer);
    return status;
}

// Run the KCL unit tests of the given packages and decode the test case
// info into `info` (up to max_info); the decoded count is stored in
// info_count. Returns false and copies the error message into err_out on
// failure.
static inline bool kcl_test(const char* work_dir,
    const char* const* filenames, size_t filename_count,
    const char* const* pkg_list, size_t pkg_count,
    const char* run_regexp, bool fail_fast,
    struct KclTestCaseInfo* info, size_t max_info, size_t* info_count,
    char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    struct Buffer* files = NULL;
    struct Buffer** file_ptrs = NULL;
    struct Buffer* pkgs = NULL;
    struct Buffer** pkg_ptrs = NULL;
    bool status = false;
    if (buffer == NULL || result_buffer == NULL)
        goto done;

    // Hoisted out of the `if` blocks below — see kcl_load_package for the
    // rationale (stack-use-after-scope on Linux when the encode callback
    // runs after this block ends).
    struct RepeatedString strs = { 0 };
    struct RepeatedString pkg_strs = { 0 };
    TestArgs args = TestArgs_init_zero;
    args.has_exec_args = true;
    if (work_dir != NULL) {
        args.exec_args.work_dir.funcs.encode = encode_string;
        args.exec_args.work_dir.arg = (void*)work_dir;
    }
    if (filename_count > 0) {
        files = (struct Buffer*)malloc(filename_count * sizeof(struct Buffer));
        file_ptrs = (struct Buffer**)malloc(filename_count * sizeof(struct Buffer*));
        if (files == NULL || file_ptrs == NULL)
            goto done;
        for (size_t i = 0; i < filename_count; ++i) {
            files[i].buffer = filenames[i];
            files[i].len = strlen(filenames[i]);
            file_ptrs[i] = &files[i];
        }
        strs = (struct RepeatedString){ .repeated = file_ptrs, .index = 0, .saved_index = 0, .max_size = filename_count };
        args.exec_args.k_filename_list.funcs.encode = encode_str_list;
        args.exec_args.k_filename_list.arg = &strs;
    }
    if (pkg_count > 0) {
        pkgs = (struct Buffer*)malloc(pkg_count * sizeof(struct Buffer));
        pkg_ptrs = (struct Buffer**)malloc(pkg_count * sizeof(struct Buffer*));
        if (pkgs == NULL || pkg_ptrs == NULL)
            goto done;
        for (size_t i = 0; i < pkg_count; ++i) {
            pkgs[i].buffer = pkg_list[i];
            pkgs[i].len = strlen(pkg_list[i]);
            pkg_ptrs[i] = &pkgs[i];
        }
        pkg_strs = (struct RepeatedString){ .repeated = pkg_ptrs, .index = 0, .saved_index = 0, .max_size = pkg_count };
        args.pkg_list.funcs.encode = encode_str_list;
        args.pkg_list.arg = &pkg_strs;
    }
    if (run_regexp != NULL) {
        args.run_regexp.funcs.encode = encode_string;
        args.run_regexp.arg = (void*)run_regexp;
    }
    args.fail_fast = fail_fast;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    // Encode manually: the static nested ExecProgramArgs would otherwise
    // trigger nanopb's two-pass submessage encoding, which breaks the
    // stateful encode_str_list callback.
    if (args.has_exec_args
        && !kcl_encode_tagged_submsg(&stream, TestArgs_exec_args_tag, ExecProgramArgs_fields, &args.exec_args))
        goto done;
    for (size_t i = 0; i < pkg_count; ++i) {
        if (!pb_encode_tag(&stream, PB_WT_STRING, TestArgs_pkg_list_tag)
            || !pb_encode_string(&stream, (const uint8_t*)pkg_list[i], strlen(pkg_list[i])))
            goto done;
    }
    if (run_regexp != NULL
        && !kcl_encode_tagged_string(&stream, TestArgs_run_regexp_tag, run_regexp))
        goto done;
    if (args.fail_fast && !kcl_encode_tagged_true(&stream, TestArgs_fail_fast_tag))
        goto done;

    size_t result_length = kcl_call("KclService.Test", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    TestResult res = TestResult_init_default;
    struct KclTestCaseCollector collector = { .items = info, .max_count = max_info, .count = 0 };
    res.info.funcs.decode = kcl_decode_test_case_info_list;
    res.info.arg = &collector;
    if (!pb_decode(&istream, TestResult_fields, &res))
        goto done;

    if (info_count != NULL)
        *info_count = collector.count;
    status = true;

done:
    free(buffer);
    free(result_buffer);
    free(files);
    free(file_ptrs);
    free(pkgs);
    free(pkg_ptrs);
    return status;
}

// Update the dependencies of the kcl.mod at manifest_path and decode the
// resolved external packages into `pkgs` (up to max_pkgs); the decoded
// count is stored in pkg_count. Returns false and copies the error
// message into err_out on failure.
static inline bool kcl_update_dependencies(const char* manifest_path, bool vendor,
    struct KclExternalPkgInfo* pkgs, size_t max_pkgs, size_t* pkg_count,
    char* err_out, size_t err_out_size)
{
    uint8_t* buffer = (uint8_t*)malloc(BUFFER_SIZE);
    uint8_t* result_buffer = (uint8_t*)malloc(BUFFER_SIZE);
    bool status = false;
    if (buffer == NULL || result_buffer == NULL)
        goto done;

    UpdateDependenciesArgs args = UpdateDependenciesArgs_init_zero;
    args.manifest_path.funcs.encode = encode_string;
    args.manifest_path.arg = (void*)manifest_path;
    args.vendor = vendor;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, BUFFER_SIZE);
    if (!pb_encode(&stream, UpdateDependenciesArgs_fields, &args))
        goto done;

    size_t result_length = kcl_call("KclService.UpdateDependencies", buffer, stream.bytes_written, result_buffer);
    if (check_error_prefix(result_buffer)) {
        kcl_copy_string(err_out, err_out_size, result_buffer);
        goto done;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    UpdateDependenciesResult res = UpdateDependenciesResult_init_default;
    struct KclExternalPkgCollector collector = { .items = pkgs, .max_count = max_pkgs, .count = 0 };
    res.external_pkgs.funcs.decode = kcl_decode_external_pkg_list;
    res.external_pkgs.arg = &collector;
    if (!pb_decode(&istream, UpdateDependenciesResult_fields, &res))
        goto done;

    if (pkg_count != NULL)
        *pkg_count = collector.count;
    status = true;

done:
    free(buffer);
    free(result_buffer);
    return status;
}

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif
