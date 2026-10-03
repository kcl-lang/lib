#pragma once

// High-level KCL facade for C++, mirroring the ergonomic surface of
// kcl-go's `pkg/kcl` (Run/RunFiles/Validate + KCLResult) on top of the
// type-safe cxx bridge in `kcl_lib.hpp`.
//
// The bridge layer forces callers to build `kcl_lib::ExecProgramArgs` by
// hand and decode `yaml_result` strings manually. This header adds:
//
//   * `kcl_lib::Kcl::run(code, opts)` / `kcl_lib::Kcl::run_files(paths, opts)`
//     which merge code/files + options into `ExecProgramArgs`, execute, and
//     throw `kcl_lib::KclError` when the runtime returns a non-empty
//     `err_message` (mirroring kcl-go, where `Run` returns the message as an
//     error; .NET/Java in this repo throw the same way).
//   * `kcl_lib::Options`, a designated-initializer friendly option bag
//     aligned with the Python/.NET/Java facades in this repo and with
//     kcl-go's `Option` factories (WithCode/WithOverrides/WithSettings/...).
//   * `kcl_lib::KclResult` with raw `yaml_result`/`json_result`/`log_message`/
//     `err_message` accessors plus `get("a.b.c")` dotted-path navigation over
//     the parsed JSON document.
//   * kcl-go's `_type` rewriting hook: when `include_schema_type_path` is on
//     and `full_type_path` is off (the default), `_type` values are shortened
//     to their last path segment (e.g. `__main__.AppConfig` -> `AppConfig`).
//
// JSON backing store
// ------------------
// `KclResult::get` returns `kcl_lib::JsonValue`, which is
// `nlohmann::ordered_json` when `<nlohmann/json.hpp>` is on the include path
// and a bundled hand-rolled `Json` otherwise. `ordered_json` is required
// rather than plain `nlohmann::json` because the latter stores objects in a
// `std::map`, which sorts keys and would reorder the runtime's output when
// the hook re-emits YAML/JSON.
//
// The bundled fallback is compiled only when nlohmann/json is absent, which
// keeps the header usable with nothing but a C++17 toolchain; the CMake build
// picks nlohmann up through `find_package(nlohmann_json)` when it is
// installed. Define `KCL_LIB_NO_NLOHMANN` to force the fallback.
//
// `KclResult::getInt` / `getString` / `getFloat` / `getBool` / `getObject` /
// `getArray` are the portable accessors: they behave identically whichever
// backing store is compiled in, so callers that want to build against both
// configurations should prefer them over the raw `get` return value.

#include "kcl_lib.hpp"

#include <cstdint>
#include <cstdlib>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#if !defined(KCL_LIB_NO_NLOHMANN)
#  if defined(__has_include)
#    if __has_include(<nlohmann/json.hpp>)
#      include <nlohmann/json.hpp>
#      define KCL_LIB_HAS_NLOHMANN 1
#    endif
#  endif
#endif

namespace kcl_lib {

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// Error raised by the facade for every run failure: a non-empty runtime
/// `err_message`, invalid options, unparseable results, and native/transport
/// failures from the cxx bridge (wrapped so callers only ever catch
/// KclError, mirroring the .NET/Java facades' KclException).
class KclError : public std::runtime_error {
public:
    explicit KclError(const std::string& message)
        : std::runtime_error(message)
    {
    }
};

// ---------------------------------------------------------------------------
// JSON value
// ---------------------------------------------------------------------------

#ifdef KCL_LIB_HAS_NLOHMANN
/// The JSON value type the facade parses results into and hands back to
/// callers. `ordered_json` is required rather than plain `nlohmann::json`:
/// the latter keeps objects in a `std::map`, which sorts keys and would
/// reorder the runtime's output when the `_type` hook re-emits YAML/JSON.
using JsonValue = nlohmann::ordered_json;
#else
/// A parsed JSON value. Object member order is preserved so re-emitted
/// YAML/JSON keeps the runtime's key order. Numbers keep their raw token for
/// lossless re-emission (`1e3` stays `1e3`).
///
/// Bundled fallback compiled only when nlohmann/json is not on the include
/// path, so the header stays dependency-free. The walks in `detail` reach
/// this class through a handful of small adapters rather than through its
/// API directly.
class Json {
public:
    enum class Kind {
        Null,
        Bool,
        Number,
        String,
        Array,
        Object,
    };

    Json() = default;
    static Json boolean(bool value) { return Json(Kind::Bool, value ? "true" : "false"); }
    static Json number(std::string raw_token) { return Json(Kind::Number, std::move(raw_token)); }
    static Json string(std::string value) { return Json(Kind::String, std::move(value)); }
    static Json array(std::vector<Json> items)
    {
        Json v;
        v.kind_ = Kind::Array;
        v.array_ = std::move(items);
        return v;
    }
    static Json object(std::vector<std::pair<std::string, Json>> members)
    {
        Json v;
        v.kind_ = Kind::Object;
        v.object_ = std::move(members);
        return v;
    }

    Kind kind() const { return kind_; }
    bool is_null() const { return kind_ == Kind::Null; }
    bool is_bool() const { return kind_ == Kind::Bool; }
    bool is_number() const { return kind_ == Kind::Number; }
    bool is_string() const { return kind_ == Kind::String; }
    bool is_array() const { return kind_ == Kind::Array; }
    bool is_object() const { return kind_ == Kind::Object; }

    /// Element / member count, and emptiness for collections. `nlohmann`
    /// spells both the same way, which is what lets `detail` share its walks.
    size_t size() const
    {
        if (kind_ == Kind::Array) {
            return array_.size();
        }
        return kind_ == Kind::Object ? object_.size() : 0;
    }
    bool empty() const { return size() == 0; }

    bool as_bool() const
    {
        require(Kind::Bool);
        return scalar_ == "true";
    }

