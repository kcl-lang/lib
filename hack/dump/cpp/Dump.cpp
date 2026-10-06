/*
 * Dump.cpp — Cross-language AST dump for the C++ binding.
 *
 *   c++ -std=c++17 -Icpp/include -o dump Dump.cpp
 *
 * Runs the binding's real decoder (`kcl::ast::Module::from_json`) over the
 * shared capture and writes the tree in the shape
 * `hack/ast_diff/canonical.rb` compares.
 *
 * Why this file is a per-class walk rather than a reflection loop
 * ---------------------------------------------------------------
 *
 * Every other language with an AST package gets this for free: Ruby's
 * `Struct#members`, Dart's `dart:mirrors`, Java's `getDeclaredFields`,
 * Python's `dataclasses.fields`, Swift's `Mirror`. C++ has no runtime
 * reflection — no member enumeration, no field names, nothing to walk — so
 * the list of fields per class has to be written down here, once, by hand.
 *
 * That is the maintenance cost this file exists to pay, and it is worth
 * naming plainly: every field below is a *second* statement of what
 * `cpp/include/kcl_ast.hpp` declares, and the two can drift. The drift this
 * harness is built to catch is not the field *names* — `hack/
 * check_ast_field_types.rb` reads the header's source and catches those — it
 * is a field read at the wrong nesting level or off the wrong object, which
 * is why the same golden runs through this walk and through every other
 * binding's. If a field is renamed in the header and not here, the
 * comparison says so by name rather than passing quietly.
 *
 * So the rule this file follows: name every field, emit it under the *wire*
 * key, and never consult the JSON. The only thing this file knows about the
 * wire is the handful of shapes below, and each of them says why it is
 * shaped that way rather than quietly normalising it.
 *
 * The shapes that are not a plain field-for-field walk
 * ---------------------------------------------------
 *
 *   * `Node<T>` is a template, so one `dumpNode` covers every wrapper. It
 *     writes `node` and `pos`; the comparator's R2 hoists the nested
 *     position back onto the wrapper, which is where serde puts it.
 *   * `LiteralValue` and `NumberLitValue` are the tag+content enums behind
 *     an adjacently-tagged `value`. Both are one struct per *union* rather
 *     than one per arm, so only the active arm's fields are written —
 *     writing the other arms' defaults would report differences about data
 *     the decoder never touched.
 *   * `ExprContext` and the operator enums are scalars on the wire
 *     (`ctx: "Load"`), so they are written as their string value and not as
 *     a box.
 */

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <memory>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#include "kcl_ast.hpp"

using kcl::ast::Arguments;
using kcl::ast::ArgumentsExpr;
using kcl::ast::ArgumentsRef;
using kcl::ast::AssignStmt;
using kcl::ast::AssertStmt;
using kcl::ast::AugAssignStmt;
using kcl::ast::BinaryExpr;
using kcl::ast::CheckExpr;
using kcl::ast::CheckExprRef;
using kcl::ast::Comment;
using kcl::ast::CommentRef;
using kcl::ast::Compare;
using kcl::ast::CompClause;
using kcl::ast::CompClauseRef;
using kcl::ast::ConfigEntry;
using kcl::ast::ConfigEntryRef;
using kcl::ast::ConfigExpr;
using kcl::ast::ConfigIfEntryExpr;
using kcl::ast::Decorator;
using kcl::ast::DecoratorRef;
using kcl::ast::DictComp;
using kcl::ast::DictType;
using kcl::ast::Expr;
using kcl::ast::ExprRef;
using kcl::ast::FormattedValue;
using kcl::ast::FunctionType;
using kcl::ast::Identifier;
using kcl::ast::IdentifierExpr;
using kcl::ast::IdRef;
using kcl::ast::IfExpr;
using kcl::ast::IfStmt;
using kcl::ast::ImportStmt;
using kcl::ast::IndexSignatureRef;
using kcl::ast::JoinedString;
using kcl::ast::Keyword;
using kcl::ast::KeywordExpr;
using kcl::ast::KeywordRef;
using kcl::ast::LambdaExpr;
using kcl::ast::ListComp;
using kcl::ast::ListExpr;
using kcl::ast::ListIfItemExpr;
using kcl::ast::ListType;
using kcl::ast::LiteralType;
using kcl::ast::MissingExpr;
using kcl::ast::Module;
using kcl::ast::NameConstantLit;
using kcl::ast::Node;
using kcl::ast::NumberLit;
using kcl::ast::ParenExpr;
using kcl::ast::Pos;
using kcl::ast::QuantExpr;
using kcl::ast::RuleStmt;
using kcl::ast::SchemaAttr;
using kcl::ast::SchemaConfig;
using kcl::ast::SchemaConfigRef;
using kcl::ast::SchemaExpr;
using kcl::ast::SchemaIndexSignature;
using kcl::ast::SchemaStmt;
using kcl::ast::SelectorExpr;
using kcl::ast::StarredExpr;
using kcl::ast::Stmt;
using kcl::ast::StmtRef;
using kcl::ast::StrRef;
using kcl::ast::StringLit;
using kcl::ast::Subscript;
using kcl::ast::Target;
using kcl::ast::TargetExpr;
using kcl::ast::TargetRef;
using kcl::ast::Type;
using kcl::ast::TypeAliasStmt;
using kcl::ast::TypeRef;
using kcl::ast::UnaryExpr;
using kcl::ast::UnionType;
using kcl::ast::UnificationStmt;

// ---------------------------------------------------------------------------
// A minimal ordered JSON value.
//
// Order is only for the reader; the comparator is key-driven. It is *not* a
// general-purpose JSON library: it holds exactly what a decoded AST can
// contain, which is why there is no `operator[]` and no implicit conversion
// to get wrong.
// ---------------------------------------------------------------------------

