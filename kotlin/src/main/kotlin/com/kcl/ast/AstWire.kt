// AstWire.kt — The write side: typed AST objects back to the JSON Rust emits.
//
// `parseModule` (AstJson.kt) turns `ast_json` into the classes in
// `com.kcl.ast`; this turns those classes back into the same bytes. That
// symmetry is the point: a caller can build a tree with the factories in
// `AstBuild.kt` and hand it to anything that reads a KCL AST, and a
// decode/encode cycle is a fixed point, which is what makes a dropped field
// visible at all.
//
// Jackson cannot do this job, and it is worth saying why, because the classes
// are already Jackson-annotated and it looks like it should:
//
//   1. `Stmt` and `Expr` are `#[serde(tag = "type")]` and every variant is a
//      newtype over a struct, so serde *flattens* the struct's fields beside
//      the tag: `{"type":"Call","func":…,"args":[…],"keywords":[…]}`. There is
//      no `call` wrapper key, and the field-identical `@JsonSubTypes` mapping
//      on `Expr` cannot tell the two spellings apart — a decorator and a call
//      are the same struct, and only the context says which one it is.
//   2. `Type` is `#[serde(tag = "type", content = "value")]` — adjacently
//      tagged. `@JsonTypeInfo.As.PROPERTY` cannot express that; it would write
//      `{"type":"Basic","name":…}` where serde writes
//      `{"type":"Basic","value":"Int"}`, and the tag names the *shape* rather
//      than the type inside, so a registry keyed on the variant name matches
//      nothing. `Any` is a unit variant: `{"type":"Any"}` with no `value` key
//      at all.
//   3. `Option<T>` and `Vec<T>` are different things. The classes are
//      `@JsonInclude(NON_NULL)`, which drops every absent `Option` — but
//      serde *writes* those keys as `null`. A Jackson round trip therefore
//      loses `"doc": null`, `"ty": null` and every other `Option` on the
//      module, and that is a fixed-point failure on every fixture.
//
// Everything else about the classes is right and is reused as it is.
//
// The mirror of this file is `dotnet/KclLib.AST/Wire.cs`; the two are meant
// to read the same so that a generated version of both can replace them.

package com.kcl.ast

import com.fasterxml.jackson.databind.ObjectMapper
import java.util.Optional

private val WIRE_MAPPER: ObjectMapper = ObjectMapper()

// -----------------------------------------------------------------------
// NodeRef
// -----------------------------------------------------------------------

/**
 * A `NodeRef`: the five position keys are flattened onto the wrapper beside
 * `node` — there is no `pos` key on the wire — and `id` is not written at all,
 * because Rust only serialises it under `SHOULD_SERIALIZE_ID`, which is off.
 *
 * [payload] is the shape of the wrapped value, which is not always the one
 * `toWire` would give it: a `CallExpr` in a decorator list is the untagged
 * struct even though the same class is a tagged `"Call"` in an expression.
 */
private fun <T> nodeWireOf(node: NodeRef<T>?, payload: (T) -> Any?): Map<String, Any?>? = node?.let {
    linkedMapOf(
        "node" to it.node?.let(payload),
        "filename" to it.filename,
        "line" to it.line,
        "column" to it.column,
        "end_line" to it.endLine,
        "end_column" to it.endColumn,
    )
}

/**
 * A `NodeRef<T>`-typed field.
 *
 * Almost every field the classes declare as `NodeRef<T>` is an
 * `Option<NodeRef<T>>` in Rust — a null wrapper is `None` and is written as
 * `null`, not as `{}`. The classes cannot say the difference, so a null field
 * has to mean `null` here. (The two genuinely-`Vec` shapes, `listWire` below
 * and the `Optional` ones, `optNode` further down, are the other cases.)
 */
private fun <T> nodeWire(node: NodeRef<T>?): Map<String, Any?>? = nodeWireOf(node) { toWire(it) }

/**
 * A `Vec<NodeRef<T>>`. A Rust `Vec` is never absent, so a null list is written
 * as an empty array rather than as `null`.
 */
private fun <T> listWire(nodes: List<NodeRef<T>>?): List<Any?> =
    (nodes ?: emptyList()).map { nodeWire(it) }

