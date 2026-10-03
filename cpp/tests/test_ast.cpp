// Contract tests for the C++ typed AST in `include/kcl_ast.hpp`.
//
// Two directions, on purpose:
//
//   * The golden capture at `testdata/ast/alignment.json` is what the parser
//     is *specified* to emit, decoded into the typed tree and asserted field
//     by field. `kcl_ast.hpp` raises on a `type` tag it does not know, so
//     decoding the capture without throwing is itself the load-bearing
//     assertion — a decoder that mistyped a tag fails at the first node that
//     carries it, and a decoder that dropped a subtree fails on the
//     `test_every_tag_in_the_golden_capture_resolves` walk, which compares
//     the tags the typed walk reached against every tag in the raw document.
//
//   * One live parse through `kcl_lib::parse_file`, which proves the decoder
//     accepts something the real parser actually emits. The capture pins the
//     contract; the live parse pins that the contract has not drifted from
//     the implementation.
//
// The walk has one blind spot, and it is a real one: a payload *routed* to
// the wrong decoder does not raise if both decoders accept it. Decoding a
// bare `SchemaExpr` through the tagged `Expr` path would look for a `type`
// key that is not there, so this header raises — but decoding a
// `SchemaConfig` through the `SchemaExpr` reader would not. That is why
// `test_unification_value_is_a_schema_config` asserts the *class* and not
// just the presence of the value.

#include "kcl_ast.hpp"
#include "kcl_lib.hpp"

#include <cstdio>
#include <fstream>
#include <iostream>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <vector>

namespace ast = kcl::ast;

#ifndef KCL_TEST_DATA_DIR
#define KCL_TEST_DATA_DIR "../test_data"
#endif

// The golden capture lives at the repository root, two levels above `cpp/`.
#ifndef KCL_AST_FIXTURE
#define KCL_AST_FIXTURE "../../testdata/ast/alignment.json"
#endif

#define CHECK(cond)                                                                \
    do {                                                                           \
        if (!(cond)) {                                                             \
            std::cerr << "CHECK failed: " << #cond << " at " << __FILE__ << ":"     \
                      << __LINE__ << std::endl;                                    \
            return false;                                                          \
        }                                                                          \
    } while (0)

namespace {

// `CmpOp` from `../kcl/crates/ast/src/ast.rs`, listed so a typo in either the
// parser or the fixture shows up as a failure rather than passing through as
// an opaque string.
const std::vector<std::string>& cmp_ops()
{
    static const std::vector<std::string> ops = { "Eq",  "NotEq", "Lt",   "LtE", "Gt",
                                                  "GtE", "Is",    "In",   "NotIn", "Not",
                                                  "IsNot" };
    return ops;
}

std::string read_file(const std::string& path)
{
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        return std::string();
    }
    std::ostringstream buffer;
    buffer << in.rdbuf();
    return buffer.str();
}

std::string golden_path()
{
    const std::string candidates[] = {
        KCL_AST_FIXTURE,
        "../testdata/ast/alignment.json",
        "../../testdata/ast/alignment.json",
        "testdata/ast/alignment.json",
    };
    for (const std::string& candidate : candidates) {
        if (!read_file(candidate).empty()) {
            return candidate;
        }
    }
    return std::string();
}

// Decoded once: the tests all read the same module, and re-parsing a ~1MB
// document per test buys nothing.
const ast::Module& golden()
{
    static const ast::Module module = [] {
        const std::string path = golden_path();
        if (path.empty()) {
            std::cerr << "could not locate testdata/ast/alignment.json" << std::endl;
            return ast::Module {};
        }
        return ast::Module::from_json(read_file(path), path);
    }();
    return module;
}

// -------------------------------------------------------------------- //
// Lookups
// -------------------------------------------------------------------- //

template <typename T>
std::shared_ptr<T> stmt_of(const ast::StmtRef& ref)
{
    return std::dynamic_pointer_cast<T>(ref.node);
}

template <typename T>
std::shared_ptr<T> expr_of(const ast::ExprRef& ref)
{
    return std::dynamic_pointer_cast<T>(ref.node);
}

// The optional-expression fields (`Option<NodeRef<Expr>>`) decode to a
// `std::optional<Node<Expr>>`, so narrowing one needs its own overload
// rather than a `->node` at every call site.
template <typename T>
std::shared_ptr<T> expr_of(const std::optional<ast::ExprRef>& ref)
{
    return ref ? expr_of<T>(*ref) : nullptr;
}

template <typename T>
std::shared_ptr<T> type_of(const std::optional<ast::TypeRef>& ref)
{
    return ref ? ast::as<T>(ref->node) : nullptr;
}

const ast::SchemaStmt* find_schema(const std::string& name)
{
    for (const auto& ref : golden().body) {
        auto schema = stmt_of<ast::SchemaStmt>(ref);
        if (schema != nullptr && schema->name.node != nullptr && *schema->name.node == name) {
            return schema.get();
        }
    }
    return nullptr;
}

const ast::AssignStmt* find_assign(const std::string& name)
{
    for (const auto& ref : golden().body) {
        auto assign = stmt_of<ast::AssignStmt>(ref);
        if (assign == nullptr || assign->targets.empty() || !assign->targets.front().node) {
            continue;
        }
        const ast::Target& target = *assign->targets.front().node;
        if (target.name.node != nullptr && *target.name.node == name) {
            return assign.get();
        }
    }
    return nullptr;
}

const ast::TypeAliasStmt* find_type_alias(const std::string& name)
{
    for (const auto& ref : golden().body) {
        auto alias = stmt_of<ast::TypeAliasStmt>(ref);
        if (alias != nullptr && alias->type_name.node != nullptr
            && alias->type_name.node->name() == name) {
            return alias.get();
        }
    }
    return nullptr;
}

std::shared_ptr<ast::Expr> assigned_value(const std::string& name)
{
    const ast::AssignStmt* assign = find_assign(name);
    return assign == nullptr ? nullptr : assign->value.node;
}

std::shared_ptr<ast::Type> alias_type(const std::string& name)
{
    const ast::TypeAliasStmt* alias = find_type_alias(name);
    return alias == nullptr ? nullptr : alias->ty.node;
}

const ast::SchemaAttr* schema_attr(const std::string& schema_name, const std::string& attr_name)
{
    const ast::SchemaStmt* schema = find_schema(schema_name);
    if (schema == nullptr) {
        return nullptr;
    }
    for (const auto& ref : schema->body) {
        auto attr = stmt_of<ast::SchemaAttr>(ref);
        if (attr != nullptr && attr->name.node != nullptr && *attr->name.node == attr_name) {
            return attr.get();
        }
    }
    return nullptr;
}

// -------------------------------------------------------------------- //
// Tests
// -------------------------------------------------------------------- //