struct JValue;
using JPtr = std::shared_ptr<JValue>;

struct JValue {
    enum class Kind { Null, Bool, Int, Double, Str, Arr, Obj };

    Kind kind = Kind::Null;
    bool boolean = false;
    long long integer = 0;
    double number = 0.0;
    std::string text;
    std::vector<JPtr> arr;
    std::vector<std::pair<std::string, JPtr>> obj;
};

JPtr JNull()
{
    auto v = std::make_shared<JValue>();
    v->kind = JValue::Kind::Null;
    return v;
}

JPtr JBool(bool b)
{
    auto v = std::make_shared<JValue>();
    v->kind = JValue::Kind::Bool;
    v->boolean = b;
    return v;
}

JPtr JInt(long long i)
{
    auto v = std::make_shared<JValue>();
    v->kind = JValue::Kind::Int;
    v->integer = i;
    return v;
}

JPtr JDouble(double d)
{
    auto v = std::make_shared<JValue>();
    v->kind = JValue::Kind::Double;
    v->number = d;
    return v;
}

JPtr JStr(std::string s)
{
    auto v = std::make_shared<JValue>();
    v->kind = JValue::Kind::Str;
    v->text = std::move(s);
    return v;
}

JPtr JArr()
{
    auto v = std::make_shared<JValue>();
    v->kind = JValue::Kind::Arr;
    return v;
}

JPtr JObj()
{
    auto v = std::make_shared<JValue>();
    v->kind = JValue::Kind::Obj;
    return v;
}

/// Append a key. `put` rather than an indexer so that writing the same field
/// twice is a visible accident in review rather than a silent overwrite.
void put(const JPtr& o, const char* key, JPtr value)
{
    o->obj.emplace_back(key, std::move(value));
}

/// The `@cls` / `@tag` envelope every named object carries.
///
/// `@cls` is the class name verbatim, and `@tag` is the binding's own claim
/// about which variant it decoded — here `Expr::tag()`, which is a virtual
/// the header defines. The comparator checks both against CLASS_TAGS and
/// against the golden, so a decoder that returns the right *value* under the
/// wrong class is still caught.
///
/// `tag` is null for the plain structs. Rust declares those as structs
/// rather than enum variants, so there is no wire tag to claim, and claiming
/// one would put a `type` key on every DTO in the file.
JPtr envelope(const char* cls, const char* tag)
{
    JPtr o = JObj();
    put(o, "@cls", JStr(cls));
    if (tag != nullptr) {
        put(o, "@tag", JStr(tag));
    }
    return o;
}

// ---------------------------------------------------------------------------
// Serialisation
// ---------------------------------------------------------------------------

void writeEscaped(const std::string& s, std::string& out)
{
    for (unsigned char ch : s) {
        switch (ch) {
        case '"': out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\n': out += "\\n"; break;
        case '\r': out += "\\r"; break;
        case '\t': out += "\\t"; break;
        case '\b': out += "\\b"; break;
        case '\f': out += "\\f"; break;
        default:
            if (ch < 0x20) {
                char buf[8];
                std::snprintf(buf, sizeof(buf), "\\u%04x", ch);
                out += buf;
            } else {
                out.push_back(static_cast<char>(ch));
            }
        }
    }
}

/// A double that round-trips.
///
/// `%.17g` always round-trips but prints `1.5` as `1.5` only by luck of the
/// format, and the golden has exact values (`1.5`, `0.0`) that Ruby parses
/// back as Floats and compares for equality. So the precision is raised from
/// 1 until the text reads back as the same double — the shortest
/// representation that survives, which is what both the wire and every other
/// dumper in this harness print.
std::string formatDouble(double d)
{
    char buf[64];
    for (int precision = 1; precision <= 17; ++precision) {
        std::snprintf(buf, sizeof(buf), "%.*g", precision, d);
        if (std::strtod(buf, nullptr) == d) {
            return buf;
        }
    }
    return buf;
}

void write(const JPtr& v, std::string& out, int indent)
{
    const std::string pad(static_cast<size_t>(indent) * 2, ' ');
    const std::string inner(static_cast<size_t>(indent + 1) * 2, ' ');

    switch (v->kind) {
    case JValue::Kind::Null:
        out += "null";
        return;
    case JValue::Kind::Bool:
        out += v->boolean ? "true" : "false";
        return;
    case JValue::Kind::Int:
        out += std::to_string(v->integer);
        return;
    case JValue::Kind::Double:
        out += formatDouble(v->number);
        return;
    case JValue::Kind::Str:
        out.push_back('"');
        writeEscaped(v->text, out);
        out.push_back('"');
        return;
    case JValue::Kind::Arr:
        if (v->arr.empty()) {
            out += "[]";
            return;
        }
        out += "[\n";
        for (size_t i = 0; i < v->arr.size(); ++i) {
            out += inner;
            write(v->arr[i], out, indent + 1);
            out += (i + 1 == v->arr.size()) ? "\n" : ",\n";
        }
        out += pad + "]";
        return;
    case JValue::Kind::Obj:
        if (v->obj.empty()) {
            out += "{}";
            return;
        }
        out += "{\n";
        for (size_t i = 0; i < v->obj.size(); ++i) {
            out += inner + "\"";
            writeEscaped(v->obj[i].first, out);
            out += "\": ";
            write(v->obj[i].second, out, indent + 1);
            out += (i + 1 == v->obj.size()) ? "\n" : ",\n";
        }
        out += pad + "}";
        return;
    }
}

