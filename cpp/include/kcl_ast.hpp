/*
 * kcl_ast.hpp — the typed KCL AST for C++.
 *
 * `kcl_lib::parse_file` hands back the parser's output as one JSON string.
 * `kcl_lib_ast.hpp` wraps that string in the C binding's C structs, which is
 * the right shape for a C caller and the wrong one for C++: unions,
 * `KCL_*_KIND` enums, macro-generated node wrappers, and a caller who has to
 * switch on a discriminant by hand. This header is the C++ equivalent of what
 * `java/`, `nodejs/`, `ruby/` and the rest carry — a tree of typed objects,
 * decoded once, with no untyped maps anywhere a caller has to look.
 *
 * ```cpp
 * auto parsed = kcl_lib::parse_file(args);
 * kcl::ast::Module module = kcl::ast::Module::from_json(parsed.ast_json);
 * for (const auto* schema : module.schemas()) {
 *     for (const auto& line : schema->body) {
 *         if (auto attr = kcl::ast::as<kcl::ast::SchemaAttr>(line.node)) {
 *             if (attr->name.node)
 *                 std::puts(attr->name.node->c_str());
 *         }
 *     }
 * }
 * ```
 *
 * The wire contract
 * -----------------
 * Everything below is pinned against `testdata/ast/alignment.json`, a golden
 * capture of the real parser's output for `testdata/ast/alignment.k`. Three
 * shapes are in play and they are easy to confuse:
 *
 *  1. `Stmt` and `Expr` are `#[serde(tag = "type")]` internally tagged, and
 *     their variants are newtypes over structs — so serde *flattens* the
 *     struct's fields into the same object. `Expr::Call(CallExpr)` arrives as
 *     `{"type":"Call","func":…,"args":[…],"keywords":[…]}`. There is no
 *     `call` wrapper key to descend through, which is why `CallExpr` here
 *     holds the fields directly.
 *
 *  2. `Type` is `#[serde(tag = "type", content = "value")]` — adjacently
 *     tagged. `{"type":"Basic","value":"Int"}`: the tag names the *shape*,
 *     not the variant, and the payload rides under `value`. `Any` is the one
 *     unit variant, so it is `{"type":"Any"}` with no `value` at all.
 *
 *  3. Plain untagged structs — `Identifier`, `Target`, `Keyword`,
 *     `Arguments`, `ConfigEntry`, `CheckExpr`, `CallExpr`/`Decorator`,
 *     `CompClause`, `SchemaExpr`/`SchemaConfig`, `SchemaIndexSignature`,
 *     `Comment`, `MemberOrIndex` — have no `type` key and cannot be
 *     dispatched on. Where Rust reuses one of them in both a tagged and an
 *     untagged position, Java's vocabulary splits them and so does this
 *     header: `CallExpr` (tagged) / `Decorator` (untagged) and `SchemaExpr`
 *     (tagged) / `SchemaConfig` (untagged, the `UnificationStmt.value`
 *     payload). `CompClause` and `CheckExpr` have no split, because they are
 *     only ever reached untagged in practice while still being `Expr`
 *     variants in the grammar.
 *
 * `NodeRef<T>` has optionality at *two* levels, and this header models both.
 * The wrapper itself may be absent — an `Option<NodeRef<T>>` serialises as
 * `null` — which is `std::optional<Node<T>>` at the field. A *present*
 * wrapper may still hold no value, which is `Node<T>::node` being empty. So
 * `Node<T>` keeps `node` (the payload) and `pos` (the position) separately,
 * and `Vec<Option<…>>` fields such as `Arguments::defaults` and
 * `Arguments::ty_list` keep their nulls: those lists are index-aligned with
 * `args`, and dropping a null moves every argument after it.
 *
 * `Comment` is a plain struct with one `String` field, so the object under
 * `node` is `{"text": "…"}` and not the text itself. Decoding it as a bare
 * string is silently wrong — it produces an empty comment rather than an
 * error — and that exact bug shipped in four bindings (lua, .NET, nodejs,
 * wasm) before this header checked for it.
 *
 * Unknown tags raise
 * ------------------
 * Java has no `Unknown*` variant: Jackson raises on a subtype it has not been
 * told about, so an unregistered tag is an exception. C++ can do the same, so
 * it does. {Module::from_json} throws {AstError} for a `type` tag this
 * header does not know, and for a tagged payload that arrives without one —
 * which is exactly the shape of "someone routed a plain struct through the
 * tagged decoder" and would otherwise decode to a zero-valued node and pass
 * every field-by-field assertion. A C++ binding is not obliged to degrade
 * gracefully, and matching Java keeps the vocabulary identical across
 * bindings, so the strict path is the one taken.
 */

#pragma once

#include <cstddef>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include "kcl_ast_json.hpp"

namespace kcl {
namespace ast {

/// Raised for any wire document this header cannot decode: malformed JSON, a
/// `type` tag it does not know, or a tagged payload that arrived without one.
class AstError : public std::runtime_error {
public:
    explicit AstError(const std::string& message)
        : std::runtime_error(message)
    {
    }
};

// ---------------------------------------------------------------------------
// Positions
// ---------------------------------------------------------------------------

/// The source range a node was parsed from. Rust's `Pos` is a tuple struct
/// that serialises as a flat object: the position keys sit on the `NodeRef`
/// wrapper itself, not in a nested `pos` object, so a decoder that looks for
/// `{"pos":{…}}` finds nothing.
struct Pos {
    std::string filename;
    long long line = 0;
    long long column = 0;
    long long end_line = 0;
    long long end_column = 0;
};

// ---------------------------------------------------------------------------
// NodeRef
// ---------------------------------------------------------------------------

/// A decoded `NodeRef<T>`: the payload, and the position it was parsed at.
///
/// `node` is empty when the wrapper was present but its payload was `null`.
/// That is a *different* thing from the field being absent, which the
/// holding type expresses as `std::nullopt` — see the file comment. `pos` is
/// unset when the wrapper carried no position keys at all, which is how
/// `NodeRef<String>` fields like `SchemaStmt::doc` arrive.
template <typename T>
class Node {
public:
    std::shared_ptr<T> node;
    std::optional<Pos> pos;

    /// True when the wrapper held a payload.
    bool has_value() const { return node != nullptr; }
    explicit operator bool() const { return has_value(); }

    T& operator*() { return *node; }
    const T& operator*() const { return *node; }
    T* operator->() { return node.get(); }
    const T* operator->() const { return node.get(); }
};

// ---------------------------------------------------------------------------
// Forward declarations and the reference aliases
// ---------------------------------------------------------------------------

struct Identifier;
struct Target;
struct Keyword;
struct Arguments;
struct ConfigEntry;
struct SchemaIndexSignature;
struct Comment;
struct Decorator;
struct SchemaConfig;
class CompClause;
class CheckExpr;
class Expr;
class Stmt;
class Type;

using StrRef = Node<std::string>;
using IdRef = Node<Identifier>;
using TargetRef = Node<Target>;
using KeywordRef = Node<Keyword>;
using ArgumentsRef = Node<Arguments>;
using ConfigEntryRef = Node<ConfigEntry>;
using CompClauseRef = Node<CompClause>;
using CheckExprRef = Node<CheckExpr>;
using CommentRef = Node<Comment>;
using DecoratorRef = Node<Decorator>;
using SchemaConfigRef = Node<SchemaConfig>;
using IndexSignatureRef = Node<SchemaIndexSignature>;
using ExprRef = Node<Expr>;
using StmtRef = Node<Stmt>;
using TypeRef = Node<Type>;

// ---------------------------------------------------------------------------
// ExprContext
// ---------------------------------------------------------------------------

/// `ExprContext` from `../kcl/crates/ast/src/ast.rs` — `Load` and `Store`
/// and nothing else. An identifier on the right of an assignment is `Store`,
/// everything else is `Load`; there is no `Del`.
enum class ExprContext {
    Load,
    Store,
};

inline const char* to_string(ExprContext context)
{
    return context == ExprContext::Store ? "Store" : "Load";
}

// ---------------------------------------------------------------------------
// Plain structs
// ---------------------------------------------------------------------------

/// `Identifier` — `a`, `b`, `_c`, `pkg.a`. The name is *not* a single field:
/// `names` is a list of `NodeRef<String>` and the identifier is the dotted
/// join of them, which is what {name()} returns.
struct Identifier {
    std::vector<StrRef> names;
    std::string pkgpath;
    ExprContext ctx = ExprContext::Load;

    /// The dotted name, e.g. `pkg.a` for `names == ["pkg", "a"]`.
    std::string name() const
    {
        std::string out;
        for (const auto& part : names) {
            if (!out.empty()) {
                out.push_back('.');
            }
            if (part.node) {
                out += *part.node;
            }
        }
        return out;
    }
};

/// `MemberOrIndex` — `a.b` or `b[0]`. Adjacently tagged (`{"type":…,"value":…}`),
/// and it is the one tagged union that is *not* an `Expr`: it appears as a
/// bare element of `Target::paths` with no `NodeRef` around it, so the member
/// name and the index expression are stored per arm and there is no position
/// on the element itself.
class MemberOrIndex {
public:
    enum class Kind {
        Member,
        Index,
    };

    Kind kind = Kind::Member;
    /// The `Member` arm: a `NodeRef<String>`, so it carries its own position.
    std::optional<StrRef> member;
    /// The `Index` arm: a `NodeRef<Expr>`.
    std::optional<ExprRef> index;

    /// The wire discriminator.
    const char* type() const { return kind == Kind::Index ? "Index" : "Member"; }

