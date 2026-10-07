/*
 * kcl_lib_msgs.c — Shared protobuf encode/decode helpers for the typed
 * wrappers declared in kcl_lib.h. See kcl_lib_msgs.h for the API shape.
 *
 * Nanopb hands every CALLBACK message field a substream limited to that
 * field's bytes; the decoders below pb_decode() the substream directly.
 * Static (inline) submessage members such as Parameter.ty or map entry
 * `value` fields cannot be intercepted on the wire, so their inner
 * callback fields are wired to a temporary "scratch" sink and the
 * rendered JSON is spliced into the parent once pb_decode returns.
 *
 * Top-level list/map decoders (kcl_decode_*_json taking a
 * struct KclJsonSink*) render one JSON array of entries. The caller
 * sets sink->auto_array = true and invokes kcl_json_sink_finish() after
 * pb_decode() to close the array; an empty field renders as "[]".
 */

#include <pb_decode.h>
#include <pb_encode.h>
#include <spec.pb.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "kcl_lib_msgs.h"

static bool kclm_sink_puts(struct KclJsonSink* sink, const char* s);
static bool kclm_sink_end(struct KclJsonSink* sink);
static bool kclm_sink_close_to(struct KclJsonSink* sink, int depth);
static bool kclm_sink_ok(const struct KclJsonSink* sink);

/* ------------------------------------------------------------------ */
/* Encode/decode primitives                                            */
/* ------------------------------------------------------------------ */

static bool kclm_encode_string(pb_ostream_t* stream, const pb_field_t* field, void* const* arg)
{
    if (!pb_encode_tag_for_field(stream, field))
        return false;
    return pb_encode_string(stream, (const uint8_t*)(*arg), strlen((const char*)*arg));
}

bool kcl_decode_copy_string(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclStringSlot* slot = (struct KclStringSlot*)(*arg);
    size_t size = stream->bytes_left;
    (void)field;
    if (size >= slot->size)
        return false;
    if (!pb_read(stream, (uint8_t*)slot->buffer, size))
        return false;
    slot->buffer[size] = '\0';
    return true;
}

bool kcl_decode_count_only(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    size_t* count = (size_t*)(*arg);
    (void)field;
    if (!pb_read(stream, NULL, stream->bytes_left))
        return false;
    ++*count;
    return true;
}

/* ------------------------------------------------------------------ */
/* JSON sink                                                           */
/* ------------------------------------------------------------------ */

void kcl_json_sink_init(struct KclJsonSink* sink, char* buffer, size_t size)
{
    memset(sink, 0, sizeof(*sink));
    sink->buffer = buffer;
    sink->size = size;
    if (buffer != NULL && size > 0)
        buffer[0] = '\0';
    sink->depth = -1;
}

bool kcl_json_sink_finish(struct KclJsonSink* sink)
{
    bool status = kclm_sink_close_to(sink, -1);
    if (status && sink->auto_array && !sink->auto_array_open) {
        status = kclm_sink_puts(sink, "[]");
    }
    return status && kclm_sink_ok(sink);
}

static bool kclm_sink_putn(struct KclJsonSink* sink, const char* data, size_t len)
{
    if (sink->overflow)
        return false;
    if (sink->length + len >= sink->size) {
        sink->overflow = true;
        return false;
    }
    memcpy(sink->buffer + sink->length, data, len);
    sink->length += len;
    sink->buffer[sink->length] = '\0';
    sink->after_member = false;
    return true;
}

static bool kclm_sink_puts(struct KclJsonSink* sink, const char* s)
{
    return kclm_sink_putn(sink, s, strlen(s));
}

static bool kclm_sink_putf(struct KclJsonSink* sink, const char* fmt, ...)
{
    va_list ap;
    int n;
    if (sink->overflow || sink->length >= sink->size)
        return false;
    va_start(ap, fmt);
    n = vsnprintf(sink->buffer + sink->length, sink->size - sink->length, fmt, ap);
    va_end(ap);
    if (n < 0 || (size_t)n >= sink->size - sink->length) {
        sink->overflow = true;
        return false;
    }
    sink->length += (size_t)n;
    sink->after_member = false;
    return true;
}

static bool kclm_sink_json_string(struct KclJsonSink* sink, const char* data, size_t len)
{
    static const char hex[] = "0123456789abcdef";
    size_t i;
    if (!kclm_sink_putn(sink, "\"", 1))
        return false;
    for (i = 0; i < len; i++) {
        unsigned char c = (unsigned char)data[i];
        const char* esc = NULL;
        char tmp[7];
        switch (c) {
        case '"':
            esc = "\\\"";
            break;
        case '\\':
            esc = "\\\\";
            break;
        case '\b':
            esc = "\\b";
            break;
        case '\f':
            esc = "\\f";
            break;
        case '\n':
            esc = "\\n";
            break;
        case '\r':
            esc = "\\r";
            break;
        case '\t':
            esc = "\\t";
            break;
        default:
            if (c < 0x20) {
                tmp[0] = '\\';
                tmp[1] = 'u';
                tmp[2] = '0';
                tmp[3] = '0';
                tmp[4] = hex[c >> 4];
                tmp[5] = hex[c & 0xf];
                tmp[6] = '\0';
                esc = tmp;
            }
            break;
        }
        if (esc != NULL) {
            if (!kclm_sink_puts(sink, esc))
                return false;
        } else if (!kclm_sink_putn(sink, (const char*)&data[i], 1)) {
            return false;
        }
    }
    return kclm_sink_putn(sink, "\"", 1);
}

/* Emit the separator and `"name":` in front of an object member. A
 * trailing open array left by an earlier repeated member is closed
 * first; repeated fields always deliver their elements consecutively. */
static bool kclm_sink_member(struct KclJsonSink* sink, const char* name)
{
    while (sink->depth >= 0 && sink->frames[sink->depth].is_array) {
        if (!kclm_sink_end(sink))
            return false;
    }
    if (sink->depth < 0 || sink->frames[sink->depth].is_array)
        return false;
    if (sink->frames[sink->depth].has_items && !kclm_sink_putn(sink, ",", 1))
        return false;
    sink->frames[sink->depth].has_items = true;
    if (!kclm_sink_putf(sink, "\"%s\":", name))
        return false;
    sink->after_member = true;
    return true;
}

/* Emit `"name": <json>` where <json> is raw JSON text, optionally braced. */
static bool kclm_sink_member_raw(struct KclJsonSink* sink, const char* name, const char* json, bool brace)
{
    if (!kclm_sink_member(sink, name))
        return false;
    if (brace && !kclm_sink_putn(sink, "{", 1))
        return false;
    if (!kclm_sink_puts(sink, json))
        return false;
    if (brace && !kclm_sink_putn(sink, "}", 1))
        return false;
    return true;
}

/* Open an object or array container as the next value of the parent. */
static bool kclm_sink_begin(struct KclJsonSink* sink, bool is_array)
{
    if (sink->depth >= (int)(sizeof(sink->frames) / sizeof(sink->frames[0])) - 1)
        return false;
    if (sink->depth >= 0) {
        if (sink->frames[sink->depth].has_items && !sink->after_member
            && !kclm_sink_putn(sink, ",", 1))
            return false;
        sink->frames[sink->depth].has_items = true;
    }
    sink->depth++;
    sink->frames[sink->depth].is_array = is_array;
    sink->frames[sink->depth].has_items = false;
    return kclm_sink_putn(sink, is_array ? "[" : "{", 1);
}

/* Close the innermost container. */
static bool kclm_sink_end(struct KclJsonSink* sink)
{
    bool is_array;
    if (sink->depth < 0)
        return false;
    is_array = sink->frames[sink->depth].is_array;
    sink->depth--;
    return kclm_sink_putn(sink, is_array ? "]" : "}", 1);
}

/* Close containers until `depth` is reached again. */
static bool kclm_sink_close_to(struct KclJsonSink* sink, int depth)
{
    while (sink->depth > depth) {
        if (!kclm_sink_end(sink))
            return false;
    }
    return sink->depth == depth;
}