// ---------------------------------------------------------------------------
// The walk
// ---------------------------------------------------------------------------

// Every overload is declared before the templates that call them, because a
// template body is only looked up against what was visible where it was
// *written* — and these all live in the global namespace, so argument-
// dependent lookup cannot find them in `kcl::ast` at the point of
// instantiation. The declarations are the walk's field list in one more
// sense: adding a class here is what makes the walk able to reach it.
JPtr dump(const std::string& v);
JPtr dump(bool v);
JPtr dump(const Pos& v);
JPtr dump(const Identifier& v);
JPtr dump(const Target& v);
JPtr dump(const kcl::ast::MemberOrIndex& v);
JPtr dump(const Keyword& v);
JPtr dump(const Arguments& v);
JPtr dump(const ConfigEntry& v);
JPtr dump(const SchemaIndexSignature& v);
JPtr dump(const Comment& v);
JPtr dump(const Decorator& v);
JPtr dump(const SchemaConfig& v);
JPtr dump(const CompClause& v);
JPtr dump(const CheckExpr& v);
JPtr dump(const kcl::ast::LiteralValue& v);
JPtr dump(const kcl::ast::NumberLitValue& v);
JPtr dump(const std::shared_ptr<Expr>& v);
JPtr dump(const std::shared_ptr<Stmt>& v);
JPtr dump(const std::shared_ptr<Type>& v);
JPtr dump(const Module& v);

/// Dump a `shared_ptr` payload, or null when it is null.
///
/// The three abstract bases (`Expr`, `Stmt`, `Type`) have their own overloads
/// because their payload cannot be dispatched from a base *reference* — the
/// `dump` that knows how to narrow them takes the pointer. Every concrete
/// type goes through the template. A non-template overload beats the
/// template, so `Node<Expr>` reaches the `Expr` one and `Node<Identifier>`
/// reaches the generic one.
template <typename T>
JPtr dumpPtr(const std::shared_ptr<T>& p)
{
    return p ? dump(*p) : JNull();
}

JPtr dumpPtr(const std::shared_ptr<Expr>& p);
JPtr dumpPtr(const std::shared_ptr<Stmt>& p);
JPtr dumpPtr(const std::shared_ptr<Type>& p);

/// Narrow a base pointer to a concrete variant, or null for a different one.
///
/// `kcl_ast.hpp` ships `as<T>()` for `Expr` and `Type` but not for `Stmt`,
/// so this walk does not depend on which base classes the header happens to
/// have narrowed: every branch below narrows the same way. The header's own
/// `as` is what a *caller* uses, and this is the same thing with the
/// overload set filled in.
template <typename T, typename Base>
std::shared_ptr<T> narrow(const std::shared_ptr<Base>& p)
{
    return std::dynamic_pointer_cast<T>(p);
}

JPtr dump(const std::string& v)
{
    return JStr(v);
}

JPtr dump(bool v)
{
    return JBool(v);
}

/// `Pos` — five scalars, and no `@cls`.
///
/// The comparator's R2 recognises a nested position by its key set, and
/// `hoist_pos` deliberately ignores `@`-prefixed keys, so an `@cls` here
/// would not make the object *un*recognisable — it would simply be dropped.
/// It is left off because the position is not a class in this AST, it is a
/// value that every wrapper carries.
JPtr dump(const Pos& v)
{
    JPtr o = JObj();
    put(o, "filename", JStr(v.filename));
    put(o, "line", JInt(v.line));
    put(o, "column", JInt(v.column));
    put(o, "end_line", JInt(v.end_line));
    put(o, "end_column", JInt(v.end_column));
    return o;
}

/// `NodeRef<T>` — the wrapper, for every `T`.
///
/// `node` is written even when it is null: a wrapper that was present with
/// no payload is a different thing from a field that was absent, and the
/// comparator's R3 treats a null and an absent key as equivalent *only*
/// because it cannot tell them apart — it must not be a licence to invent
/// one.
///
/// `pos` is written only when the wrapper carried position keys at all. That
/// is the distinction the header draws between a positioned `NodeRef<String>`
/// and an unpositioned one.
template <typename T>
JPtr dumpNode(const Node<T>& v)
{
    JPtr o = JObj();
    put(o, "node", dumpPtr(v.node));
    if (v.pos) {
        put(o, "pos", dump(*v.pos));
    }
    return o;
}

/// `Option<NodeRef<T>>` — an absent wrapper is a null, not an empty object.
template <typename T>
JPtr dumpOpt(const std::optional<Node<T>>& v)
{
    return v ? dumpNode(*v) : JNull();
}

template <typename V>
JPtr dumpList(const V& v)
{
    JPtr a = JArr();
    for (const auto& item : v) {
        a->arr.push_back(dump(item));
    }
    return a;
}

/// `Vec<Option<NodeRef<T>>>`.
///
/// The nulls occupy a slot and are written as nulls. `Arguments::defaults`
/// and `Arguments::ty_list` are index-aligned with `args`, so a list this
/// walk shortened would re-pair every later default with the wrong argument —
/// and would report agreement about a decode that never happened.
template <typename V>
JPtr dumpOptList(const V& v)
{
    JPtr a = JArr();
    for (const auto& item : v) {
        a->arr.push_back(item ? dumpNode(*item) : JNull());
    }
    return a;
}

/// A `Vec<NodeRef<T>>` of plain-struct payloads: `Vec<NodeRef<Keyword>>`,
/// `Vec<NodeRef<CallExpr>>` as decorators, `Vec<NodeRef<ConfigEntry>>`.
template <typename T>
JPtr dumpRefList(const std::vector<Node<T>>& v)
{
    JPtr a = JArr();
    for (const auto& item : v) {
        a->arr.push_back(dumpNode(item));
    }
    return a;
}

