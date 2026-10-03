/*
 * kcl_ast_json.hpp — the JSON reader behind `kcl_ast.hpp`.
 *
 * The typed AST in `kcl_ast.hpp` has to read the `ast_json` string the KCL
 * service produces, and it must do so with nothing but a C++17 toolchain:
 * this header is the whole dependency, which keeps the AST usable from a
 * translation unit that never touches the cxx bridge, the cxx-generated
 * header, or `nlohmann/json`. (`kcl_facade.hpp` has its own, nlohmann-aware
 * DOM; that one exists to re-emit runtime results with their key order
 * intact, and reusing it would drag the bridge in behind it.)
 *
 * The parser is a plain recursive descent over the JSON grammar — objects,
 * arrays, strings with `\uXXXX` escapes and surrogate pairs, numbers, and the
 * three literals. Object member order is preserved, and a number keeps its
 * raw token, so `1e3` does not come back as `1000.0`. Neither property is
 * load-bearing for the AST — the decoder looks members up by name and the
 * only numbers it reads are `Pos` line/column pairs and literal values — but
 * both are cheap here and both have bitten this repo's other JSON readers.
 *
 * Accessors are total: asking a string of a number yields `""`, asking an
 * object of an array yields `nullptr`. The AST decoder is written against
 * that, so a field the parser stops emitting decodes to its empty value
 * instead of throwing halfway through a document.
 */

#pragma once

#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace kcl {
namespace ast {
namespace json {

/// Thrown for input that is not well-formed JSON. `kcl_ast.hpp` re-throws
/// this as an `AstError` so callers only ever catch one type.
class ParseError : public std::runtime_error {
public:
    explicit ParseError(const std::string& message)
        : std::runtime_error(message)
    {
    }
};

class Value;

/// Object members in parser order, as `(key, value)` pairs.
using Members = std::vector<std::pair<std::string, Value>>;
/// Array elements in order.
using Items = std::vector<Value>;

/// A parsed JSON value.
class Value {
public:
    enum class Kind {
        Null,
        Bool,
        Number,
        String,
        Array,
        Object,
    };

    Value() = default;

    Kind kind() const { return kind_; }
    bool is_null() const { return kind_ == Kind::Null; }
    bool is_bool() const { return kind_ == Kind::Bool; }
    bool is_number() const { return kind_ == Kind::Number; }
    bool is_string() const { return kind_ == Kind::String; }
    bool is_array() const { return kind_ == Kind::Array; }
    bool is_object() const { return kind_ == Kind::Object; }

    /// `true`/`false`, or `false` for any other kind.
    bool as_bool() const { return kind_ == Kind::Bool && text_ == "true"; }

    /// The raw number token, or `""` for any other kind. Truncates towards
    /// zero and keeps only the leading integer run, so `1.5` reads as `1` —
    /// which is why the AST reads floats through {as_double}.
    long long as_int() const;

    /// The number as a double, or `0.0` for any other kind.
    double as_double() const;

    /// The string value, or `""` for any other kind.
    const std::string& as_string() const { return text_; }

    /// The elements, or an empty span for any other kind.
    const Items& as_array() const { return items_; }

    /// The members, or an empty span for any other kind.
    const Members& as_object() const { return members_; }

    /// Member lookup on an object; `nullptr` when this is not an object or
    /// the key is absent. An explicit `null` member is a hit — a
    /// `NodeRef` field the parser left empty is present-but-null, and the
    /// AST decoder tells that apart from an absent key.
    const Value* find(std::string_view key) const
    {
        if (kind_ != Kind::Object) {
            return nullptr;
        }
        for (const auto& member : members_) {
            if (member.first == key) {
                return &member.second;
            }
        }
        return nullptr;
    }

    /// Elements of an array, or an empty span for any other kind. The name
    /// says what it is for: the AST decodes every list field through it, and
    /// a list that is absent, null, or the wrong kind all decode to "empty"
    /// rather than to a crash.
    const Items& elements() const { return items_; }