    bool is_member() const { return kind == Kind::Member; }
    bool is_index() const { return kind == Kind::Index; }
};

/// `Target` — the left-hand side of an assignment. A plain struct, so it
/// carries no tag and no position of its own inside a `Vec<NodeRef<Target>>`.
struct Target {
    StrRef name;
    std::vector<MemberOrIndex> paths;
    std::string pkgpath;
};

/// `Keyword` — `k = 3` inside a call. A plain struct, and `arg` is a
/// `NodeRef<Identifier>`, *not* a `NodeRef<Expr>`: the payload is
/// `{names, pkgpath, ctx}` and not a tagged node, so reading it as an
/// expression yields a zero-valued node rather than an error.
struct Keyword {
    IdRef arg;
    std::optional<ExprRef> value;
};

/// `Arguments` — a parameter list.
///
/// `defaults` and `ty_list` are `Vec<Option<NodeRef<…>>>`: index-aligned
/// with `args`, and the nulls occupy a slot. `lambda x: int = 1` has
/// `args: [x]`, `defaults: [null, 1]`, `ty_list: [null, Int]`, so dropping
/// the nulls would silently re-pair every argument with the wrong default.
struct Arguments {
    std::vector<IdRef> args;
    std::vector<std::optional<ExprRef>> defaults;
    std::vector<std::optional<TypeRef>> ty_list;
};

/// `ConfigEntry` — one `key = value` (or `key: value`) pair. A plain struct
/// with no tag, and `is_shorthand` is `#[serde(skip_serializing_if =
/// "is_false")]`, so the key is *absent* rather than explicitly `false` when
/// the entry is not ES6 shorthand.
struct ConfigEntry {
    std::optional<ExprRef> key;
    ExprRef value;
    /// `ConfigEntryOperation`: "Override" or "Union".
    std::string operation;
    bool is_shorthand = false;
};

/// `SchemaIndexSignature` — `[str]: int` inside a schema. A plain struct.
struct SchemaIndexSignature {
    std::optional<StrRef> key_name;
    std::optional<ExprRef> value;
    bool any_other = false;
    TypeRef key_ty;
    TypeRef value_ty;
};

/// `Comment` — `# text`.
///
/// A plain struct with a single `String` field, so the object under `node` is
/// `{"text": "…"}` and *not* the text itself. Four bindings (lua, .NET,
/// nodejs, wasm) read it as a bare string, which does not raise — it just
/// yields an empty comment. `Module::from_json` reads `node.text`.
struct Comment {
    std::string text;
};

/// `Decorator` — `@deprecated` on a schema, a rule or an attribute.
///
/// A plain `CallExpr`: `{func, args, keywords}` with no `type` key, because
/// `Vec<NodeRef<CallExpr>>` is not an `Expr` position. It has the same three
/// fields as {CallExpr} and exists as its own type so a caller switching on
/// the node kind can tell "this was a decorator payload" from "this was a
/// call expression" without comparing a `type` string that one of them does
/// not have.
struct Decorator {
    ExprRef func;
    std::vector<ExprRef> args;
    std::vector<KeywordRef> keywords;
};

/// `SchemaConfig` — `Person { name = "Alice" }`.
///
/// The untagged twin of {SchemaExpr}, and the payload type of
/// `UnificationStmt::value`, which is a `NodeRef<SchemaExpr>` on a *plain*
/// struct: the wire object there is `{name, args, kwargs, config}` with no
/// `type` key, so it must not be decoded through the tagged `Expr` path.
/// Same four fields, no discriminator.
struct SchemaConfig {
    IdRef name;
    std::vector<ExprRef> args;
    std::vector<KeywordRef> kwargs;
    ExprRef config;
};

// ---------------------------------------------------------------------------
// Type — adjacently tagged
// ---------------------------------------------------------------------------

/// Base of the `Type` hierarchy. `Type` is
/// `#[serde(tag = "type", content = "value")]`, so the discriminator names
/// the *shape* and the payload rides under `value`.
class Type {
public:
    virtual ~Type() = default;
    /// The `type` discriminator, which is the shape name: "Any", "Basic",
    /// "Named", "List", "Dict", "Union", "Literal", "Function".
    virtual const char* tag() const = 0;
};

/// `Type::Any` — the only unit variant, so it is `{"type":"Any"}` with no
/// `value` at all.
class AnyType final : public Type {
public:
    const char* tag() const override { return "Any"; }
};

/// `Type::Basic` — `{"type":"Basic","value":"Int"}`. The payload is a bare
/// string, one of Bool / Int / Float / Str, not an object.
class BasicType final : public Type {
public:
    const char* tag() const override { return "Basic"; }
    std::string name;
};

/// `Type::Named` — the `Identifier` newtype is inlined, so the payload is
/// `{names, pkgpath, ctx}` rather than something tagged.
class NamedType final : public Type {
public:
    const char* tag() const override { return "Named"; }
    Identifier identifier;
};

/// `Type::List` — `{"type":"List","value":{"inner_type":…}}`.
class ListType final : public Type {
public:
    const char* tag() const override { return "List"; }
    std::optional<TypeRef> inner_type;
};

/// `Type::Dict` — `{"type":"Dict","value":{"key_type":…,"value_type":…}}`.
/// Both are optional in Rust, so both stay optional here.
class DictType final : public Type {
public:
    const char* tag() const override { return "Dict"; }
    std::optional<TypeRef> key_type;
    std::optional<TypeRef> value_type;
};

/// `Type::Union` — `{"type":"Union","value":{"type_elements":[…]}}`. The
/// field keeps the Rust name, so the wire key and the C++ name agree.
class UnionType final : public Type {
public:
    const char* tag() const override { return "Union"; }
    std::vector<TypeRef> type_elements;
};

/// `LiteralTypeValue` — the *inner* tag+content enum of `Type::Literal`, so
/// `Type::Literal`'s `value` is a second tagged document. Its four arms do
/// not have the same shape: `Int` wraps `{value, suffix}`, `Float` and `Str`
/// wrap a bare scalar, and `Bool` wraps a bare boolean. Keeping them in one
/// struct with a `kind` is the only way to stay typed without inventing a
/// tag the wire does not have.
struct LiteralValue {
    enum class Kind {
        Int,
        Float,
        Str,
        Bool,
    };