/// `Vec<NodeRef<Expr>>` / `Vec<NodeRef<Stmt>>` / `Vec<NodeRef<Type>>`.
template <typename T>
JPtr dumpNodeRefList(const std::vector<Node<T>>& v)
{
    JPtr a = JArr();
    for (const auto& item : v) {
        a->arr.push_back(dumpNode(item));
    }
    return a;
}

// -- plain structs ----------------------------------------------------------

/// `Identifier` — `a`, `pkg.a`.
///
/// Both a plain struct and the `Expr::Identifier` payload, so the class
/// claims no tag of its own; the comparator resolves `identifier` against
/// CLASS_TAGS, which lists it as ambiguous and lets the golden referee.
JPtr dump(const Identifier& v)
{
    JPtr o = envelope("Identifier", nullptr);
    put(o, "names", dumpRefList(v.names));
    put(o, "pkgpath", JStr(v.pkgpath));
    put(o, "ctx", JStr(kcl::ast::to_string(v.ctx)));
    return o;
}

/// `MemberOrIndex` — adjacently tagged, so the discriminator is a *value*
/// and the payload rides under `value`.
JPtr dump(const kcl::ast::MemberOrIndex& v)
{
    JPtr o = envelope("MemberOrIndex", v.type());
    if (v.member) {
        put(o, "value", dumpNode(*v.member));
    } else if (v.index) {
        put(o, "value", dumpNode(*v.index));
    } else {
        put(o, "value", JNull());
    }
    return o;
}

/// `Target` — a plain struct, no tag: `Vec<NodeRef<Target>>` is not an
/// `Expr` position.
JPtr dump(const Target& v)
{
    JPtr o = envelope("Target", nullptr);
    put(o, "name", dumpNode(v.name));
    put(o, "paths", dumpList(v.paths));
    put(o, "pkgpath", JStr(v.pkgpath));
    return o;
}

/// `Keyword` — plain struct; `arg` is a `NodeRef<Identifier>`, not a
/// `NodeRef<Expr>`, so reading it as one yields a zero-valued node and no
/// error.
JPtr dump(const Keyword& v)
{
    JPtr o = envelope("Keyword", nullptr);
    put(o, "arg", dumpNode(v.arg));
    put(o, "value", dumpOpt(v.value));
    return o;
}

/// `Arguments` — `defaults` and `ty_list` keep their nulls.
JPtr dump(const Arguments& v)
{
    JPtr o = envelope("Arguments", nullptr);
    put(o, "args", dumpRefList(v.args));
    put(o, "defaults", dumpOptList(v.defaults));
    put(o, "ty_list", dumpOptList(v.ty_list));
    return o;
}

/// `ConfigEntry` — `is_shorthand` is
/// `#[serde(skip_serializing_if = "is_false")]`, so the wire omits it when
/// false; the comparator's R5 says absent and `false` are the same value.
JPtr dump(const ConfigEntry& v)
{
    JPtr o = envelope("ConfigEntry", nullptr);
    put(o, "key", dumpOpt(v.key));
    put(o, "value", dumpNode(v.value));
    put(o, "operation", JStr(v.operation));
    put(o, "is_shorthand", JBool(v.is_shorthand));
    return o;
}

JPtr dump(const SchemaIndexSignature& v)
{
    JPtr o = envelope("SchemaIndexSignature", nullptr);
    put(o, "key_name", dumpOpt(v.key_name));
    put(o, "value", dumpOpt(v.value));
    put(o, "any_other", JBool(v.any_other));
    put(o, "key_ty", dumpNode(v.key_ty));
    put(o, "value_ty", dumpNode(v.value_ty));
    return o;
}

/// `Comment` — a plain struct with one `String` field, so the object under
/// `node` is `{"text": "…"}` and not the text itself. Reading it as a bare
/// string yields an empty comment and no error, which is the bug that
/// shipped in five bindings before this contract existed.
JPtr dump(const Comment& v)
{
    JPtr o = envelope("Comment", nullptr);
    put(o, "text", JStr(v.text));
    return o;
}

/// `Decorator` — a bare `CallExpr`: `{func, args, keywords}` with no `type`
/// key, because `Vec<NodeRef<CallExpr>>` is not an `Expr` position. It is a
/// class of its own so a caller can tell a decorator from a call expression
/// without comparing a `type` string one of them does not have.
JPtr dump(const Decorator& v)
{
    JPtr o = envelope("Decorator", nullptr);
    put(o, "func", dumpNode(v.func));
    put(o, "args", dumpRefList(v.args));
    put(o, "keywords", dumpRefList(v.keywords));
    return o;
}

/// `SchemaConfig` — the untagged twin of `SchemaExpr`, and the payload of
/// `UnificationStmt::value`, which is a `NodeRef<SchemaExpr>` over a *plain*
/// struct: the wire object there is `{name, args, kwargs, config}` with no
/// `type` key, so routing it through the tagged `Expr` decoder would look for
/// a discriminator that is not there.
JPtr dump(const SchemaConfig& v)
{
    JPtr o = envelope("SchemaConfig", nullptr);
    put(o, "name", dumpNode(v.name));
    put(o, "args", dumpRefList(v.args));
    put(o, "kwargs", dumpRefList(v.kwargs));
    put(o, "config", dumpNode(v.config));
    return o;
}

// -- Type -------------------------------------------------------------------