    static Value make_null() { return Value(); }
    static Value make_bool(bool v);
    static Value make_number(std::string token) { return Value(Kind::Number, std::move(token)); }
    static Value make_string(std::string v) { return Value(Kind::String, std::move(v)); }
    static Value make_array(Items v);
    static Value make_object(Members v);

private:
    Kind kind_ = Kind::Null;
    /// The `true`/`false` literal, the raw number token, or the string value.
    std::string text_;
    Items items_;
    Members members_;

    explicit Value(Kind kind, std::string text)
        : kind_(kind)
        , text_(std::move(text))
    {
    }
};

inline Value Value::make_bool(bool v)
{
    return Value(Kind::Bool, v ? "true" : "false");
}

inline Value Value::make_array(Items v)
{
    Value out;
    out.kind_ = Kind::Array;
    out.items_ = std::move(v);
    return out;
}

inline Value Value::make_object(Members v)
{
    Value out;
    out.kind_ = Kind::Object;
    out.members_ = std::move(v);
    return out;
}

inline long long Value::as_int() const
{
    if (kind_ != Kind::Number) {
        return 0;
    }
    // `strtoll` stops at the first non-digit, which is the truncation the
    // doc comment promises: `1.5` -> 1, `-3` -> -3, `1e3` -> 1.
    return std::strtoll(text_.c_str(), nullptr, 10);
}

inline double Value::as_double() const
{
    if (kind_ != Kind::Number) {
        return 0.0;
    }
    return std::strtod(text_.c_str(), nullptr);
}

namespace detail {

/// Recursive-descent parser over the JSON grammar.
class Parser {
public:
    Parser(std::string_view text, std::string origin)
        : text_(text)
        , origin_(std::move(origin))
    {
    }

    Value parse_document()
    {
        skip_whitespace();
        Value out = parse_value(0);
        skip_whitespace();
        if (pos_ != text_.size()) {
            fail("trailing content after the top-level value");
        }
        return out;
    }

private:
    /// Bounds the recursion so a pathological document cannot exhaust the
    /// stack. The parser nests two levels per container in the deepest legal
    /// AST (a `Type` is a tagged document inside a tagged document), so a
    /// real capture never comes close.
    static constexpr int kMaxDepth = 256;

    std::string_view text_;
    std::string origin_;
    size_t pos_ = 0;

    [[noreturn]] void fail(const std::string& what) const
    {
        throw ParseError(origin_ + ": " + what + " at offset " + std::to_string(pos_));
    }

    bool eof() const { return pos_ >= text_.size(); }
    char peek() const { return eof() ? '\0' : text_[pos_]; }

    void skip_whitespace()
    {
        while (!eof()) {
            const char ch = text_[pos_];
            if (ch != ' ' && ch != '\t' && ch != '\n' && ch != '\r') {
                return;
            }
            pos_++;
        }
    }

    void expect(char ch)
    {
        if (eof() || text_[pos_] != ch) {
            fail(std::string("expected '") + ch + "'");
        }
        pos_++;
    }

    void expect_literal(std::string_view word)
    {
        if (text_.substr(pos_, word.size()) != word) {
            fail("expected '" + std::string(word) + "'");
        }
        pos_ += word.size();
    }

    Value parse_value(int depth)
    {
        if (depth > kMaxDepth) {
            fail("JSON nested too deeply");
        }
        if (eof()) {
            fail("unexpected end of input");
        }
        switch (peek()) {
        case '{':
            return parse_object(depth);
        case '[':
            return parse_array(depth);
        case '"':
            return Value::make_string(parse_string());
        case 't':
            expect_literal("true");
            return Value::make_bool(true);
        case 'f':
            expect_literal("false");
            return Value::make_bool(false);
        case 'n':
            expect_literal("null");
            return Value::make_null();
        default:
            return parse_number();
        }
    }