static bool kclm_sink_ok(const struct KclJsonSink* sink)
{
    return !sink->overflow;
}

/* Open the implicit JSON array for sinks fed by a top-level list/map
 * decoder; called once per decoded entry. */
static bool kclm_sink_list_entry_begin(struct KclJsonSink* sink)
{
    if (sink->auto_array && !sink->auto_array_open) {
        if (!kclm_sink_begin(sink, true))
            return false;
        sink->auto_array_open = true;
    }
    return true;
}

/* Scratch sink backing the callback fields of one static submessage. */
static bool kclm_scratch_begin(struct KclJsonSink* scratch, size_t capacity)
{
    kcl_json_sink_init(scratch, NULL, 0);
    scratch->buffer = (char*)malloc(capacity);
    if (scratch->buffer == NULL)
        return false;
    scratch->size = capacity;
    scratch->buffer[0] = '\0';
    return true;
}

static void kclm_scratch_end(struct KclJsonSink* scratch)
{
    free(scratch->buffer);
    scratch->buffer = NULL;
    scratch->size = 0;
}

/* ------------------------------------------------------------------ */
/* JSON decode callbacks (generic)                                     */
/* ------------------------------------------------------------------ */

struct KclJsonMemberCtx {
    struct KclJsonSink* sink;
    const char* name;
    bool array_started;
};

static bool kclm_decode_json_string_member(pb_istream_t* stream, const pb_field_t* field, void** arg);
static bool kclm_decode_json_string_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg);
static bool kclm_decode_json_int32_member(pb_istream_t* stream, const pb_field_t* field, void** arg);

static void kclm_wire_string_member(pb_callback_t* cb, struct KclJsonMemberCtx* ctx, struct KclJsonSink* sink, const char* name)
{
    ctx->sink = sink;
    ctx->name = name;
    ctx->array_started = false;
    cb->funcs.decode = kclm_decode_json_string_member;
    cb->arg = ctx;
}

/* Decode a string field as an escaped, quoted JSON value. */
static bool kclm_decode_json_string(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    size_t size = stream->bytes_left;
    char* data = (char*)malloc(size + 1);
    bool status;
    if (data == NULL)
        return false;
    status = pb_read(stream, (uint8_t*)data, size);
    if (status)
        status = kclm_sink_json_string(sink, data, size);
    free(data);
    return status;
}

/* Decode a string field as an object member: `"name": "value"`. */
static bool kclm_decode_json_string_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonMemberCtx* ctx = (struct KclJsonMemberCtx*)(*arg);
    if (!kclm_sink_member(ctx->sink, ctx->name))
        return false;
    return kclm_decode_json_string(stream, field, (void**)&ctx->sink);
}

/* Decode one element of a repeated string member: `"name": ["a", "b"]`.
 * Scalar elements carry no kclm_sink_begin of their own, so the comma
 * between them is emitted here: the array frame's has_items is set when
 * the first element lands and checked before every later one. */
static bool kclm_decode_json_string_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonMemberCtx* ctx = (struct KclJsonMemberCtx*)(*arg);
    if (!ctx->array_started) {
        if (!kclm_sink_member(ctx->sink, ctx->name))
            return false;
        if (!kclm_sink_begin(ctx->sink, true))
            return false;
        ctx->array_started = true;
    } else if (ctx->sink->depth >= 0 && ctx->sink->frames[ctx->sink->depth].has_items && !ctx->sink->after_member) {
        if (!kclm_sink_putn(ctx->sink, ",", 1))
            return false;
    }
    if (ctx->sink->depth >= 0)
        ctx->sink->frames[ctx->sink->depth].has_items = true;
    return kclm_decode_json_string(stream, field, (void**)&ctx->sink);
}

/* Decode an int32 field delivered through a callback (KclType.line). */
static bool kclm_decode_json_int32_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonMemberCtx* ctx = (struct KclJsonMemberCtx*)(*arg);
    uint32_t value;
    if (!pb_decode_varint32(stream, &value))
        return false;
    if (!kclm_sink_member(ctx->sink, ctx->name))
        return false;
    return kclm_sink_putf(ctx->sink, "%d", (int32_t)value);
}

/* ------------------------------------------------------------------ */
/* KclType and friends -> JSON                                         */
/* ------------------------------------------------------------------ */

/* Repeated-member wrapper: `"name": [<element>, ...]` where each
 * element is rendered by `render`. */
struct KclJsonArrayCtx {
    struct KclJsonSink* sink;
    const char* name;
    bool array_started;
};

struct KclKclTypeWire {
    KclType kt;
    struct KclJsonMemberCtx ctx[12];
    struct KclJsonMemberCtx ctx_union;
    struct KclJsonArrayCtx ctx_properties;
    struct KclJsonArrayCtx ctx_examples;
    struct KclJsonArrayCtx ctx_decorators;
    struct KclJsonMemberCtx ctx_function;
    struct KclJsonMemberCtx ctx_index_signature;
};

static bool kclm_kcltype_to_json(pb_istream_t* stream, struct KclJsonSink* sink);
static bool kcl_decode_json_kcltype_member(pb_istream_t* stream, const pb_field_t* field, void** arg);
static bool kclm_decode_decorator_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg);
static bool kcl_decode_function_type_member(pb_istream_t* stream, const pb_field_t* field, void** arg);
static bool kcl_decode_index_signature_member(pb_istream_t* stream, const pb_field_t* field, void** arg);

typedef bool (*kclm_element_renderer_t)(pb_istream_t* stream, struct KclJsonSink* sink);

static bool kclm_decode_json_element_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg, kclm_element_renderer_t render)
{
    struct KclJsonArrayCtx* ctx = (struct KclJsonArrayCtx*)(*arg);
    if (!ctx->array_started) {
        if (!kclm_sink_member(ctx->sink, ctx->name))
            return false;
        if (!kclm_sink_begin(ctx->sink, true))
            return false;
        ctx->array_started = true;
    }
    return render(stream, ctx->sink);
}

static bool kclm_decode_json_kcltype_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    return kclm_decode_json_element_array_member(stream, field, arg, kclm_kcltype_to_json);
}

/* Wire every callback field of a KclType to `sink`. The wire context
 * must stay alive until pb_decode of the surrounding message returns. */
static void kclm_kcltype_wire_init(struct KclKclTypeWire* w, struct KclJsonSink* sink)
{
    memset(w, 0, sizeof(*w));
    kclm_wire_string_member(&w->kt.type, &w->ctx[0], sink, "type");
    kclm_wire_string_member(&w->kt.default_, &w->ctx[1], sink, "default");
    kclm_wire_string_member(&w->kt.schema_name, &w->ctx[2], sink, "schema_name");
    kclm_wire_string_member(&w->kt.schema_doc, &w->ctx[3], sink, "schema_doc");
    kclm_wire_string_member(&w->kt.filename, &w->ctx[4], sink, "filename");
    kclm_wire_string_member(&w->kt.pkg_path, &w->ctx[5], sink, "pkg_path");
    kclm_wire_string_member(&w->kt.description, &w->ctx[6], sink, "description");
    kclm_wire_string_member(&w->kt.key, &w->ctx[7], sink, "key");
    w->kt.key.funcs.decode = kcl_decode_json_kcltype_member;
    kclm_wire_string_member(&w->kt.item, &w->ctx[8], sink, "item");
    w->kt.item.funcs.decode = kcl_decode_json_kcltype_member;
    kclm_wire_string_member(&w->kt.base_schema, &w->ctx[9], sink, "base_schema");
    w->kt.base_schema.funcs.decode = kcl_decode_json_kcltype_member;
    kclm_wire_string_member(&w->kt.required, &w->ctx[10], sink, "required");
    w->kt.required.funcs.decode = kclm_decode_json_string_array_member;
    w->ctx[11].sink = sink;
    w->ctx[11].name = "line";
    w->kt.line.funcs.decode = kclm_decode_json_int32_member;
    w->kt.line.arg = &w->ctx[11];
    w->ctx_union.sink = sink;
    w->ctx_union.name = "union_types";
    w->kt.union_types.funcs.decode = kclm_decode_json_kcltype_array_member;
    w->kt.union_types.arg = &w->ctx_union;
    w->ctx_properties.sink = sink;
    w->ctx_properties.name = "properties";
    w->ctx_properties.array_started = false;
    w->kt.properties.funcs.decode = kcl_decode_kcltype_properties_map_json;
    w->kt.properties.arg = &w->ctx_properties;
    w->ctx_decorators.sink = sink;
    w->ctx_decorators.name = "decorators";
    w->ctx_decorators.array_started = false;
    w->kt.decorators.funcs.decode = kclm_decode_decorator_array_member;
    w->kt.decorators.arg = &w->ctx_decorators;
    w->ctx_examples.sink = sink;
    w->ctx_examples.name = "examples";
    w->ctx_examples.array_started = false;
    w->kt.examples.funcs.decode = kcl_decode_example_map_json;
    w->kt.examples.arg = &w->ctx_examples;
    w->ctx_function.sink = sink;
    w->ctx_function.name = "function";
    w->ctx_function.array_started = false;
    w->kt.function.funcs.decode = kcl_decode_function_type_member;
    w->kt.function.arg = &w->ctx_function;
    w->ctx_index_signature.sink = sink;
    w->ctx_index_signature.name = "index_signature";
    w->ctx_index_signature.array_started = false;
    w->kt.index_signature.funcs.decode = kcl_decode_index_signature_member;
    w->kt.index_signature.arg = &w->ctx_index_signature;
}