/// `LiteralTypeValue` — the tag+content enum *inside* `Type::Literal`, so
/// `value` is a second tagged document.
///
/// The four arms do not share a shape: `Int` wraps `{value, suffix}` while
/// `Float`, `Str` and `Bool` wrap a bare scalar. Only the active arm's
/// fields are written — the others hold their `LiteralValue` defaults, which
/// the decoder never wrote and which are not part of the payload.
JPtr dump(const kcl::ast::LiteralValue& v)
{
    switch (v.kind) {
    case kcl::ast::LiteralValue::Kind::Int: {
        // The payload's own `value` field, spread beside the arm's tag —
        // the comparator's R15, and the shape Swift models as
        // `IntLiteralType`.
        JPtr o = envelope("LiteralValue", "Int");
        put(o, "value", JInt(v.int_value));
        if (v.suffix) {
            put(o, "suffix", JStr(*v.suffix));
        }
        return o;
    }
    case kcl::ast::LiteralValue::Kind::Float: {
        JPtr o = envelope("LiteralValue", "Float");
        put(o, "value", JDouble(v.float_value));
        return o;
    }
    case kcl::ast::LiteralValue::Kind::Str: {
        JPtr o = envelope("LiteralValue", "Str");
        put(o, "value", JStr(v.str_value));
        return o;
    }
    case kcl::ast::LiteralValue::Kind::Bool: {
        JPtr o = envelope("LiteralValue", "Bool");
        put(o, "value", JBool(v.bool_value));
        return o;
    }
    }
    return JNull();
}

/// `NumberLitValue` — the tag+content enum inside `NumberLit`. Same union,
/// two arms, both bare scalars.
JPtr dump(const kcl::ast::NumberLitValue& v)
{
    if (v.kind == kcl::ast::NumberLitValue::Kind::Int) {
        JPtr o = envelope("NumberLitValue", "Int");
        put(o, "value", JInt(v.int_value));
        return o;
    }
    JPtr o = envelope("NumberLitValue", "Float");
    put(o, "value", JDouble(v.float_value));
    return o;
}

JPtr dump(const std::shared_ptr<Type>& v)
{
    if (!v) {
        return JNull();
    }

    // `Type` is `#[serde(tag = "type", content = "value")]` — adjacently
    // tagged — so the discriminator names the *shape* and the payload rides
    // under `value`. Each variant here holds that payload as its own fields,
    // which is what the comparator's R7 compares through. `Any` is the only
    // unit variant and carries no payload at all.

    if (auto p = narrow<kcl::ast::AnyType>(v)) {
        return envelope("AnyType", p->tag());
    }
    if (auto p = narrow<kcl::ast::BasicType>(v)) {
        // The wire calls this scalar `value`; the header calls it `name`,
        // which reads better at the call site. R7 (iii) matches a scalar
        // payload against a single differently-named field, and only when the
        // two values are equal.
        JPtr o = envelope("BasicType", p->tag());
        put(o, "name", JStr(p->name));
        return o;
    }
    if (auto p = narrow<kcl::ast::NamedType>(v)) {
        // `Named(Identifier)` inlines the newtype, so the payload is a bare
        // `{names, pkgpath, ctx}` object held in one field. R7 (ii).
        JPtr o = envelope("NamedType", p->tag());
        put(o, "identifier", dump(p->identifier));
        return o;
    }
    if (auto p = narrow<kcl::ast::ListType>(v)) {
        JPtr o = envelope("ListType", p->tag());
        put(o, "inner_type", dumpOpt(p->inner_type));
        return o;
    }
    if (auto p = narrow<kcl::ast::DictType>(v)) {
        JPtr o = envelope("DictType", p->tag());
        put(o, "key_type", dumpOpt(p->key_type));
        put(o, "value_type", dumpOpt(p->value_type));
        return o;
    }
    if (auto p = narrow<kcl::ast::UnionType>(v)) {
        // The field keeps the Rust name, so the wire key and the C++ name
        // agree and no rename is needed.
        JPtr o = envelope("UnionType", p->tag());
        put(o, "type_elements", dumpNodeRefList(p->type_elements));
        return o;
    }
    if (auto p = narrow<kcl::ast::LiteralType>(v)) {
        JPtr o = envelope("LiteralType", p->tag());
        put(o, "value", dump(p->value));
        return o;
    }
    if (auto p = narrow<kcl::ast::FunctionType>(v)) {
        // `params_ty` is an `Option<Vec<…>>`, so an absent list and an empty
        // one both mean "no parameters" and both are an empty vector here.
        // That is the signed-off normalisation the report names as R4.
        JPtr o = envelope("FunctionType", p->tag());
        put(o, "params_ty", dumpNodeRefList(p->params_ty));
        put(o, "ret_ty", dumpOpt(p->ret_ty));
        return o;
    }

    throw kcl::ast::AstError(std::string("cpp dump: an unknown Type variant, tag ")
                             + v->tag());
}

// -- Expr -------------------------------------------------------------------

JPtr dumpPtr(const std::shared_ptr<Expr>& p)
{
    return dump(p);
}

JPtr dumpPtr(const std::shared_ptr<Stmt>& p)
{
    return dump(p);
}

JPtr dumpPtr(const std::shared_ptr<Type>& p)
{
    return dump(p);
}

JPtr dump(const CompClause& v)
{
    JPtr o = envelope("CompClause", v.tag());
    put(o, "targets", dumpRefList(v.targets));
    put(o, "iter", dumpNode(v.iter));
    put(o, "ifs", dumpRefList(v.ifs));
    return o;
}

JPtr dump(const CheckExpr& v)
{
    JPtr o = envelope("CheckExpr", v.tag());
    put(o, "test", dumpNode(v.test));
    put(o, "if_cond", dumpOpt(v.if_cond));
    put(o, "msg", dumpOpt(v.msg));
    return o;
}