/**
 * A `Vec<Option<NodeRef<T>>>`. A null slot is data — an unnamed lambda
 * parameter with no default and no annotation is `"defaults":[null, null]`,
 * not `[]` — so the nulls are kept and the slot order is preserved.
 */
private fun <T> optSlotWire(nodes: List<NodeRef<T>?>?): List<Any?> =
    (nodes ?: emptyList()).map { slot -> slot?.let { nodeWire(it) } }

/**
 * An `Option<T>` declared as a `java.util.Optional`. The classes use
 * `Optional` for the handful of fields the Rust type declares that way, and
 * `Optional.empty()` has to become `null` on the wire — not an empty `{}`, and
 * not a dropped key.
 */
private fun <T> optValue(value: Optional<T>?): T? = value?.orElse(null)

/** An `Option<NodeRef<T>>`. */
private fun <T> optNode(value: Optional<NodeRef<T>>?): Map<String, Any?>? =
    optValue(value)?.let { nodeWire(it) }

/**
 * An `Option<Vec<NodeRef<T>>>` — the one place a list is nullable rather than
 * empty. The parser only produces `None` or `Some(non-empty)`
 * (`crates/parser/src/parser/ty.rs` ~line 244), so `[]` is not a third case
 * that needs inventing; an empty list still round-trips as an empty array
 * because that is what a `Vec` always writes.
 */
private fun <T> optNodeList(value: Optional<List<NodeRef<T>>>?): List<Any?>? {
    val nodes: List<NodeRef<T>>? = optValue<List<NodeRef<T>>>(value)
    return nodes?.map { nodeWire(it) }
}

// -----------------------------------------------------------------------
// The one entry point
// -----------------------------------------------------------------------

/**
 * The wire tree for an AST object: nested `Map`/`List`/scalars, ready to
 * serialize or to embed in a larger document. The mirror of
 * `AstWriter.ToWire` in .NET.
 *
 * A value that is *already* a wire tree is passed through unchanged, so
 * `toJson(toWire(x))` is the same document as `toJson(x)` rather than a second
 * conversion pass that finds no AST node. A JSON scalar passes through for the
 * same reason, and because a bare string *is* the right wire shape for the
 * payloads that are strings.
 */
fun toWire(node: Any?): Any? = when (node) {
    null -> null
    is Map<*, *>, is List<*>, is String, is Boolean, is Long, is Int, is Double -> node
    is Module -> moduleWire(node)
    is Program -> programWire(node)
    is Type -> typeWire(node)
    is Stmt -> stmtWire(node)
    is MemberOrIndex -> memberOrIndexWire(node)
    // The untagged plain structs, which cannot be dispatched on because they
    // carry no tag of their own. `CompClause` is both: `Expr::CompClause` is a
    // newtype over it, so the same class is written with a tag in an
    // expression position and without one in a `generators` list.
    is Comment -> commentWire(node)
    is Identifier -> identifierWire(node)
    is Target -> targetWire(node)
    is Keyword -> keywordWire(node)
    is Arguments -> argumentsWire(node)
    is CheckExpr -> checkWire(node)
    is Decorator -> decoratorWire(node)
    is ConfigEntry -> configEntryWire(node)
    is CompClause -> compClauseWire(node)
    is SchemaConfig -> schemaConfigWire(node)
    is SchemaIndexSignature -> indexSignatureWire(node)
    is Expr -> exprWire(node)
    // A wrapper handed over without a static type. Kotlin erases the type
    // argument at a call site that widens to `Any?`, so `toJson(nodeRef(x))`
    // arrives here and the payload still has to be recognised by its runtime
    // class. That works because every branch above dispatches on the payload
    // too — the star projection is only a problem for the handful of places
    // where the same class has two wire shapes, and those are decided by the
    // declared field type, never from here.
    is NodeRef<*> -> nodeWire(node)
    else -> throw IllegalArgumentException("no wire shape for ${node.javaClass.name}")
}

/** Serialize an AST object to the JSON the parser emits. */
fun toJson(node: Any?): String = WIRE_MAPPER.writeValueAsString(toWire(node))

/** The `ast_json` for one module. */
fun Module.toJson(): String = toJson(this)