    Kind kind = Kind::Int;
    /// Kind::Int — the literal's value. The Rust field is `i64`.
    long long int_value = 0;
    /// Kind::Int — `NumberBinarySuffix` (`n`, `u`, `m`, `k`, `Ki`, …).
    std::optional<std::string> suffix;
    /// Kind::Float.
    double float_value = 0.0;
    /// Kind::Str.
    std::string str_value;
    /// Kind::Bool.
    bool bool_value = false;
};

/// `Type::Literal` — `1 | 1.5 | "s" | True`.
class LiteralType final : public Type {
public:
    const char* tag() const override { return "Literal"; }
    LiteralValue value;
};

/// `Type::Function` — `(int, str) -> bool`. `params_ty` is an
/// `Option<Vec<…>>`, so an absent list and an empty one are both "no
/// parameters" and are represented by an empty vector.
class FunctionType final : public Type {
public:
    const char* tag() const override { return "Function"; }
    std::vector<TypeRef> params_ty;
    std::optional<TypeRef> ret_ty;
};

// ---------------------------------------------------------------------------
// Expr — internally tagged
// ---------------------------------------------------------------------------

/// Base of the internally tagged `Expr` hierarchy. See the file comment for
/// why the fields sit beside the `type` key rather than under it.
class Expr {
public:
    virtual ~Expr() = default;
    /// The `type` discriminator the parser emitted.
    virtual const char* tag() const = 0;
};

/// `Expr::Target(Target)` — a bare `Target`, flattened.
class TargetExpr final : public Expr {
public:
    const char* tag() const override { return "Target"; }
    Target target;
};

/// `Expr::Identifier(Identifier)` — the `Identifier` newtype is inlined.
class IdentifierExpr final : public Expr {
public:
    const char* tag() const override { return "Identifier"; }
    Identifier identifier;
};

/// `Expr::Unary` — `{op, operand}`. `UnaryOp` is one of
/// `{UAdd, USub, Invert, Not, LShift, RShift, BitAnd, BitOr, BitXor}`.
class UnaryExpr final : public Expr {
public:
    const char* tag() const override { return "Unary"; }
    std::string op;
    ExprRef operand;
};

/// `Expr::Binary` — `{left, op, right}`.
class BinaryExpr final : public Expr {
public:
    const char* tag() const override { return "Binary"; }
    ExprRef left;
    std::string op;
    ExprRef right;
};

/// `Expr::If` — the ternary `a if cond else b`. All three are plain
/// `NodeRef`s, never optional. `Stmt::If` is a different type with `orelse`
/// as a list of statements.
class IfExpr final : public Expr {
public:
    const char* tag() const override { return "If"; }
    ExprRef body;
    ExprRef cond;
    ExprRef orelse;
};

/// `Expr::Selector` — `a.b` and `a?.b`. `attr` is a `NodeRef<Identifier>`,
/// so the attribute is `{names, pkgpath, ctx}` and not a bare string, and
/// the optional-access flag is called `has_question` — there is no
/// `attr_name` field.
class SelectorExpr final : public Expr {
public:
    const char* tag() const override { return "Selector"; }
    ExprRef value;
    IdRef attr;
    ExprContext ctx = ExprContext::Load;
    bool has_question = false;
};

/// `Expr::Call` — `f(1, k = 3)`. `keywords` is a `Vec<NodeRef<Keyword>>`
/// over a plain struct, so each element is a `Node` wrapping an untagged
/// payload and `Keyword::arg` is an `Identifier`, not an `Expr`.
class CallExpr final : public Expr {
public:
    const char* tag() const override { return "Call"; }
    ExprRef func;
    std::vector<ExprRef> args;
    std::vector<KeywordRef> keywords;
};

/// `Expr::Paren` — the parenthesised expression is in a field called
/// `expr`, not `value`.
class ParenExpr final : public Expr {
public:
    const char* tag() const override { return "Paren"; }
    ExprRef expr;
};

/// `Expr::Quant` — `all v in target {…}`. `op` is a single
/// `QuantOperation` — one of `{All, Any, Filter, Map}` — and not a list,
/// and `variables` holds `Identifier`s rather than `Target`s.
class QuantExpr final : public Expr {
public:
    const char* tag() const override { return "Quant"; }
    ExprRef target;
    std::vector<IdRef> variables;
    std::string op;
    ExprRef test;
    std::optional<ExprRef> if_cond;
    ExprContext ctx = ExprContext::Load;
};

/// `Expr::List` — `[1, 2, 3]`.
class ListExpr final : public Expr {
public:
    const char* tag() const override { return "List"; }
    std::vector<ExprRef> elts;
    ExprContext ctx = ExprContext::Load;
};

/// `Expr::ListIfItem` — `{v for v in xs if v > 1} if cond else [...]`.
/// There is no `if_expr` field: the three are `if_cond`, `exprs` and
/// `orelse`, and `orelse` is a single optional expression rather than a list.
class ListIfItemExpr final : public Expr {
public:
    const char* tag() const override { return "ListIfItem"; }
    ExprRef if_cond;
    std::vector<ExprRef> exprs;
    std::optional<ExprRef> orelse;
};

/// `Expr::ListComp` — `[i for i in xs]`. There is no `cond` field; the
/// filter lives in the generator clause's `ifs`.
class ListComp final : public Expr {
public:
    const char* tag() const override { return "ListComp"; }
    ExprRef elt;
    std::vector<CompClauseRef> generators;
};

/// `Expr::Starred` — `*xs`.
class StarredExpr final : public Expr {
public:
    const char* tag() const override { return "Starred"; }
    ExprRef value;
    ExprContext ctx = ExprContext::Load;
};

/// `Expr::DictComp` — `{k: v for k, v in …}`. `entry` is a bare
/// `ConfigEntry` — there is no `key`/`value` pair on the node itself and no
/// `cond` — and it is not wrapped in a `NodeRef`, so the entry has no
/// position of its own.
class DictComp final : public Expr {
public:
    const char* tag() const override { return "DictComp"; }
    ConfigEntry entry;
    std::vector<CompClauseRef> generators;
};

/// `Expr::ConfigIfEntry` — the `if cond then … else …` arm of a config. It
/// hangs off a `ConfigEntry` whose `key` is null.
class ConfigIfEntryExpr final : public Expr {
public:
    const char* tag() const override { return "ConfigIfEntry"; }
    ExprRef if_cond;
    std::vector<ConfigEntryRef> items;
    std::optional<ExprRef> orelse;
};

/// `CompClause` — `i in xs if i > 1`.
///
/// A plain struct, so the generator list carries it untagged; it is also an
/// `Expr` variant (`Expr::CompClause`), which is why this is a class rather
/// than a struct. `targets` are `Identifier`s, and `iter` is required.
class CompClause final : public Expr {
public:
    const char* tag() const override { return "CompClause"; }
    std::vector<IdRef> targets;
    ExprRef iter;
    std::vector<ExprRef> ifs;
};

/// `Expr::Schema` — `Person { name = "Alice" }`. Tagged, so the four fields
/// sit beside the `type` key. The untagged twin is {SchemaConfig}.
class SchemaExpr final : public Expr {
public:
    const char* tag() const override { return "Schema"; }
    IdRef name;
    std::vector<ExprRef> args;
    std::vector<KeywordRef> kwargs;
    ExprRef config;
};

/// `Expr::Config` — `{a = 1, b: 2}`. `items` is
/// `Vec<NodeRef<ConfigEntry>>` over an untagged struct, and a `key` is
/// nullable — a `ConfigIfEntry` hangs off a null key.
class ConfigExpr final : public Expr {
public:
    const char* tag() const override { return "Config"; }
    std::vector<ConfigEntryRef> items;
};

/// `CheckExpr` — `len(attr) > 3 if attr, "Check failed message"`.
///
/// A plain struct, so `SchemaStmt::checks` and `RuleStmt::checks` hold it
/// untagged; it is also the `Expr::Check` variant, which is why this is a
/// class. `if_cond` and `msg` are the two optional fields — `test` is
/// required.
class CheckExpr final : public Expr {
public:
    const char* tag() const override { return "Check"; }
    ExprRef test;
    std::optional<ExprRef> if_cond;
    std::optional<ExprRef> msg;
};

/// `Expr::Lambda` — `lambda x: int -> int { x }`. `args` is an
/// `Option<NodeRef<Arguments>>`, so an absent list and a present-but-empty
/// one are different: `lambda_plain` arrives as `"args": null`. `body` is a
/// list of *statements*.
class LambdaExpr final : public Expr {
public:
    const char* tag() const override { return "Lambda"; }
    std::optional<ArgumentsRef> args;
    std::vector<StmtRef> body;
    std::optional<TypeRef> return_ty;
};

/// `Expr::Subscript` — `x[0]` and `x[0:2:1]`. A slice leaves `index` null
/// and fills `lower`/`upper`/`step`; `has_question` is the optional-access
/// flag `x?[0]`, and it is *also* on {SelectorExpr}, so the two are easy to
/// confuse by name alone.
class Subscript final : public Expr {
public:
    const char* tag() const override { return "Subscript"; }
    ExprRef value;
    std::optional<ExprRef> index;
    std::optional<ExprRef> lower;
    std::optional<ExprRef> upper;
    std::optional<ExprRef> step;
    ExprContext ctx = ExprContext::Load;
    bool has_question = false;
};

/// `Expr::Keyword` — the `Keyword` newtype flattened under a `type` key.
/// The parser does not emit this in the AST captures (keywords arrive inside
/// a call's `keywords` list, untagged), but the grammar allows it.
class KeywordExpr final : public Expr {
public:
    const char* tag() const override { return "Keyword"; }
    std::shared_ptr<Keyword> keyword;
};

/// `Expr::Arguments` — the {Arguments} struct under a `type` key. Likewise
/// grammar-only: arguments are reached through `LambdaExpr::args` and
/// `SchemaStmt::args`, untagged.
class ArgumentsExpr final : public Expr {
public:
    const char* tag() const override { return "Arguments"; }
    std::shared_ptr<Arguments> arguments;
};

/// `Expr::Compare` — `a < b <= 10`. `ops` and `comparators` are parallel
/// arrays and `ops` holds `CmpOp` values —
/// `{Eq, NotEq, Lt, LtE, Gt, GtE, Is, In, NotIn, Not, IsNot}`.
class Compare final : public Expr {
public:
    const char* tag() const override { return "Compare"; }
    ExprRef left;
    std::vector<std::string> ops;
    std::vector<ExprRef> comparators;
};

/// `NumberLitValue` — the tag+content enum inside `NumberLit`, so the tag is
/// the only thing telling an `1` from a `1.5`.
struct NumberLitValue {
    enum class Kind {
        Int,
        Float,
    };