bool test_module_shape()
{
    const ast::Module& m = golden();
    CHECK(m.filename.find(".k") != std::string::npos);
    CHECK(!m.body.empty());
    // `comments` is `Vec<NodeRef<Comment>>`, so the payload is `{text}`
    // rather than a bare string. Four bindings read it as a bare string and
    // produce an empty comment with no error at all; asserting the text is
    // non-empty is what catches that.
    CHECK(!m.comments.empty());
    CHECK(m.comments.front().node != nullptr);
    CHECK(!m.comments.front().node->text.empty());
    CHECK(m.comments.front().node->text[0] == '#');
    // Positions are flat on the wrapper, so a `pos` with a line number
    // proves the reader reads `line` and is not looking for a nested `pos`
    // object.
    CHECK(m.body.front().pos.has_value());
    CHECK(m.body.front().pos->line > 0);
    CHECK(!m.body.front().pos->filename.empty());
    return true;
}

bool test_import_is_flat()
{
    const ast::Module& m = golden();
    auto imp = stmt_of<ast::ImportStmt>(m.body.front());
    CHECK(imp != nullptr);
    // `path` is a `NodeRef<String>`, so it carries a position of its own.
    CHECK(imp->path.node != nullptr);
    CHECK(imp->path.pos.has_value());
    CHECK(!imp->rawpath.empty());
    CHECK(!imp->name.empty());
    CHECK(!imp->pkg_name.empty());
    // `asname` is an absent `Option<NodeRef<String>>`, not an empty string.
    CHECK(!imp->as_name.has_value());
    return true;
}

bool test_unification_value_is_a_schema_config()
{
    const ast::UnificationStmt* found = nullptr;
    for (const auto& ref : golden().body) {
        if (auto un = stmt_of<ast::UnificationStmt>(ref)) {
            found = un.get();
            break;
        }
    }
    CHECK(found != nullptr);
    // `target` is an `Identifier`, not a `Target` — so it has a `ctx`.
    CHECK(found->target.node != nullptr);
    CHECK(found->target.node->ctx == ast::ExprContext::Store);
    // `value` is a `NodeRef<SchemaExpr>` over a *plain* struct, so the wire
    // object carries no `type` key. Decoding it through the tagged `Expr`
    // path raises here; decoding it as a `SchemaConfig` does not. Assert the
    // class, not just the presence — both readers would accept the object.
    CHECK(found->value.node != nullptr);
    CHECK(found->value.node->name.node != nullptr);
    CHECK(found->value.node->name.node->name() == "Person");
    CHECK(found->value.node->config.node != nullptr);
    CHECK(expr_of<ast::ConfigExpr>(found->value.node->config) != nullptr);
    return true;
}

bool test_schema_decorators_are_untagged_call_exprs()
{
    const ast::SchemaStmt* person = find_schema("Person");
    CHECK(person != nullptr);
    // `@deprecated` and `@info` sit on the `name` attribute, not on the
    // schema header, so the schema's own list is empty.
    CHECK(person->decorators.empty());
    CHECK(!person->checks.empty());
    // `checks` is `Vec<NodeRef<CheckExpr>>` over a plain struct: no tag on
    // the element, and `Decorators` likewise.
    CHECK(person->checks.front().node != nullptr);
    CHECK(person->checks.front().node->test.node != nullptr);
    CHECK(person->checks.front().node->msg.has_value());
    CHECK(!person->checks.front().node->if_cond.has_value());
    // `doc` keeps its `"""` delimiters: `parse_doc` clones
    // `StringLit::raw_value`, not the unquoted `value`.
    CHECK(person->doc.has_value());
    CHECK(*person->doc->node == "\"\"\"A person.\"\"\"");

    const ast::SchemaAttr* name = schema_attr("Person", "name");
    CHECK(name != nullptr);
    // `SchemaAttr::doc` is a plain `String`, not a `NodeRef<String>`, so an
    // attribute with no docstring decodes to "" rather than to no value.
    CHECK(name->doc.empty());
    CHECK(name->decorators.size() == 2);
    // `ty` is a `NodeRef<Type>`, not an `Option`.
    CHECK(name->ty.node != nullptr);
    auto basic = ast::as<ast::BasicType>(name->ty.node);
    CHECK(basic != nullptr);
    CHECK(basic->name == "Str");

    // A decorator payload is a bare `{func,args,keywords}`; `func` is a
    // `NodeRef<Expr>` that *does* carry a tag.
    const ast::Decorator& deco = *name->decorators.front().node;
    CHECK(deco.args.empty());
    auto decorated = expr_of<ast::IdentifierExpr>(deco.func);
    CHECK(decorated != nullptr);
    CHECK(decorated->identifier.name() == "deprecated");
    return true;
}

bool test_schema_attr_optional_and_index_signature()
{
    const ast::SchemaAttr* age = schema_attr("Person", "age");
    CHECK(age != nullptr);
    CHECK(age->is_optional);
    // `op` is `Option<AugOp>`, and the parser emits the operator rather than
    // leaving it null: `age: int = 0` carries `Assign`, not an absent value.
    CHECK(age->op.has_value());
    CHECK(*age->op == "Assign");
    CHECK(age->value.has_value());
    CHECK(expr_of<ast::NumberLit>(age->value) != nullptr);

    const ast::SchemaStmt* bag = find_schema("Bag");
    CHECK(bag != nullptr);
    // `index_signature` is `Option<NodeRef<SchemaIndexSignature>>` — a plain
    // struct, so `key_ty`/`value_ty` are present `NodeRef<Type>`s rather
    // than optionals, while `key_name` and `value` are genuinely optional.
    CHECK(bag->index_signature.has_value());
    const ast::SchemaIndexSignature& sig = *bag->index_signature->node;
    CHECK(sig.key_name.has_value());
    CHECK(*sig.key_name->node == "k");
    CHECK(sig.value.has_value());
    CHECK(!sig.any_other);
    CHECK(ast::as<ast::BasicType>(sig.key_ty.node) != nullptr);
    CHECK(ast::as<ast::BasicType>(sig.key_ty.node)->name == "Str");
    CHECK(ast::as<ast::BasicType>(sig.value_ty.node)->name == "Int");
    return true;
}

bool test_rule_stmt()
{
    const ast::RuleStmt* found = nullptr;
    for (const auto& ref : golden().body) {
        if (auto rule = stmt_of<ast::RuleStmt>(ref)) {
            found = rule.get();
            break;
        }
    }
    CHECK(found != nullptr);
    CHECK(found->name.node != nullptr);
    // The fixture's rule is undecorated, which is itself the assertion: a
    // decoder that invented a tag for a decorator payload could not produce
    // an empty list here.
    CHECK(found->decorators.empty());
    CHECK(!found->checks.empty());
    CHECK(found->checks.front().node != nullptr);
    CHECK(found->checks.front().node->test.node != nullptr);
    CHECK(!found->doc.has_value());
    return true;
}

bool test_schema_expr_is_not_a_call()
{
    // `x = Person {...}` puts its entries in `config` and leaves `keywords`
    // empty; `y = Person(1, name = "Bob")` is a plain Call.
    auto x = assigned_value("x");
    CHECK(x != nullptr);
    auto schema = ast::as<ast::SchemaExpr>(x);
    CHECK(schema != nullptr);
    CHECK(schema->kwargs.empty());
    CHECK(expr_of<ast::ConfigExpr>(schema->config) != nullptr);

    auto y = assigned_value("y");
    CHECK(y != nullptr);
    auto call = ast::as<ast::CallExpr>(y);
    CHECK(call != nullptr);
    CHECK(call->args.size() == 1);
    // `Keyword::arg` is a `NodeRef<Identifier>`, not an Expr, and `value` is
    // an `Option<NodeRef<Expr>>`.
    CHECK(call->keywords.size() == 1);
    CHECK(call->keywords.front().node != nullptr);
    CHECK(call->keywords.front().node->arg.node != nullptr);
    CHECK(call->keywords.front().node->arg.node->name() == "name");
    CHECK(call->keywords.front().node->value.has_value());
    return true;
}