    std::vector<Json>& as_array()
    {
        require(Kind::Array);
        return array_;
    }

    std::vector<std::pair<std::string, Json>>& as_object()
    {
        require(Kind::Object);
        return object_;
    }

    /// Integer view of a number; truncates towards zero like kcl-go's
    /// float64 -> int conversions in `KCLResult.Get`.
    long long as_int() const
    {
        require(Kind::Number);
        return std::strtoll(scalar_.c_str(), nullptr, 10);
    }

    double as_double() const
    {
        require(Kind::Number);
        return std::strtod(scalar_.c_str(), nullptr);
    }

    const std::string& as_string() const
    {
        require(Kind::String);
        return scalar_;
    }

    const std::vector<Json>& as_array() const
    {
        require(Kind::Array);
        return array_;
    }

    const std::vector<std::pair<std::string, Json>>& as_object() const
    {
        require(Kind::Object);
        return object_;
    }

    /// Member lookup for objects; nullptr when this is not an object or the
    /// key is missing.
    const Json* find(const std::string& key) const
    {
        if (kind_ != Kind::Object) {
            return nullptr;
        }
        for (const auto& member : object_) {
            if (member.first == key) {
                return &member.second;
            }
        }
        return nullptr;
    }

    /// Compact JSON rendering (objects preserve member order).
    std::string dump() const
    {
        std::string out;
        dump_to(out);
        return out;
    }

    /// JSON string escaping shared with the YAML emitter in `detail`.
    static void dump_string(const std::string& value, std::string& out)
    {
        out.push_back('"');
        for (char ch : value) {
            switch (ch) {
            case '"':
                out += "\\\"";
                break;
            case '\\':
                out += "\\\\";
                break;
            case '\b':
                out += "\\b";
                break;
            case '\f':
                out += "\\f";
                break;
            case '\n':
                out += "\\n";
                break;
            case '\r':
                out += "\\r";
                break;
            case '\t':
                out += "\\t";
                break;
            default:
                out.push_back(ch);
            }
        }
        out.push_back('"');
    }

private:
    Kind kind_ = Kind::Null;
    std::string scalar_; // bool literal, raw number token, or string value
    std::vector<Json> array_;
    std::vector<std::pair<std::string, Json>> object_;

    Json(Kind kind, std::string scalar)
        : kind_(kind)
        , scalar_(std::move(scalar))
    {
    }

    void require(Kind expected) const
    {
        if (kind_ != expected) {
            throw KclError("kcl: Json value kind mismatch");
        }
    }

    void dump_to(std::string& out) const
    {
        switch (kind_) {
        case Kind::Null:
            out += "null";
            break;
        case Kind::Bool:
        case Kind::Number:
            out += scalar_;
            break;
        case Kind::String:
            dump_string(scalar_, out);
            break;
        case Kind::Array:
            out.push_back('[');
            for (size_t i = 0; i < array_.size(); ++i) {
                if (i > 0) {
                    out.push_back(',');
                }
                array_[i].dump_to(out);
            }
            out.push_back(']');
            break;
        case Kind::Object:
            out.push_back('{');
            for (size_t i = 0; i < object_.size(); ++i) {
                if (i > 0) {
                    out.push_back(',');
                }
                dump_string(object_[i].first, out);
                out.push_back(':');
                object_[i].second.dump_to(out);
            }
            out.push_back('}');
            break;
        }
    }
};

/// See the nlohmann branch above for what this alias selects.
using JsonValue = Json;
#endif // !KCL_LIB_HAS_NLOHMANN

namespace detail {

#ifndef KCL_LIB_HAS_NLOHMANN
// Recursive-descent parser for the JSON subset the KCL runtime emits.
// Supports the full JSON grammar including \uXXXX escapes and surrogate
// pairs; the stream form (several top-level values separated by whitespace,
// as in json_result's one-document-per-line layout) is accepted.
class JsonParser {
public:
    JsonParser(const char* begin, const char* end)
        : cur_(begin)
        , end_(end)
    {
    }

    std::vector<Json> parse_stream()
    {
        std::vector<Json> docs;
        skip_ws();
        while (cur_ != end_) {
            docs.push_back(parse_value());
            skip_ws();
        }
        return docs;
    }

private:
    const char* cur_;
    const char* end_;

    [[noreturn]] void fail(const std::string& what) const
    {
        throw KclError("kcl: invalid JSON result: " + what);
    }

    void skip_ws()
    {
        while (cur_ != end_ && (*cur_ == ' ' || *cur_ == '\t' || *cur_ == '\n' || *cur_ == '\r')) {
            ++cur_;
        }
    }

    char take()
    {
        if (cur_ == end_) {
            fail("unexpected end of input");
        }
        return *cur_++;
    }

    void expect_literal(const char* literal)
    {
        for (const char* p = literal; *p != '\0'; ++p) {
            if (cur_ == end_ || *cur_ != *p) {
                fail("invalid literal");
            }
            ++cur_;
        }
    }