    Kind kind = Kind::Int;
    /// Kind::Int — the Rust field is `i64`.
    long long int_value = 0;
    /// Kind::Float.
    double float_value = 0.0;
    /// `NumberBinarySuffix` (`n`, `u`, `m`, `k`, `K`, `M`, `G`, `T`, `P`,
    /// `Ki`, …) for a suffixed integer literal such as `1Ki`.
    std::optional<std::string> binary_suffix;
};

/// `Expr::NumberLit` — `1`, `1.5`, `1Ki`.
class NumberLit final : public Expr {
public:
    const char* tag() const override { return "NumberLit"; }
    std::optional<std::string> binary_suffix;
    NumberLitValue value;
};

/// `Expr::StringLit` — `"s"`. `raw_value` keeps the delimiters and `value`
/// does not; `is_long_string` distinguishes `"""…"""`.
class StringLit final : public Expr {
public:
    const char* tag() const override { return "StringLit"; }
    bool is_long_string = false;
    std::string raw_value;
    std::string value;
};

/// `Expr::NameConstantLit` — `True`, `False`, `None`, `Undefined`. The
/// payload is the variant *name* as a string, not a boolean: `"True"`, not
/// `true`.
class NameConstantLit final : public Expr {
public:
    const char* tag() const override { return "NameConstantLit"; }
    std::string value;
};

/// `Expr::JoinedString` — an f-string. `values` interleaves literal
/// segments with the interpolated ones, so a `FormattedValue` is not
/// necessarily the first element.
class JoinedString final : public Expr {
public:
    const char* tag() const override { return "JoinedString"; }
    bool is_long_string = false;
    std::vector<ExprRef> values;
    std::string raw_value;
};

/// `Expr::FormattedValue` — one `${…}` inside an f-string. The field is
/// called `format_spec`, not `spec`.
class FormattedValue final : public Expr {
public:
    const char* tag() const override { return "FormattedValue"; }
    bool is_long_string = false;
    ExprRef value;
    std::optional<std::string> format_spec;
};

/// `Expr::Missing` — the parser's placeholder for an absent expression. The
/// parser substitutes a plain `Identifier` named `missing` in the AST
/// captures, so this variant is grammar-only; it is here so a `Missing` tag
/// decodes to the right type rather than raising.
class MissingExpr final : public Expr {
public:
    const char* tag() const override { return "Missing"; }
};

/// Narrow a `std::shared_ptr<Expr>` to a concrete variant, returning null
/// when it is a different one. `as<CallExpr>(…)->args` instead of a
/// `switch` on a tag string.
template <typename T>
std::shared_ptr<T> as(const std::shared_ptr<Expr>& expr)
{
    return std::dynamic_pointer_cast<T>(expr);
}

/// True when `expr` decodes as the variant `T`.
template <typename T>
bool is(const std::shared_ptr<Expr>& expr)
{
    return std::dynamic_pointer_cast<T>(expr) != nullptr;
}

/// Narrow a `std::shared_ptr<Type>` to a concrete variant.
template <typename T>
std::shared_ptr<T> as(const std::shared_ptr<Type>& type)
{
    return std::dynamic_pointer_cast<T>(type);
}

// ---------------------------------------------------------------------------
// Stmt — internally tagged
// ---------------------------------------------------------------------------

/// Base of the internally tagged `Stmt` hierarchy.
class Stmt {
public:
    virtual ~Stmt() = default;
    /// The `type` discriminator the parser emitted.
    virtual const char* tag() const = 0;
};

/// `Stmt::TypeAlias` — `TInt = int`. The fields are `type_name` and
/// `type_value`, and `ty` is a `NodeRef<Type>` rather than an `Option`, so
/// it is always present.
class TypeAliasStmt final : public Stmt {
public:
    const char* tag() const override { return "TypeAlias"; }
    IdRef type_name;
    StrRef type_value;
    TypeRef ty;
};

/// `Stmt::Expr` — a bare expression statement.
class ExprStmt final : public Stmt {
public:
    const char* tag() const override { return "Expr"; }
    std::vector<ExprRef> exprs;
};

/// `Stmt::Unification` — `p = Person { name = "Carol" }`.
///
/// `target` is an `Identifier` and not a `Target`, so it has a `ctx` of
/// `Store`. `value` is a `NodeRef<SchemaExpr>` over a *plain* struct, so
/// the wire object has no `type` key and must be decoded as a
/// {SchemaConfig} — routing it through the tagged `Expr` decoder would look
/// for a `type` key that is not there.
class UnificationStmt final : public Stmt {
public:
    const char* tag() const override { return "Unification"; }
    IdRef target;
    SchemaConfigRef value;
};

/// `Stmt::Assign` — `x = 1`. `ty` is optional.
class AssignStmt final : public Stmt {
public:
    const char* tag() const override { return "Assign"; }
    std::vector<TargetRef> targets;
    ExprRef value;
    std::optional<TypeRef> ty;
};

/// `Stmt::AugAssign` — `a += 1`. `target` is a `Target` here, unlike
/// `UnificationStmt::target`.
class AugAssignStmt final : public Stmt {
public:
    const char* tag() const override { return "AugAssign"; }
    TargetRef target;
    ExprRef value;
    std::string op;
};

/// `Stmt::Assert` — `assert cond, "message"`. The same three fields as
/// {CheckExpr}, and all three are optional in practice.
class AssertStmt final : public Stmt {
public:
    const char* tag() const override { return "Assert"; }
    ExprRef test;
    std::optional<ExprRef> if_cond;
    std::optional<ExprRef> msg;
};

/// `Stmt::If` — `if cond { … } else { … }`. `orelse` is a list of
/// *statements*, unlike `IfExpr::orelse` which is one expression.
class IfStmt final : public Stmt {
public:
    const char* tag() const override { return "If"; }
    std::vector<StmtRef> body;
    ExprRef cond;
    std::vector<StmtRef> orelse;
};

/// `Stmt::Import` — `import data.cloud`. `path` is a `NodeRef<String>` and
/// so carries a position of its own; `asname` is an optional
/// `NodeRef<String>`, not an `Option<String>`.
class ImportStmt final : public Stmt {
public:
    const char* tag() const override { return "Import"; }
    StrRef path;
    std::string rawpath;
    std::string name;
    std::optional<StrRef> as_name;
    std::string pkg_name;
};

/// `SchemaAttr` — one line of a schema body. It is reached through
/// `SchemaStmt::body`, which is a `Vec<NodeRef<Stmt>>`, so it wears a `type`
/// key even though Rust models it as a statement.
///
/// `doc` is a plain `String`, *not* a `NodeRef<String>`, so an attribute
/// with no docstring decodes to `""` rather than to no value. `op` is
/// `Option<AugOp>` — it is set only for the augmented forms (`attr += 1`).
class SchemaAttr final : public Stmt {
public:
    const char* tag() const override { return "SchemaAttr"; }
    std::string doc;
    StrRef name;
    std::optional<std::string> op;
    std::optional<ExprRef> value;
    bool is_optional = false;
    std::vector<DecoratorRef> decorators;
    TypeRef ty;
};

/// `Stmt::Schema` — `schema Person { … }`. The docstring keeps its `"""`
/// delimiters: `parse_doc` clones `StringLit::raw_value`, not the unquoted
/// `value`.
class SchemaStmt final : public Stmt {
public:
    const char* tag() const override { return "Schema"; }
    std::optional<StrRef> doc;
    StrRef name;
    std::optional<IdRef> parent_name;
    std::optional<IdRef> for_host_name;
    bool is_mixin = false;
    bool is_protocol = false;
    std::optional<ArgumentsRef> args;
    std::vector<IdRef> mixins;
    std::vector<StmtRef> body;
    std::vector<DecoratorRef> decorators;
    std::vector<CheckExprRef> checks;
    std::optional<IndexSignatureRef> index_signature;
};

/// `Stmt::Rule` — `rule R { … }`. Like `SchemaStmt` it carries untagged
/// `Decorator` and `CheckExpr` payloads, and unlike it it has no
/// `parent_name`, `mixins`, `body` or `index_signature`.
class RuleStmt final : public Stmt {
public:
    const char* tag() const override { return "Rule"; }
    std::optional<StrRef> doc;
    StrRef name;
    std::vector<IdRef> parent_rules;
    std::vector<DecoratorRef> decorators;
    std::vector<CheckExprRef> checks;
    std::optional<ArgumentsRef> args;
    std::optional<IdRef> for_host_name;
};

// ---------------------------------------------------------------------------
// Module
// ---------------------------------------------------------------------------

/// `Module` — the abstract syntax tree of one KCL file.
class Module {
public:
    std::string filename;
    std::optional<StrRef> doc;
    std::vector<StmtRef> body;
    std::vector<CommentRef> comments;

    /// Decode the `ast_json` string returned by `kcl_lib::parse_file` or
    /// `kcl_lib::parse_program`.
    ///
    /// @throws AstError when the document is not JSON, or names a `type`
    ///   tag this header does not know — Java's Jackson does the same, and a
    ///   decoder that quietly produced a zero-valued node for a mistyped tag
    ///   is the failure this whole contract exists to catch.
    static Module from_json(const std::string& ast_json, const std::string& origin = "ast_json");

    /// The schemas declared at the top level of this file, mirroring Java's
    /// `Module.filterSchemaStmtFromModule`. The pointers stay valid as long
    /// as the module does.
    std::vector<const SchemaStmt*> schemas() const;