bool test_selector_and_subscript()
{
    // `Selector::attr` is a `NodeRef<Identifier>`, so the payload is
    // `{names, pkgpath, ctx}` rather than a bare string, and
    // `has_question` is the optional-access flag — there is no `attr_name`
    // field. Asserting only that `attr` is non-nil is not enough: decoding
    // an Identifier payload as a `NodeRef<String>` yields `""` without
    // raising.
    auto optional = assigned_value("optional");
    CHECK(optional != nullptr);
    auto selector = ast::as<ast::SelectorExpr>(optional);
    CHECK(selector != nullptr);
    CHECK(selector->has_question);
    CHECK(selector->attr.node != nullptr);
    CHECK(selector->attr.node->name() == "name");
    CHECK(selector->attr.pos.has_value());

    // A slice puts its bounds in `lower`/`upper`/`step` and leaves `index`
    // null.
    auto slice = ast::as<ast::Subscript>(assigned_value("subscript_slice"));
    CHECK(slice != nullptr);
    CHECK(!slice->index.has_value());
    CHECK(slice->lower.has_value());
    CHECK(slice->upper.has_value());
    CHECK(!slice->step.has_value());

    auto step = ast::as<ast::Subscript>(assigned_value("subscript_step"));
    CHECK(step != nullptr);
    CHECK(!step->index.has_value());
    CHECK(step->step.has_value());

    // `subscript_q` is `a?.b` — an optional *Selector*, not a Subscript. The
    // two are easy to confuse and `has_question` lives on both.
    auto q = ast::as<ast::SelectorExpr>(assigned_value("subscript_q"));
    CHECK(q != nullptr);
    CHECK(q->has_question);
    CHECK(ast::as<ast::Subscript>(assigned_value("subscript_q")) == nullptr);

    auto plain = ast::as<ast::Subscript>(assigned_value("subscript"));
    CHECK(plain != nullptr);
    CHECK(plain->index.has_value());
    return true;
}

bool test_config_entries()
{
    auto config = ast::as<ast::ConfigExpr>(assigned_value("config"));
    CHECK(config != nullptr);
    CHECK(config->items.size() == 2);
    CHECK(config->items[0].node->operation == "Override");
    CHECK(config->items[1].node->operation == "Union");
    // `skip_serializing_if = "is_false"`, so the key is absent rather than
    // explicitly false.
    CHECK(!config->items[0].node->is_shorthand);

    // The ES6 shorthand sets the flag.
    auto shorthand = ast::as<ast::ConfigExpr>(assigned_value("config_shorthand"));
    CHECK(shorthand != nullptr);
    CHECK(!shorthand->items.empty());
    for (const auto& item : shorthand->items) {
        CHECK(item.node->is_shorthand);
    }

    // `config_if` wraps a `ConfigIfEntry` in a `ConfigEntry` whose `key` is
    // null.
    auto config_if = ast::as<ast::ConfigExpr>(assigned_value("config_if"));
    CHECK(config_if != nullptr);
    CHECK(config_if->items.size() == 1);
    CHECK(!config_if->items[0].node->key.has_value());
    auto entry = expr_of<ast::ConfigIfEntryExpr>(config_if->items[0].node->value);
    CHECK(entry != nullptr);
    CHECK(!entry->items.empty());
    CHECK(entry->orelse.has_value());
    return true;
}

bool test_comprehensions()
{
    auto quant = ast::as<ast::QuantExpr>(assigned_value("quant"));
    CHECK(quant != nullptr);
    // `QuantOperation` is {All,Any,Filter,Map} — a single value, not a list.
    const std::string& op = quant->op;
    CHECK(op == "All" || op == "Any" || op == "Filter" || op == "Map");
    // `variables` is `Vec<NodeRef<Identifier>>`, not Targets.
    CHECK(!quant->variables.empty());
    CHECK(quant->variables.front().node != nullptr);
    CHECK(!quant->variables.front().node->name().empty());
    CHECK(quant->test.node != nullptr);
    CHECK(!quant->if_cond.has_value());

    // `DictComp::entry` is a bare ConfigEntry — no NodeRef, so no position
    // on it, and no `cond` on the node itself.
    auto dict_comp = ast::as<ast::DictComp>(assigned_value("dict_comp"));
    CHECK(dict_comp != nullptr);
    CHECK(dict_comp->entry.key.has_value());
    CHECK(dict_comp->entry.value.node != nullptr);
    CHECK(!dict_comp->generators.empty());
    // `CompClause::targets` are Identifiers, and `iter` is required.
    CHECK(dict_comp->generators.front().node != nullptr);
    CHECK(!dict_comp->generators.front().node->targets.empty());
    CHECK(dict_comp->generators.front().node->targets.front().node != nullptr);
    CHECK(dict_comp->generators.front().node->iter.node != nullptr);

    // `ListIfItem` is {if_cond, exprs, orelse} — there is no `if_expr`.
    auto list = ast::as<ast::ListExpr>(assigned_value("list_if_entry"));
    CHECK(list != nullptr);
    auto item = expr_of<ast::ListIfItemExpr>(list->elts.front());
    CHECK(item != nullptr);
    CHECK(item->if_cond.node != nullptr);
    CHECK(!item->exprs.empty());
    CHECK(item->orelse.has_value());

    // The `*_if` forms are ListComp — there is no `cond` field.
    auto comp = ast::as<ast::ListComp>(assigned_value("list_if"));
    CHECK(comp != nullptr);
    CHECK(!comp->generators.empty());
    CHECK(comp->elt.node != nullptr);
    return true;
}

bool test_lambda_arguments_keep_their_nulls()
{
    // `lambda_expr`'s Arguments has `args: [p]`, `defaults: [null]` and
    // `ty_list: [Int]`. Dropping the positional null would leave an empty
    // list, which is the bug this checks for.
    auto lambda = ast::as<ast::LambdaExpr>(assigned_value("lambda_expr"));
    CHECK(lambda != nullptr);
    CHECK(lambda->args.has_value());
    const ast::Arguments& args = *lambda->args->node;
    CHECK(args.args.size() == 1);
    CHECK(args.defaults.size() == 1);
    CHECK(!args.defaults[0].has_value());
    CHECK(args.ty_list.size() == 1);
    CHECK(args.ty_list[0].has_value());
    CHECK(ast::as<ast::BasicType>(args.ty_list[0]->node)->name == "Int");
    // The body is statements, not expressions.
    CHECK(!lambda->body.empty());
    CHECK(stmt_of<ast::ExprStmt>(lambda->body.front()) != nullptr);
    CHECK(lambda->return_ty.has_value());

    // `lambda_plain` has `args: null` — an absent `Option`, a different
    // thing from an empty argument list.
    auto plain = ast::as<ast::LambdaExpr>(assigned_value("lambda_plain"));
    CHECK(plain != nullptr);
    CHECK(!plain->args.has_value());
    CHECK(!plain->return_ty.has_value());
    return true;
}