/**
 * The program envelope `API.parseProgram` emits —
 * `{"root": str, "pkgs": {"__main__": [Module, …]}}` — which is a different
 * document from a single `Module`. The mirror of `AstLoader.WriteProgramJson`.
 */
fun toProgramJson(modules: List<Module>, root: String = Program.MAIN_PKG): String = WIRE_MAPPER.writeValueAsString(
    linkedMapOf<String, Any?>(
        "root" to root,
        "pkgs" to linkedMapOf<String, Any?>(root to modules.map { toWire(it) }),
    ),
)

// -----------------------------------------------------------------------
// Module
// -----------------------------------------------------------------------

private fun moduleWire(m: Module): Map<String, Any?> = linkedMapOf(
    // The Rust `Module` has no `pkg` field, so neither does this.
    "filename" to m.filename,
    "doc" to nodeWire(m.doc),
    "body" to listWire(m.body),
    "comments" to listWire(m.comments),
)

private fun programWire(p: Program): Map<String, Any?> = linkedMapOf(
    "root" to p.root,
    "pkgs" to (p.pkgs ?: emptyMap()).mapValues { (_, v) -> v.map { toWire(it) } },
)

// -----------------------------------------------------------------------
// Types — adjacently tagged
// -----------------------------------------------------------------------

/**
 * `Type` is `tag = "type", content = "value"`: the tag and the payload are
 * siblings, the tag names the shape rather than the type inside, and a newtype
 * payload is inlined into `value`, so `Named(Identifier)` is
 * `{"type":"Named","value":{…identifier…}}` with no extra wrapper.
 */
private fun typeWire(type: Type): Map<String, Any?> = when (type) {
    // A unit variant: the tag is the whole document. Writing
    // `{"type":"Any","value":null}` adds a key serde does not emit.
    is AnyType -> linkedMapOf<String, Any?>("type" to "Any")
    // `BasicType` is a fieldless enum, so its payload is the bare variant
    // name: "Int", not "int" and not {"name": "int"}.
    is BasicType -> linkedMapOf<String, Any?>("type" to "Basic", "value" to type.value?.name)
    is NamedType -> linkedMapOf<String, Any?>("type" to "Named", "value" to type.value?.let { identifierWire(it) })
    is ListType -> linkedMapOf<String, Any?>(
        "type" to "List",
        "value" to linkedMapOf<String, Any?>("inner_type" to optNode(type.value?.innerType)),
    )
    is DictType -> linkedMapOf<String, Any?>(
        "type" to "Dict",
        "value" to linkedMapOf<String, Any?>(
            "key_type" to optNode(type.value?.keyType),
            "value_type" to optNode(type.value?.valueType),
        ),
    )
    is UnionType -> linkedMapOf<String, Any?>(
        "type" to "Union",
        "value" to linkedMapOf<String, Any?>("type_elements" to listWire(type.value?.typeElements)),
    )
    // `LiteralType` is `tag + content` as well, so it nests one level deeper
    // than the rest.
    is LiteralType -> linkedMapOf<String, Any?>(
        "type" to "Literal",
        "value" to literalTypeValueWire(type.value),
    )
    is FunctionType -> linkedMapOf<String, Any?>(
        "type" to "Function",
        "value" to linkedMapOf<String, Any?>(
            // `Option<Vec<…>>`, so this one is genuinely nullable — a `Vec`
            // field would be an empty array here instead.
            "params_ty" to optNodeList(type.value?.paramsTy),
            "ret_ty" to optNode(type.value?.retTy),
        ),
    )
    else -> throw IllegalArgumentException("no wire shape for type ${type.javaClass.name}")
}

private fun literalTypeValueWire(value: LiteralTypeValue?): Map<String, Any?> = when (value) {
    null -> linkedMapOf("type" to null, "value" to null)
    // `Int` is the one variant whose `value` is a struct rather than a bare
    // scalar; `Str`/`Float`/`Bool` carry the scalar itself.
    is IntLiteralType -> linkedMapOf<String, Any?>(
        "type" to "Int",
        "value" to linkedMapOf<String, Any?>(
            "value" to value.value?.value,
            "suffix" to value.value?.suffix?.orElse(null)?.name,
        ),
    )
    is StrLiteralType -> linkedMapOf<String, Any?>("type" to "Str", "value" to value.value)
    is BoolLiteralType -> linkedMapOf<String, Any?>("type" to "Bool", "value" to value.isValue())
    is FloatLiteralType -> linkedMapOf<String, Any?>("type" to "Float", "value" to value.value)
    else -> throw IllegalArgumentException("no wire shape for literal type ${value.javaClass.name}")
}