    /// The first top-level statement carrying `tag`, or null.
    const Stmt* find(const char* tag) const;
};

/// Decode the `ast_json` string returned by `kcl_lib::parse_program`.
///
/// The runtime emits either a bare array of modules or a
/// `{"root":…, "pkgs":{…}}` envelope, and both shapes are accepted.
///
/// @throws AstError on a document that is neither
inline std::vector<Module> parse_program_json(const std::string& program_json, const std::string& origin = "program_json");

// ---------------------------------------------------------------------------
// Decoder
// ---------------------------------------------------------------------------

namespace detail {

/// A source position, or none.
///
/// The position keys live on the `NodeRef` wrapper itself, so this reads
/// them off the wrapper. A wrapper with no `filename` key has no position at
/// all — that is what a `NodeRef<String>` field like `SchemaStmt::doc`
/// looks like, and it is how "positioned" and "unpositioned" are told apart.
inline std::optional<Pos> parse_pos(const json::Value& wrapper)
{
    const json::Value* filename = wrapper.find("filename");
    if (filename == nullptr) {
        return std::nullopt;
    }
    Pos pos;
    pos.filename = filename->as_string();
    const auto field = [&wrapper](const char* key) -> long long {
        const json::Value* value = wrapper.find(key);
        return value == nullptr ? 0 : value->as_int();
    };
    pos.line = field("line");
    pos.column = field("column");
    pos.end_line = field("end_line");
    pos.end_column = field("end_column");
    return pos;
}

/// The `type` discriminator, or a thrown error when there is none.
///
/// The absence of a `type` key is the shape of "a plain struct was routed
/// through a tagged decoder": a `UnificationStmt::value`, a `Decorator`, a
/// `ConfigEntry`. Decoding that as an `Unknown*` node — which is what four
/// bindings did before this contract existed — yields a zero-valued node and
/// no error, so this raises instead.
inline const std::string& require_tag(const json::Value& value, const char* what)
{
    const json::Value* tag = value.find("type");
    if (tag == nullptr || !tag->is_string()) {
        throw AstError(std::string(what) + " has no `type` discriminator; "
                        + "a plain struct was decoded through a tagged path");
    }
    return tag->as_string();
}

/// The string value of `key`, or `""` when it is absent or not a string.
inline std::string string_field(const json::Value& value, const char* key)
{
    const json::Value* found = value.find(key);
    return found == nullptr ? std::string() : found->as_string();
}

/// `key`'s value, or null when it is absent.
inline const json::Value* field(const json::Value& value, const char* key)
{
    return value.find(key);
}

/// A `NodeRef<Src>` object holding an object payload. `load` returns a
/// `shared_ptr<Src>`, so an abstract base (`Expr`, `Stmt`, `Type`) is fine —
/// the payload is always a concrete variant allocated by the caller.
template <typename Dst, typename Loader>
std::optional<Node<Dst>> parse_node(const json::Value* wire, Loader load)
{
    if (wire == nullptr || !wire->is_object()) {
        return std::nullopt;
    }
    Node<Dst> out;
    out.pos = parse_pos(*wire);
    const json::Value* inner = wire->find("node");
    if (inner != nullptr && inner->is_object()) {
        out.node = load(*inner);
    }
    return out;
}

/// A `Vec<NodeRef<Dst>>` field. Elements that are null are dropped, matching
/// the Rust type — unlike `Vec<Option<…>>`, which keeps them.
template <typename Dst, typename Loader>
std::vector<Node<Dst>> parse_node_list(const json::Value* array, Loader load)
{
    std::vector<Node<Dst>> out;
    if (array == nullptr || !array->is_array()) {
        return out;
    }
    for (const auto& item : array->as_array()) {
        if (auto node = parse_node<Dst>(&item, load)) {
            out.push_back(std::move(*node));
        }
    }
    return out;
}

/// A `Vec<Option<NodeRef<Dst>>>` field. The nulls occupy a slot: the lists
/// are index-aligned with the argument list they annotate, so dropping them
/// re-pairs every argument after the first default with the wrong default.
template <typename Dst, typename Loader>
std::vector<std::optional<Node<Dst>>> parse_opt_node_list(const json::Value* array, Loader load)
{
    std::vector<std::optional<Node<Dst>>> out;
    if (array == nullptr || !array->is_array()) {
        return out;
    }
    for (const auto& item : array->as_array()) {
        out.push_back(parse_node<Dst>(&item, load));
    }
    return out;
}

inline ExprContext parse_expr_context(const std::string& raw, const char* where)
{
    if (raw == "Load") {
        return ExprContext::Load;
    }
    if (raw == "Store") {
        return ExprContext::Store;
    }
    throw AstError(std::string(where) + ": ExprContext is Load or Store, got \"" + raw + "\"");
}

/// A `NodeRef<String>`: the payload is a bare JSON string rather than an
/// object, so it needs its own wrapper reader.
inline std::optional<StrRef> parse_string_node(const json::Value* wire)
{
    if (wire == nullptr || !wire->is_object()) {
        return std::nullopt;
    }
    StrRef out;
    out.pos = parse_pos(*wire);
    const json::Value* inner = wire->find("node");
    if (inner != nullptr && inner->is_string()) {
        out.node = std::make_shared<std::string>(inner->as_string());
    }
    return out;
}

/// A `Vec<NodeRef<String>>` field.
inline std::vector<StrRef> parse_string_node_list(const json::Value* array)
{
    std::vector<StrRef> out;
    if (array == nullptr || !array->is_array()) {
        return out;
    }
    for (const auto& item : array->as_array()) {
        if (auto node = parse_string_node(&item)) {
            out.push_back(std::move(*node));
        }
    }
    return out;
}

std::shared_ptr<Identifier> parse_identifier(const json::Value& value);
std::shared_ptr<MemberOrIndex> parse_member_or_index(const json::Value& value);
std::shared_ptr<Target> parse_target(const json::Value& value);
std::shared_ptr<Keyword> parse_keyword(const json::Value& value);
std::shared_ptr<Arguments> parse_arguments(const json::Value& value);
std::shared_ptr<ConfigEntry> parse_config_entry(const json::Value& value);
std::shared_ptr<CompClause> parse_comp_clause(const json::Value& value);
std::shared_ptr<SchemaIndexSignature> parse_schema_index_signature(const json::Value& value);
std::shared_ptr<Comment> parse_comment(const json::Value& value);
std::shared_ptr<Decorator> parse_decorator(const json::Value& value);
std::shared_ptr<SchemaConfig> parse_schema_config(const json::Value& value);
std::shared_ptr<Expr> parse_expr(const json::Value& value);
std::shared_ptr<Stmt> parse_stmt(const json::Value& value);
std::shared_ptr<Type> parse_type(const json::Value& value);
std::shared_ptr<CheckExpr> parse_check_expr(const json::Value& value);
std::shared_ptr<LiteralValue> parse_literal_value(const json::Value& value);
std::shared_ptr<NumberLitValue> parse_number_lit_value(const json::Value& value);
std::vector<Module> parse_modules(const json::Value& root, const std::string& origin);

// ---------------------------------------------------------------------------
// Plain structs
// ---------------------------------------------------------------------------

inline std::shared_ptr<Identifier> parse_identifier(const json::Value& value)
{
    auto out = std::make_shared<Identifier>();
    out->names = parse_string_node_list(field(value, "names"));
    out->pkgpath = string_field(value, "pkgpath");
    out->ctx = parse_expr_context(string_field(value, "ctx"), "Identifier.ctx");
    return out;
}

inline std::shared_ptr<MemberOrIndex> parse_member_or_index(const json::Value& value)
{
    auto out = std::make_shared<MemberOrIndex>();
    const std::string& tag = require_tag(value, "MemberOrIndex");
    if (tag == "Member") {
        out->kind = MemberOrIndex::Kind::Member;
        // The `Member` arm's payload is a `NodeRef<String>`, so it has a
        // position of its own; the `Index` arm's is a `NodeRef<Expr>`.
        out->member = parse_string_node(field(value, "value"));
    } else if (tag == "Index") {
        out->kind = MemberOrIndex::Kind::Index;
        out->index = parse_node<Expr>(field(value, "value"), parse_expr);
    } else {
        throw AstError("MemberOrIndex: unknown tag \"" + tag + "\"");
    }
    return out;
}

inline std::shared_ptr<Target> parse_target(const json::Value& value)
{
    auto out = std::make_shared<Target>();
    if (auto name = parse_string_node(field(value, "name"))) {
        out->name = std::move(*name);
    }
    // `paths` is a bare `Vec<MemberOrIndex>`: no NodeRef, so no position on
    // the elements themselves.
    if (const json::Value* paths = field(value, "paths"); paths != nullptr && paths->is_array()) {
        for (const auto& item : paths->as_array()) {
            out->paths.push_back(*parse_member_or_index(item));
        }
    }
    out->pkgpath = string_field(value, "pkgpath");
    return out;
}

inline std::shared_ptr<Keyword> parse_keyword(const json::Value& value)
{
    auto out = std::make_shared<Keyword>();
    if (auto arg = parse_node<Identifier>(field(value, "arg"), parse_identifier)) {
        out->arg = std::move(*arg);
    }
    out->value = parse_node<Expr>(field(value, "value"), parse_expr);
    return out;
}

inline std::shared_ptr<Arguments> parse_arguments(const json::Value& value)
{
    auto out = std::make_shared<Arguments>();
    out->args = parse_node_list<Identifier>(field(value, "args"), parse_identifier);
    out->defaults = parse_opt_node_list<Expr>(field(value, "defaults"), parse_expr);
    out->ty_list = parse_opt_node_list<Type>(field(value, "ty_list"), parse_type);
    return out;
}

inline std::shared_ptr<ConfigEntry> parse_config_entry(const json::Value& value)
{
    auto out = std::make_shared<ConfigEntry>();
    // `key` is nullable — a `ConfigIfEntry` hangs off a null key.
    out->key = parse_node<Expr>(field(value, "key"), parse_expr);
    if (auto value_ref = parse_node<Expr>(field(value, "value"), parse_expr)) {
        out->value = std::move(*value_ref);
    }
    out->operation = string_field(value, "operation");
    // `skip_serializing_if = "is_false"`, so the key is absent rather than
    // explicitly false for a non-shorthand entry.
    out->is_shorthand = field(value, "is_shorthand") != nullptr
        && field(value, "is_shorthand")->as_bool();
    return out;
}

inline std::shared_ptr<CompClause> parse_comp_clause(const json::Value& value)
{
    auto out = std::make_shared<CompClause>();
    out->targets = parse_node_list<Identifier>(field(value, "targets"), parse_identifier);
    if (auto iter = parse_node<Expr>(field(value, "iter"), parse_expr)) {
        out->iter = std::move(*iter);
    }
    out->ifs = parse_node_list<Expr>(field(value, "ifs"), parse_expr);
    return out;
}

inline std::shared_ptr<SchemaIndexSignature> parse_schema_index_signature(const json::Value& value)
{
    auto out = std::make_shared<SchemaIndexSignature>();
    out->key_name = parse_string_node(field(value, "key_name"));
    out->value = parse_node<Expr>(field(value, "value"), parse_expr);
    const json::Value* any_other = field(value, "any_other");
    out->any_other = any_other != nullptr && any_other->as_bool();
    if (auto key_ty = parse_node<Type>(field(value, "key_ty"), parse_type)) {
        out->key_ty = std::move(*key_ty);
    }
    if (auto value_ty = parse_node<Type>(field(value, "value_ty"), parse_type)) {
        out->value_ty = std::move(*value_ty);
    }
    return out;
}

inline std::shared_ptr<Comment> parse_comment(const json::Value& value)
{
    // A plain struct with one `String` field: the object under `node` is
    // `{"text": "…"}`. Reading it as a bare string — the bug four bindings
    // shipped — yields an empty comment with no error at all.
    auto out = std::make_shared<Comment>();
    out->text = string_field(value, "text");
    return out;
}

/// `CheckExpr` over an *untagged* payload — the `checks` list of a schema or
/// a rule. Same three fields as the `Check` expression variant; see
/// {CheckExpr}.
inline std::shared_ptr<CheckExpr> parse_check_expr(const json::Value& value)
{
    auto out = std::make_shared<CheckExpr>();
    if (auto test = parse_node<Expr>(field(value, "test"), parse_expr)) {
        out->test = std::move(*test);
    }
    out->if_cond = parse_node<Expr>(field(value, "if_cond"), parse_expr);
    out->msg = parse_node<Expr>(field(value, "msg"), parse_expr);
    return out;
}

inline std::shared_ptr<Decorator> parse_decorator(const json::Value& value)
{
    // An untagged `CallExpr`: `{func, args, keywords}` with no `type` key.
    auto out = std::make_shared<Decorator>();
    if (auto func = parse_node<Expr>(field(value, "func"), parse_expr)) {
        out->func = std::move(*func);
    }
    out->args = parse_node_list<Expr>(field(value, "args"), parse_expr);
    out->keywords = parse_node_list<Keyword>(field(value, "keywords"), parse_keyword);
    return out;
}

inline std::shared_ptr<SchemaConfig> parse_schema_config(const json::Value& value)
{
    // The untagged twin of `SchemaExpr`. `UnificationStmt::value` is a
    // `NodeRef<SchemaExpr>` over a plain struct, so this object carries no
    // `type` key and must not go through `parse_expr`.
    auto out = std::make_shared<SchemaConfig>();
    if (auto name = parse_node<Identifier>(field(value, "name"), parse_identifier)) {
        out->name = std::move(*name);
    }
    out->args = parse_node_list<Expr>(field(value, "args"), parse_expr);
    out->kwargs = parse_node_list<Keyword>(field(value, "kwargs"), parse_keyword);
    if (auto config = parse_node<Expr>(field(value, "config"), parse_expr)) {
        out->config = std::move(*config);
    }
    return out;
}

// ---------------------------------------------------------------------------
// Type
// ---------------------------------------------------------------------------

inline std::shared_ptr<LiteralValue> parse_literal_value(const json::Value& value)
{
    auto out = std::make_shared<LiteralValue>();
    const std::string& tag = require_tag(value, "LiteralType");
    // A second tagged document: the arms do not share a shape, so the
    // payload is read per arm rather than through a common reader.
    const json::Value* inner = field(value, "value");
    if (tag == "Int") {
        out->kind = LiteralValue::Kind::Int;
        if (inner != nullptr && inner->is_object()) {
            out->int_value = field(*inner, "value") == nullptr ? 0 : field(*inner, "value")->as_int();
            if (const json::Value* suffix = field(*inner, "suffix"); suffix != nullptr && suffix->is_string()) {
                out->suffix = suffix->as_string();
            }
        }
    } else if (tag == "Float") {
        out->kind = LiteralValue::Kind::Float;
        out->float_value = inner == nullptr ? 0.0 : inner->as_double();
    } else if (tag == "Str") {
        out->kind = LiteralValue::Kind::Str;
        out->str_value = inner == nullptr ? std::string() : inner->as_string();
    } else if (tag == "Bool") {
        out->kind = LiteralValue::Kind::Bool;
        out->bool_value = inner != nullptr && inner->as_bool();
    } else {
        throw AstError("LiteralType: unknown tag \"" + tag + "\"");
    }
    return out;
}

inline std::shared_ptr<Type> parse_type(const json::Value& value)
{
    // `Type` is adjacently tagged: the tag names the shape and the payload
    // rides under `value`. `Any` is the one unit variant, so it has no
    // `value` at all.
    const std::string& tag = require_tag(value, "Type");
    const json::Value* inner = field(value, "value");
    if (tag == "Any") {
        return std::make_shared<AnyType>();
    }
    if (tag == "Basic") {
        auto out = std::make_shared<BasicType>();
        out->name = inner == nullptr ? std::string() : inner->as_string();
        return out;
    }
    if (tag == "Named") {
        auto out = std::make_shared<NamedType>();
        if (inner != nullptr) {
            out->identifier = *parse_identifier(*inner);
        }
        return out;
    }
    if (tag == "List") {
        auto out = std::make_shared<ListType>();
        if (inner != nullptr) {
            out->inner_type = parse_node<Type>(field(*inner, "inner_type"), parse_type);
        }
        return out;
    }
    if (tag == "Dict") {
        auto out = std::make_shared<DictType>();
        if (inner != nullptr) {
            out->key_type = parse_node<Type>(field(*inner, "key_type"), parse_type);
            out->value_type = parse_node<Type>(field(*inner, "value_type"), parse_type);
        }
        return out;
    }
    if (tag == "Union") {
        auto out = std::make_shared<UnionType>();
        if (inner != nullptr) {
            out->type_elements = parse_node_list<Type>(field(*inner, "type_elements"), parse_type);
        }
        return out;
    }
    if (tag == "Literal") {
        auto out = std::make_shared<LiteralType>();
        if (inner != nullptr) {
            out->value = *parse_literal_value(*inner);
        }
        return out;
    }
    if (tag == "Function") {
        auto out = std::make_shared<FunctionType>();
        if (inner != nullptr) {
            out->params_ty = parse_node_list<Type>(field(*inner, "params_ty"), parse_type);
            out->ret_ty = parse_node<Type>(field(*inner, "ret_ty"), parse_type);
        }
        return out;
    }
    throw AstError("Type: unknown tag \"" + tag + "\"");
}

inline std::shared_ptr<NumberLitValue> parse_number_lit_value(const json::Value& value)
{
    auto out = std::make_shared<NumberLitValue>();
    const std::string& tag = require_tag(value, "NumberLitValue");
    const json::Value* inner = field(value, "value");
    if (tag == "Int") {
        out->kind = NumberLitValue::Kind::Int;
        out->int_value = inner == nullptr ? 0 : inner->as_int();
    } else if (tag == "Float") {
        out->kind = NumberLitValue::Kind::Float;
        out->float_value = inner == nullptr ? 0.0 : inner->as_double();
    } else {
        throw AstError("NumberLitValue: unknown tag \"" + tag + "\"");
    }
    return out;
}

// ---------------------------------------------------------------------------
// Expr
// ---------------------------------------------------------------------------

inline std::shared_ptr<Expr> parse_expr(const json::Value& value)
{
    // Internally tagged and flattened: the variant's fields sit beside the
    // `type` key, so there is no wrapper object to descend through.
    const std::string& tag = require_tag(value, "Expr");
    if (tag == "Target") {
        auto out = std::make_shared<TargetExpr>();
        out->target = *parse_target(value);
        return out;
    }
    if (tag == "Identifier") {
        auto out = std::make_shared<IdentifierExpr>();
        out->identifier = *parse_identifier(value);
        return out;
    }
    if (tag == "Unary") {
        auto out = std::make_shared<UnaryExpr>();
        out->op = string_field(value, "op");
        if (auto operand = parse_node<Expr>(field(value, "operand"), parse_expr)) {
            out->operand = std::move(*operand);
        }
        return out;
    }
    if (tag == "Binary") {
        auto out = std::make_shared<BinaryExpr>();
        if (auto left = parse_node<Expr>(field(value, "left"), parse_expr)) {
            out->left = std::move(*left);
        }
        out->op = string_field(value, "op");
        if (auto right = parse_node<Expr>(field(value, "right"), parse_expr)) {
            out->right = std::move(*right);
        }
        return out;
    }
    if (tag == "If") {
        auto out = std::make_shared<IfExpr>();
        if (auto body = parse_node<Expr>(field(value, "body"), parse_expr)) {
            out->body = std::move(*body);
        }
        if (auto cond = parse_node<Expr>(field(value, "cond"), parse_expr)) {
            out->cond = std::move(*cond);
        }
        if (auto orelse = parse_node<Expr>(field(value, "orelse"), parse_expr)) {
            out->orelse = std::move(*orelse);
        }
        return out;
    }
    if (tag == "Selector") {
        auto out = std::make_shared<SelectorExpr>();
        if (auto base = parse_node<Expr>(field(value, "value"), parse_expr)) {
            out->value = std::move(*base);
        }
        // `attr` is a `NodeRef<Identifier>`, so the payload is
        // `{names, pkgpath, ctx}` and not a bare string.
        if (auto attr = parse_node<Identifier>(field(value, "attr"), parse_identifier)) {
            out->attr = std::move(*attr);
        }
        out->ctx = parse_expr_context(string_field(value, "ctx"), "Selector.ctx");
        const json::Value* question = field(value, "has_question");
        out->has_question = question != nullptr && question->as_bool();
        return out;
    }
    if (tag == "Call") {
        auto out = std::make_shared<CallExpr>();
        if (auto func = parse_node<Expr>(field(value, "func"), parse_expr)) {
            out->func = std::move(*func);
        }
        out->args = parse_node_list<Expr>(field(value, "args"), parse_expr);
        out->keywords = parse_node_list<Keyword>(field(value, "keywords"), parse_keyword);
        return out;
    }
    if (tag == "Paren") {
        auto out = std::make_shared<ParenExpr>();
        // The field is `expr`, not `value`.
        if (auto inner = parse_node<Expr>(field(value, "expr"), parse_expr)) {
            out->expr = std::move(*inner);
        }
        return out;
    }
    if (tag == "Quant") {
        auto out = std::make_shared<QuantExpr>();
        if (auto target = parse_node<Expr>(field(value, "target"), parse_expr)) {
            out->target = std::move(*target);
        }
        out->variables = parse_node_list<Identifier>(field(value, "variables"), parse_identifier);
        out->op = string_field(value, "op");
        if (auto test = parse_node<Expr>(field(value, "test"), parse_expr)) {
            out->test = std::move(*test);
        }
        out->if_cond = parse_node<Expr>(field(value, "if_cond"), parse_expr);
        out->ctx = parse_expr_context(string_field(value, "ctx"), "Quant.ctx");
        return out;
    }
    if (tag == "List") {
        auto out = std::make_shared<ListExpr>();
        out->elts = parse_node_list<Expr>(field(value, "elts"), parse_expr);
        out->ctx = parse_expr_context(string_field(value, "ctx"), "List.ctx");
        return out;
    }
    if (tag == "ListIfItem") {
        auto out = std::make_shared<ListIfItemExpr>();
        if (auto cond = parse_node<Expr>(field(value, "if_cond"), parse_expr)) {
            out->if_cond = std::move(*cond);
        }
        out->exprs = parse_node_list<Expr>(field(value, "exprs"), parse_expr);
        // `orelse` is `Option<NodeRef<Expr>>` — one optional expression,
        // unlike `IfStmt::orelse` which really is a list of statements.
        out->orelse = parse_node<Expr>(field(value, "orelse"), parse_expr);
        return out;
    }
    if (tag == "ListComp") {
        auto out = std::make_shared<ListComp>();
        if (auto elt = parse_node<Expr>(field(value, "elt"), parse_expr)) {
            out->elt = std::move(*elt);
        }
        out->generators = parse_node_list<CompClause>(field(value, "generators"), parse_comp_clause);
        return out;
    }
    if (tag == "Starred") {
        auto out = std::make_shared<StarredExpr>();
        if (auto base = parse_node<Expr>(field(value, "value"), parse_expr)) {
            out->value = std::move(*base);
        }
        out->ctx = parse_expr_context(string_field(value, "ctx"), "Starred.ctx");
        return out;
    }
    if (tag == "DictComp") {
        auto out = std::make_shared<DictComp>();
        // `entry` is a bare `ConfigEntry`, not a `NodeRef`, so it has no
        // position of its own.
        if (const json::Value* entry = field(value, "entry")) {
            out->entry = *parse_config_entry(*entry);
        }
        out->generators = parse_node_list<CompClause>(field(value, "generators"), parse_comp_clause);
        return out;
    }
    if (tag == "ConfigIfEntry") {
        auto out = std::make_shared<ConfigIfEntryExpr>();
        if (auto cond = parse_node<Expr>(field(value, "if_cond"), parse_expr)) {
            out->if_cond = std::move(*cond);
        }
        out->items = parse_node_list<ConfigEntry>(field(value, "items"), parse_config_entry);
        out->orelse = parse_node<Expr>(field(value, "orelse"), parse_expr);
        return out;
    }
    if (tag == "CompClause") {
        return parse_comp_clause(value);
    }
    if (tag == "Schema") {
        auto out = std::make_shared<SchemaExpr>();
        if (auto name = parse_node<Identifier>(field(value, "name"), parse_identifier)) {
            out->name = std::move(*name);
        }
        out->args = parse_node_list<Expr>(field(value, "args"), parse_expr);
        out->kwargs = parse_node_list<Keyword>(field(value, "kwargs"), parse_keyword);
        if (auto config = parse_node<Expr>(field(value, "config"), parse_expr)) {
            out->config = std::move(*config);
        }
        return out;
    }
    if (tag == "Config") {
        auto out = std::make_shared<ConfigExpr>();
        out->items = parse_node_list<ConfigEntry>(field(value, "items"), parse_config_entry);
        return out;
    }
    if (tag == "Check") {
        auto out = std::make_shared<CheckExpr>();
        if (auto test = parse_node<Expr>(field(value, "test"), parse_expr)) {
            out->test = std::move(*test);
        }
        out->if_cond = parse_node<Expr>(field(value, "if_cond"), parse_expr);
        out->msg = parse_node<Expr>(field(value, "msg"), parse_expr);
        return out;
    }
    if (tag == "Lambda") {
        auto out = std::make_shared<LambdaExpr>();
        // `args: null` is an absent `Option`, not an empty argument list.
        out->args = parse_node<Arguments>(field(value, "args"), parse_arguments);
        out->body = parse_node_list<Stmt>(field(value, "body"), parse_stmt);
        out->return_ty = parse_node<Type>(field(value, "return_ty"), parse_type);
        return out;
    }
    if (tag == "Subscript") {
        auto out = std::make_shared<Subscript>();
        if (auto base = parse_node<Expr>(field(value, "value"), parse_expr)) {
            out->value = std::move(*base);
        }
        out->index = parse_node<Expr>(field(value, "index"), parse_expr);
        out->lower = parse_node<Expr>(field(value, "lower"), parse_expr);
        out->upper = parse_node<Expr>(field(value, "upper"), parse_expr);
        out->step = parse_node<Expr>(field(value, "step"), parse_expr);
        out->ctx = parse_expr_context(string_field(value, "ctx"), "Subscript.ctx");
        const json::Value* question = field(value, "has_question");
        out->has_question = question != nullptr && question->as_bool();
        return out;
    }
    if (tag == "Keyword") {
        auto out = std::make_shared<KeywordExpr>();
        out->keyword = parse_keyword(value);
        return out;
    }
    if (tag == "Arguments") {
        auto out = std::make_shared<ArgumentsExpr>();
        out->arguments = parse_arguments(value);
        return out;
    }
    if (tag == "Compare") {
        auto out = std::make_shared<Compare>();
        if (auto left = parse_node<Expr>(field(value, "left"), parse_expr)) {
            out->left = std::move(*left);
        }
        if (const json::Value* ops = field(value, "ops"); ops != nullptr && ops->is_array()) {
            for (const auto& op : ops->as_array()) {
                out->ops.push_back(op.as_string());
            }
        }
        out->comparators = parse_node_list<Expr>(field(value, "comparators"), parse_expr);
        return out;
    }
    if (tag == "NumberLit") {
        auto out = std::make_shared<NumberLit>();
        if (const json::Value* suffix = field(value, "binary_suffix"); suffix != nullptr && suffix->is_string()) {
            out->binary_suffix = suffix->as_string();
        }
        if (const json::Value* inner = field(value, "value")) {
            out->value = *parse_number_lit_value(*inner);
        }
        return out;
    }
    if (tag == "StringLit") {
        auto out = std::make_shared<StringLit>();
        const json::Value* long_string = field(value, "is_long_string");
        out->is_long_string = long_string != nullptr && long_string->as_bool();
        out->raw_value = string_field(value, "raw_value");
        out->value = string_field(value, "value");
        return out;
    }
    if (tag == "NameConstantLit") {
        // The payload is the variant *name* as a string — `"True"`, not
        // `true`.
        auto out = std::make_shared<NameConstantLit>();
        out->value = string_field(value, "value");
        return out;
    }
    if (tag == "JoinedString") {
        auto out = std::make_shared<JoinedString>();
        const json::Value* long_string = field(value, "is_long_string");
        out->is_long_string = long_string != nullptr && long_string->as_bool();
        out->values = parse_node_list<Expr>(field(value, "values"), parse_expr);
        out->raw_value = string_field(value, "raw_value");
        return out;
    }
    if (tag == "FormattedValue") {
        auto out = std::make_shared<FormattedValue>();
        const json::Value* long_string = field(value, "is_long_string");
        out->is_long_string = long_string != nullptr && long_string->as_bool();
        if (auto base = parse_node<Expr>(field(value, "value"), parse_expr)) {
            out->value = std::move(*base);
        }
        // The field is `format_spec`, not `spec`.
        if (const json::Value* spec = field(value, "format_spec"); spec != nullptr && spec->is_string()) {
            out->format_spec = spec->as_string();
        }
        return out;
    }
    if (tag == "Missing") {
        return std::make_shared<MissingExpr>();
    }
    throw AstError("Expr: unknown tag \"" + tag + "\"");
}

// ---------------------------------------------------------------------------
// Stmt
// ---------------------------------------------------------------------------

inline std::shared_ptr<Stmt> parse_stmt(const json::Value& value)
{
    const std::string& tag = require_tag(value, "Stmt");
    if (tag == "TypeAlias") {
        auto out = std::make_shared<TypeAliasStmt>();
        if (auto name = parse_node<Identifier>(field(value, "type_name"), parse_identifier)) {
            out->type_name = std::move(*name);
        }
        if (auto type_value = parse_string_node(field(value, "type_value"))) {
            out->type_value = std::move(*type_value);
        }
        if (auto ty = parse_node<Type>(field(value, "ty"), parse_type)) {
            out->ty = std::move(*ty);
        }
        return out;
    }
    if (tag == "Expr") {
        auto out = std::make_shared<ExprStmt>();
        out->exprs = parse_node_list<Expr>(field(value, "exprs"), parse_expr);
        return out;
    }
    if (tag == "Unification") {
        auto out = std::make_shared<UnificationStmt>();
        // `target` is an `Identifier`, not a `Target` — so it has a `ctx`.
        if (auto target = parse_node<Identifier>(field(value, "target"), parse_identifier)) {
            out->target = std::move(*target);
        }
        // `value` is a `NodeRef<SchemaExpr>` over a *plain* struct: the wire
        // object has no `type` key, so it is decoded as a `SchemaConfig` and
        // not through the tagged `Expr` path.
        if (auto value_ref = parse_node<SchemaConfig>(field(value, "value"), parse_schema_config)) {
            out->value = std::move(*value_ref);
        }
        return out;
    }
    if (tag == "Assign") {
        auto out = std::make_shared<AssignStmt>();
        out->targets = parse_node_list<Target>(field(value, "targets"), parse_target);
        if (auto expr = parse_node<Expr>(field(value, "value"), parse_expr)) {
            out->value = std::move(*expr);
        }
        out->ty = parse_node<Type>(field(value, "ty"), parse_type);
        return out;
    }
    if (tag == "AugAssign") {
        auto out = std::make_shared<AugAssignStmt>();
        if (auto target = parse_node<Target>(field(value, "target"), parse_target)) {
            out->target = std::move(*target);
        }
        if (auto expr = parse_node<Expr>(field(value, "value"), parse_expr)) {
            out->value = std::move(*expr);
        }
        out->op = string_field(value, "op");
        return out;
    }
    if (tag == "Assert") {
        auto out = std::make_shared<AssertStmt>();
        if (auto test = parse_node<Expr>(field(value, "test"), parse_expr)) {
            out->test = std::move(*test);
        }
        out->if_cond = parse_node<Expr>(field(value, "if_cond"), parse_expr);
        out->msg = parse_node<Expr>(field(value, "msg"), parse_expr);
        return out;
    }
    if (tag == "If") {
        auto out = std::make_shared<IfStmt>();
        out->body = parse_node_list<Stmt>(field(value, "body"), parse_stmt);
        if (auto cond = parse_node<Expr>(field(value, "cond"), parse_expr)) {
            out->cond = std::move(*cond);
        }
        // `orelse` is `Vec<NodeRef<Stmt>>`, not an expression list.
        out->orelse = parse_node_list<Stmt>(field(value, "orelse"), parse_stmt);
        return out;
    }
    if (tag == "Import") {
        auto out = std::make_shared<ImportStmt>();
        if (auto path = parse_string_node(field(value, "path"))) {
            out->path = std::move(*path);
        }
        out->rawpath = string_field(value, "rawpath");
        out->name = string_field(value, "name");
        // `asname` is an `Option<NodeRef<String>>`, not an `Option<String>`.
        out->as_name = parse_string_node(field(value, "asname"));
        out->pkg_name = string_field(value, "pkg_name");
        return out;
    }
    if (tag == "SchemaAttr") {
        auto out = std::make_shared<SchemaAttr>();
        // `doc` is a plain `String`, so an attribute with no docstring
        // decodes to "" rather than to no value.
        out->doc = string_field(value, "doc");
        if (auto name = parse_string_node(field(value, "name"))) {
            out->name = std::move(*name);
        }
        if (const json::Value* op = field(value, "op"); op != nullptr && op->is_string()) {
            out->op = op->as_string();
        }
        out->value = parse_node<Expr>(field(value, "value"), parse_expr);
        const json::Value* optional_flag = field(value, "is_optional");
        out->is_optional = optional_flag != nullptr && optional_flag->as_bool();
        out->decorators = parse_node_list<Decorator>(field(value, "decorators"), parse_decorator);
        // `ty` is a `NodeRef<Type>`, not an `Option`, so it is always there.
        if (auto ty = parse_node<Type>(field(value, "ty"), parse_type)) {
            out->ty = std::move(*ty);
        }
        return out;
    }
    if (tag == "Schema") {
        auto out = std::make_shared<SchemaStmt>();
        out->doc = parse_string_node(field(value, "doc"));
        if (auto name = parse_string_node(field(value, "name"))) {
            out->name = std::move(*name);
        }
        out->parent_name = parse_node<Identifier>(field(value, "parent_name"), parse_identifier);
        out->for_host_name = parse_node<Identifier>(field(value, "for_host_name"), parse_identifier);
        const json::Value* mixin = field(value, "is_mixin");
        out->is_mixin = mixin != nullptr && mixin->as_bool();
        const json::Value* protocol = field(value, "is_protocol");
        out->is_protocol = protocol != nullptr && protocol->as_bool();
        out->args = parse_node<Arguments>(field(value, "args"), parse_arguments);
        out->mixins = parse_node_list<Identifier>(field(value, "mixins"), parse_identifier);
        out->body = parse_node_list<Stmt>(field(value, "body"), parse_stmt);
        out->decorators = parse_node_list<Decorator>(field(value, "decorators"), parse_decorator);
        out->checks = parse_node_list<CheckExpr>(field(value, "checks"), parse_check_expr);
        out->index_signature
            = parse_node<SchemaIndexSignature>(field(value, "index_signature"), parse_schema_index_signature);
        return out;
    }
    if (tag == "Rule") {
        auto out = std::make_shared<RuleStmt>();
        out->doc = parse_string_node(field(value, "doc"));
        if (auto name = parse_string_node(field(value, "name"))) {
            out->name = std::move(*name);
        }
        out->parent_rules = parse_node_list<Identifier>(field(value, "parent_rules"), parse_identifier);
        out->decorators = parse_node_list<Decorator>(field(value, "decorators"), parse_decorator);
        out->checks = parse_node_list<CheckExpr>(field(value, "checks"), parse_check_expr);
        out->args = parse_node<Arguments>(field(value, "args"), parse_arguments);
        out->for_host_name = parse_node<Identifier>(field(value, "for_host_name"), parse_identifier);
        return out;
    }
    throw AstError("Stmt: unknown tag \"" + tag + "\"");
}

/// `Comment` over a `NodeRef<Comment>`: the payload is `{"text": "…"}`.
inline std::shared_ptr<Comment> parse_comment_node(const json::Value& wire)
{
    if (!wire.is_object()) {
        return nullptr;
    }
    const json::Value* inner = wire.find("node");
    if (inner == nullptr || !inner->is_object()) {
        return nullptr;
    }
    return parse_comment(*inner);
}

/// A module out of an already-parsed document.
inline Module parse_module(const json::Value& root, const std::string& origin)
{
    if (!root.is_object()) {
        throw AstError(origin + ": a module's AST is an object");
    }
    Module out;
    out.filename = string_field(root, "filename");
    out.doc = parse_string_node(field(root, "doc"));
    out.body = parse_node_list<Stmt>(field(root, "body"), parse_stmt);
    if (const json::Value* comments = field(root, "comments"); comments != nullptr && comments->is_array()) {
        for (const auto& item : comments->as_array()) {
            CommentRef ref;
            ref.pos = parse_pos(item);
            // The payload is a `Comment` object — `{"text": "…"}` — and not
            // the comment text itself. Reading it as a bare string, the way
            // four bindings do, yields an empty comment and no error.
            ref.node = parse_comment_node(item);
            out.comments.push_back(std::move(ref));
        }
    }
    return out;
}

/// Every module in a `parse_program` document. The runtime emits either a
/// bare array of modules or a `{"root":…, "pkgs":{…}}` envelope, and both
/// shapes are accepted.
inline std::vector<Module> parse_modules(const json::Value& root, const std::string& origin)
{
    std::vector<Module> out;
    if (root.is_array()) {
        for (const auto& item : root.as_array()) {
            out.push_back(parse_module(item, origin));
        }
        return out;
    }
    if (!root.is_object()) {
        throw AstError(origin + ": a program's AST is an array or a {\"pkgs\":…} object");
    }
    const json::Value* pkgs = root.find("pkgs");
    if (pkgs == nullptr || !pkgs->is_object()) {
        return out;
    }
    for (const auto& pkg : pkgs->as_object()) {
        if (!pkg.second.is_array()) {
            continue;
        }
        for (const auto& item : pkg.second.as_array()) {
            out.push_back(parse_module(item, origin));
        }
    }
    return out;
}

/// `json::parse`, with its `ParseError` folded into an `AstError` so a caller
/// only ever has to catch one type. The message already carries the origin,
/// so nothing is added to it.
inline json::Value parse_document(const std::string& text, const std::string& origin)
{
    try {
        return json::parse(text, origin);
    } catch (const json::ParseError& e) {
        throw AstError(e.what());
    }
}

} // namespace detail

// ---------------------------------------------------------------------------
// Module decoding
// ---------------------------------------------------------------------------

inline Module Module::from_json(const std::string& ast_json, const std::string& origin)
{
    return detail::parse_module(detail::parse_document(ast_json, origin), origin);
}

inline std::vector<const SchemaStmt*> Module::schemas() const
{
    std::vector<const SchemaStmt*> out;
    for (const auto& ref : body) {
        if (auto schema = std::dynamic_pointer_cast<SchemaStmt>(ref.node)) {
            out.push_back(schema.get());
        }
    }
    return out;
}

inline const Stmt* Module::find(const char* tag) const
{
    for (const auto& ref : body) {
        if (ref.node != nullptr && std::string(ref.node->tag()) == tag) {
            return ref.node.get();
        }
    }
    return nullptr;
}

inline std::vector<Module> parse_program_json(const std::string& program_json, const std::string& origin)
{
    return detail::parse_modules(detail::parse_document(program_json, origin), origin);
}

} // namespace ast
} // namespace kcl