JPtr dump(const std::shared_ptr<Expr>& v)
{
    if (!v) {
        return JNull();
    }

    // `Stmt` and `Expr` are `#[serde(tag = "type")]` with no `rename_all`,
    // so the wire tag is the variant name verbatim and the newtype payloads
    // are *flattened* into the same object: there is no `call` wrapper key to
    // descend through. Where the header keeps a payload in a field of its
    // own — `IdentifierExpr::identifier`, `TargetExpr::target`,
    // `NumberLit::value` — the comparator's R8 compares through it, and only
    // when the field's keys cover the golden's.

    if (auto p = narrow<TargetExpr>(v)) {
        JPtr o = envelope("TargetExpr", p->tag());
        put(o, "target", dump(p->target));
        return o;
    }
    if (auto p = narrow<IdentifierExpr>(v)) {
        JPtr o = envelope("IdentifierExpr", p->tag());
        put(o, "identifier", dump(p->identifier));
        return o;
    }
    if (auto p = narrow<UnaryExpr>(v)) {
        JPtr o = envelope("UnaryExpr", p->tag());
        put(o, "op", JStr(p->op));
        put(o, "operand", dumpNode(p->operand));
        return o;
    }
    if (auto p = narrow<BinaryExpr>(v)) {
        JPtr o = envelope("BinaryExpr", p->tag());
        put(o, "left", dumpNode(p->left));
        put(o, "op", JStr(p->op));
        put(o, "right", dumpNode(p->right));
        return o;
    }
    if (auto p = narrow<IfExpr>(v)) {
        JPtr o = envelope("IfExpr", p->tag());
        put(o, "body", dumpNode(p->body));
        put(o, "cond", dumpNode(p->cond));
        put(o, "orelse", dumpNode(p->orelse));
        return o;
    }
    if (auto p = narrow<SelectorExpr>(v)) {
        JPtr o = envelope("SelectorExpr", p->tag());
        put(o, "value", dumpNode(p->value));
        put(o, "attr", dumpNode(p->attr));
        put(o, "ctx", JStr(kcl::ast::to_string(p->ctx)));
        put(o, "has_question", JBool(p->has_question));
        return o;
    }
    if (auto p = narrow<kcl::ast::CallExpr>(v)) {
        // A `CallExpr` reached as an `Expr` *is* tagged; the same three
        // fields reached as a `Decorator` are not. One class serves both
        // roles, so CLASS_TAGS lists it as ambiguous and the golden decides.
        JPtr o = envelope("CallExpr", p->tag());
        put(o, "func", dumpNode(p->func));
        put(o, "args", dumpRefList(p->args));
        put(o, "keywords", dumpRefList(p->keywords));
        return o;
    }
    if (auto p = narrow<ParenExpr>(v)) {
        JPtr o = envelope("ParenExpr", p->tag());
        put(o, "expr", dumpNode(p->expr));
        return o;
    }
    if (auto p = narrow<QuantExpr>(v)) {
        JPtr o = envelope("QuantExpr", p->tag());
        put(o, "target", dumpNode(p->target));
        put(o, "variables", dumpRefList(p->variables));
        put(o, "op", JStr(p->op));
        put(o, "test", dumpNode(p->test));
        put(o, "if_cond", dumpOpt(p->if_cond));
        put(o, "ctx", JStr(kcl::ast::to_string(p->ctx)));
        return o;
    }
    if (auto p = narrow<ListExpr>(v)) {
        JPtr o = envelope("ListExpr", p->tag());
        put(o, "elts", dumpRefList(p->elts));
        put(o, "ctx", JStr(kcl::ast::to_string(p->ctx)));
        return o;
    }
    if (auto p = narrow<ListIfItemExpr>(v)) {
        JPtr o = envelope("ListIfItemExpr", p->tag());
        put(o, "if_cond", dumpNode(p->if_cond));
        put(o, "exprs", dumpRefList(p->exprs));
        put(o, "orelse", dumpOpt(p->orelse));
        return o;
    }
    if (auto p = narrow<ListComp>(v)) {
        JPtr o = envelope("ListComp", p->tag());
        put(o, "elt", dumpNode(p->elt));
        put(o, "generators", dumpRefList(p->generators));
        return o;
    }
    if (auto p = narrow<StarredExpr>(v)) {
        JPtr o = envelope("StarredExpr", p->tag());
        put(o, "value", dumpNode(p->value));
        put(o, "ctx", JStr(kcl::ast::to_string(p->ctx)));
        return o;
    }
    if (auto p = narrow<DictComp>(v)) {
        JPtr o = envelope("DictComp", p->tag());
        // `entry` is a bare `ConfigEntry` — no `key`/`value` pair on the node
        // itself, and no `NodeRef` around it, so it has no position.
        put(o, "entry", dump(p->entry));
        put(o, "generators", dumpRefList(p->generators));
        return o;
    }
    if (auto p = narrow<ConfigIfEntryExpr>(v)) {
        JPtr o = envelope("ConfigIfEntryExpr", p->tag());
        put(o, "if_cond", dumpNode(p->if_cond));
        put(o, "items", dumpRefList(p->items));
        put(o, "orelse", dumpOpt(p->orelse));
        return o;
    }
    if (auto p = narrow<CompClause>(v)) {
        return dump(*p);
    }
    if (auto p = narrow<SchemaExpr>(v)) {
        JPtr o = envelope("SchemaExpr", p->tag());
        put(o, "name", dumpNode(p->name));
        put(o, "args", dumpRefList(p->args));
        put(o, "kwargs", dumpRefList(p->kwargs));
        put(o, "config", dumpNode(p->config));
        return o;
    }
    if (auto p = narrow<ConfigExpr>(v)) {
        JPtr o = envelope("ConfigExpr", p->tag());
        put(o, "items", dumpRefList(p->items));
        return o;
    }
    if (auto p = narrow<CheckExpr>(v)) {
        return dump(*p);
    }
    if (auto p = narrow<LambdaExpr>(v)) {
        JPtr o = envelope("LambdaExpr", p->tag());
        // `lambda_plain` arrives as `"args": null`, which is a *different*
        // thing from an empty argument list, so the optional is kept.
        put(o, "args", dumpOpt(p->args));
        put(o, "body", dumpRefList(p->body));
        put(o, "return_ty", dumpOpt(p->return_ty));
        return o;
    }
    if (auto p = narrow<Subscript>(v)) {
        JPtr o = envelope("Subscript", p->tag());
        put(o, "value", dumpNode(p->value));
        put(o, "index", dumpOpt(p->index));
        put(o, "lower", dumpOpt(p->lower));
        put(o, "upper", dumpOpt(p->upper));
        put(o, "step", dumpOpt(p->step));
        put(o, "ctx", JStr(kcl::ast::to_string(p->ctx)));
        put(o, "has_question", JBool(p->has_question));
        return o;
    }
    if (auto p = narrow<KeywordExpr>(v)) {
        JPtr o = envelope("KeywordExpr", p->tag());
        put(o, "keyword", p->keyword ? dump(*p->keyword) : JNull());
        return o;
    }
    if (auto p = narrow<ArgumentsExpr>(v)) {
        JPtr o = envelope("ArgumentsExpr", p->tag());
        put(o, "arguments", p->arguments ? dump(*p->arguments) : JNull());
        return o;
    }
    if (auto p = narrow<Compare>(v)) {
        JPtr o = envelope("Compare", p->tag());
        put(o, "left", dumpNode(p->left));
        // `ops` and `comparators` are parallel arrays.
        JPtr ops = JArr();
        for (const auto& op : p->ops) {
            ops->arr.push_back(JStr(op));
        }
        put(o, "ops", ops);
        put(o, "comparators", dumpRefList(p->comparators));
        return o;
    }
    if (auto p = narrow<NumberLit>(v)) {
        JPtr o = envelope("NumberLit", p->tag());
        if (p->binary_suffix) {
            put(o, "binary_suffix", JStr(*p->binary_suffix));
        }
        put(o, "value", dump(p->value));
        return o;
    }
    if (auto p = narrow<StringLit>(v)) {
        JPtr o = envelope("StringLit", p->tag());
        put(o, "is_long_string", JBool(p->is_long_string));
        put(o, "raw_value", JStr(p->raw_value));
        put(o, "value", JStr(p->value));
        return o;
    }
    if (auto p = narrow<NameConstantLit>(v)) {
        // The payload is the variant *name* as a string — `"True"`, not
        // `true`.
        JPtr o = envelope("NameConstantLit", p->tag());
        put(o, "value", JStr(p->value));
        return o;
    }
    if (auto p = narrow<JoinedString>(v)) {
        JPtr o = envelope("JoinedString", p->tag());
        put(o, "is_long_string", JBool(p->is_long_string));
        put(o, "values", dumpRefList(p->values));
        put(o, "raw_value", JStr(p->raw_value));
        return o;
    }
    if (auto p = narrow<FormattedValue>(v)) {
        JPtr o = envelope("FormattedValue", p->tag());
        put(o, "is_long_string", JBool(p->is_long_string));
        put(o, "value", dumpNode(p->value));
        if (p->format_spec) {
            put(o, "format_spec", JStr(*p->format_spec));
        }
        return o;
    }
    if (auto p = narrow<MissingExpr>(v)) {
        // A unit struct: no fields at all.
        return envelope("MissingExpr", p->tag());
    }

    // There is no `Unknown*` fallback to land here: `Module::from_json`
    // throws `AstError` on a tag it does not know, the same as Java's
    // Jackson. A decoder that quietly produced a zero-valued node for a
    // mistyped tag is the failure this whole contract exists to catch, so
    // reaching this line means the header grew a variant without this walk.
    throw kcl::ast::AstError(std::string("cpp dump: an unknown Expr variant, tag ")
                             + v->tag());
}