static bool kclm_kcltype_to_json(pb_istream_t* stream, struct KclJsonSink* sink)
{
    struct KclKclTypeWire w;
    int depth = sink->depth;
    bool status;
    kclm_kcltype_wire_init(&w, sink);
    if (!kclm_sink_begin(sink, false))
        return false;
    status = pb_decode(stream, KclType_fields, &w.kt);
    if (status)
        status = kclm_sink_close_to(sink, depth);
    return status && kclm_sink_ok(sink);
}

bool kcl_decode_kcltype_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    return kclm_kcltype_to_json(stream, (struct KclJsonSink*)(*arg));
}

/* Single KclType member of an enclosing object (`"name": <KclType>`). */
static bool kcl_decode_json_kcltype_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonMemberCtx* ctx = (struct KclJsonMemberCtx*)(*arg);
    if (!kclm_sink_member(ctx->sink, ctx->name))
        return false;
    return kclm_kcltype_to_json(stream, ctx->sink);
}

/* ------------------------------------------------------------------ */
/* Index helpers (SymbolIndex / ScopeIndex)                            */
/* ------------------------------------------------------------------ */

static void kclm_symbol_index_wire(SymbolIndex* idx, struct KclJsonMemberCtx* ctx, struct KclJsonSink* sink)
{
    ctx->sink = sink;
    ctx->name = "kind";
    ctx->array_started = false;
    idx->kind.funcs.decode = kclm_decode_json_string_member;
    idx->kind.arg = ctx;
}

static void kclm_scope_index_wire(ScopeIndex* idx, struct KclJsonMemberCtx* ctx, struct KclJsonSink* sink)
{
    ctx->sink = sink;
    ctx->name = "kind";
    ctx->array_started = false;
    idx->kind.funcs.decode = kclm_decode_json_string_member;
    idx->kind.arg = ctx;
}

/* Render one SymbolIndex substream as a JSON object. */
static bool kclm_symbol_index_to_json(pb_istream_t* stream, struct KclJsonSink* sink)
{
    SymbolIndex idx = SymbolIndex_init_default;
    struct KclJsonMemberCtx ctx;
    int depth = sink->depth;
    bool status;
    kclm_symbol_index_wire(&idx, &ctx, sink);
    if (!kclm_sink_begin(sink, false))
        return false;
    status = pb_decode(stream, SymbolIndex_fields, &idx);
    if (status)
        status = kclm_sink_member(sink, "i") && kclm_sink_putf(sink, "%" PRIu64, idx.i);
    if (status)
        status = kclm_sink_member(sink, "g") && kclm_sink_putf(sink, "%" PRIu64, idx.g);
    if (status)
        status = kclm_sink_close_to(sink, depth);
    return status && kclm_sink_ok(sink);
}

/* Render one ScopeIndex substream as a JSON object. */
static bool kclm_scope_index_to_json(pb_istream_t* stream, struct KclJsonSink* sink)
{
    ScopeIndex idx = ScopeIndex_init_default;
    struct KclJsonMemberCtx ctx;
    int depth = sink->depth;
    bool status;
    kclm_scope_index_wire(&idx, &ctx, sink);
    if (!kclm_sink_begin(sink, false))
        return false;
    status = pb_decode(stream, ScopeIndex_fields, &idx);
    if (status)
        status = kclm_sink_member(sink, "i") && kclm_sink_putf(sink, "%" PRIu64, idx.i);
    if (status)
        status = kclm_sink_member(sink, "g") && kclm_sink_putf(sink, "%" PRIu64, idx.g);
    if (status)
        status = kclm_sink_close_to(sink, depth);
    return status && kclm_sink_ok(sink);
}

static bool kclm_decode_scope_index_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    return kclm_decode_json_element_array_member(stream, field, arg, kclm_scope_index_to_json);
}

static bool kclm_decode_symbol_index_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    return kclm_decode_json_element_array_member(stream, field, arg, kclm_symbol_index_to_json);
}

/* Finish an index-valued scratch object: emit the static i/g members
 * and close the object so it is a complete JSON value. */
static bool kclm_index_value_finish(struct KclJsonSink* value_scratch, uint64_t i, uint64_t g)
{
    bool status = kclm_sink_member(value_scratch, "i") && kclm_sink_putf(value_scratch, "%" PRIu64, i);
    if (status)
        status = kclm_sink_member(value_scratch, "g") && kclm_sink_putf(value_scratch, "%" PRIu64, g);
    if (status)
        status = kclm_sink_close_to(value_scratch, 0);
    if (status)
        status = kclm_sink_end(value_scratch);
    return status;
}

/* ------------------------------------------------------------------ */
/* LoadPackage map entries -> JSON                                     */
/* ------------------------------------------------------------------ */

bool kcl_decode_scope_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    LoadPackageResult_ScopesEntry entry = LoadPackageResult_ScopesEntry_init_default;
    struct KclJsonSink value_scratch;
    struct KclJsonSink parent_scratch;
    struct KclJsonSink owner_scratch;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    struct KclJsonMemberCtx ctx_kind = { NULL, "kind", false };
    struct KclJsonMemberCtx ctx_parent = { NULL, "kind", false };
    struct KclJsonMemberCtx ctx_owner = { NULL, "kind", false };
    struct KclJsonArrayCtx ctx_children = { NULL, "children", false };
    struct KclJsonArrayCtx ctx_defs = { NULL, "defs", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    bool status;

    if (!kclm_scratch_begin(&value_scratch, capacity)
        || !kclm_scratch_begin(&parent_scratch, capacity)
        || !kclm_scratch_begin(&owner_scratch, capacity)) {
        kclm_scratch_end(&value_scratch);
        kclm_scratch_end(&parent_scratch);
        kclm_scratch_end(&owner_scratch);
        return false;
    }

    ctx_kind.sink = &value_scratch;
    entry.value.kind.funcs.decode = kclm_decode_json_string_member;
    entry.value.kind.arg = &ctx_kind;
    kclm_scope_index_wire(&entry.value.parent, &ctx_parent, &parent_scratch);
    kclm_symbol_index_wire(&entry.value.owner, &ctx_owner, &owner_scratch);
    ctx_children.sink = &value_scratch;
    ctx_defs.sink = &value_scratch;
    entry.value.children.funcs.decode = kclm_decode_scope_index_array_member;
    entry.value.children.arg = &ctx_children;
    entry.value.defs.funcs.decode = kclm_decode_symbol_index_array_member;
    entry.value.defs.arg = &ctx_defs;

    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;

    /* parent_scratch and owner_scratch back static submessage members,
     * so they are opened here like value_scratch: their `kind` member
     * callback fires while the entry decodes, and kclm_index_value_finish
     * appends the i/g members and closes them before the splice. */
    if (!kclm_sink_list_entry_begin(sink)
        || !kclm_sink_begin(sink, false)
        || !kclm_sink_begin(&value_scratch, false)
        || !kclm_sink_begin(&parent_scratch, false)
        || !kclm_sink_begin(&owner_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, LoadPackageResult_ScopesEntry_fields, &entry);
        if (status && entry.value.has_parent)
            status = kclm_index_value_finish(&parent_scratch, entry.value.parent.i, entry.value.parent.g);
        if (status && entry.value.has_owner)
            status = kclm_index_value_finish(&owner_scratch, entry.value.owner.i, entry.value.owner.g);
        if (status && entry.value.has_parent)
            status = kclm_sink_member_raw(&value_scratch, "parent", parent_scratch.buffer, false);
        if (status && entry.value.has_owner)
            status = kclm_sink_member_raw(&value_scratch, "owner", owner_scratch.buffer, false);
        if (status)
            status = kclm_sink_close_to(&value_scratch, 0);
        if (status)
            status = kclm_sink_end(&value_scratch);
        if (status)
            status = kclm_sink_member_raw(sink, "value", value_scratch.buffer, false);
        if (status)
            status = kclm_sink_end(sink);
    }

    status = status && kclm_sink_ok(&value_scratch) && kclm_sink_ok(&parent_scratch) && kclm_sink_ok(&owner_scratch);
    kclm_scratch_end(&value_scratch);
    kclm_scratch_end(&parent_scratch);
    kclm_scratch_end(&owner_scratch);
    return status && kclm_sink_ok(sink);
}

