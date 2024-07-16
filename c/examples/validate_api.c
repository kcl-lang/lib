#include <kcl_lib.h>

int validate(const char* code_str, const char* data_str)
{
    uint8_t buffer[BUFFER_SIZE];
    uint8_t result_buffer[BUFFER_SIZE];
    size_t message_length;
    bool status;

    ValidateCode_Args validate_args = ValidateCode_Args_init_zero;
    validate_args.code.funcs.encode = encode_string;
    validate_args.code.arg = (void*)code_str;
    validate_args.data.funcs.encode = encode_string;
    validate_args.data.arg = (void*)data_str;

    pb_ostream_t stream = pb_ostream_from_buffer(buffer, sizeof(buffer));
    status = pb_encode(&stream, ValidateCode_Args_fields, &validate_args);
    message_length = stream.bytes_written;

    if (!status) {
        printf("Encoding failed: %s\n", PB_GET_ERROR(&stream));
        return 1;
    }

    const char* api_str = "KclvmService.ValidateCode";
    size_t result_length = call_native((const uint8_t*)api_str, strlen(api_str), buffer, message_length, result_buffer);
    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    ValidateCode_Result result = ValidateCode_Result_init_default;

    result.err_message.funcs.decode = decode_string;
    uint8_t value_buffer[BUFFER_SIZE] = { 0 };
    result.err_message.arg = value_buffer;

    status = pb_decode(&istream, ValidateCode_Result_fields, &result);

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