    static void encode_utf8(unsigned code_point, std::string& out)
    {
        if (code_point < 0x80) {
            out.push_back(static_cast<char>(code_point));
        } else if (code_point < 0x800) {
            out.push_back(static_cast<char>(0xC0 | (code_point >> 6)));
            out.push_back(static_cast<char>(0x80 | (code_point & 0x3F)));
        } else if (code_point < 0x10000) {
            out.push_back(static_cast<char>(0xE0 | (code_point >> 12)));
            out.push_back(static_cast<char>(0x80 | ((code_point >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (code_point & 0x3F)));
        } else {
            out.push_back(static_cast<char>(0xF0 | (code_point >> 18)));
            out.push_back(static_cast<char>(0x80 | ((code_point >> 12) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | ((code_point >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (code_point & 0x3F)));
        }
    }

    unsigned parse_hex4()
    {
        unsigned value = 0;
        for (int i = 0; i < 4; ++i) {
            char ch = take();
            value <<= 4;
            if (ch >= '0' && ch <= '9') {
                value |= static_cast<unsigned>(ch - '0');
            } else if (ch >= 'a' && ch <= 'f') {
                value |= static_cast<unsigned>(ch - 'a' + 10);
            } else if (ch >= 'A' && ch <= 'F') {
                value |= static_cast<unsigned>(ch - 'A' + 10);
            } else {
                fail("invalid \\u escape");
            }
        }
        return value;
    }

    std::string parse_string()
    {
        if (take() != '"') {
            fail("expected string");
        }
        std::string out;
        for (;;) {
            char ch = take();
            if (ch == '"') {
                return out;
            }
            if (static_cast<unsigned char>(ch) < 0x20) {
                fail("unescaped control character in string");
            }
            if (ch != '\\') {
                out.push_back(ch);
                continue;
            }
            char esc = take();
            switch (esc) {
            case '"':
                out.push_back('"');
                break;
            case '\\':
                out.push_back('\\');
                break;
            case '/':
                out.push_back('/');
                break;
            case 'b':
                out.push_back('\b');
                break;
            case 'f':
                out.push_back('\f');
                break;
            case 'n':
                out.push_back('\n');
                break;
            case 'r':
                out.push_back('\r');
                break;
            case 't':
                out.push_back('\t');
                break;
            case 'u': {
                unsigned code_point = parse_hex4();
                if (code_point >= 0xD800 && code_point <= 0xDBFF) {
                    // High surrogate: require a paired low surrogate.
                    if (take() != '\\' || take() != 'u') {
                        fail("unpaired surrogate in \\u escape");
                    }
                    unsigned low = parse_hex4();
                    if (low < 0xDC00 || low > 0xDFFF) {
                        fail("unpaired surrogate in \\u escape");
                    }
                    code_point = 0x10000 + ((code_point - 0xD800) << 10) + (low - 0xDC00);
                }
                encode_utf8(code_point, out);
                break;
            }
            default:
                fail("invalid escape sequence");
            }
        }
    }

    Json parse_number()
    {
        const char* start = cur_;
        if (cur_ != end_ && *cur_ == '-') {
            ++cur_;
        }
        bool digits = false;
        while (cur_ != end_ && *cur_ >= '0' && *cur_ <= '9') {
            ++cur_;
            digits = true;
        }
        if (cur_ != end_ && *cur_ == '.') {
            ++cur_;
            bool frac_digits = false;
            while (cur_ != end_ && *cur_ >= '0' && *cur_ <= '9') {
                ++cur_;
                frac_digits = true;
            }
            digits = digits && frac_digits;
        }
        if (!digits) {
            fail("invalid number");
        }
        if (cur_ != end_ && (*cur_ == 'e' || *cur_ == 'E')) {
            ++cur_;
            if (cur_ != end_ && (*cur_ == '+' || *cur_ == '-')) {
                ++cur_;
            }
            bool exp_digits = false;
            while (cur_ != end_ && *cur_ >= '0' && *cur_ <= '9') {
                ++cur_;
                exp_digits = true;
            }
            if (!exp_digits) {
                fail("invalid number exponent");
            }
        }
        return Json::number(std::string(start, static_cast<size_t>(cur_ - start)));
    }

    Json parse_array()
    {
        take(); // '['
        std::vector<Json> items;
        skip_ws();
        if (cur_ != end_ && *cur_ == ']') {
            ++cur_;
            return Json::array(std::move(items));
        }
        for (;;) {
            items.push_back(parse_value());
            skip_ws();
            char ch = take();
            if (ch == ']') {
                return Json::array(std::move(items));
            }
            if (ch != ',') {
                fail("expected ',' or ']' in array");
            }
        }
    }

    Json parse_object()
    {
        take(); // '{'
        std::vector<std::pair<std::string, Json>> members;
        skip_ws();
        if (cur_ != end_ && *cur_ == '}') {
            ++cur_;
            return Json::object(std::move(members));
        }
        for (;;) {
            skip_ws();
            std::string key = parse_string();
            skip_ws();
            if (take() != ':') {
                fail("expected ':' in object");
            }
            Json value = parse_value();
            // Last duplicate key wins, matching encoding/json.
            bool replaced = false;
            for (auto& member : members) {
                if (member.first == key) {
                    member.second = std::move(value);
                    replaced = true;
                    break;
                }
            }
            if (!replaced) {
                members.emplace_back(std::move(key), std::move(value));
            }
            skip_ws();
            char ch = take();
            if (ch == '}') {
                return Json::object(std::move(members));
            }
            if (ch != ',') {
                fail("expected ',' or '}' in object");
            }
        }
    }

    Json parse_value()
    {
        skip_ws();
        if (cur_ == end_) {
            fail("unexpected end of input");
        }
        switch (*cur_) {
        case 'n':
            expect_literal("null");
            return Json();
        case 't':
            expect_literal("true");
            return Json::boolean(true);
        case 'f':
            expect_literal("false");
            return Json::boolean(false);
        case '"':
            return Json::string(parse_string());
        case '[':
            return parse_array();
        case '{':
            return parse_object();
        default:
            return parse_number();
        }
    }
};
#endif // !KCL_LIB_HAS_NLOHMANN

// ---------------------------------------------------------------------------
// Backend adapters
//
// Everything below walks `JsonValue` rather than a concrete JSON type. These
// few adapters are the only code that knows which backend is compiled in; the
// YAML emitter, the `_type` hook and the dotted-path lookup are written once.
// ---------------------------------------------------------------------------

/// JSON string escaping (used for both values and object keys).
inline void json_quote(const std::string& value, std::string& out)
{
#ifdef KCL_LIB_HAS_NLOHMANN
    out += nlohmann::ordered_json(value).dump();
#else
    Json::dump_string(value, out);
#endif
}

/// Call `fn(key, value)` for every member of an object, in the runtime's
/// order.
template <typename F>
inline void for_each_member(const JsonValue& value, F&& fn)
{
#ifdef KCL_LIB_HAS_NLOHMANN
    for (auto it = value.begin(); it != value.end(); ++it) {
        fn(it.key(), it.value());
    }
#else
    for (const auto& member : value.as_object()) {
        fn(member.first, member.second);
    }
#endif
}

/// Mutable variant of {for_each_member}.
template <typename F>
inline void for_each_member_mut(JsonValue& value, F&& fn)
{
#ifdef KCL_LIB_HAS_NLOHMANN
    for (auto it = value.begin(); it != value.end(); ++it) {
        fn(it.key(), it.value());
    }
#else
    for (auto& member : value.as_object()) {
        fn(member.first, member.second);
    }
#endif
}

/// Call `fn(item)` for every element of an array.
template <typename F>
inline void for_each_item(const JsonValue& value, F&& fn)
{
#ifdef KCL_LIB_HAS_NLOHMANN
    for (const auto& item : value) {
        fn(item);
    }
#else
    for (const auto& item : value.as_array()) {
        fn(item);
    }
#endif
}

/// Mutable variant of {for_each_item}.
template <typename F>
inline void for_each_item_mut(JsonValue& value, F&& fn)
{
#ifdef KCL_LIB_HAS_NLOHMANN
    for (auto& item : value) {
        fn(item);
    }
#else
    for (auto& item : value.as_array()) {
        fn(item);
    }
#endif
}

/// Member lookup for objects; nullptr when `value` is not an object or the
/// key is missing.
inline const JsonValue* json_find(const JsonValue& value, const std::string& key)
{
#ifdef KCL_LIB_HAS_NLOHMANN
    if (!value.is_object()) {
        return nullptr;
    }
    auto it = value.find(key);
    return it == value.end() ? nullptr : &(*it);
#else
    return value.find(key);
#endif
}

/// Array element lookup; nullptr when `value` is not an array or the index is
/// out of range.
inline const JsonValue* json_index(const JsonValue& value, size_t index)
{
    if (!value.is_array() || index >= value.size()) {
        return nullptr;
    }
#ifdef KCL_LIB_HAS_NLOHMANN
    return &value[index];
#else
    return &value.as_array()[index];
#endif
}

/// Render a non-string scalar (null / bool / number) as its JSON literal.
/// Strings are handled through {json_string}.
inline void json_scalar_text(const JsonValue& value, std::string& out)
{
#ifdef KCL_LIB_HAS_NLOHMANN
    switch (value.type()) {
    case nlohmann::ordered_json::value_t::null:
        out += "null";
        return;
    case nlohmann::ordered_json::value_t::boolean:
        out += value.get<bool>() ? "true" : "false";
        return;
    case nlohmann::ordered_json::value_t::number_integer:
        out += std::to_string(value.get<nlohmann::ordered_json::number_integer_t>());
        return;
    case nlohmann::ordered_json::value_t::number_unsigned:
        out += std::to_string(value.get<nlohmann::ordered_json::number_unsigned_t>());
        return;
    case nlohmann::ordered_json::value_t::number_float:
        out += value.dump();
        return;
    default:
        return;
    }
#else
    out += value.dump();
#endif
}

/// Copy a string scalar out of `value`; returns false when it holds another
/// type.
inline bool json_string(const JsonValue& value, std::string& out)
{
#ifdef KCL_LIB_HAS_NLOHMANN
    if (!value.is_string()) {
        return false;
    }
    out = value.get<std::string>();
    return true;
#else
    if (!value.is_string()) {
        return false;
    }
    out = value.as_string();
    return true;
#endif
}

/// Replace `target` with a string scalar.
inline void json_set_string(JsonValue& target, std::string value)
{
#ifdef KCL_LIB_HAS_NLOHMANN
    target = std::move(value);
#else
    target = Json::string(std::move(value));
#endif
}

/// Parse the runtime's JSON *stream* into one value per document.
inline std::vector<JsonValue> parse_json_stream(const std::string& text)
{
#ifdef KCL_LIB_HAS_NLOHMANN
    // The runtime emits one compact JSON value per line, and serde_json never
    // emits a literal newline inside a string, so line splitting is safe.
    std::vector<JsonValue> docs;
    size_t start = 0;
    while (start <= text.size()) {
        size_t end = text.find('\n', start);
        const bool last = end == std::string::npos;
        const std::string line = text.substr(start, last ? std::string::npos : end - start);
        if (!line.empty() && line.find_first_not_of(" \t\r") != std::string::npos) {
            // `allow_exceptions = false` keeps a malformed payload from
            // throwing nlohmann's own exception type past the facade.
            auto parsed = nlohmann::ordered_json::parse(line, nullptr, false);
            if (parsed.is_discarded()) {
                throw KclError("kcl: invalid JSON result: " + line);
            }
            docs.push_back(std::move(parsed));
        }
        if (last) {
            break;
        }
        start = end + 1;
    }
    return docs;
#else
    return JsonParser(text.data(), text.data() + text.size()).parse_stream();
#endif
}

/// Dotted-path lookup mirroring kcl-go's `KCLResult.Get("a.b.c")`: dots
/// navigate nested objects and integer segments index into arrays. Returns a
/// null value when any segment is missing.
inline JsonValue json_get_path(const JsonValue& root, const std::string& dotted_path)
{
    const JsonValue* current = &root;
    std::string segment;
    for (size_t i = 0; i <= dotted_path.size(); ++i) {
        if (i != dotted_path.size() && dotted_path[i] != '.') {
            segment.push_back(dotted_path[i]);
            continue;
        }
        if (segment.empty()) {
            return JsonValue();
        }
        if (current->is_object()) {
            current = json_find(*current, segment);
        } else if (current->is_array()) {
            const bool numeric = segment.find_first_not_of("0123456789") == std::string::npos;
            const size_t index = static_cast<size_t>(std::strtoull(segment.c_str(), nullptr, 10));
            current = numeric ? json_index(*current, index) : nullptr;
        } else {
            current = nullptr;
        }
        if (current == nullptr) {
            return JsonValue();
        }
        segment.clear();
    }
    return *current;
}

// kcl-go hook.go's resultTypeAttributeHook: when the runtime was asked to
// include schema type paths and the caller did not opt into full type paths,
// rewrite every `_type` value to its last segment (`pkg.Sub` -> `Sub`). The
// Go walk only descends into objects; this one also descends into arrays so
// schema instances nested in lists are rewritten consistently.
inline void rewrite_type_attribute(JsonValue& value)
{
    if (value.is_object()) {
        for_each_member_mut(value, [](const std::string& key, JsonValue& child) {
            std::string full;
            if (key == "_type" && json_string(child, full)) {
                const size_t dot = full.rfind('.');
                if (dot != std::string::npos) {
                    json_set_string(child, full.substr(dot + 1));
                }
                return;
            }
            rewrite_type_attribute(child);
        });
    } else if (value.is_array()) {
        for_each_item_mut(value, [](JsonValue& item) { rewrite_type_attribute(item); });
    }
}

// Minimal YAML emitter covering the subset the KCL runtime emits: nested
// mappings/sequences with two-space indents and plain scalars. Strings that
// could be misread as another scalar type or contain YAML specials are
// emitted double-quoted.
inline bool yaml_needs_quotes(const std::string& value)
{
    if (value.empty() || value.front() == ' ' || value.back() == ' ') {
        return true;
    }
    // Scalars that YAML would decode as a non-string type.
    std::string lower;
    for (char ch : value) {
        lower.push_back(static_cast<char>(ch >= 'A' && ch <= 'Z' ? ch - 'A' + 'a' : ch));
    }
    if (lower == "null" || lower == "~" || lower == "true" || lower == "false") {
        return true;
    }
    char first = value.front();
    if ((first >= '0' && first <= '9') || first == '-' || first == '+' || first == '.') {
        return true;
    }
    return value.find_first_of(":#{}[],&*?|>%@!\"'\n\r\t") != std::string::npos;
}

inline void yaml_emit_scalar(const JsonValue& value, std::string& out)
{
    std::string text;
    if (json_string(value, text)) {
        if (yaml_needs_quotes(text)) {
            json_quote(text, out);
        } else {
            out += text;
        }
        return;
    }
    json_scalar_text(value, out);
}

inline void yaml_emit(const JsonValue& value, size_t indent, std::string& out);

/// Write `key: <value>`. Nested collections start on the next line indented by
/// `child_indent`; empty ones collapse to `{}` / `[]`.
inline void yaml_emit_member(const std::string& key, const JsonValue& child, size_t child_indent, std::string& out)
{
    if (yaml_needs_quotes(key)) {
        json_quote(key, out);
    } else {
        out += key;
    }
    if (child.is_object() || child.is_array()) {
        if (child.empty()) {
            out += child.is_object() ? ": {}\n" : ": []\n";
        } else {
            out += ":\n";
            yaml_emit(child, child_indent, out);
        }
    } else {
        out += ": ";
        yaml_emit_scalar(child, out);
        out.push_back('\n');
    }
}

inline void yaml_emit(const JsonValue& value, size_t indent, std::string& out)
{
    const std::string pad(indent, ' ');
    if (value.is_object()) {
        if (value.empty()) {
            out += pad + "{}\n";
            return;
        }
        for_each_member(value, [&](const std::string& key, const JsonValue& child) {
            out += pad;
            yaml_emit_member(key, child, indent + 2, out);
        });
        return;
    }
    if (value.is_array()) {
        if (value.empty()) {
            out += pad + "[]\n";
            return;
        }
        for_each_item(value, [&](const JsonValue& item) {
            out += pad + "-";
            if (item.is_object() && !item.empty()) {
                // The first member sits on the dash line, the rest are
                // indented to line up underneath it.
                bool first = true;
                for_each_member(item, [&](const std::string& key, const JsonValue& child) {
                    out += first ? " " : std::string(indent + 2, ' ');
                    first = false;
                    yaml_emit_member(key, child, indent + 4, out);
                });
            } else if (item.is_array() && !item.empty()) {
                out.push_back('\n');
                yaml_emit(item, indent + 2, out);
            } else {
                out.push_back(' ');
                yaml_emit_scalar(item, out);
                out.push_back('\n');
            }
        });
        return;
    }
    out += pad;
    yaml_emit_scalar(value, out);
    out.push_back('\n');
}

} // namespace detail

// ---------------------------------------------------------------------------
// Options
// ---------------------------------------------------------------------------

/// Option bag for `Kcl::run` / `Kcl::run_files`, mirroring the union of
/// fields kcl-go's `Option` can populate. All fields have defaults so callers
/// can use C++17 designated initializers for just the knobs they need:
///
/// ```cpp
/// kcl_lib::Kcl::run(code, kcl_lib::Options {
///     .overrides = { "app.replicas=5" },
///     .disable_none = true,
/// });
/// ```
///
/// `std::optional` fields distinguish "not set" from an explicit value so
/// settings-file defaults are only overridden when the caller really sets a
/// value (matching kcl-go's layered Option/SettingsFile semantics).
struct Options {
    /// Working directory for the evaluation (kcl-go `WithWorkDir`).
    std::string work_dir;
    /// Extra in-memory KCL sources (kcl-go `WithCode`).
    std::vector<std::string> code;
    /// Extra KCL file paths (kcl-go `WithKFilenames`).
    std::vector<std::string> filenames;
    /// `option("key")` arguments as name/value pairs (kcl-go `WithOptions`,
    /// the `-D key=value` flag).
    std::vector<std::pair<std::string, std::string>> args;
    /// Override specs (kcl-go `WithOverrides`, the `-O` flag).
    std::vector<std::string> overrides;
    /// Path selectors (kcl-go `WithSelectors`, the `-S` flag).
    std::vector<std::string> selectors;
    /// External packages as name/path pairs (kcl-go `WithExternalPkgs`,
    /// the `-E name=path` flag).
    std::vector<std::pair<std::string, std::string>> external_pkgs;
    /// `kcl.yaml` settings file path (kcl-go `WithSettings`). Loaded through
    /// the bridge's `load_settings_files` and merged as the base layer:
    /// explicit fields in this struct are layered on top of it.
    std::string settings;
    /// `-n --disable-none`.
    std::optional<bool> disable_none;
    /// `-k --sort_keys`.
    std::optional<bool> sort_keys;
    /// `-H --show_hidden`.
    std::optional<bool> show_hidden;
    /// Include schema type paths in the result. When set without
    /// `full_type_path`, the `_type` values are rewritten to their last
    /// segment by default (kcl-go `WithIncludeSchemaTypePath` + hook).
    std::optional<bool> include_schema_type_path;
    /// Keep the full `pkg.path.Schema` form in `_type` values. Implies
    /// `include_schema_type_path` and disables the rewriting hook
    /// (kcl-go `WithFullTypePath`).
    bool full_type_path = false;
    /// `-r --strict_range_check`.
    std::optional<bool> strict_range_check;
    /// `-v --verbose` level.
    std::optional<int> verbose;
    /// `-d --debug` level.
    std::optional<int> debug;
    /// Print the override AST instead of applying overrides.
    std::optional<bool> print_override_ast;
    /// Ask the runtime not to populate `yaml_result`.
    std::optional<bool> disable_yaml_result;
    /// Diagnostic output format: "pretty" (default), "short", "arcanist" or
    /// "sarif" (kcl-go `WithErrorFormat`, `--error_format`).
    std::string error_format;
    /// Output format selector: "yaml" or "json". Empty (the default) lets
    /// the runtime emit both representations (kcl-go `WithOutputFormat`).
    std::string format;
};

// ---------------------------------------------------------------------------
// Result
// ---------------------------------------------------------------------------

/// One evaluated KCL run. Wraps the bridge's `ExecProgramResult`: the raw
/// `yaml_result` / `json_result` strings are exposed as-is (after the `_type`
/// hook ran, exactly like kcl-go), and `get` navigates the parsed JSON
/// document with dotted paths.
class KclResult {
public:
    explicit KclResult(ExecProgramResult raw, bool shorten_type_paths)
        : raw_yaml_(std::string(raw.yaml_result))
        , raw_json_(std::string(raw.json_result))
        , raw_log_(std::string(raw.log_message))
        , raw_err_(std::string(raw.err_message))
    {
        if (!shorten_type_paths || raw_json_.empty()) {
            return;
        }
        std::vector<JsonValue> docs;
        try {
            docs = detail::parse_json_stream(raw_json_);
        } catch (const KclError&) {
            // Leave the raw strings untouched, mirroring kcl-go's hook which
            // silently skips results it cannot decode.
            return;
        }
        if (docs.empty()) {
            return;
        }
        for (auto& doc : docs) {
            detail::rewrite_type_attribute(doc);
        }
        for (size_t i = 0; i < docs.size(); ++i) {
            if (i > 0) {
                json_.push_back('\n');
            }
            json_ += docs[i].dump();
        }
        if (!raw_yaml_.empty()) {
            for (size_t i = 0; i < docs.size(); ++i) {
                if (i > 0) {
                    yaml_ += "---\n";
                }
                detail::yaml_emit(docs[i], 0, yaml_);
            }
        }
    }

    /// Raw YAML rendering of the run's output documents (post-hook).
    const std::string& yaml_result() const { return yaml_.empty() ? raw_yaml_ : yaml_; }
    /// Raw JSON rendering of the run's output documents (post-hook).
    const std::string& json_result() const { return json_.empty() ? raw_json_ : json_; }
    /// Runtime log messages (kcl-go forwards these to the option logger).
    const std::string& log_message() const { return raw_log_; }
    /// Runtime error message; the facade throws `KclError` before callers see
    /// a non-empty value here, kept for parity with kcl-go's KCLResult.
    const std::string& err_message() const { return raw_err_; }

    /// Number of JSON documents the run produced.
    size_t document_count() const
    {
        ensure_parsed();
        return docs_.size();
    }

    /// Dotted-path lookup over the parsed JSON document
    /// (`get("a.b.c")`, integer segments index into lists), mirroring
    /// kcl-go's `KCLResult.Get`. Returns a null value when the path does not
    /// resolve or when the runtime emitted no JSON for this run (e.g.
    /// `format = "yaml"` was forced).
    ///
    /// The return type is the active {JsonValue} backend. Prefer the typed
    /// accessors below when the code has to build both with and without
    /// nlohmann/json.
    JsonValue get(const std::string& dotted_path, size_t document = 0) const
    {
        ensure_parsed();
        if (document >= docs_.size()) {
            return JsonValue();
        }
        return detail::json_get_path(docs_[document], dotted_path);
    }

    // -- portable typed accessors ------------------------------------------
    //
    // These behave identically on either backend, so callers that do not care
    // which one is compiled in can use them instead of `get`'s raw value.
    // A missing path or a type mismatch throws KclError, mirroring kcl-go's
    // strict `KCLResult.Get(key, &target)`.

    /// Integer view of the value at `path`; floats truncate towards zero.
    long long getInt(const std::string& path, size_t document = 0) const
    {
        const JsonValue value = get(path, document);
#ifdef KCL_LIB_HAS_NLOHMANN
        if (value.is_number_integer()) {
            return value.get<long long>();
        }
        if (value.is_number_unsigned()) {
            return static_cast<long long>(value.get<nlohmann::ordered_json::number_unsigned_t>());
        }
        if (value.is_number_float()) {
            return static_cast<long long>(value.get<double>());
        }
#else
        if (value.is_number()) {
            return value.as_int();
        }
#endif
        throw KclError("kcl: " + path + " is not an integer");
    }

    /// Floating-point view of the value at `path`.
    double getFloat(const std::string& path, size_t document = 0) const
    {
        const JsonValue value = get(path, document);
#ifdef KCL_LIB_HAS_NLOHMANN
        if (value.is_number()) {
            return value.get<double>();
        }
#else
        if (value.is_number()) {
            return value.as_double();
        }
#endif
        throw KclError("kcl: " + path + " is not a number");
    }

    /// String view of the value at `path`.
    std::string getString(const std::string& path, size_t document = 0) const
    {
        const JsonValue value = get(path, document);
        std::string text;
        if (detail::json_string(value, text)) {
            return text;
        }
        throw KclError("kcl: " + path + " is not a string");
    }

    /// Boolean view of the value at `path`.
    bool getBool(const std::string& path, size_t document = 0) const
    {
        const JsonValue value = get(path, document);
#ifdef KCL_LIB_HAS_NLOHMANN
        if (value.is_boolean()) {
            return value.get<bool>();
        }
#else
        if (value.is_bool()) {
            return value.as_bool();
        }
#endif
        throw KclError("kcl: " + path + " is not a boolean");
    }

    /// Elements of the array at `path`.
    std::vector<JsonValue> getArray(const std::string& path, size_t document = 0) const
    {
        const JsonValue value = get(path, document);
        if (!value.is_array()) {
            throw KclError("kcl: " + path + " is not an array");
        }
        std::vector<JsonValue> items;
        items.reserve(value.size());
        detail::for_each_item(value, [&](const JsonValue& item) { items.push_back(item); });
        return items;
    }

    /// Members of the object at `path`, in the runtime's key order.
    std::vector<std::pair<std::string, JsonValue>> getObject(const std::string& path, size_t document = 0) const
    {
        const JsonValue value = get(path, document);
        if (!value.is_object()) {
            throw KclError("kcl: " + path + " is not an object");
        }
        std::vector<std::pair<std::string, JsonValue>> members;
        members.reserve(value.size());
        detail::for_each_member(value, [&](const std::string& key, const JsonValue& member) {
            members.emplace_back(key, member);
        });
        return members;
    }

private:
    // Raw bridge output copied into std::string (cxx::rust::String is not
    // implicitly convertible), plus post-hook renderings; the empty string
    // means "fall back to the raw copy".
    std::string raw_yaml_;
    std::string raw_json_;
    std::string raw_log_;
    std::string raw_err_;
    std::string yaml_;
    std::string json_;
    mutable std::vector<JsonValue> docs_;
    mutable bool parsed_ = false;

    void ensure_parsed() const
    {
        if (parsed_) {
            return;
        }
        parsed_ = true;
        const std::string& source = json_.empty() ? raw_json_ : json_;
        if (source.empty()) {
            return;
        }
        try {
            docs_ = detail::parse_json_stream(source);
        } catch (const KclError&) {
            docs_.clear();
        }
    }
};

// ---------------------------------------------------------------------------
// Kcl entry points
// ---------------------------------------------------------------------------

/// High-level static entry points mirroring kcl-go's `pkg/kcl`.
class Kcl {
public:
    /// Evaluate the in-memory KCL source `code` and return the parsed
    /// result. Throws `KclError` when the run produces a non-empty
    /// `err_message`; the cxx bridge may also throw `rust::Error` for
    /// transport-level failures.
    static KclResult run(const std::string& code, const Options& options = {})
    {
        return exec(code, {}, options);
    }

    /// Multi-file variant of `run` (kcl-go `RunFiles`).
    static KclResult run_files(const std::vector<std::string>& paths, const Options& options = {})
    {
        return exec({}, paths, options);
    }

    /// Validate `data` (JSON/YAML string) against the schema `code`.
    /// Throws `KclError` on validation errors, returns the success flag.
    static bool validate(const std::string& code, const std::string& data, const std::string& format = "yaml")
    {
        ValidateCodeArgs args;
        args.code = code;
        args.data = data;
        args.format = format;
        ValidateCodeResult result;
        try {
            result = validate_code(args);
        } catch (const KclError&) {
            throw;
        } catch (const std::exception& err) {
            throw KclError(err.what());
        }
        if (!result.err_message.empty()) {
            throw KclError(std::string(result.err_message));
        }
        return result.success;
    }

private:
    static std::string join_path(const std::string& dir, const std::string& path)
    {
        if (dir.empty() || dir == ".") {
            return path;
        }
        if (!dir.empty() && dir.back() == '/') {
            return dir + path;
        }
        return dir + "/" + path;
    }

    // Settings-file `${PWD}` expansion + relative path resolution, following
    // the Python/Java facades: relative entries are resolved against the
    // work dir so a settings file can live next to the sources it names.
    static std::string resolve_settings_file(std::string path, const std::string& work_dir)
    {
        if (path.empty()) {
            return path;
        }
        std::string pwd_token = "${PWD}";
        size_t pos = 0;
        while ((pos = path.find(pwd_token, pos)) != std::string::npos) {
            path.replace(pos, pwd_token.size(), work_dir);
            pos += work_dir.size();
        }
        bool absolute = !path.empty() && path.front() == '/';
#ifdef _WIN32
        absolute = absolute || (path.size() > 2 && path[1] == ':');
#endif
        bool parameterized = path.find("${") != std::string::npos;
        if (!absolute && !parameterized && (path.front() == '.' || !work_dir.empty())) {
            return join_path(work_dir, path);
        }
        return path;
    }

    static void merge_settings(ExecProgramArgs& args, const Options& options, const std::string& work_dir)
    {
        LoadSettingsFilesArgs load_args;
        load_args.work_dir = work_dir;
        load_args.files = { options.settings };
        LoadSettingsFilesResult loaded = load_settings_files(load_args);
        if (loaded.kcl_cli_configs.has_value) {
            const CliConfig& config = loaded.kcl_cli_configs.value;
            for (const auto& file : config.files) {
                args.k_filename_list.push_back(resolve_settings_file(std::string(file), work_dir));
            }
            if (!config.output.empty()) {
                args.format = std::string(config.output);
            }
            for (const auto& override_spec : config.overrides) {
                args.overrides.push_back(std::string(override_spec));
            }
            for (const auto& selector : config.path_selector) {
                args.path_selector.push_back(std::string(selector));
            }
            if (config.strict_range_check) {
                args.strict_range_check = true;
            }
            if (config.disable_none) {
                args.disable_none = true;
            }
            if (config.verbose > 0) {
                args.verbose = static_cast<int32_t>(config.verbose);
            }
            if (config.debug) {
                args.debug = 1;
            }
            if (config.sort_keys) {
                args.sort_keys = true;
            }
            if (config.show_hidden) {
                args.show_hidden = true;
            }
            if (config.include_schema_type_path) {
                args.include_schema_type_path = true;
            }
            if (config.fast_eval) {
                args.fast_eval = true;
            }
        }
        for (const KeyValuePair& option : loaded.kcl_options) {
            Argument argument;
            argument.name = option.key;
            argument.value = option.value;
            args.args.push_back(std::move(argument));
        }
    }

    static ExecProgramArgs build_args(const std::string& code, const std::vector<std::string>& paths, const Options& options)
    {
        ExecProgramArgs args;
        const std::string work_dir = options.work_dir.empty() ? std::string(".") : options.work_dir;

        // 1. The settings file (if any) provides the base arguments.
        if (!options.settings.empty()) {
            merge_settings(args, options, work_dir);
        }

        // 2. Explicit options are layered on top with kcl-go's Merge
        //    semantics: repeated fields append, scalars overwrite last-wins.
        if (!options.work_dir.empty()) {
            args.work_dir = options.work_dir;
        }
        if (!options.format.empty()) {
            args.format = options.format;
        }
        if (!options.error_format.empty()) {
            args.error_format = options.error_format;
        }
        if (options.disable_none.has_value()) {
            args.disable_none = *options.disable_none;
        }
        if (options.sort_keys.has_value()) {
            args.sort_keys = *options.sort_keys;
        }
        if (options.show_hidden.has_value()) {
            args.show_hidden = *options.show_hidden;
        }
        // `full_type_path` implies `include_schema_type_path` (kcl-go
        // WithFullTypePath); otherwise only touch the flag when the caller
        // set it explicitly so settings-file values survive.
        if (options.full_type_path) {
            args.include_schema_type_path = true;
        } else if (options.include_schema_type_path.has_value()) {
            args.include_schema_type_path = *options.include_schema_type_path;
        }
        if (options.strict_range_check.has_value()) {
            args.strict_range_check = *options.strict_range_check;
        }
        if (options.verbose.has_value()) {
            args.verbose = *options.verbose;
        }
        if (options.debug.has_value()) {
            args.debug = *options.debug;
        }
        if (options.print_override_ast.has_value()) {
            args.print_override_ast = *options.print_override_ast;
        }
        if (options.disable_yaml_result.has_value()) {
            args.disable_yaml_result = *options.disable_yaml_result;
        }
        for (const auto& kv : options.args) {
            Argument argument;
            argument.name = kv.first;
            argument.value = kv.second;
            args.args.push_back(std::move(argument));
        }
        for (const auto& override_spec : options.overrides) {
            args.overrides.push_back(override_spec);
        }
        for (const auto& selector : options.selectors) {
            args.path_selector.push_back(selector);
        }
        for (const auto& pkg : options.external_pkgs) {
            ExternalPkg external_pkg;
            external_pkg.pkg_name = pkg.first;
            external_pkg.pkg_path = pkg.second;
            args.external_pkgs.push_back(std::move(external_pkg));
        }
        for (const auto& source : options.code) {
            args.k_code_list.push_back(source);
        }
        for (const auto& filename : options.filenames) {
            args.k_filename_list.push_back(filename);
        }

        // 3. The positional inputs are appended last, matching kcl-go's
        //    ParseArgs where the run paths merge after the user options.
        if (!code.empty()) {
            args.k_code_list.push_back(code);
        }
        for (const auto& path : paths) {
            args.k_filename_list.push_back(path);
        }

        if (args.k_filename_list.empty() && args.k_code_list.empty()) {
            throw KclError("kcl.Run: no kcl file or code");
        }
        return args;
    }

    static KclResult exec(const std::string& code, const std::vector<std::string>& paths, const Options& options)
    {
        ExecProgramArgs args;
        ExecProgramResult raw;
        try {
            args = build_args(code, paths, options);
            raw = exec_program(args);
        } catch (const KclError&) {
            throw;
        } catch (const std::exception& err) {
            // Native/transport failures from the cxx bridge (thrown as
            // rust::Error, a std::exception subclass this cxx version does
            // not expose in the public header) are unified with the facade's
            // own errors so callers only ever catch KclError (mirrors the
            // .NET/Java facades wrapping every failure in their
            // KclException).
            throw KclError(err.what());
        }
        if (!raw.err_message.empty()) {
            throw KclError(std::string(raw.err_message));
        }
        // kcl-go's typeAttributeHook: rewrite `_type` when the runtime was
        // asked to include schema type paths and the caller did not opt into
        // full type paths.
        bool shorten_type_paths = !options.full_type_path && args.include_schema_type_path;
        return KclResult(std::move(raw), shorten_type_paths);
    }
};

} // namespace kcl_lib