bool kcl_decode_symbol_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    LoadPackageResult_SymbolsEntry entry = LoadPackageResult_SymbolsEntry_init_default;
    struct KclKclTypeWire ty_wire;
    struct KclJsonSink value_scratch;
    struct KclJsonSink ty_scratch;
    struct KclJsonSink owner_scratch;
    struct KclJsonSink def_scratch;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    struct KclJsonMemberCtx ctx_name = { NULL, "name", false };
    struct KclJsonMemberCtx ctx_owner = { NULL, "kind", false };
    struct KclJsonMemberCtx ctx_def = { NULL, "kind", false };
    struct KclJsonArrayCtx ctx_attrs = { NULL, "attrs", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    bool status;

    if (!kclm_scratch_begin(&value_scratch, capacity)
        || !kclm_scratch_begin(&ty_scratch, capacity)
        || !kclm_scratch_begin(&owner_scratch, capacity)
        || !kclm_scratch_begin(&def_scratch, capacity)) {
        kclm_scratch_end(&value_scratch);
        kclm_scratch_end(&ty_scratch);
        kclm_scratch_end(&owner_scratch);
        kclm_scratch_end(&def_scratch);
        return false;
    }

    ctx_name.sink = &value_scratch;
    entry.value.name.funcs.decode = kclm_decode_json_string_member;
    entry.value.name.arg = &ctx_name;
    kclm_kcltype_wire_init(&ty_wire, &ty_scratch);
    entry.value.ty = ty_wire.kt;
    kclm_symbol_index_wire(&entry.value.owner, &ctx_owner, &owner_scratch);
    kclm_symbol_index_wire(&entry.value.def, &ctx_def, &def_scratch);
    ctx_attrs.sink = &value_scratch;
    entry.value.attrs.funcs.decode = kclm_decode_symbol_index_array_member;
    entry.value.attrs.arg = &ctx_attrs;

    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;

    /* owner_scratch and def_scratch back static submessage members; see
     * kcl_decode_scope_map_json for why they are opened and finished
     * around the entry decode. */
    if (!kclm_sink_list_entry_begin(sink)
        || !kclm_sink_begin(sink, false)
        || !kclm_sink_begin(&value_scratch, false)
        || !kclm_sink_begin(&ty_scratch, false)
        || !kclm_sink_begin(&owner_scratch, false)
        || !kclm_sink_begin(&def_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, LoadPackageResult_SymbolsEntry_fields, &entry);
        if (status)
            status = kclm_sink_close_to(&ty_scratch, 0) && kclm_sink_end(&ty_scratch);
        if (status && entry.value.has_ty)
            status = kclm_sink_member_raw(&value_scratch, "ty", ty_scratch.buffer, false);
        if (status && entry.value.has_owner)
            status = kclm_index_value_finish(&owner_scratch, entry.value.owner.i, entry.value.owner.g);
        if (status && entry.value.has_def)
            status = kclm_index_value_finish(&def_scratch, entry.value.def.i, entry.value.def.g);
        if (status && entry.value.has_owner)
            status = kclm_sink_member_raw(&value_scratch, "owner", owner_scratch.buffer, false);
        if (status && entry.value.has_def)
            status = kclm_sink_member_raw(&value_scratch, "def", def_scratch.buffer, false);
        if (status && entry.value.is_global)
            status = kclm_sink_member(&value_scratch, "is_global") && kclm_sink_puts(&value_scratch, "true");
        if (status)
            status = kclm_sink_close_to(&value_scratch, 0);
        if (status)
            status = kclm_sink_end(&value_scratch);
        if (status)
            status = kclm_sink_member_raw(sink, "value", value_scratch.buffer, false);
        if (status)
            status = kclm_sink_end(sink);
    }

    status = status && kclm_sink_ok(&value_scratch) && kclm_sink_ok(&ty_scratch) && kclm_sink_ok(&owner_scratch) && kclm_sink_ok(&def_scratch);
    kclm_scratch_end(&value_scratch);
    kclm_scratch_end(&ty_scratch);
    kclm_scratch_end(&owner_scratch);
    kclm_scratch_end(&def_scratch);
    return status && kclm_sink_ok(sink);
}

/* ------------------------------------------------------------------ */
/* Index-valued map entries -> JSON                                    */
/* ------------------------------------------------------------------ */

bool kcl_decode_symbol_index_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    LoadPackageResult_NodeSymbolMapEntry entry = LoadPackageResult_NodeSymbolMapEntry_init_default;
    struct KclJsonSink value_scratch;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    struct KclJsonMemberCtx ctx_kind = { NULL, "kind", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    bool status;

    if (!kclm_scratch_begin(&value_scratch, capacity))
        return false;

    ctx_kind.sink = &value_scratch;
    kclm_symbol_index_wire(&entry.value, &ctx_kind, &value_scratch);
    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;

    if (!kclm_sink_list_entry_begin(sink)
        || !kclm_sink_begin(sink, false)
        || !kclm_sink_begin(&value_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, LoadPackageResult_NodeSymbolMapEntry_fields, &entry);
        if (status)
            status = kclm_index_value_finish(&value_scratch, entry.value.i, entry.value.g);
        if (status)
            status = kclm_sink_member_raw(sink, "value", value_scratch.buffer, false);
        if (status)
            status = kclm_sink_end(sink);
    }

    status = status && kclm_sink_ok(&value_scratch);
    kclm_scratch_end(&value_scratch);
    return status && kclm_sink_ok(sink);
}

bool kcl_decode_fully_qualified_name_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    LoadPackageResult_FullyQualifiedNameMapEntry entry = LoadPackageResult_FullyQualifiedNameMapEntry_init_default;
    struct KclJsonSink value_scratch;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    struct KclJsonMemberCtx ctx_kind = { NULL, "kind", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    bool status;

    if (!kclm_scratch_begin(&value_scratch, capacity))
        return false;

    ctx_kind.sink = &value_scratch;
    kclm_symbol_index_wire(&entry.value, &ctx_kind, &value_scratch);
    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;

    if (!kclm_sink_list_entry_begin(sink)
        || !kclm_sink_begin(sink, false)
        || !kclm_sink_begin(&value_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, LoadPackageResult_FullyQualifiedNameMapEntry_fields, &entry);
        if (status)
            status = kclm_index_value_finish(&value_scratch, entry.value.i, entry.value.g);
        if (status)
            status = kclm_sink_member_raw(sink, "value", value_scratch.buffer, false);
        if (status)
            status = kclm_sink_end(sink);
    }

    status = status && kclm_sink_ok(&value_scratch);
    kclm_scratch_end(&value_scratch);
    return status && kclm_sink_ok(sink);
}