// -----------------------------------------------------------------------
// Statements — internally tagged, struct fields flattened
// -----------------------------------------------------------------------

private fun stmtWire(stmt: Stmt): Map<String, Any?> = when (stmt) {
    is TypeAliasStmt -> linkedMapOf(
        "type" to "TypeAlias",
        "type_name" to nodeWire(stmt.typeName),
        "type_value" to nodeWire(stmt.typeValue),
        "ty" to nodeWire(stmt.ty),
    )
    is ExprStmt -> linkedMapOf("type" to "Expr", "exprs" to listWire(stmt.exprs))
    is UnificationStmt -> linkedMapOf(
        "type" to "Unification",
        "target" to nodeWire(stmt.target),
        // Untagged: the field is declared with the `SchemaExpr` struct, so the
        // payload carries no `type` key.
        "value" to nodeWire(stmt.value),
    )
    is AssignStmt -> linkedMapOf(
        "type" to "Assign",
        "targets" to listWire(stmt.targets),
        "value" to nodeWire(stmt.value),
        "ty" to nodeWire(stmt.ty),
    )
    is AugAssignStmt -> linkedMapOf(
        "type" to "AugAssign",
        "target" to nodeWire(stmt.target),
        "value" to nodeWire(stmt.value),
        "op" to stmt.op?.name,
    )
    is AssertStmt -> linkedMapOf(
        "type" to "Assert",
        "test" to nodeWire(stmt.test),
        "if_cond" to nodeWire(stmt.ifCond),
        "msg" to nodeWire(stmt.msg),
    )
    is IfStmt -> linkedMapOf(
        "type" to "If",
        "body" to listWire(stmt.body),
        "cond" to nodeWire(stmt.cond),
        "orelse" to listWire(stmt.orelse),
    )
    is ImportStmt -> linkedMapOf(
        "type" to "Import",
        "path" to nodeWire(stmt.path),
        "rawpath" to stmt.rawpath,
        "name" to stmt.name,
        // Spelled `asname` on the wire, with no separator.
        "asname" to nodeWire(stmt.asname),
        "pkg_name" to stmt.pkgName,
    )
    is SchemaAttr -> linkedMapOf(
        "type" to "SchemaAttr",
        // `SchemaAttr::doc` is a `String`, not an `Option<String>`, so it is
        // written as `""` rather than dropped — unlike `SchemaStmt`'s.
        "doc" to (stmt.doc ?: ""),
        "name" to nodeWire(stmt.name),
        "op" to stmt.op?.name,
        "value" to nodeWire(stmt.value),
        "is_optional" to stmt.isOptional,
        "decorators" to listWire(stmt.decorators),
        "ty" to nodeWire(stmt.ty),
    )
    is SchemaStmt -> linkedMapOf(
        "type" to "Schema",
        "doc" to nodeWire(stmt.doc),
        "name" to nodeWire(stmt.name),
        "parent_name" to nodeWire(stmt.parentName),
        "for_host_name" to nodeWire(stmt.forHostName),
        "is_mixin" to stmt.isMixin,
        "is_protocol" to stmt.isProtocol,
        "args" to nodeWire(stmt.args),
        "mixins" to listWire(stmt.mixins),
        "body" to listWire(stmt.body),
        "decorators" to listWire(stmt.decorators),
        "checks" to listWire(stmt.checks),
        "index_signature" to nodeWire(stmt.indexSignature),
    )
    is RuleStmt -> linkedMapOf(
        "type" to "Rule",
        "doc" to nodeWire(stmt.doc),
        "name" to nodeWire(stmt.name),
        "parent_rules" to listWire(stmt.parentRules),
        // `RuleStmt.decorators` is `Vec<NodeRef<CallExpr>>` — a field, not an
        // enum variant — so these are written *without* `"type":"Call"`, the
        // same shape `Decorator` has. Running them through `toWire` would put
        // a tag Rust never writes beside a struct it does.
        "decorators" to stmt.decorators.orEmpty().map { nodeWireOf(it) { c -> callStructWire(c) } },
        "checks" to listWire(stmt.checks),
        "args" to nodeWire(stmt.args),
        "for_host_name" to nodeWire(stmt.forHostName),
    )
    else -> throw IllegalArgumentException("no wire shape for statement ${stmt.javaClass.name}")
}