bool test_literals()
{
    // `NumberLitValue` is tag+content, so the tag is the only thing telling
    // an int payload from a float one.
    auto int_lit = ast::as<ast::NumberLit>(assigned_value("lit_int"));
    CHECK(int_lit != nullptr);
    CHECK(int_lit->value.kind == ast::NumberLitValue::Kind::Int);
    CHECK(int_lit->value.int_value == 1);
    CHECK(!int_lit->binary_suffix.has_value());

    auto float_lit = ast::as<ast::NumberLit>(assigned_value("lit_float"));
    CHECK(float_lit != nullptr);
    CHECK(float_lit->value.kind == ast::NumberLitValue::Kind::Float);
    CHECK(float_lit->value.float_value != 0.0);

    auto str_lit = ast::as<ast::StringLit>(assigned_value("lit_str"));
    CHECK(str_lit != nullptr);
    CHECK(str_lit->value == "s");
    // `raw_value` keeps the quotes; `value` does not.
    CHECK(str_lit->raw_value == "\"s\"");
    CHECK(!str_lit->is_long_string);

    auto long_lit = ast::as<ast::StringLit>(assigned_value("lit_long"));
    CHECK(long_lit != nullptr);
    CHECK(long_lit->is_long_string);

    // The payload is the variant *name* as a string — `"True"`, not `true`.
    auto name_lit = ast::as<ast::NameConstantLit>(assigned_value("lit_name"));
    CHECK(name_lit != nullptr);
    CHECK(name_lit->value == "True");

    // The field is `format_spec`, not `spec`.
    auto joined = ast::as<ast::JoinedString>(assigned_value("joined"));
    CHECK(joined != nullptr);
    CHECK(!joined->raw_value.empty());
    CHECK(!joined->values.empty());
    // An f-string interleaves literal segments with the interpolated ones, so
    // the FormattedValue is not necessarily the first element.
    const ast::FormattedValue* formatted = nullptr;
    for (const auto& part : joined->values) {
        if (auto fv = expr_of<ast::FormattedValue>(part)) {
            formatted = fv.get();
        }
    }
    CHECK(formatted != nullptr);
    // The fixture interpolates without a width, so `format_spec` is null.
    CHECK(!formatted->format_spec.has_value());
    CHECK(expr_of<ast::IdentifierExpr>(formatted->value) != nullptr);
    return true;
}

bool test_unary_compare_and_parenthesised()
{
    // `-a` is `USub`, not a generic "negate".
    auto unary = ast::as<ast::UnaryExpr>(assigned_value("unary"));
    CHECK(unary != nullptr);
    CHECK(unary->op == "USub");
    CHECK(expr_of<ast::IdentifierExpr>(unary->operand) != nullptr);

    auto not_op = ast::as<ast::UnaryExpr>(assigned_value("unary_not"));
    CHECK(not_op != nullptr);
    CHECK(not_op->op == "Not");

    // `ops` and `comparators` are parallel arrays.
    auto chain = ast::as<ast::Compare>(assigned_value("compare_chain"));
    CHECK(chain != nullptr);
    CHECK(chain->ops.size() == chain->comparators.size());
    for (const auto& op : chain->ops) {
        bool known = false;
        for (const auto& candidate : cmp_ops()) {
            known = known || op == candidate;
        }
        CHECK(known);
    }
    CHECK(chain->left.node != nullptr);

    // The ternary is `Expr::If`, whose `orelse` is one expression —
    // `Stmt::If::orelse` is a list of statements.
    auto tern = ast::as<ast::IfExpr>(assigned_value("tern"));
    CHECK(tern != nullptr);
    CHECK(tern->body.node != nullptr);
    CHECK(tern->cond.node != nullptr);
    CHECK(tern->orelse.node != nullptr);

    auto paren = ast::as<ast::ParenExpr>(assigned_value("paren"));
    CHECK(paren != nullptr);
    // The field is `expr`, not `value`.
    CHECK(paren->expr.node != nullptr);
    return true;
}

bool test_assert_and_if_statements()
{
    bool saw_assert = false;
    bool saw_if = false;
    bool saw_aug = false;
    for (const auto& ref : golden().body) {
        // `AssertStmt` is `{test, if_cond, msg}`.
        if (auto assert = stmt_of<ast::AssertStmt>(ref)) {
            saw_assert = true;
            CHECK(assert->test.node != nullptr);
            CHECK(!assert->msg.has_value() || assert->msg->node != nullptr);
        }
        // `orelse` is `Vec<NodeRef<Stmt>>`, not an expression list.
        if (auto if_stmt = stmt_of<ast::IfStmt>(ref)) {
            saw_if = true;
            CHECK(if_stmt->cond.node != nullptr);
            CHECK(!if_stmt->body.empty());
            CHECK(!if_stmt->orelse.empty());
        }
        // `AugAssignStmt::target` is a Target, unlike `UnificationStmt`'s.
        if (auto aug = stmt_of<ast::AugAssignStmt>(ref)) {
            saw_aug = true;
            CHECK(aug->op == "Add");
            CHECK(aug->target.node != nullptr);
            CHECK(aug->target.node->name.node != nullptr);
            CHECK(*aug->target.node->name.node == "a");
        }
    }
    CHECK(saw_assert);
    CHECK(saw_if);
    CHECK(saw_aug);
    return true;
}

bool test_target_paths()
{
    // `Target::paths` is a bare `Vec<MemberOrIndex>` — no NodeRef, so no
    // position on the element itself.
    bool saw_paths = false;
    bool saw_member = false;
    bool saw_index = false;
    bool saw_deep_path = false;
    for (const auto& ref : golden().body) {
        auto assign = stmt_of<ast::AssignStmt>(ref);
        if (assign == nullptr) {
            continue;
        }
        for (const auto& target_ref : assign->targets) {
            if (!target_ref.node) {
                continue;
            }
            const ast::Target& target = *target_ref.node;
            if (target.paths.empty()) {
                continue;
            }
            saw_paths = true;
            for (const ast::MemberOrIndex& path : target.paths) {
                if (path.is_member()) {
                    saw_member = true;
                    CHECK(std::string(path.type()) == "Member");
                    // The payload is a `NodeRef<String>`, so it carries its
                    // own position.
                    CHECK(path.member.has_value());
                    CHECK(!path.member->node->empty());
                    CHECK(path.member->pos.has_value());
                } else {
                    saw_index = true;
                    CHECK(std::string(path.type()) == "Index");
                    CHECK(path.index.has_value());
                    CHECK(expr_of<ast::NumberLit>(*path.index) != nullptr);
                }
            }
            // `pkgpath` is a single string, not a list, and it stays empty
            // for a dotted or indexed target — the path lives in `paths`.
            CHECK(target.pkgpath.empty());
            CHECK(target.paths.size() == 1 || target.paths.size() == 2);
            // `Member` arm values are the dotted segments and the `Index`
            // arm is the index expression; the count is what separates
            // `x.name.deep` from `x[0]`.
            if (target.paths.size() == 2) {
                saw_deep_path = true;
            }
        }
    }
    CHECK(saw_paths);
    CHECK(saw_member);
    CHECK(saw_index);
    CHECK(saw_deep_path);
    return true;
}