    Value parse_object(int depth)
    {
        expect('{');
        Members members;
        skip_whitespace();
        if (peek() == '}') {
            pos_++;
            return Value::make_object(std::move(members));
        }
        while (true) {
            skip_whitespace();
            if (peek() != '"') {
                fail("expected a member name");
            }
            std::string key = parse_string();
            skip_whitespace();
            expect(':');
            skip_whitespace();
            members.emplace_back(std::move(key), parse_value(depth + 1));
            skip_whitespace();
            if (peek() == ',') {
                pos_++;
                continue;
            }
            expect('}');
            return Value::make_object(std::move(members));
        }
    }

    Value parse_array(int depth)
    {
        expect('[');
        Items items;
        skip_whitespace();
        if (peek() == ']') {
            pos_++;
            return Value::make_array(std::move(items));
        }
        while (true) {
            skip_whitespace();
            items.push_back(parse_value(depth + 1));
            skip_whitespace();
            if (peek() == ',') {
                pos_++;
                continue;
            }
            expect(']');
            return Value::make_array(std::move(items));
        }
    }

    static void append_utf8(uint32_t code_point, std::string& out)
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

    uint32_t parse_hex4()
    {
        if (pos_ + 4 > text_.size()) {
            fail("truncated \\u escape");
        }
        uint32_t value = 0;
        for (int i = 0; i < 4; i++) {
            const char ch = text_[pos_++];
            value <<= 4;
            if (ch >= '0' && ch <= '9') {
                value |= static_cast<uint32_t>(ch - '0');
            } else if (ch >= 'a' && ch <= 'f') {
                value |= static_cast<uint32_t>(ch - 'a' + 10);
            } else if (ch >= 'A' && ch <= 'F') {
                value |= static_cast<uint32_t>(ch - 'A' + 10);
            } else {
                fail("invalid \\u escape");
            }
        }
        return value;
    }

    std::string parse_string()
    {
        expect('"');
        std::string out;
        while (true) {
            if (eof()) {
                fail("unterminated string");
            }
            const char ch = text_[pos_++];
            if (ch == '"') {
                return out;
            }
            if (ch != '\\') {
                out.push_back(ch);
                continue;
            }
            if (eof()) {
                fail("unterminated escape");
            }
            const char esc = text_[pos_++];
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
                uint32_t code = parse_hex4();
                // A high surrogate must be followed by its low half; the
                // pair encodes one code point above the BMP.
                if (code >= 0xD800 && code <= 0xDBFF && text_.substr(pos_, 2) == "\\u") {
                    const size_t mark = pos_;
                    pos_ += 2;
                    const uint32_t low = parse_hex4();
                    if (low >= 0xDC00 && low <= 0xDFFF) {
                        code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00);
                    } else {
                        pos_ = mark;
                    }
                }
                append_utf8(code, out);
                break;
            }
            default:
                fail("invalid escape");
            }
        }
    }

    Value parse_number()
    {
        const size_t start = pos_;
        if (peek() == '-') {
            pos_++;
        }
        while (!eof() && std::isdigit(static_cast<unsigned char>(peek())) != 0) {
            pos_++;
        }
        if (peek() == '.') {
            pos_++;
            while (!eof() && std::isdigit(static_cast<unsigned char>(peek())) != 0) {
                pos_++;
            }
        }
        if (peek() == 'e' || peek() == 'E') {
            pos_++;
            if (peek() == '+' || peek() == '-') {
                pos_++;
            }
            while (!eof() && std::isdigit(static_cast<unsigned char>(peek())) != 0) {
                pos_++;
            }
        }
        if (pos_ == start) {
            fail("expected a value");
        }
        return Value::make_number(std::string(text_.substr(start, pos_ - start)));
    }
};

} // namespace detail

/// Parse one JSON document.
///
/// @param text the document
/// @param origin a label for error messages, e.g. a file name
/// @throws ParseError when the document is not well-formed JSON
inline Value parse(std::string_view text, std::string_view origin = "json")
{
    detail::Parser parser(text, std::string(origin));
    return parser.parse_document();
}

} // namespace json
} // namespace ast
} // namespace kcl