bool kcl_decode_scope_index_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    LoadPackageResult_PkgScopeMapEntry entry = LoadPackageResult_PkgScopeMapEntry_init_default;
    struct KclJsonSink value_scratch;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    struct KclJsonMemberCtx ctx_kind = { NULL, "kind", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    bool status;

    if (!kclm_scratch_begin(&value_scratch, capacity))
        return false;

    ctx_kind.sink = &value_scratch;
    kclm_scope_index_wire(&entry.value, &ctx_kind, &value_scratch);
    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;

    if (!kclm_sink_list_entry_begin(sink)
        || !kclm_sink_begin(sink, false)
        || !kclm_sink_begin(&value_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, LoadPackageResult_PkgScopeMapEntry_fields, &entry);
        if (status)
            status = kclm_index_value_finish(&value_scratch, entry.value.i, entry.value.g);
        if (status)
            status = kclm_sink_member_raw(sink, "value", value_scratch.buffer, false);
        if (status)
            status = kclm_sink_end(sink);
    }

    status = status && kclm_sink_ok(&value_scratch);
    kclm_scratch_end(&value_scratch);
    return status && kclm_sink_ok(sink);
}

/* ------------------------------------------------------------------ */
/* String-valued map entries -> JSON                                   */
/* ------------------------------------------------------------------ */

bool kcl_decode_string_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    LoadPackageResult_SymbolNodeMapEntry entry = LoadPackageResult_SymbolNodeMapEntry_init_default;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    struct KclJsonMemberCtx ctx_value = { sink, "value", false };
    bool status;

    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;
    entry.value.funcs.decode = kclm_decode_json_string_member;
    entry.value.arg = &ctx_value;

    if (!kclm_sink_list_entry_begin(sink) || !kclm_sink_begin(sink, false))
        return false;
    status = pb_decode(stream, LoadPackageResult_SymbolNodeMapEntry_fields, &entry);
    if (status)
        status = kclm_sink_end(sink);
    return status && kclm_sink_ok(sink);
}

bool kcl_decode_string_string_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    RenameCodeResult_ChangedCodesEntry entry = RenameCodeResult_ChangedCodesEntry_init_default;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    struct KclJsonMemberCtx ctx_value = { sink, "value", false };
    bool status;

    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;
    entry.value.funcs.decode = kclm_decode_json_string_member;
    entry.value.arg = &ctx_value;

    if (!kclm_sink_list_entry_begin(sink) || !kclm_sink_begin(sink, false))
        return false;
    status = pb_decode(stream, RenameCodeResult_ChangedCodesEntry_fields, &entry);
    if (status)
        status = kclm_sink_end(sink);
    return status && kclm_sink_ok(sink);
}

/* ------------------------------------------------------------------ */
/* Schema type mapping entries -> JSON                                 */
/* ------------------------------------------------------------------ */

bool kcl_decode_kcltype_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    /* One map entry: { "key": name, "value": <KclType> } */
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    GetSchemaTypeMappingResult_SchemaTypeMappingEntry entry = GetSchemaTypeMappingResult_SchemaTypeMappingEntry_init_default;
    struct KclKclTypeWire w;
    struct KclJsonSink value_scratch;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    bool status;

    if (!kclm_scratch_begin(&value_scratch, capacity))
        return false;

    kclm_kcltype_wire_init(&w, &value_scratch);
    entry.value = w.kt;
    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;

    if (!kclm_sink_list_entry_begin(sink)
        || !kclm_sink_begin(sink, false)
        || !kclm_sink_begin(&value_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, GetSchemaTypeMappingResult_SchemaTypeMappingEntry_fields, &entry);
        if (status)
            status = kclm_sink_close_to(&value_scratch, 0);
        if (status)
            status = kclm_sink_end(&value_scratch);
        if (status)
            status = kclm_sink_member_raw(sink, "value", value_scratch.buffer, false);
        if (status)
            status = kclm_sink_end(sink);
    }

    status = status && kclm_sink_ok(&value_scratch);
    kclm_scratch_end(&value_scratch);
    return status && kclm_sink_ok(sink);
}

bool kcl_decode_schema_types_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    /* One map entry: { "key": pkg, "value": { "schema_type": [<KclType>] } } */
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    GetSchemaTypeMappingUnderPathResult_SchemaTypeMappingEntry entry = GetSchemaTypeMappingUnderPathResult_SchemaTypeMappingEntry_init_default;
    struct KclJsonSink value_scratch;
    struct KclJsonSink types_scratch;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    bool status;

    if (!kclm_scratch_begin(&value_scratch, capacity) || !kclm_scratch_begin(&types_scratch, capacity)) {
        kclm_scratch_end(&value_scratch);
        kclm_scratch_end(&types_scratch);
        return false;
    }

    entry.value.schema_type.funcs.decode = kcl_decode_kcltype_json;
    entry.value.schema_type.arg = &types_scratch;
    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;

    if (!kclm_sink_list_entry_begin(sink)
        || !kclm_sink_begin(sink, false)
        || !kclm_sink_begin(&value_scratch, false)
        || !kclm_sink_begin(&types_scratch, true)) {
        status = false;
    } else {
        status = pb_decode(stream, GetSchemaTypeMappingUnderPathResult_SchemaTypeMappingEntry_fields, &entry);
        if (status)
            status = kclm_sink_close_to(&types_scratch, 0);
        if (status)
            status = kclm_sink_end(&types_scratch);
        if (status)
            status = kclm_sink_member_raw(&value_scratch, "schema_type", types_scratch.buffer, false);
        if (status)
            status = kclm_sink_close_to(&value_scratch, 0);
        if (status)
            status = kclm_sink_end(&value_scratch);
        if (status)
            status = kclm_sink_member_raw(sink, "value", value_scratch.buffer, false);
        if (status)
            status = kclm_sink_end(sink);
    }

    status = status && kclm_sink_ok(&value_scratch) && kclm_sink_ok(&types_scratch);
    kclm_scratch_end(&value_scratch);
    kclm_scratch_end(&types_scratch);
    return status && kclm_sink_ok(sink);
}

/* ------------------------------------------------------------------ */
/* KclType nested members                                              */
/* ------------------------------------------------------------------ */

bool kcl_decode_kcltype_properties_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonArrayCtx* ctx = (struct KclJsonArrayCtx*)(*arg);
    struct KclJsonSink* sink = ctx->sink;
    KclType_PropertiesEntry entry = KclType_PropertiesEntry_init_default;
    struct KclKclTypeWire w;
    struct KclJsonSink value_scratch;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    int depth;
    bool status;

    if (!kclm_scratch_begin(&value_scratch, capacity))
        return false;

    if (!ctx->array_started) {
        if (!kclm_sink_member(sink, ctx->name) || !kclm_sink_begin(sink, true)) {
            kclm_scratch_end(&value_scratch);
            return false;
        }
        ctx->array_started = true;
    }
    depth = sink->depth;

    kclm_kcltype_wire_init(&w, &value_scratch);
    entry.value = w.kt;
    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;

    if (!kclm_sink_begin(sink, false) || !kclm_sink_begin(&value_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, KclType_PropertiesEntry_fields, &entry);
        if (status)
            status = kclm_sink_close_to(&value_scratch, 0);
        if (status)
            status = kclm_sink_end(&value_scratch);
        if (status)
            status = kclm_sink_member_raw(sink, "value", value_scratch.buffer, false);
        if (status)
            status = kclm_sink_close_to(sink, depth);
    }

    status = status && kclm_sink_ok(&value_scratch);
    kclm_scratch_end(&value_scratch);
    return status && kclm_sink_ok(sink);
}