// -- Stmt -------------------------------------------------------------------

JPtr dump(const std::shared_ptr<Stmt>& v)
{
    if (!v) {
        return JNull();
    }

    if (auto p = narrow<TypeAliasStmt>(v)) {
        JPtr o = envelope("TypeAliasStmt", p->tag());
        put(o, "type_name", dumpNode(p->type_name));
        put(o, "type_value", dumpNode(p->type_value));
        put(o, "ty", dumpNode(p->ty));
        return o;
    }
    if (auto p = narrow<kcl::ast::ExprStmt>(v)) {
        JPtr o = envelope("ExprStmt", p->tag());
        put(o, "exprs", dumpRefList(p->exprs));
        return o;
    }
    if (auto p = narrow<UnificationStmt>(v)) {
        JPtr o = envelope("UnificationStmt", p->tag());
        put(o, "target", dumpNode(p->target));
        put(o, "value", dumpNode(p->value));
        return o;
    }
    if (auto p = narrow<AssignStmt>(v)) {
        JPtr o = envelope("AssignStmt", p->tag());
        put(o, "targets", dumpRefList(p->targets));
        put(o, "value", dumpNode(p->value));
        put(o, "ty", dumpOpt(p->ty));
        return o;
    }
    if (auto p = narrow<AugAssignStmt>(v)) {
        JPtr o = envelope("AugAssignStmt", p->tag());
        put(o, "target", dumpNode(p->target));
        put(o, "value", dumpNode(p->value));
        put(o, "op", JStr(p->op));
        return o;
    }
    if (auto p = narrow<AssertStmt>(v)) {
        JPtr o = envelope("AssertStmt", p->tag());
        put(o, "test", dumpNode(p->test));
        put(o, "if_cond", dumpOpt(p->if_cond));
        put(o, "msg", dumpOpt(p->msg));
        return o;
    }
    if (auto p = narrow<IfStmt>(v)) {
        JPtr o = envelope("IfStmt", p->tag());
        // `orelse` is a list of *statements*, unlike `IfExpr::orelse` which
        // is one expression.
        put(o, "cond", dumpNode(p->cond));
        put(o, "body", dumpRefList(p->body));
        put(o, "orelse", dumpRefList(p->orelse));
        return o;
    }
    if (auto p = narrow<ImportStmt>(v)) {
        JPtr o = envelope("ImportStmt", p->tag());
        put(o, "path", dumpNode(p->path));
        put(o, "rawpath", JStr(p->rawpath));
        put(o, "name", JStr(p->name));
        put(o, "asname", dumpOpt(p->as_name));
        put(o, "pkg_name", JStr(p->pkg_name));
        return o;
    }
    if (auto p = narrow<SchemaAttr>(v)) {
        JPtr o = envelope("SchemaAttr", p->tag());
        // `doc` is a plain `String`, *not* a `NodeRef<String>`, so an
        // attribute with no docstring is `""` rather than no value.
        put(o, "doc", JStr(p->doc));
        put(o, "name", dumpNode(p->name));
        if (p->op) {
            put(o, "op", JStr(*p->op));
        }
        put(o, "value", dumpOpt(p->value));
        put(o, "is_optional", JBool(p->is_optional));
        put(o, "decorators", dumpRefList(p->decorators));
        put(o, "ty", dumpNode(p->ty));
        return o;
    }
    if (auto p = narrow<SchemaStmt>(v)) {
        JPtr o = envelope("SchemaStmt", p->tag());
        put(o, "doc", dumpOpt(p->doc));
        put(o, "name", dumpNode(p->name));
        put(o, "parent_name", dumpOpt(p->parent_name));
        put(o, "for_host_name", dumpOpt(p->for_host_name));
        put(o, "is_mixin", JBool(p->is_mixin));
        put(o, "is_protocol", JBool(p->is_protocol));
        put(o, "args", dumpOpt(p->args));
        put(o, "mixins", dumpRefList(p->mixins));
        put(o, "body", dumpRefList(p->body));
        put(o, "decorators", dumpRefList(p->decorators));
        put(o, "checks", dumpRefList(p->checks));
        put(o, "index_signature", dumpOpt(p->index_signature));
        return o;
    }
    if (auto p = narrow<RuleStmt>(v)) {
        JPtr o = envelope("RuleStmt", p->tag());
        put(o, "doc", dumpOpt(p->doc));
        put(o, "name", dumpNode(p->name));
        put(o, "parent_rules", dumpRefList(p->parent_rules));
        put(o, "decorators", dumpRefList(p->decorators));
        put(o, "checks", dumpRefList(p->checks));
        put(o, "args", dumpOpt(p->args));
        put(o, "for_host_name", dumpOpt(p->for_host_name));
        return o;
    }

    throw kcl::ast::AstError(std::string("cpp dump: an unknown Stmt variant, tag ")
                             + v->tag());
}