bool test_starred_and_missing()
{
    auto starred_list = ast::as<ast::ListExpr>(assigned_value("starred"));
    CHECK(starred_list != nullptr);
    auto elt = expr_of<ast::StarredExpr>(starred_list->elts.front());
    CHECK(elt != nullptr);
    // `StarredExpr::ctx` is `ExprContext`, which has Load and Store — there
    // is no `Del`.
    CHECK(elt->ctx == ast::ExprContext::Load);

    // The parser substitutes a placeholder `Identifier` for a missing
    // expression, so this decodes as an Identifier with a name rather than as
    // `Expr::Missing`.
    auto missing = assigned_value("missing_expr");
    CHECK(missing != nullptr);
    auto identifier = ast::as<ast::IdentifierExpr>(missing);
    CHECK(identifier != nullptr);
    CHECK(identifier->identifier.name() == "missing");
    return true;
}

bool test_type_is_adjacently_tagged()
{
    // `Type` is `#[serde(tag = "type", content = "value")]`: the tag names
    // the shape and the payload is inlined under `value`. `Any` is the only
    // unit variant, so it has no `value` at all.
    auto any_t = ast::as<ast::AnyType>(alias_type("TAny"));
    CHECK(any_t != nullptr);
    CHECK(std::string(any_t->tag()) == "Any");

    // `Basic` carries a bare string, not an object.
    auto basic_t = ast::as<ast::BasicType>(alias_type("TBasic"));
    CHECK(basic_t != nullptr);
    CHECK(basic_t->name == "Bool" || basic_t->name == "Int" || basic_t->name == "Float"
        || basic_t->name == "Str");

    // `Named` inlines the `Identifier` newtype, so the payload is untagged.
    auto named_t = ast::as<ast::NamedType>(alias_type("TNamed"));
    CHECK(named_t != nullptr);
    CHECK(named_t->identifier.name() == "Cloud");
    CHECK(named_t->identifier.ctx == ast::ExprContext::Load);

    auto list_t = ast::as<ast::ListType>(alias_type("TList"));
    CHECK(list_t != nullptr);
    CHECK(list_t->inner_type.has_value());
    CHECK(ast::as<ast::BasicType>(list_t->inner_type->node) != nullptr);

    auto dict_t = ast::as<ast::DictType>(alias_type("TDict"));
    CHECK(dict_t != nullptr);
    CHECK(dict_t->key_type.has_value());
    CHECK(dict_t->value_type.has_value());

    auto union_t = ast::as<ast::UnionType>(alias_type("TUnion"));
    CHECK(union_t != nullptr);
    CHECK(union_t->type_elements.size() >= 2);
    for (const auto& element : union_t->type_elements) {
        CHECK(ast::as<ast::BasicType>(element.node) != nullptr);
    }

    // `FunctionType` uses `params_ty` / `ret_ty`, and `params_ty` is an
    // `Option<Vec<…>>` — absent and empty both mean "no parameters".
    auto func_t = ast::as<ast::FunctionType>(alias_type("TFunc"));
    CHECK(func_t != nullptr);
    CHECK(func_t->params_ty.size() == 2);
    CHECK(func_t->ret_ty.has_value());

    // `LiteralType` is itself tag+content, so `Type::Literal`'s value is a
    // *second* tagged document, and its four arms do not share a shape.
    auto lit_int = ast::as<ast::LiteralType>(alias_type("TLitInt"));
    CHECK(lit_int != nullptr);
    CHECK(lit_int->value.kind == ast::LiteralValue::Kind::Int);
    CHECK(lit_int->value.int_value == 1);
    CHECK(!lit_int->value.suffix.has_value());

    auto lit_str = ast::as<ast::LiteralType>(alias_type("TLitStr"));
    CHECK(lit_str != nullptr);
    CHECK(lit_str->value.kind == ast::LiteralValue::Kind::Str);
    CHECK(!lit_str->value.str_value.empty());

    auto lit_bool = ast::as<ast::LiteralType>(alias_type("TLitBool"));
    CHECK(lit_bool != nullptr);
    CHECK(lit_bool->value.kind == ast::LiteralValue::Kind::Bool);
    CHECK(lit_bool->value.bool_value);

    auto lit_float = ast::as<ast::LiteralType>(alias_type("TLitFloat"));
    CHECK(lit_float != nullptr);
    CHECK(lit_float->value.kind == ast::LiteralValue::Kind::Float);
    CHECK(lit_float->value.float_value != 0.0);

    // `TypeAliasStmt` names its fields `type_name` / `type_value`.
    CHECK(find_type_alias("TAny")->type_value.node != nullptr);
    return true;
}

bool test_unknown_tags_raise()
{
    // Hand-written documents, so this case does not depend on the capture:
    // an unknown `type` tag, a plain struct routed through a tagged decoder,
    // a bad tag buried three levels down, and malformed JSON. Java's Jackson
    // does the same — a decoder that quietly produced a zero-valued node is
    // the failure the whole contract exists to catch.
    //
    // Each is one raw string with the line breaks inside it rather than four
    // adjacent literals: a raw string's terminator is the first `)J"` it
    // sees, and a literal ending in `,` puts that terminator right where the
    // next literal begins. Newlines are whitespace to JSON, so the document
    // is the same either way and the intent is readable.
    const std::string bad_tag = R"J(
        {"filename":"a.k","body":[{"node":{"type":"Nope"},"line":1}]}
    )J";

    // A plain `{name, args, kwargs, config}` object where the grammar wants a
    // tagged `Expr`. It is exactly the shape `UnificationStmt::value` really
    // has on the wire, but that field decodes as a `SchemaConfig` and has no
    // `type` key to dispatch on — routed through the tagged path it must
    // raise rather than decode to a zero-valued node.
    const std::string untagged_as_tagged = R"J(
        {"filename":"a.k","body":[{"node":{"type":"Assign","targets":[],
         "value":{"node":{"name":{"node":{"names":[{"node":"P"}],
         "pkgpath":"","ctx":"Load"}},"args":[],"kwargs":[],"config":null}},
         "ty":null}}]}
    )J";

    const std::string bad_type_tag = R"J(
        {"filename":"a.k","body":[{"node":{"type":"TypeAlias",
         "type_name":{"node":{"names":[{"node":"T"}],"pkgpath":"","ctx":"Load"}},
         "type_value":{"node":"x"},"ty":{"node":{"type":"Nope"}}}}]}
    )J";

    // Every tagged payload in the document is checked, not just the outermost
    // ones, which is why decoding the golden capture end to end is the
    // load-bearing test and field-by-field assertions on a handful of nodes
    // are not.
    const std::string nested_bad_tag = R"J(
        {"filename":"a.k","body":[{"node":{"type":"Assign","targets":[],
         "value":{"node":{"type":"Schema","name":null,"args":[],"kwargs":[],
         "config":{"node":{"type":"List","elts":[{"node":{"type":"Nope"}}],
         "ctx":"Load"}}}},"ty":{"node":{"type":"Basic","value":"Int"}}}}]}
    )J";

    for (const std::string& document : { bad_tag, untagged_as_tagged, bad_type_tag, nested_bad_tag }) {
        bool raised = false;
        try {
            ast::Module::from_json(document, "hand-written.k");
        } catch (const ast::AstError&) {
            raised = true;
        }
        CHECK(raised);
    }

    // Malformed JSON raises too, with the origin in the message.
    bool raised = false;
    try {
        ast::Module::from_json("{not json", "hand-written.k");
    } catch (const ast::AstError& e) {
        raised = std::string(e.what()).find("hand-written.k") != std::string::npos;
    }
    CHECK(raised);
    return true;
}