static bool kclm_keyword_entry_to_json(pb_istream_t* stream, struct KclJsonSink* sink)
{
    Decorator_KeywordsEntry entry = Decorator_KeywordsEntry_init_default;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    struct KclJsonMemberCtx ctx_value = { sink, "value", false };
    int depth = sink->depth;
    bool status;

    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;
    entry.value.funcs.decode = kclm_decode_json_string_member;
    entry.value.arg = &ctx_value;

    if (!kclm_sink_begin(sink, false))
        return false;
    status = pb_decode(stream, Decorator_KeywordsEntry_fields, &entry);
    if (status)
        status = kclm_sink_close_to(sink, depth);
    return status && kclm_sink_ok(sink);
}

static bool kclm_decode_keyword_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    return kclm_decode_json_element_array_member(stream, field, arg, kclm_keyword_entry_to_json);
}

static bool kclm_decorator_to_json(pb_istream_t* stream, struct KclJsonSink* sink)
{
    Decorator decorator = Decorator_init_default;
    struct KclJsonMemberCtx ctx_name = { sink, "name", false };
    struct KclJsonMemberCtx ctx_args = { sink, "arguments", false };
    struct KclJsonArrayCtx ctx_keywords = { sink, "keywords", false };
    int depth = sink->depth;
    bool status;

    kclm_wire_string_member(&decorator.name, &ctx_name, sink, "name");
    kclm_wire_string_member(&decorator.arguments, &ctx_args, sink, "arguments");
    decorator.keywords.funcs.decode = kclm_decode_keyword_array_member;
    decorator.keywords.arg = &ctx_keywords;

    if (!kclm_sink_begin(sink, false))
        return false;
    status = pb_decode(stream, Decorator_fields, &decorator);
    if (status)
        status = kclm_sink_close_to(sink, depth);
    return status && kclm_sink_ok(sink);
}

bool kcl_decode_decorator_list_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    return kclm_decorator_to_json(stream, sink);
}

static bool kclm_decode_decorator_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    return kclm_decode_json_element_array_member(stream, field, arg, kclm_decorator_to_json);
}

bool kcl_decode_example_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonArrayCtx* ctx = (struct KclJsonArrayCtx*)(*arg);
    struct KclJsonSink* sink = ctx->sink;
    KclType_ExamplesEntry entry = KclType_ExamplesEntry_init_default;
    struct KclJsonSink value_scratch;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    struct KclJsonMemberCtx ctx_summary = { NULL, "summary", false };
    struct KclJsonMemberCtx ctx_description = { NULL, "description", false };
    struct KclJsonMemberCtx ctx_value = { NULL, "value", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    int depth;
    bool status;

    if (!kclm_scratch_begin(&value_scratch, capacity))
        return false;

    if (!ctx->array_started) {
        if (!kclm_sink_member(sink, ctx->name) || !kclm_sink_begin(sink, true)) {
            kclm_scratch_end(&value_scratch);
            return false;
        }
        ctx->array_started = true;
    }
    depth = sink->depth;

    ctx_summary.sink = &value_scratch;
    entry.value.summary.funcs.decode = kclm_decode_json_string_member;
    entry.value.summary.arg = &ctx_summary;
    ctx_description.sink = &value_scratch;
    entry.value.description.funcs.decode = kclm_decode_json_string_member;
    entry.value.description.arg = &ctx_description;
    ctx_value.sink = &value_scratch;
    entry.value.value.funcs.decode = kclm_decode_json_string_member;
    entry.value.value.arg = &ctx_value;
    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;

    if (!kclm_sink_begin(sink, false) || !kclm_sink_begin(&value_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, KclType_ExamplesEntry_fields, &entry);
        if (status)
            status = kclm_sink_close_to(&value_scratch, 0);
        if (status)
            status = kclm_sink_end(&value_scratch);
        if (status)
            status = kclm_sink_member_raw(sink, "value", value_scratch.buffer, false);
        if (status)
            status = kclm_sink_close_to(sink, depth);
    }

    status = status && kclm_sink_ok(&value_scratch);
    kclm_scratch_end(&value_scratch);
    return status && kclm_sink_ok(sink);
}

/* FunctionType / Parameter */

static bool kclm_parameter_to_json(pb_istream_t* stream, struct KclJsonSink* sink)
{
    Parameter param = Parameter_init_default;
    struct KclKclTypeWire w;
    struct KclJsonSink ty_scratch;
    struct KclJsonMemberCtx ctx_name = { sink, "name", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    int depth = sink->depth;
    bool status;

    if (!kclm_scratch_begin(&ty_scratch, capacity))
        return false;

    kclm_kcltype_wire_init(&w, &ty_scratch);
    param.ty = w.kt;
    param.name.funcs.decode = kclm_decode_json_string_member;
    param.name.arg = &ctx_name;

    if (!kclm_sink_begin(sink, false) || !kclm_sink_begin(&ty_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, Parameter_fields, &param);
        if (status)
            status = kclm_sink_close_to(&ty_scratch, 0);
        if (status)
            status = kclm_sink_end(&ty_scratch);
        if (status && param.has_ty)
            status = kclm_sink_member_raw(sink, "ty", ty_scratch.buffer, false);
        if (status)
            status = kclm_sink_close_to(sink, depth);
    }

    status = status && kclm_sink_ok(&ty_scratch);
    kclm_scratch_end(&ty_scratch);
    return status && kclm_sink_ok(sink);
}

static bool kclm_decode_parameter_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    return kclm_decode_json_element_array_member(stream, field, arg, kclm_parameter_to_json);
}

bool kcl_decode_parameter_list_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    return kclm_parameter_to_json(stream, (struct KclJsonSink*)(*arg));
}

bool kcl_decode_function_type_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    FunctionType ft = FunctionType_init_default;
    struct KclKclTypeWire w;
    struct KclJsonSink return_scratch;
    struct KclJsonArrayCtx ctx_params = { sink, "params", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    int depth = sink->depth;
    bool status;

    if (!kclm_scratch_begin(&return_scratch, capacity))
        return false;

    kclm_kcltype_wire_init(&w, &return_scratch);
    ft.return_ty = w.kt;
    ft.params.funcs.decode = kclm_decode_parameter_array_member;
    ft.params.arg = &ctx_params;

    if (!kclm_sink_begin(sink, false) || !kclm_sink_begin(&return_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, FunctionType_fields, &ft);
        if (status)
            status = kclm_sink_close_to(&return_scratch, 0);
        if (status)
            status = kclm_sink_end(&return_scratch);
        if (status && ft.has_return_ty)
            status = kclm_sink_member_raw(sink, "return_ty", return_scratch.buffer, false);
        if (status)
            status = kclm_sink_close_to(sink, depth);
    }

    status = status && kclm_sink_ok(&return_scratch);
    kclm_scratch_end(&return_scratch);
    return status && kclm_sink_ok(sink);
}

static bool kcl_decode_function_type_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonMemberCtx* ctx = (struct KclJsonMemberCtx*)(*arg);
    void* sink_arg = (void*)ctx->sink;
    if (!kclm_sink_member(ctx->sink, ctx->name))
        return false;
    return kcl_decode_function_type_json(stream, field, &sink_arg);
}

bool kcl_decode_index_signature_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    IndexSignature sig = IndexSignature_init_default;
    struct KclKclTypeWire key_wire;
    struct KclKclTypeWire val_wire;
    struct KclJsonSink key_scratch;
    struct KclJsonSink val_scratch;
    struct KclJsonMemberCtx ctx_key_name = { sink, "key_name", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    int depth = sink->depth;
    bool status;

    if (!kclm_scratch_begin(&key_scratch, capacity) || !kclm_scratch_begin(&val_scratch, capacity)) {
        kclm_scratch_end(&key_scratch);
        kclm_scratch_end(&val_scratch);
        return false;
    }

    kclm_kcltype_wire_init(&key_wire, &key_scratch);
    sig.key = key_wire.kt;
    kclm_kcltype_wire_init(&val_wire, &val_scratch);
    sig.val = val_wire.kt;
    sig.key_name.funcs.decode = kclm_decode_json_string_member;
    sig.key_name.arg = &ctx_key_name;

    if (!kclm_sink_begin(sink, false)
        || !kclm_sink_begin(&key_scratch, false)
        || !kclm_sink_begin(&val_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, IndexSignature_fields, &sig);
        if (status)
            status = kclm_sink_close_to(&key_scratch, 0);
        if (status)
            status = kclm_sink_end(&key_scratch);
        if (status)
            status = kclm_sink_close_to(&val_scratch, 0);
        if (status)
            status = kclm_sink_end(&val_scratch);
        if (status && sig.has_key)
            status = kclm_sink_member_raw(sink, "key", key_scratch.buffer, false);
        if (status && sig.has_val)
            status = kclm_sink_member_raw(sink, "val", val_scratch.buffer, false);
        if (status && sig.any_other)
            status = kclm_sink_member(sink, "any_other") && kclm_sink_puts(sink, "true");
        if (status)
            status = kclm_sink_close_to(sink, depth);
    }

    status = status && kclm_sink_ok(&key_scratch) && kclm_sink_ok(&val_scratch);
    kclm_scratch_end(&key_scratch);
    kclm_scratch_end(&val_scratch);
    return status && kclm_sink_ok(sink);
}