// -----------------------------------------------------------------------
// Expressions — internally tagged, struct fields flattened
// -----------------------------------------------------------------------

private fun exprWire(expr: Expr): Map<String, Any?> = when (expr) {
    is TargetExpr -> linkedMapOf(
        "type" to "Target",
        "name" to nodeWire(expr.nameRef),
        "pkgpath" to expr.pkgpath,
        "paths" to expr.paths.orEmpty().map { memberOrIndexWire(it) },
    )
    is IdentifierExpr -> linkedMapOf(
        "type" to "Identifier",
        "names" to listWire(expr.nameNodes),
        "pkgpath" to expr.pkgpath,
        "ctx" to expr.ctx?.name,
    )
    is UnaryExpr -> linkedMapOf("type" to "Unary", "op" to expr.op?.name, "operand" to nodeWire(expr.operand))
    is BinaryExpr -> linkedMapOf(
        "type" to "Binary",
        "left" to nodeWire(expr.left),
        "op" to expr.op?.name,
        "right" to nodeWire(expr.right),
    )
    is IfExpr -> linkedMapOf(
        "type" to "If",
        "body" to nodeWire(expr.body),
        "cond" to nodeWire(expr.cond),
        "orelse" to nodeWire(expr.orelse),
    )
    is SelectorExpr -> linkedMapOf(
        "type" to "Selector",
        "value" to nodeWire(expr.value),
        "attr" to nodeWire(expr.attr),
        "ctx" to expr.ctx?.name,
        "has_question" to expr.isHasQuestion,
    )
    is CallExpr -> callWire(expr)
    is ParenExpr -> linkedMapOf("type" to "Paren", "expr" to nodeWire(expr.expr))
    is QuantExpr -> linkedMapOf(
        "type" to "Quant",
        "target" to nodeWire(expr.target),
        "variables" to listWire(expr.variables),
        "op" to expr.op?.name,
        "test" to nodeWire(expr.test),
        "if_cond" to nodeWire(expr.ifCond),
        "ctx" to expr.ctx?.name,
    )
    is ListExpr -> linkedMapOf("type" to "List", "elts" to listWire(expr.elts), "ctx" to expr.ctx?.name)
    is ListIfItemExpr -> linkedMapOf(
        "type" to "ListIfItem",
        "if_cond" to nodeWire(expr.ifCond),
        "exprs" to listWire(expr.exprs),
        "orelse" to nodeWire(expr.orelse),
    )
    is ListComp -> linkedMapOf(
        "type" to "ListComp",
        "elt" to nodeWire(expr.elt),
        "generators" to listWire(expr.generators),
    )
    is StarredExpr -> linkedMapOf("type" to "Starred", "value" to nodeWire(expr.value), "ctx" to expr.ctx?.name)
    is DictComp -> linkedMapOf(
        "type" to "DictComp",
        // `entry` is a bare `ConfigEntry` — no `type` key, no `node` wrapper.
        "entry" to configEntryWire(expr.entry),
        "generators" to listWire(expr.generators),
    )
    is ConfigIfEntryExpr -> linkedMapOf(
        "type" to "ConfigIfEntry",
        "if_cond" to nodeWire(expr.ifCond),
        "items" to listWire(expr.items),
        "orelse" to nodeWire(expr.orelse),
    )
    is CompClause -> compClauseTagged(expr)
    is SchemaExpr -> schemaTagged(expr)
    is ConfigExpr -> linkedMapOf("type" to "Config", "items" to listWire(expr.items))
    is LambdaExpr -> linkedMapOf(
        "type" to "Lambda",
        "args" to nodeWire(expr.args),
        "body" to listWire(expr.body),
        "return_ty" to nodeWire(expr.returnTy),
    )
    is Subscript -> linkedMapOf(
        "type" to "Subscript",
        // A slice keeps its bounds in `lower`/`upper`/`step`; each is an
        // `Option<NodeRef<Expr>>` and each is null for a plain `a[0]`.
        "value" to nodeWire(expr.value),
        "index" to nodeWire(expr.index),
        "lower" to nodeWire(expr.lower),
        "upper" to nodeWire(expr.upper),
        "step" to nodeWire(expr.step),
        "ctx" to expr.ctx?.name,
        "has_question" to expr.isHasQuestion,
    )
    is Compare -> linkedMapOf(
        "type" to "Compare",
        "left" to nodeWire(expr.left),
        // A `CmpOp` is a fieldless enum, not a node: a bare array of strings,
        // with no `node` key and no position.
        "ops" to expr.ops.orEmpty().map { it.name },
        "comparators" to listWire(expr.comparators),
    )
    is NumberLit -> linkedMapOf(
        "type" to "NumberLit",
        "binary_suffix" to expr.binarySuffix?.orElse(null)?.name,
        // Doubly tagged: the number is a `{"type":"Int","value":1}` object of
        // its own, not the bare number.
        "value" to numberLitValueWire(expr.value),
    )
    is StringLit -> linkedMapOf(
        "type" to "StringLit",
        "is_long_string" to expr.isLongString,
        "raw_value" to expr.rawValue,
        "value" to expr.value,
    )
    is NameConstantLit -> linkedMapOf("type" to "NameConstantLit", "value" to expr.value?.name)
    is JoinedString -> linkedMapOf(
        "type" to "JoinedString",
        "is_long_string" to expr.isLongString,
        "values" to listWire(expr.values),
        "raw_value" to expr.rawValue,
    )
    is FormattedValue -> linkedMapOf(
        "type" to "FormattedValue",
        "is_long_string" to expr.isLongString,
        "value" to nodeWire(expr.value),
        // `Option<String>` — the text after the `:`, with no position and no
        // wrapper around it.
        "format_spec" to expr.formatSpec,
    )
    // A unit struct: the tag is the whole object. Rust's variant is
    // `Missing(MissingExpr)`, so the tag is "Missing" -- not the name of the
    // class, and not the `get_expr_name()` spelling "MissingExpression".
    is MissingExpr -> linkedMapOf<String, Any?>("type" to "Missing")
    else -> throw IllegalArgumentException("no wire shape for expression ${expr.javaClass.name}")
}

private fun numberLitValueWire(value: NumberLitValue?): Map<String, Any?>? = when (value) {
    null -> null
    is IntNumberLitValue -> linkedMapOf<String, Any?>("type" to "Int", "value" to value.value)
    is FloatNumberLitValue -> linkedMapOf<String, Any?>("type" to "Float", "value" to value.value)
    else -> throw IllegalArgumentException("no wire shape for number literal ${value.javaClass.name}")
}

// -----------------------------------------------------------------------
// Untagged plain structs
// -----------------------------------------------------------------------

private fun identifierWire(i: Identifier?): Map<String, Any?>? = i?.let {
    linkedMapOf(
        "names" to listWire(it.nameNodes),
        "pkgpath" to (it.pkgpath ?: ""),
        "ctx" to it.ctx?.name,
    )
}

private fun targetWire(t: Target?): Map<String, Any?>? = t?.let {
    linkedMapOf(
        "name" to nodeWire(it.nameRef),
        "paths" to it.paths.orEmpty().map { p -> memberOrIndexWire(p) },
        "pkgpath" to (it.pkgpath ?: ""),
    )
}

private fun keywordWire(k: Keyword?): Map<String, Any?>? = k?.let {
    linkedMapOf(
        "arg" to nodeWire(it.arg),
        "value" to nodeWire(it.value),
    )
}

private fun argumentsWire(a: Arguments?): Map<String, Any?>? = a?.let {
    linkedMapOf(
        // A parameter name is the untagged `Identifier` struct, so it is
        // written without a `type` key — the same name reached as an
        // expression carries `"type":"Identifier"`.
        "args" to listWire(it.args),
        // `Vec<Option<…>>`: the nulls are slots, and a missing key is an empty
        // list because a `Vec` is never absent.
        "defaults" to optSlotWire(it.defaults),
        "ty_list" to optSlotWire(it.tyList),
    )
}