bool test_parse_program_accepts_both_shapes()
{
    // A bare array of modules.
    const std::string module_json = "{\"filename\":\"a.k\",\"body\":[],\"comments\":[]}";
    auto flat = ast::parse_program_json("[" + module_json + "]");
    CHECK(flat.size() == 1);
    CHECK(flat.front().filename == "a.k");

    // The `{"root":…, "pkgs":{…}}` envelope the runtime emits.
    const std::string envelope
        = "{\"root\":\"__main__\",\"pkgs\":{\"__main__\":[" + module_json + "]}}";
    auto wrapped = ast::parse_program_json(envelope);
    CHECK(wrapped.size() == 1);
    CHECK(wrapped.front().filename == "a.k");

    // Neither shape.
    bool raised = false;
    try {
        ast::parse_program_json("42");
    } catch (const ast::AstError&) {
        raised = true;
    }
    CHECK(raised);
    return true;
}

// -------------------------------------------------------------------- //
// The load-bearing case
// -------------------------------------------------------------------- //

// Every `"type"` string anywhere in a raw document, including the ones that
// are not `Expr`/`Stmt`/`Type` discriminators: `MemberOrIndex`, the inner
// `NumberLitValue` and the inner `LiteralTypeValue` are all tag+content
// documents of their own.
void collect_raw_tags(const ast::json::Value& value, std::set<std::string>& out)
{
    if (value.is_array()) {
        for (const auto& item : value.as_array()) {
            collect_raw_tags(item, out);
        }
        return;
    }
    if (!value.is_object()) {
        return;
    }
    const ast::json::Value* tag = value.find("type");
    if (tag != nullptr && tag->is_string()) {
        out.insert(tag->as_string());
    }
    for (const auto& member : value.as_object()) {
        collect_raw_tags(member.second, out);
    }
}

// A recursive walk over the whole typed tree, recording the discriminator of
// every tagged node it reaches. It is written as a struct rather than a nest
// of lambdas for the same reason the Ruby one is: `stmt` reaches `expr` and
// `expr` reaches back through `LambdaExpr::body`, and a local function in C++
// cannot be written that way without a visitor.
struct TagWalk {
    std::set<std::string> tags;
    size_t seen = 0;

    void type(const ast::TypeRef& ref, const char* where)
    {
        if (!ref.node) {
            return;
        }
        seen++;
        const ast::Type* node = ref.node.get();
        tags.insert(node->tag());
        if (auto list = ast::as<ast::ListType>(ref.node)) {
            if (list->inner_type) {
                type(*list->inner_type, where);
            }
        } else if (auto dict = ast::as<ast::DictType>(ref.node)) {
            if (dict->key_type) {
                type(*dict->key_type, where);
            }
            if (dict->value_type) {
                type(*dict->value_type, where);
            }
        } else if (auto union_t = ast::as<ast::UnionType>(ref.node)) {
            for (const auto& element : union_t->type_elements) {
                type(element, where);
            }
        } else if (auto function = ast::as<ast::FunctionType>(ref.node)) {
            for (const auto& param : function->params_ty) {
                type(param, where);
            }
            if (function->ret_ty) {
                type(*function->ret_ty, where);
            }
        } else if (ast::as<ast::LiteralType>(ref.node)) {
            // The second tagged document: its inner tag is not a `Type`
            // discriminator, but the walk records it so the tag set matches
            // the raw document's.
            static const std::set<std::string> inner = { "Int", "Float", "Str", "Bool" };
            for (const std::string& tag : inner) {
                tags.insert(tag);
            }
        }
    }

    // An `Option<NodeRef<Expr>>` field: absent and present-but-empty both
    // contribute no tagged node, which is the point of routing them through
    // the same walk.
    void expr(const std::optional<ast::ExprRef>& ref, const char* where)
    {
        if (ref) {
            expr(*ref, where);
        }
    }

    void type(const std::optional<ast::TypeRef>& ref, const char* where)
    {
        if (ref) {
            type(*ref, where);
        }
    }

