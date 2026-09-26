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

#define BUFFER_SIZE (4 * 1024 * 1024)

struct Buffer {
    const char* buffer;
    size_t len;
};

struct RepeatedString {
    struct Buffer** repeated;
    int index;
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
    if (result_buffer[0] == 'E' && result_buffer[1] == 'R' && result_buffer[2] == 'R' && result_buffer[3] == 'O' && result_buffer[4] == 'R') {
        return true;
    }
    return false;
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
    return call_native((const uint8_t*)api_str, strlen(api_str), args, args_len, result_buffer);
}

static inline bool kcl_decode_string_list(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
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
    struct RepeatedString strs = { .repeated = file_ptrs, .index = 0, .max_size = filename_count };
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
    struct RepeatedString strs = { .repeated = lint_path_ptrs, .index = 0, .max_size = path_count };
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
    struct RepeatedString strs = { .repeated = file_ptrs, .index = 0, .max_size = filename_count };
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

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif
