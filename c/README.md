# KCL Artifact Library for C

## Developing

**Prerequisites**

+ Make
+ C++ compiler with C++11 support
+ Cargo

Run the command to build KCL C Lib.

```shell
make cargo
make
```

## Formatting

```shell
make fmt
```

## Examples

Run the following command to build all example codes.

```shell
make examples
```

+ ExecProgram

```c
#include <kcl_lib.h>

int exec_file(const char* file_str) {
    static uint8_t buffer[BUFFER_SIZE];
    static uint8_t result_buffer[BUFFER_SIZE];
    size_t message_length;
    bool status;
    struct Buffer file = {
        .buffer = file_str,
        .len = strlen(file_str),
    };
    struct Buffer* files[] = { &file };
    struct RepeatedString strs = { .repeated = &files[0], .index = 0, .max_size = 1 };
    ExecProgramArgs args = ExecProgramArgs_init_zero;
    args.k_filename_list.funcs.encode = encode_str_list;
    args.k_filename_list.arg = &strs;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, sizeof(buffer));
    status = pb_encode(&stream, ExecProgramArgs_fields, &args);
    message_length = stream.bytes_written;

    if (!status) {
        printf("Encoding failed: %s\n", PB_GET_ERROR(&stream));
        return 1;
    }

    const char* api_str = "KclService.ExecProgram";
    size_t result_length = call_native((const uint8_t*)api_str, strlen(api_str), buffer, message_length, result_buffer);
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

    status = pb_decode(&istream, ExecProgramResult_fields, &result);

    if (!status) {
        printf("Decoding failed: %s\n", PB_GET_ERROR(&istream));
        return 1;
    }

    if (result.yaml_result.arg) {
        printf("%s\n", (char*)result.yaml_result.arg);
    }

    return 0;
}

int main()
{
    exec_file("./test_data/schema.k");
    return 0;
}
```

Run the ExecProgram example.

```shell
./examples/exec_api
```

+ ValidateCode

```c
#include <kcl_lib.h>

int validate(const char* code_str, const char* data_str)
{
    static uint8_t buffer[BUFFER_SIZE];
    static uint8_t result_buffer[BUFFER_SIZE];
    size_t message_length;
    bool status;

    ValidateCodeArgs validate_args = ValidateCodeArgs_init_zero;
    validate_args.code.funcs.encode = encode_string;
    validate_args.code.arg = (void*)code_str;
    validate_args.data.funcs.encode = encode_string;
    validate_args.data.arg = (void*)data_str;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, sizeof(buffer));
    status = pb_encode(&stream, ValidateCodeArgs_fields, &validate_args);
    message_length = stream.bytes_written;

    if (!status) {
        printf("Encoding failed: %s\n", PB_GET_ERROR(&stream));
        return 1;
    }

    const char* api_str = "KclService.ValidateCode";
    size_t result_length = call_native((const uint8_t*)api_str, strlen(api_str), buffer, message_length, result_buffer);
    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    ValidateCodeResult result = ValidateCodeResult_init_default;

    result.err_message.funcs.decode = decode_string;
    static uint8_t value_buffer[BUFFER_SIZE] = { 0 };
    result.err_message.arg = value_buffer;

    status = pb_decode(&istream, ValidateCodeResult_fields, &result);

    if (!status) {
        printf("Decoding failed: %s\n", PB_GET_ERROR(&istream));
        return 1;
    }

    printf("Validate Status: %d\n", result.success);
    if (result.err_message.arg) {
        printf("Validate Error Message: %s\n", (char*)result.err_message.arg);
    }
    return 0;
}

int main()
{
    const char* code_str = "schema Person:\n"
                           "    name: str\n"
                           "    age: int\n"
                           "    check:\n"
                           "        0 < age < 120\n";
    const char* data_str = "{\"name\": \"Alice\", \"age\": 10}";
    const char* error_data_str = "{\"name\": \"Alice\", \"age\": 1110}";
    validate(code_str, data_str);
    validate(code_str, error_data_str);
    return 0;
}
```

Run the ValidateCode example.

```shell
./examples/validate_api
```

## Typed API

`kcl_lib.h` provides typed wrappers around the raw protobuf encode/decode
helpers for the commonly used methods. All wrappers return `true` on success
and `false` on failure (on failure the error message is copied into the
provided output buffer when one is available).

```c
#include <kcl_lib.h>

int main()
{
    // Ping
    char ping_value[128] = { 0 };
    if (kcl_ping("hello", ping_value, sizeof(ping_value))) {
        printf("%s\n", ping_value);
    }

    // GetVersion
    struct KclVersion version = { 0 };
    if (kcl_get_version(&version)) {
        printf("%s\n", version.version);
    }

    // ExecProgram
    static char yaml[BUFFER_SIZE];
    static char exec_err[BUFFER_SIZE];
    const char* files[] = { "./test_data/schema.k" };
    if (kcl_exec_program(files, 1, yaml, sizeof(yaml), exec_err, sizeof(exec_err))) {
        printf("%s\n", yaml);
    }

    // ValidateCode
    bool success = false;
    char validate_err[BUFFER_SIZE] = { 0 };
    const char* code = "schema Person:\n    name: str\n    age: int\n    check:\n        0 < age < 120\n";
    if (kcl_validate_code(code, "{\"name\": \"Alice\", \"age\": 10}", &success, validate_err, sizeof(validate_err))) {
        printf("Validate Status: %d\n", success);
    }

    // FormatCode
    static char formatted[BUFFER_SIZE];
    if (kcl_format_code("a = 1", formatted, sizeof(formatted))) {
        printf("%s\n", formatted);
    }

    // LintPath
    static char lint_results[BUFFER_SIZE];
    const char* lint_paths[] = { "./test_data/schema.k" };
    if (kcl_lint_path(lint_paths, 1, lint_results, sizeof(lint_results))) {
        printf("%s\n", lint_results);
    }

    return 0;
}
```