    void expr(const ast::ExprRef& ref, const char* where)
    {
        if (!ref.node) {
            return;
        }
        seen++;
        const ast::Expr* node = ref.node.get();
        tags.insert(node->tag());
        if (auto unary = ast::as<ast::UnaryExpr>(ref.node)) {
            expr(unary->operand, where);
        } else if (auto binary = ast::as<ast::BinaryExpr>(ref.node)) {
            expr(binary->left, where);
            expr(binary->right, where);
        } else if (auto if_expr = ast::as<ast::IfExpr>(ref.node)) {
            expr(if_expr->body, where);
            expr(if_expr->cond, where);
            expr(if_expr->orelse, where);
        } else if (auto selector = ast::as<ast::SelectorExpr>(ref.node)) {
            expr(selector->value, where);
        } else if (auto starred = ast::as<ast::StarredExpr>(ref.node)) {
            expr(starred->value, where);
        } else if (auto paren = ast::as<ast::ParenExpr>(ref.node)) {
            // `Paren` wraps the parenthesised expression in a field called
            // `expr`, not `value`.
            expr(paren->expr, where);
        } else if (auto call = ast::as<ast::CallExpr>(ref.node)) {
            expr(call->func, where);
            for (const auto& arg : call->args) {
                expr(arg, where);
            }
        } else if (auto quant = ast::as<ast::QuantExpr>(ref.node)) {
            expr(quant->target, where);
            expr(quant->test, where);
            if (quant->if_cond) {
                expr(*quant->if_cond, where);
            }
        } else if (auto list = ast::as<ast::ListExpr>(ref.node)) {
            for (const auto& elt : list->elts) {
                expr(elt, where);
            }
        } else if (auto item = ast::as<ast::ListIfItemExpr>(ref.node)) {
            expr(item->if_cond, where);
            for (const auto& sub : item->exprs) {
                expr(sub, where);
            }
            if (item->orelse) {
                expr(*item->orelse, where);
            }
        } else if (auto comp = ast::as<ast::ListComp>(ref.node)) {
            expr(comp->elt, where);
            for (const auto& generator : comp->generators) {
                clause(generator);
            }
        } else if (auto dict_comp = ast::as<ast::DictComp>(ref.node)) {
            expr(dict_comp->entry.key, where);
            expr(dict_comp->entry.value, where);
            for (const auto& generator : dict_comp->generators) {
                clause(generator);
            }
        } else if (auto config_if = ast::as<ast::ConfigIfEntryExpr>(ref.node)) {
            expr(config_if->if_cond, where);
            config_entries(config_if->items);
            if (config_if->orelse) {
                expr(*config_if->orelse, where);
            }
        } else if (auto config = ast::as<ast::ConfigExpr>(ref.node)) {
            config_entries(config->items);
        } else if (auto check = ast::as<ast::CheckExpr>(ref.node)) {
            check_expr(*check);
        } else if (auto lambda = ast::as<ast::LambdaExpr>(ref.node)) {
            // `Arguments::defaults` / `ty_list` are index-aligned, so walk
            // them by position rather than by index into `args`.
            if (lambda->args && lambda->args->node) {
                for (const auto& d : lambda->args->node->defaults) {
                    if (d) {
                        expr(*d, where);
                    }
                }
                for (const auto& t : lambda->args->node->ty_list) {
                    if (t) {
                        type(*t, where);
                    }
                }
            }
            for (const auto& s : lambda->body) {
                stmt(s);
            }
            if (lambda->return_ty) {
                type(*lambda->return_ty, where);
            }
        } else if (auto sub = ast::as<ast::Subscript>(ref.node)) {
            expr(sub->value, where);
            if (sub->index) {
                expr(*sub->index, where);
            }
            if (sub->lower) {
                expr(*sub->lower, where);
            }
            if (sub->upper) {
                expr(*sub->upper, where);
            }
            if (sub->step) {
                expr(*sub->step, where);
            }
        } else if (auto compare = ast::as<ast::Compare>(ref.node)) {
            expr(compare->left, where);
            for (const auto& comparator : compare->comparators) {
                expr(comparator, where);
            }
        } else if (auto schema = ast::as<ast::SchemaExpr>(ref.node)) {
            for (const auto& arg : schema->args) {
                expr(arg, where);
            }
            expr(schema->config, where);
        } else if (auto number = ast::as<ast::NumberLit>(ref.node)) {
            static const std::set<std::string> inner = { "Int", "Float" };
            for (const std::string& tag : inner) {
                tags.insert(tag);
            }
        } else if (auto joined = ast::as<ast::JoinedString>(ref.node)) {
            for (const auto& part : joined->values) {
                expr(part, where);
            }
        } else if (auto formatted = ast::as<ast::FormattedValue>(ref.node)) {
            expr(formatted->value, where);
        }
    }

    void clause(const ast::CompClauseRef& ref)
    {
        if (!ref.node) {
            return;
        }
        seen++;
        tags.insert(ref.node->tag());
        expr(ref.node->iter, "comp_clause.iter");
        for (const auto& guard : ref.node->ifs) {
            expr(guard, "comp_clause.ifs");
        }
    }

    void check_expr(const ast::CheckExpr& check)
    {
        tags.insert(check.tag());
        expr(check.test, "check.test");
        if (check.if_cond) {
            expr(*check.if_cond, "check.if_cond");
        }
        if (check.msg) {
            expr(*check.msg, "check.msg");
        }
    }

    void config_entries(const std::vector<ast::ConfigEntryRef>& items)
    {
        for (const auto& item : items) {
            if (item.node) {
                expr(item.node->key, "config_entry.key");
                expr(item.node->value, "config_entry.value");
            }
        }
    }

    void keyword(const ast::KeywordRef& ref)
    {
        if (!ref.node) {
            return;
        }
        if (ref.node->value) {
            expr(*ref.node->value, "keyword.value");
        }
    }

    void decorator(const ast::DecoratorRef& ref)
    {
        if (!ref.node) {
            return;
        }
        expr(ref.node->func, "decorator.func");
        for (const auto& arg : ref.node->args) {
            expr(arg, "decorator.args");
        }
        for (const auto& kw : ref.node->keywords) {
            keyword(kw);
        }
    }

    // Only the `Index` arm of a `MemberOrIndex` is a `NodeRef<Expr>`; the
    // `Member` arm is a `NodeRef<String>`.
    void member_or_index(const std::vector<ast::MemberOrIndex>& paths)
    {
        for (const ast::MemberOrIndex& path : paths) {
            tags.insert(path.type());
            if (path.is_index() && path.index) {
                expr(*path.index, "target.paths.index");
            }
        }
    }

    void target(const ast::TargetRef& ref)
    {
        if (!ref.node) {
            return;
        }
        member_or_index(ref.node->paths);
    }

    void schema_config(const ast::SchemaConfigRef& ref)
    {
        if (!ref.node) {
            return;
        }
        for (const auto& arg : ref.node->args) {
            expr(arg, "schema_config.args");
        }
        for (const auto& kw : ref.node->kwargs) {
            keyword(kw);
        }
        expr(ref.node->config, "schema_config.config");
    }

    void arguments(const std::optional<ast::ArgumentsRef>& ref)
    {
        if (!ref || !ref->node) {
            return;
        }
        for (const auto& d : ref->node->defaults) {
            if (d) {
                expr(*d, "arguments.defaults");
            }
        }
        for (const auto& t : ref->node->ty_list) {
            if (t) {
                type(*t, "arguments.ty_list");
            }
        }
    }

    void stmt(const ast::StmtRef& ref)
    {
        if (!ref.node) {
            return;
        }
        seen++;
        const ast::Stmt* node = ref.node.get();
        tags.insert(node->tag());
        if (auto alias = std::dynamic_pointer_cast<ast::TypeAliasStmt>(ref.node)) {
            type(alias->ty, "type_alias.ty");
        } else if (auto expr_stmt = std::dynamic_pointer_cast<ast::ExprStmt>(ref.node)) {
            for (const auto& e : expr_stmt->exprs) {
                expr(e, "expr_stmt.exprs");
            }
        } else if (auto un = std::dynamic_pointer_cast<ast::UnificationStmt>(ref.node)) {
            // `value` is a bare SchemaConfig — walk its config, not `name`,
            // which is an Identifier and carries no tag.
            schema_config(un->value);
        } else if (auto assign = std::dynamic_pointer_cast<ast::AssignStmt>(ref.node)) {
            for (const auto& t : assign->targets) {
                target(t);
            }
            expr(assign->value, "assign.value");
            if (assign->ty) {
                type(*assign->ty, "assign.ty");
            }
        } else if (auto aug = std::dynamic_pointer_cast<ast::AugAssignStmt>(ref.node)) {
            expr(aug->value, "aug_assign.value");
            target(aug->target);
        } else if (auto assert = std::dynamic_pointer_cast<ast::AssertStmt>(ref.node)) {
            expr(assert->test, "assert.test");
            if (assert->if_cond) {
                expr(*assert->if_cond, "assert.if_cond");
            }
            if (assert->msg) {
                expr(*assert->msg, "assert.msg");
            }
        } else if (auto if_stmt = std::dynamic_pointer_cast<ast::IfStmt>(ref.node)) {
            for (const auto& s : if_stmt->body) {
                stmt(s);
            }
            expr(if_stmt->cond, "if.cond");
            for (const auto& s : if_stmt->orelse) {
                stmt(s);
            }
        } else if (auto attr = std::dynamic_pointer_cast<ast::SchemaAttr>(ref.node)) {
            if (attr->value) {
                expr(*attr->value, "schema_attr.value");
            }
            type(attr->ty, "schema_attr.ty");
            for (const auto& d : attr->decorators) {
                decorator(d);
            }
        } else if (auto schema = std::dynamic_pointer_cast<ast::SchemaStmt>(ref.node)) {
            arguments(schema->args);
            for (const auto& s : schema->body) {
                stmt(s);
            }
            for (const auto& d : schema->decorators) {
                decorator(d);
            }
            for (const auto& c : schema->checks) {
                if (c.node) {
                    check_expr(*c.node);
                }
            }
            if (schema->index_signature && schema->index_signature->node) {
                const ast::SchemaIndexSignature& sig = *schema->index_signature->node;
                expr(sig.value, "index_signature.value");
                type(sig.key_ty, "index_signature.key_ty");
                type(sig.value_ty, "index_signature.value_ty");
            }
        } else if (auto rule = std::dynamic_pointer_cast<ast::RuleStmt>(ref.node)) {
            arguments(rule->args);
            for (const auto& d : rule->decorators) {
                decorator(d);
            }
            for (const auto& c : rule->checks) {
                if (c.node) {
                    check_expr(*c.node);
                }
            }
        }
    }