static bool kcl_decode_index_signature_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonMemberCtx* ctx = (struct KclJsonMemberCtx*)(*arg);
    void* sink_arg = (void*)ctx->sink;
    if (!kclm_sink_member(ctx->sink, ctx->name))
        return false;
    return kcl_decode_index_signature_json(stream, field, &sink_arg);
}

/* ------------------------------------------------------------------ */
/* Error -> JSON                                                       */
/* ------------------------------------------------------------------ */

static bool kclm_message_to_json(pb_istream_t* stream, struct KclJsonSink* sink)
{
    Message msg = Message_init_default;
    struct KclJsonSink pos_scratch;
    struct KclJsonMemberCtx ctx_msg = { sink, "msg", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    int depth = sink->depth;
    bool status;

    if (!kclm_scratch_begin(&pos_scratch, capacity))
        return false;

    ctx_msg.sink = sink;
    msg.msg.funcs.decode = kclm_decode_json_string_member;
    msg.msg.arg = &ctx_msg;
    {
        struct KclJsonMemberCtx ctx_filename = { &pos_scratch, "filename", false };
        msg.pos.filename.funcs.decode = kclm_decode_json_string_member;
        msg.pos.filename.arg = &ctx_filename;
    }

    if (!kclm_sink_begin(sink, false)) {
        status = false;
    } else {
        status = pb_decode(stream, Message_fields, &msg);
        if (status && msg.has_pos) {
            status = kclm_sink_member(sink, "pos")
                && kclm_sink_begin(sink, false)
                && kclm_sink_member(sink, "line")
                && kclm_sink_putf(sink, "%" PRId64, msg.pos.line)
                && kclm_sink_member(sink, "column")
                && kclm_sink_putf(sink, "%" PRId64, msg.pos.column);
            if (status && pos_scratch.length > 0)
                status = kclm_sink_member(sink, "filename") && kclm_sink_puts(sink, pos_scratch.buffer);
            if (status)
                status = kclm_sink_end(sink);
        }
        if (status)
            status = kclm_sink_close_to(sink, depth);
    }

    status = status && kclm_sink_ok(&pos_scratch);
    kclm_scratch_end(&pos_scratch);
    return status && kclm_sink_ok(sink);
}

static bool kcl_decode_message_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    return kclm_decode_json_element_array_member(stream, field, arg, kclm_message_to_json);
}

static bool kclm_error_to_json(pb_istream_t* stream, struct KclJsonSink* sink)
{
    Error error = Error_init_default;
    struct KclJsonMemberCtx ctx_level = { sink, "level", false };
    struct KclJsonMemberCtx ctx_code = { sink, "code", false };
    struct KclJsonArrayCtx ctx_messages = { sink, "messages", false };
    int depth = sink->depth;
    bool status;

    kclm_wire_string_member(&error.level, &ctx_level, sink, "level");
    kclm_wire_string_member(&error.code, &ctx_code, sink, "code");
    error.messages.funcs.decode = kcl_decode_message_array_member;
    error.messages.arg = &ctx_messages;

    if (!kclm_sink_begin(sink, false))
        return false;
    status = pb_decode(stream, Error_fields, &error);
    if (status)
        status = kclm_sink_close_to(sink, depth);
    return status && kclm_sink_ok(sink);
}

bool kcl_decode_error_list_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    if (!kclm_sink_list_entry_begin(sink))
        return false;
    return kclm_error_to_json(stream, sink);
}

/* ------------------------------------------------------------------ */
/* Variable -> JSON (recursive)                                        */
/* ------------------------------------------------------------------ */

static bool kclm_variable_to_json(pb_istream_t* stream, struct KclJsonSink* sink);

static void kclm_variable_wire(Variable* v, struct KclJsonSink* sink,
    struct KclJsonMemberCtx* ctx_value, struct KclJsonMemberCtx* ctx_type_name,
    struct KclJsonMemberCtx* ctx_op_sym, struct KclJsonArrayCtx* ctx_items,
    struct KclJsonArrayCtx* ctx_entries);

static bool kclm_map_entry_to_json(pb_istream_t* stream, struct KclJsonSink* sink)
{
    MapEntry entry = MapEntry_init_default;
    struct KclJsonSink value_scratch;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    struct KclJsonMemberCtx ctx_value = { NULL, "value", false };
    struct KclJsonMemberCtx ctx_type_name = { NULL, "type_name", false };
    struct KclJsonMemberCtx ctx_op_sym = { NULL, "op_sym", false };
    struct KclJsonArrayCtx ctx_items = { NULL, "list_items", false };
    struct KclJsonArrayCtx ctx_entries = { NULL, "dict_entries", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    int depth = sink->depth;
    bool status;

    if (!kclm_scratch_begin(&value_scratch, capacity))
        return false;

    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;
    kclm_variable_wire(&entry.value, &value_scratch,
        &ctx_value, &ctx_type_name, &ctx_op_sym, &ctx_items, &ctx_entries);

    if (!kclm_sink_begin(sink, false) || !kclm_sink_begin(&value_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, MapEntry_fields, &entry);
        if (status)
            status = kclm_sink_close_to(&value_scratch, 0);
        if (status)
            status = kclm_sink_end(&value_scratch);
        if (status && entry.has_value)
            status = kclm_sink_member_raw(sink, "value", value_scratch.buffer, false);
        if (status)
            status = kclm_sink_close_to(sink, depth);
    }

    status = status && kclm_sink_ok(&value_scratch);
    kclm_scratch_end(&value_scratch);
    return status && kclm_sink_ok(sink);
}

static bool kclm_decode_variable_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    return kclm_decode_json_element_array_member(stream, field, arg, kclm_variable_to_json);
}

static bool kclm_decode_map_entry_array_member(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    return kclm_decode_json_element_array_member(stream, field, arg, kclm_map_entry_to_json);
}

static void kclm_variable_wire(Variable* v, struct KclJsonSink* sink,
    struct KclJsonMemberCtx* ctx_value, struct KclJsonMemberCtx* ctx_type_name,
    struct KclJsonMemberCtx* ctx_op_sym, struct KclJsonArrayCtx* ctx_items,
    struct KclJsonArrayCtx* ctx_entries)
{
    kclm_wire_string_member(&v->value, ctx_value, sink, "value");
    kclm_wire_string_member(&v->type_name, ctx_type_name, sink, "type_name");
    kclm_wire_string_member(&v->op_sym, ctx_op_sym, sink, "op_sym");
    ctx_items->sink = sink;
    ctx_items->name = "list_items";
    ctx_items->array_started = false;
    v->list_items.funcs.decode = kclm_decode_variable_array_member;
    v->list_items.arg = ctx_items;
    ctx_entries->sink = sink;
    ctx_entries->name = "dict_entries";
    ctx_entries->array_started = false;
    v->dict_entries.funcs.decode = kclm_decode_map_entry_array_member;
    v->dict_entries.arg = ctx_entries;
}

