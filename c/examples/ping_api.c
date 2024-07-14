#include <kcl_lib.h>

int main()
{
    uint8_t buffer[BUFFER_SIZE];
    uint8_t result_buffer[BUFFER_SIZE];
    size_t message_length;
    bool status;

    Ping_Args ping_args = Ping_Args_init_zero;
    pb_ostream_t stream = pb_ostream_from_buffer(buffer, sizeof(buffer));
    ping_args.value.funcs.encode = encode_string;
    const char* hello_str = "hello";
    ping_args.value.arg = (void*)hello_str;

    status = pb_encode(&stream, Ping_Args_fields, &ping_args);
    message_length = stream.bytes_written;

    if (!status) {
        printf("Encoding failed: %s\n", PB_GET_ERROR(&stream));
        return 1;
    }

    const char* api_str = "KclvmService.Ping";
    size_t result_length = call_native((const uint8_t*)api_str, strlen(api_str), buffer, message_length, result_buffer);

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    Ping_Args decoded_ping_args = Ping_Args_init_default;
    decoded_ping_args.value.funcs.decode = decode_string;
    uint8_t value_buffer[BUFFER_SIZE] = { 0 };
    decoded_ping_args.value.arg = value_buffer;

    status = pb_decode(&istream, Ping_Args_fields, &decoded_ping_args);

    if (!status) {
        printf("Decoding failed: %s\n", PB_GET_ERROR(&istream));
        return 1;
    }

    if (decoded_ping_args.value.arg) {
        printf("Decoded message: %s\n", (char*)decoded_ping_args.value.arg);
    } else {
        printf("No decoded message\n");
    }

    return 0;
}