// -- Module -----------------------------------------------------------------

JPtr dump(const Module& v)
{
    JPtr o = envelope("Module", nullptr);
    put(o, "filename", JStr(v.filename));
    put(o, "doc", dumpOpt(v.doc));
    put(o, "body", dumpNodeRefList(v.body));
    put(o, "comments", dumpRefList(v.comments));
    return o;
}

// ---------------------------------------------------------------------------

int main(int argc, char** argv)
{
    if (argc != 3) {
        std::fprintf(stderr, "usage: dump <golden.json> <out.json>\n");
        return 2;
    }

    std::ifstream in(argv[1], std::ios::binary);
    if (!in) {
        std::fprintf(stderr, "cpp dump: cannot read %s\n", argv[1]);
        return 2;
    }
    std::ostringstream buffer;
    buffer << in.rdbuf();
    const std::string text = buffer.str();

    try {
        // The binding's own decoder, unmodified. If `from_json` raises on the
        // golden, that is the finding — the same signal java's Jackson
        // decoder gives, and the reason the exception is caught here only to
        // turn it into a non-zero exit and a message on stderr.
        const Module module = Module::from_json(text, "testdata/ast/alignment.json");

        JPtr doc = JObj();
        put(doc, "schema", JStr("kcl-ast-canonical/1"));
        put(doc, "binding", JStr("cpp"));
        put(doc, "mode", JStr("reflect"));
        put(doc, "root", dump(module));

        std::string out;
        write(doc, out, 0);
        out.push_back('\n');

        std::ofstream os(argv[2], std::ios::binary);
        if (!os) {
            std::fprintf(stderr, "cpp dump: cannot write %s\n", argv[2]);
            return 2;
        }
        os << out;
    } catch (const kcl::ast::AstError& e) {
        std::fprintf(stderr, "cpp dump: %s\n", e.what());
        return 1;
    } catch (const std::exception& e) {
        std::fprintf(stderr, "cpp dump: %s\n", e.what());
        return 1;
    }

    return 0;
}