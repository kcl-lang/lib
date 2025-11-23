#include <kcl_lib.h>

int ping(const char* msg)
{
    uint8_t buffer[BUFFER_SIZE];
    uint8_t result_buffer[BUFFER_SIZE];
    size_t message_length;
    bool status;

    PingArgs ping_args = PingArgs_init_zero;
    pb_ostream_t stream = pb_ostream_from_buffer(buffer, sizeof(buffer));
    ping_args.value.funcs.encode = encode_string;
    ping_args.value.arg = (void*)msg;

    status = pb_encode(&stream, PingArgs_fields, &ping_args);
    message_length = stream.bytes_written;

    if (!status) {
        printf("Encoding failed: %s\n", PB_GET_ERROR(&stream));
        return 1;
    }

    const char* api_str = "KclService.Ping";
    size_t result_length = call_native((const uint8_t*)api_str, strlen(api_str), buffer, message_length, result_buffer);

    pb_istream_t istream = pb_istream_from_buffer(result_buffer, result_length);
    PingResult decoded_ping_args = PingResult_init_default;
    decoded_ping_args.value.funcs.decode = decode_string;
    uint8_t value_buffer[BUFFER_SIZE] = { 0 };
    decoded_ping_args.value.arg = value_buffer;

    status = pb_decode(&istream, PingResult_fields, &decoded_ping_args);

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

int main()
{
    ping("hello");
    ping("world");
    return 0;
}