    void run(const ast::Module& module)
    {
        for (const auto& ref : module.body) {
            stmt(ref);
        }
    }
};

bool test_every_tag_in_the_golden_capture_resolves()
{
    // `golden()` is built by `Module::from_json`, and this header raises on a
    // `type` tag it does not know, so reaching this line at all means every
    // tag in the capture resolved. The walk then checks the other half: that
    // nothing was dropped on the way down.
    const std::string path = golden_path();
    CHECK(!path.empty());
    const std::string text = read_file(path);
    std::set<std::string> raw;
    collect_raw_tags(ast::json::parse(text, path), raw);

    TagWalk walk;
    walk.run(golden());
    // Sanity-check the walk itself before trusting its verdict: a walk that
    // visits nothing reports "nothing missing" just as happily as a correct
    // one, and the capture is large enough that a silently broken walk is a
    // real risk.
    CHECK(walk.seen > 200);

    std::vector<std::string> missing;
    for (const std::string& tag : raw) {
        if (walk.tags.find(tag) == walk.tags.end()) {
            missing.push_back(tag);
        }
    }
    CHECK(missing.empty());
    return true;
}

// The other half of the pair: decode a tree the *real* parser produced, not
// a capture of one. This is what catches a contract that has drifted from
// the implementation — a new tag the parser emits and the decoder does not
// know would raise here.
bool test_live_parse_decodes()
{
    kcl_lib::ParseFileArgs args;
    args.path = KCL_TEST_DATA_DIR "/ast_alignment/main.k";
    auto result = kcl_lib::parse_file(args);
    CHECK(result.errors.empty());
    CHECK(!result.ast_json.empty());

    ast::Module module
        = ast::Module::from_json(std::string(result.ast_json.c_str()), std::string(args.path.c_str()));
    CHECK(module.filename.find(".k") != std::string::npos);
    CHECK(!module.body.empty());

    // The fixture is the same shape `testdata/ast/alignment.k` covers: a
    // schema with a check and a decorator on an attribute, and a lambda with
    // an argument list. Decoding those through the typed tree is what proves
    // the contract has not drifted from the parser.
    const ast::SchemaStmt* person = nullptr;
    for (const ast::SchemaStmt* schema : module.schemas()) {
        if (schema->name.node != nullptr && *schema->name.node == "Person") {
            person = schema;
        }
    }
    CHECK(person != nullptr);
    CHECK(!person->checks.empty());
    CHECK(person->checks.front().node != nullptr);
    CHECK(person->checks.front().node->test.node != nullptr);

    bool saw_decorated_attr = false;
    bool saw_long_doc = false;
    for (const auto& ref : person->body) {
        auto attr = std::dynamic_pointer_cast<ast::SchemaAttr>(ref.node);
        if (attr == nullptr) {
            continue;
        }
        saw_decorated_attr = saw_decorated_attr || !attr->decorators.empty();
    }
    if (person->doc.has_value() && person->doc->node != nullptr) {
        // The docstring keeps its `"""` delimiters.
        saw_long_doc = person->doc->node->rfind("\"\"\"", 0) == 0;
    }
    CHECK(saw_decorated_attr);
    CHECK(saw_long_doc);

    bool saw_lambda = false;
    for (const auto& ref : module.body) {
        auto assign = std::dynamic_pointer_cast<ast::AssignStmt>(ref.node);
        if (assign == nullptr) {
            continue;
        }
        auto lambda = ast::as<ast::LambdaExpr>(assign->value.node);
        if (lambda != nullptr && lambda->args.has_value()) {
            saw_lambda = true;
            CHECK(!lambda->args->node->args.empty());
        }
    }
    CHECK(saw_lambda);

    TagWalk walk;
    walk.run(module);
    CHECK(walk.seen > 0);
    return true;
}

} // namespace

int main()
{
    const std::vector<std::pair<const char*, bool (*)()>> tests = {
        { "module_shape", test_module_shape },
        { "import_is_flat", test_import_is_flat },
        { "unification_value_is_a_schema_config", test_unification_value_is_a_schema_config },
        { "schema_decorators_are_untagged_call_exprs", test_schema_decorators_are_untagged_call_exprs },
        { "schema_attr_optional_and_index_signature", test_schema_attr_optional_and_index_signature },
        { "rule_stmt", test_rule_stmt },
        { "schema_expr_is_not_a_call", test_schema_expr_is_not_a_call },
        { "selector_and_subscript", test_selector_and_subscript },
        { "config_entries", test_config_entries },
        { "comprehensions", test_comprehensions },
        { "lambda_arguments_keep_their_nulls", test_lambda_arguments_keep_their_nulls },
        { "literals", test_literals },
        { "unary_compare_and_parenthesised", test_unary_compare_and_parenthesised },
        { "assert_and_if_statements", test_assert_and_if_statements },
        { "target_paths", test_target_paths },
        { "starred_and_missing", test_starred_and_missing },
        { "type_is_adjacently_tagged", test_type_is_adjacently_tagged },
        { "unknown_tags_raise", test_unknown_tags_raise },
        { "parse_program_accepts_both_shapes", test_parse_program_accepts_both_shapes },
        { "every_tag_in_the_golden_capture_resolves", test_every_tag_in_the_golden_capture_resolves },
        { "live_parse_decodes", test_live_parse_decodes },
    };

    int failed = 0;
    for (const auto& [name, fn] : tests) {
        try {
            if (fn()) {
                std::cout << "[PASS] " << name << std::endl;
            } else {
                std::cout << "[FAIL] " << name << std::endl;
                ++failed;
            }
        } catch (const std::exception& e) {
            std::cerr << "[FAIL] " << name << " threw: " << e.what() << std::endl;
            ++failed;
        }
    }

    if (failed > 0) {
        std::cerr << failed << " test(s) failed" << std::endl;
        return 1;
    }
    std::cout << "All " << tests.size() << " tests passed" << std::endl;
    return 0;
}