private fun checkWire(c: CheckExpr?): Map<String, Any?>? = c?.let {
    linkedMapOf(
        "test" to nodeWire(it.test),
        "if_cond" to nodeWire(it.ifCond),
        "msg" to nodeWire(it.msg),
    )
}

private fun decoratorWire(d: Decorator?): Map<String, Any?>? = d?.let {
    linkedMapOf(
        "func" to nodeWire(it.func),
        "args" to listWire(it.args),
        "keywords" to listWire(it.keywords),
    )
}

/** The untagged `CallExpr` struct, without the `"type":"Call"` an expression gets. */
private fun callStructWire(c: CallExpr?): Map<String, Any?>? = c?.let {
    linkedMapOf(
        "func" to nodeWire(it.func),
        "args" to listWire(it.args),
        "keywords" to listWire(it.keywords),
    )
}

private fun callWire(c: CallExpr): Map<String, Any?> =
    linkedMapOf<String, Any?>("type" to "Call") + callStructWire(c)!!

private fun configEntryWire(c: ConfigEntry?): Map<String, Any?>? {
    if (c == null) return null
    val wire = linkedMapOf<String, Any?>(
        "key" to nodeWire(c.key),
        "value" to nodeWire(c.value),
        "operation" to c.operation?.name,
    )
    // `#[serde(skip_serializing_if = "is_false")]` — omitted when false,
    // present when true. Writing `"is_shorthand": false` puts a key Rust never
    // writes next to the three it does.
    if (c.isShorthand) wire["is_shorthand"] = true
    return wire
}

private fun compClauseWire(c: CompClause?): Map<String, Any?>? = c?.let {
    linkedMapOf(
        "targets" to listWire(it.targets),
        "iter" to nodeWire(it.iter),
        "ifs" to listWire(it.ifs),
    )
}

/** `Expr::CompClause` is a newtype over the same struct, so this is the tagged spelling. */
private fun compClauseTagged(c: CompClause): Map<String, Any?> =
    linkedMapOf<String, Any?>("type" to "CompClause") + compClauseWire(c)!!

private fun schemaConfigWire(s: SchemaConfig?): Map<String, Any?>? = s?.let {
    linkedMapOf(
        "name" to nodeWire(it.name),
        "args" to listWire(it.args),
        "kwargs" to listWire(it.kwargs),
        "config" to nodeWire(it.config),
    )
}

/** `Expr::Schema` is a newtype over `SchemaConfig`, so this is the tagged spelling. */
private fun schemaTagged(s: SchemaExpr): Map<String, Any?> =
    linkedMapOf<String, Any?>("type" to "Schema") + linkedMapOf(
        "name" to nodeWire(s.name),
        "args" to listWire(s.args),
        "kwargs" to listWire(s.kwargs),
        "config" to nodeWire(s.config),
    )

private fun indexSignatureWire(s: SchemaIndexSignature?): Map<String, Any?>? = s?.let {
    linkedMapOf(
        "key_name" to nodeWire(it.keyName),
        "value" to nodeWire(it.value),
        "any_other" to it.isAnyOther,
        "key_ty" to nodeWire(it.keyTy),
        "value_ty" to nodeWire(it.valueTy),
    )
}

/**
 * `Comment` is a plain struct with one `String` field, so the object under
 * `node` is `{"text": "…"}` and *not* the text. A writer that emits the bare
 * string here produces a document no decoder can read back — the bug that has
 * shipped in four bindings.
 */
private fun commentWire(c: Comment?): Map<String, Any?>? = c?.let { linkedMapOf("text" to it.text) }

/**
 * `MemberOrIndex` is `tag = "type", content = "value"` like `Type`, so the
 * node sits under `value` beside the tag.
 */
private fun memberOrIndexWire(m: MemberOrIndex): Map<String, Any?> = when (m) {
    is Member -> linkedMapOf("type" to "Member", "value" to nodeWire(m.value))
    is Index -> linkedMapOf("type" to "Index", "value" to nodeWire(m.value))
    else -> throw IllegalArgumentException("no wire shape for member/index ${m.javaClass.name}")
}