static bool kclm_variable_to_json(pb_istream_t* stream, struct KclJsonSink* sink)
{
    Variable variable = Variable_init_default;
    struct KclJsonMemberCtx ctx_value = { sink, "value", false };
    struct KclJsonMemberCtx ctx_type_name = { sink, "type_name", false };
    struct KclJsonMemberCtx ctx_op_sym = { sink, "op_sym", false };
    struct KclJsonArrayCtx ctx_items = { sink, "list_items", false };
    struct KclJsonArrayCtx ctx_entries = { sink, "dict_entries", false };
    int depth = sink->depth;
    bool status;

    kclm_variable_wire(&variable, sink, &ctx_value, &ctx_type_name, &ctx_op_sym, &ctx_items, &ctx_entries);

    if (!kclm_sink_begin(sink, false))
        return false;
    status = pb_decode(stream, Variable_fields, &variable);
    if (status)
        status = kclm_sink_close_to(sink, depth);
    return status && kclm_sink_ok(sink);
}

/* ListVariables map entry: { "key": file, "value": { "variables": [...] } } */
bool kcl_decode_variable_map_json(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclJsonSink* sink = (struct KclJsonSink*)(*arg);
    ListVariablesResult_VariablesEntry entry = ListVariablesResult_VariablesEntry_init_default;
    struct KclJsonSink value_scratch;
    struct KclJsonMemberCtx ctx_key = { sink, "key", false };
    struct KclJsonArrayCtx ctx_variables = { NULL, "variables", false };
    size_t capacity = stream->bytes_left * 8 + 4096;
    bool status;

    if (!kclm_scratch_begin(&value_scratch, capacity))
        return false;

    ctx_variables.sink = &value_scratch;
    entry.value.variables.funcs.decode = kclm_decode_variable_array_member;
    entry.value.variables.arg = &ctx_variables;
    entry.key.funcs.decode = kclm_decode_json_string_member;
    entry.key.arg = &ctx_key;

    if (!kclm_sink_list_entry_begin(sink)
        || !kclm_sink_begin(sink, false)
        || !kclm_sink_begin(&value_scratch, false)) {
        status = false;
    } else {
        status = pb_decode(stream, ListVariablesResult_VariablesEntry_fields, &entry);
        if (status)
            status = kclm_sink_close_to(&value_scratch, 0);
        if (status)
            status = kclm_sink_end(&value_scratch);
        if (status)
            status = kclm_sink_member_raw(sink, "value", value_scratch.buffer, false);
        if (status)
            status = kclm_sink_end(sink);
    }

    status = status && kclm_sink_ok(&value_scratch);
    kclm_scratch_end(&value_scratch);
    return status && kclm_sink_ok(sink);
}

/* ------------------------------------------------------------------ */
/* Collectors: repeated message -> array of plain structs              */
/* ------------------------------------------------------------------ */

bool kcl_decode_option_help_list(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclOptionHelpCollector* coll = (struct KclOptionHelpCollector*)(*arg);
    OptionHelp oh = OptionHelp_init_default;
    struct KclStringSlot slots[4];
    if (coll->count >= coll->max_count)
        return false;
    slots[0].buffer = coll->items[coll->count].name;
    slots[0].size = sizeof(coll->items[coll->count].name);
    slots[1].buffer = coll->items[coll->count].type;
    slots[1].size = sizeof(coll->items[coll->count].type);
    slots[2].buffer = coll->items[coll->count].default_value;
    slots[2].size = sizeof(coll->items[coll->count].default_value);
    slots[3].buffer = coll->items[coll->count].help;
    slots[3].size = sizeof(coll->items[coll->count].help);
    oh.name.funcs.decode = kcl_decode_copy_string;
    oh.name.arg = &slots[0];
    oh.type.funcs.decode = kcl_decode_copy_string;
    oh.type.arg = &slots[1];
    oh.default_value.funcs.decode = kcl_decode_copy_string;
    oh.default_value.arg = &slots[2];
    oh.help.funcs.decode = kcl_decode_copy_string;
    oh.help.arg = &slots[3];
    if (!pb_decode(stream, OptionHelp_fields, &oh))
        return false;
    coll->items[coll->count].required = oh.required;
    coll->count++;
    return true;
}

bool kcl_decode_test_case_info_list(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclTestCaseCollector* coll = (struct KclTestCaseCollector*)(*arg);
    TestCaseInfo info = TestCaseInfo_init_default;
    struct KclStringSlot slots[3];
    if (coll->count >= coll->max_count)
        return false;
    slots[0].buffer = coll->items[coll->count].name;
    slots[0].size = sizeof(coll->items[coll->count].name);
    slots[1].buffer = coll->items[coll->count].error;
    slots[1].size = sizeof(coll->items[coll->count].error);
    slots[2].buffer = coll->items[coll->count].log_message;
    slots[2].size = sizeof(coll->items[coll->count].log_message);
    info.name.funcs.decode = kcl_decode_copy_string;
    info.name.arg = &slots[0];
    info.error.funcs.decode = kcl_decode_copy_string;
    info.error.arg = &slots[1];
    info.log_message.funcs.decode = kcl_decode_copy_string;
    info.log_message.arg = &slots[2];
    if (!pb_decode(stream, TestCaseInfo_fields, &info))
        return false;
    coll->items[coll->count].duration = info.duration;
    coll->count++;
    return true;
}

bool kcl_decode_external_pkg_list(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclExternalPkgCollector* coll = (struct KclExternalPkgCollector*)(*arg);
    ExternalPkg pkg = ExternalPkg_init_default;
    struct KclStringSlot slots[2];
    if (coll->count >= coll->max_count)
        return false;
    slots[0].buffer = coll->items[coll->count].pkg_name;
    slots[0].size = sizeof(coll->items[coll->count].pkg_name);
    slots[1].buffer = coll->items[coll->count].pkg_path;
    slots[1].size = sizeof(coll->items[coll->count].pkg_path);
    pkg.pkg_name.funcs.decode = kcl_decode_copy_string;
    pkg.pkg_name.arg = &slots[0];
    pkg.pkg_path.funcs.decode = kcl_decode_copy_string;
    pkg.pkg_path.arg = &slots[1];
    if (!pb_decode(stream, ExternalPkg_fields, &pkg))
        return false;
    coll->count++;
    return true;
}

bool kcl_decode_key_value_pair_list(pb_istream_t* stream, const pb_field_t* field, void** arg)
{
    struct KclKeyValueCollector* coll = (struct KclKeyValueCollector*)(*arg);
    KeyValuePair pair = KeyValuePair_init_default;
    struct KclStringSlot slots[2];
    if (coll->count >= coll->max_count)
        return false;
    slots[0].buffer = coll->items[coll->count].key;
    slots[0].size = sizeof(coll->items[coll->count].key);
    slots[1].buffer = coll->items[coll->count].value;
    slots[1].size = sizeof(coll->items[coll->count].value);
    pair.key.funcs.decode = kcl_decode_copy_string;
    pair.key.arg = &slots[0];
    pair.value.funcs.decode = kcl_decode_copy_string;
    pair.value.arg = &slots[1];
    if (!pb_decode(stream, KeyValuePair_fields, &pair))
        return false;
    coll->count++;
    return true;
}

/* ------------------------------------------------------------------ */
/* Encoder for map<string, string> request fields                      */
/* ------------------------------------------------------------------ */

bool kcl_encode_string_map_entries(pb_ostream_t* stream, const pb_field_t* field, void* const* arg)
{
    struct KclStringPairList* list = (struct KclStringPairList*)(*arg);
    while (list->index < list->count) {
        const struct KclStringPair* pair = &list->items[list->index++];
        RenameCodeArgs_SourceCodesEntry entry = RenameCodeArgs_SourceCodesEntry_init_default;
        entry.key.funcs.encode = kclm_encode_string;
        entry.key.arg = (void*)pair->key;
        entry.value.funcs.encode = kclm_encode_string;
        entry.value.arg = (void*)pair->value;
        if (!pb_encode_tag(stream, PB_WT_STRING, field->tag))
            return false;
        if (!pb_encode_submessage(stream, RenameCodeArgs_SourceCodesEntry_fields, &entry))
            return false;
    }
    return true;
}
