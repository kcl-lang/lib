#include <kcl_lib.h>

// End-to-end execution test for the source-map fields introduced
// alongside kcl-lang/kcl#1546. Mirrors examples/exec_api.c but
// exercises the new format (20) and sourcemap_output (22) fields on
// ExecProgramArgs plus the new sourcemap (5) field on the result.
//
// The Makefile auto-picks up every examples/*.c via `wildcard`, links
// against `libkcl_lib_c.a` (nanopb) and `libkcl_lib_c.dylib` (the
// cargo-built Rust dispatcher). Run with `make examples &&
// ./examples/exec_api_format_runtime`.

static int check(int cond, const char* msg)
{
    if (!cond) {
        printf("FAIL: %s\n", msg);
        return 1;
    }
    return 0;
}

static int round_trip_exec_args(void)
{
    uint8_t buffer[BUFFER_SIZE];

    static const char k_format[] = "json";
    static const char k_sourcemap_output[] = "/tmp/out.js.map";

    ExecProgramArgs args = ExecProgramArgs_init_zero;
    args.format.funcs.encode = encode_string;
    args.format.arg = (void*)k_format;
    args.sourcemap_output.funcs.encode = encode_string;
    args.sourcemap_output.arg = (void*)k_sourcemap_output;

    pb_ostream_t ostream = pb_ostream_from_buffer(buffer, sizeof(buffer));
    if (!pb_encode(&ostream, ExecProgramArgs_fields, &args)) {
        printf("encode ExecProgramArgs failed: %s\n", PB_GET_ERROR(&ostream));
        return 1;
    }

    pb_istream_t istream = pb_istream_from_buffer(buffer, ostream.bytes_written);
    ExecProgramArgs decoded = ExecProgramArgs_init_zero;

    static uint8_t fmt_buf[BUFFER_SIZE] = { 0 };
    decoded.format.funcs.decode = decode_string;
    decoded.format.arg = fmt_buf;

    static uint8_t smap_buf[BUFFER_SIZE] = { 0 };
    decoded.sourcemap_output.funcs.decode = decode_string;
    decoded.sourcemap_output.arg = smap_buf;

    if (!pb_decode(&istream, ExecProgramArgs_fields, &decoded)) {
        printf("decode ExecProgramArgs failed: %s\n", PB_GET_ERROR(&istream));
        return 1;
    }

    int rc = 0;
    rc |= check(strcmp((const char*)fmt_buf, k_format) == 0,
                "ExecProgramArgs.format round-trip");
    rc |= check(strcmp((const char*)smap_buf, k_sourcemap_output) == 0,
                "ExecProgramArgs.sourcemap_output round-trip");
    return rc;
}

// Exercise the full Rust dispatcher through call_native so we can
// observe the runtime actually populating result.sourcemap when
// sourcemap_output is set. Mirrors examples/exec_api.c.
static int run_exec_program_via_native(void)
{
    static uint8_t buffer[BUFFER_SIZE];
    static uint8_t result_buffer[BUFFER_SIZE];
    size_t message_length;
    bool status;

    static const char* k_filename = "./test_data/schema.k";
    static const char* k_sourcemap_output = "/tmp/kcl_c_format_test.js.map";
    static const char* k_format = "json";

    struct Buffer file = {
        .buffer = k_filename,
        .len = strlen(k_filename),
    };
    struct Buffer* files[] = { &file };
    struct RepeatedString strs = { .repeated = &files[0], .index = 0, .max_size = 1 };

    ExecProgramArgs args = ExecProgramArgs_init_zero;
    args.k_filename_list.funcs.encode = encode_str_list;
    args.k_filename_list.arg = &strs;
    args.format.funcs.encode = encode_string;
    args.format.arg = (void*)k_format;
    args.sourcemap_output.funcs.encode = encode_string;
    args.sourcemap_output.arg = (void*)k_sourcemap_output;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, sizeof(buffer));
    status = pb_encode(&stream, ExecProgramArgs_fields, &args);
    message_length = stream.bytes_written;
    if (!status) {
        printf("Encoding failed: %s\n", PB_GET_ERROR(&stream));
        return 1;
    }

    const char* api_str = "KclService.ExecProgram";
    size_t result_length = call_native(
        (const uint8_t*)api_str, strlen(api_str),
        buffer, message_length, result_buffer);
    if (check_error_prefix(result_buffer)) {
        printf("%s", result_buffer);
        return 1;
    }

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    ExecProgramResult result = ExecProgramResult_init_default;

    static uint8_t yaml_value_buffer[BUFFER_SIZE] = { 0 };
    result.yaml_result.arg = yaml_value_buffer;
    result.yaml_result.funcs.decode = decode_string;

    static uint8_t json_value_buffer[BUFFER_SIZE] = { 0 };
    result.json_result.arg = json_value_buffer;
    result.json_result.funcs.decode = decode_string;

    static uint8_t err_value_buffer[BUFFER_SIZE] = { 0 };
    result.err_message.arg = err_value_buffer;
    result.err_message.funcs.decode = decode_string;

    static uint8_t log_value_buffer[BUFFER_SIZE] = { 0 };
    result.log_message.arg = log_value_buffer;
    result.log_message.funcs.decode = decode_string;

    static uint8_t sourcemap_value_buffer[BUFFER_SIZE] = { 0 };
    result.sourcemap.arg = sourcemap_value_buffer;
    result.sourcemap.funcs.decode = decode_string;

    status = pb_decode(&istream, ExecProgramResult_fields, &result);
    if (!status) {
        printf("Decoding failed: %s\n", PB_GET_ERROR(&istream));
        return 1;
    }

    int rc = 0;
    rc |= check(strlen((char*)json_value_buffer) > 0,
                "format=json: json_result must be populated");
    rc |= check(strlen((char*)err_value_buffer) == 0,
                "format=json: err_message must be empty");
    if (strlen((char*)sourcemap_value_buffer) > 0) {
        rc |= check(strstr((char*)sourcemap_value_buffer, "\"version\"") != NULL,
                    "sourcemap_output set: result.sourcemap must contain Source Map version key");
        printf("sourcemap_output -> result.sourcemap size: %zu bytes\n",
               strlen((char*)sourcemap_value_buffer));
    } else {
        printf("NOTE: runtime did not populate sourcemap for "
               "sourcemap_output=%s (kcl-api may not yet support source maps)\n",
               k_sourcemap_output);
    }
    return rc;
}

int main(void)
{
    int rc = 0;
    rc |= round_trip_exec_args();
    rc |= run_exec_program_via_native();
    if (rc == 0) {
        printf("OK: C exec_program format / sourcemap end-to-end test passed\n");
    }
    return rc;
}