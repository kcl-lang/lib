#include <kcl_lib.h>

// Pure protobuf round-trip for the new fields introduced alongside
// kcl-lang/kcl#1546 — the C binding has to encode and decode them in
// lockstep with the .proto definition:
//
//   ExecProgramArgs.format           (tag 20, wire 0xa2 0x01)
//   ExecProgramArgs.sourcemap_output (tag 22, wire 0xb2 0x01)
//   ExecProgramResult.sourcemap      (tag 5,  wire 0x2a)
//
// This intentionally does NOT invoke call_native() / the Rust dispatcher:
// the goal is to confirm the regenerated spec.pb.{h,c} handles the new
// fields without rebuilding the cargo crate. The Makefile auto-picks up
// any examples/*.c, so a plain `./examples/exec_api_format` after
// `make examples` runs the whole check.

static int check(int cond, const char* msg)
{
    if (!cond) {
        printf("FAIL: %s\n", msg);
        return 1;
    }
    return 0;
}

// Round-trip ExecProgramArgs.format (20) + sourcemap_output (22).
static int round_trip_exec_args(void)
{
    uint8_t buffer[BUFFER_SIZE];

    static const char k_format[] = "json";
    static const char k_sourcemap_output[] = "/tmp/out.js.map";

    ExecProgramArgs args = ExecProgramArgs_init_zero;

    // format (field 20) — SINGULAR STRING.
    args.format.funcs.encode = encode_string;
    args.format.arg = (void*)k_format;

    // sourcemap_output (field 22) — OPTIONAL STRING.
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

// Round-trip ExecProgramResult.sourcemap (5).
static int round_trip_exec_result(void)
{
    uint8_t buffer[BUFFER_SIZE];

    static const char k_yaml[] = "a: 1\n";
    static const char k_json[] = "{\"a\": 1}";
    static const char k_sourcemap[] = "{\"version\":3,\"sources\":[]}";

    ExecProgramResult result = ExecProgramResult_init_zero;
    result.yaml_result.funcs.encode = encode_string;
    result.yaml_result.arg = (void*)k_yaml;
    result.json_result.funcs.encode = encode_string;
    result.json_result.arg = (void*)k_json;
    result.sourcemap.funcs.encode = encode_string;
    result.sourcemap.arg = (void*)k_sourcemap;

    pb_ostream_t ostream = pb_ostream_from_buffer(buffer, sizeof(buffer));
    if (!pb_encode(&ostream, ExecProgramResult_fields, &result)) {
        printf("encode ExecProgramResult failed: %s\n", PB_GET_ERROR(&ostream));
        return 1;
    }

    pb_istream_t istream = pb_istream_from_buffer(buffer, ostream.bytes_written);
    ExecProgramResult decoded = ExecProgramResult_init_zero;

    static uint8_t ybuf[BUFFER_SIZE] = { 0 };
    decoded.yaml_result.funcs.decode = decode_string;
    decoded.yaml_result.arg = ybuf;

    static uint8_t jbuf[BUFFER_SIZE] = { 0 };
    decoded.json_result.funcs.decode = decode_string;
    decoded.json_result.arg = jbuf;

    static uint8_t sbuf[BUFFER_SIZE] = { 0 };
    decoded.sourcemap.funcs.decode = decode_string;
    decoded.sourcemap.arg = sbuf;

    if (!pb_decode(&istream, ExecProgramResult_fields, &decoded)) {
        printf("decode ExecProgramResult failed: %s\n", PB_GET_ERROR(&istream));
        return 1;
    }

    int rc = 0;
    rc |= check(strcmp((const char*)ybuf, k_yaml) == 0,
                "ExecProgramResult.yaml_result round-trip");
    rc |= check(strcmp((const char*)jbuf, k_json) == 0,
                "ExecProgramResult.json_result round-trip");
    rc |= check(strcmp((const char*)sbuf, k_sourcemap) == 0,
                "ExecProgramResult.sourcemap round-trip");
    return rc;
}

int main(void)
{
    int rc = 0;
    rc |= round_trip_exec_args();
    rc |= round_trip_exec_result();
    if (rc == 0) {
        printf("OK: C round-trip for format / sourcemap_output / sourcemap passed\n");
    }
    return rc;
}