#ifndef _KCL_LIB_H
#define _KCL_LIB_H

#ifdef __cplusplus
extern "C" {
#endif

#include <pb_decode.h>
#include <pb_encode.h>
#include <spec.pb.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#include "kcl_ffi.h"

#define BUFFER_SIZE 1024

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

// Decode callback function for getting string
bool decode_string(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    uint8_t buffer[BUFFER_SIZE] = { 0 };

    /* We could read block-by-block to avoid the large buffer... */
    if (stream->bytes_left > sizeof(buffer) - 1)
        return false;

    if (!pb_read(stream, buffer, stream->bytes_left))
        return false;

    memcpy((char*)*arg, buffer, BUFFER_SIZE);
    return true;
}

bool check_error_prefix(uint8_t result_buffer[])
{
    if (result_buffer[0] == 'E' && result_buffer[1] == 'R' && result_buffer[2] == 'R' && result_buffer[3] == 'O' && result_buffer[4] == 'R') {
        return true;
    }
    return false;
}

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif
