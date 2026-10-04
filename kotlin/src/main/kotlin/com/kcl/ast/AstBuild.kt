// AstBuild.kt — constructors for the typed AST.
//
// The node classes in `src/main/java/com/kcl/ast` are Jackson-bound Java
// POJOs: a no-arg constructor, a private field, a getter and a setter. That
// shape is what `parseModule` needs and it is kept exactly as it is — turning
// them into Kotlin `data class`es would move every `@JsonProperty` off the
// class the deserializer binds, and would take the `Expr`/`Stmt`/`Type`
// `@JsonSubTypes` hierarchy with it. So the "constructor" for this binding is
// a set of factory functions with default arguments, one per node type, and
// the default for each parameter is the value the Rust parser itself produces
// for that field:
//
//   * a `Vec<T>` is never absent, so a list parameter defaults to an empty
//     list and is written as `[]` — never `null`;
//   * an `Option<T>` defaults to `null` (or `Optional.empty()`, where the
//     field is declared `Optional`) and is written as `null`;
//   * a `String` field is written as `""` when unset, because Rust writes the
//     key either way.
//
// This is the same shape as the .NET `X.Of(...)` factories in
// `dotnet/KclLib.AST`, which is deliberate: the two bindings are meant to
// converge on one generated form later, and a hand-written pair that reads the
// same is the cheapest way to find out what that form should be.
//
// One thing this binding does *not* need, and the .NET one does, is a
// boxing lift. `Expr`, `Stmt` and `Type` are three real base classes here, so
// a field is declared `NodeRef<Expr>` and a `CallExpr` is already an `Expr`;
// the invariant-generics problem that forces .NET to store those fields as
// `NodeRef<object>` does not arise.

package com.kcl.ast

import java.util.Optional

/**
 * Wrap a payload in a `NodeRef` — the shape the wire carries.
 *
 * The five position keys are flattened onto the wrapper beside `node`; there
 * is no `pos` key on the wire and no nested object. `id` is left `null`
 * because Rust only serialises it under `SHOULD_SERIALIZE_ID`, which is off,
 * so `id` never appears in `ast_json`.
 */
fun <T> nodeRef(
    node: T,
    filename: String = "",
    line: Long = 1L,
    column: Long = 1L,
    endLine: Long = line,
    endColumn: Long = column,
): NodeRef<T> = NodeRef<T>(null, node, filename, line, column, endLine, endColumn)

/**
 * A wrapper that is present but holds nothing — Rust's `Node<T>`, whose `node`
 * field is not an `Option`, so serde writes `"node": null` rather than
 * dropping the key. Distinct from a `null` field reference, which is the
 * `Option::None` at the outer level and serialises as the field itself being
 * `null`.
 */
fun <T> emptyNodeRef(
    filename: String = "",
    line: Long = 1L,
    column: Long = 1L,
    endLine: Long = line,
    endColumn: Long = column,
): NodeRef<T> = NodeRef<T>(null, null, filename, line, column, endLine, endColumn)

/**
 * One segment of a dotted name, wrapped. `identifierExpr("pkg", "a")` is
 * `pkg.a`, so the arguments are the `names` list and not a name plus a
 * package path.
 */
fun nameRef(name: String, filename: String = "", line: Long = 1L, column: Long = 1L, endColumn: Long = column): NodeRef<String> =
    nodeRef(name, filename, line, column, endColumn = endColumn)

// --- flat DTOs: plain structs with no `type` tag --------------------------

fun identifier(
    vararg names: String,
    pkgpath: String = "",
    ctx: ExprContext? = null,
): Identifier = Identifier().apply {
    setNames(names.map { nameRef(it) })
    this.pkgpath = pkgpath
    this.ctx = ctx
}

/** The same [identifier] with positions on each name segment. */
fun identifierAt(
    vararg names: String,
    pkgpath: String = "",
    ctx: ExprContext? = null,
    filename: String = "",
    line: Long = 1L,
    column: Long = 1L,
): Identifier = Identifier().apply {
    setNames(names.mapIndexed { i, n -> nameRef(n, filename, line, column + i, endColumn = column + i + n.length) })
    this.pkgpath = pkgpath
    this.ctx = ctx
}

fun target(name: String, pkgpath: String = "", paths: List<MemberOrIndex> = emptyList()): Target =
    Target().apply {
        setName(nameRef(name))
        this.pkgpath = pkgpath
        this.paths = paths
    }

fun keyword(arg: String, value: NodeRef<Expr>? = null): Keyword =
    keyword(nodeRef(identifier(arg)), value)

fun keyword(arg: Identifier, value: NodeRef<Expr>? = null): Keyword =
    keyword(nodeRef(arg), value)

/**
 * The overload to reach for when the argument name has a position of its own.
 *
 * A keyword argument name is a full [Identifier] behind a `NodeRef`, and the
 * parser gives that `NodeRef` the name's span — not the keyword's — while the
 * keyword itself is wrapped at the span that starts at the name. Passing an
 * unpositioned [Identifier] to the overload above silently substitutes the
 * zero span and changes two fields the capture would not match.
 */
fun keyword(arg: NodeRef<Identifier>, value: NodeRef<Expr>? = null): Keyword = Keyword().apply {
    this.arg = arg
    this.value = value
}

/**
 * A lambda's parameter list.
 *
 * `defaults` and `ty_list` are `Vec<Option<NodeRef<…>>>` and are indexed by
 * argument position, so they carry one slot per parameter — `lambda x, y` is
 * `"defaults": [null, null]`, not `[]`. [arguments] therefore takes three
 * parallel lists; the null-filled ones are built for you by the convenience
 * overloads below.
 */
fun arguments(
    args: List<NodeRef<Identifier>> = emptyList(),
    defaults: List<NodeRef<Expr>?> = emptyList(),
    tyList: List<NodeRef<Type>?> = emptyList(),
): Arguments = Arguments().apply {
    this.args = args
    this.defaults = defaults
    this.tyList = tyList
}

/** `lambda x, y` — two names and no defaults and no annotations. */
fun argumentsOf(vararg names: String): Arguments =
    arguments(names.map { nodeRef(identifier(it)) }, List(names.size) { null }, List(names.size) { null })

fun checkExpr(test: NodeRef<Expr>? = null, ifCond: NodeRef<Expr>? = null, msg: NodeRef<Expr>? = null): CheckExpr =
    CheckExpr().apply {
        this.test = test
        this.ifCond = ifCond
        this.msg = msg
    }

/**
 * A decorator is a call. `SchemaStmt.decorators`, `SchemaAttr.decorators` and
 * `RuleStmt.decorators` are all `Vec<NodeRef<CallExpr>>` reached through a
 * field rather than through the `Expr` enum, so the struct is written without
 * a `"type":"Call"` beside it — the same shape, spelled twice in Rust.
 */
fun decorator(func: NodeRef<Expr>? = null, args: List<NodeRef<Expr>> = emptyList(), keywords: List<NodeRef<Keyword>> = emptyList()): Decorator =
    Decorator().apply {
        this.func = func
        this.args = args
        this.keywords = keywords
    }

fun configEntry(
    key: NodeRef<Expr>? = null,
    value: NodeRef<Expr>? = null,
    operation: ConfigEntryOperation? = null,
    isShorthand: Boolean = false,
): ConfigEntry = ConfigEntry().apply {
    this.key = key
    this.value = value
    this.operation = operation
    this.isShorthand = isShorthand
}

fun compClause(
    targets: List<NodeRef<Identifier>> = emptyList(),
    iter: NodeRef<Expr>? = null,
    ifs: List<NodeRef<Expr>> = emptyList(),
): CompClause = CompClause().apply {
    this.targets = targets
    this.iter = iter
    this.ifs = ifs
}

fun schemaConfig(
    name: NodeRef<Identifier>? = null,
    args: List<NodeRef<Expr>> = emptyList(),
    kwargs: List<NodeRef<Keyword>> = emptyList(),
    config: NodeRef<Expr>? = null,
): SchemaConfig = SchemaConfig().apply {
    this.name = name
    this.args = args
    this.kwargs = kwargs
    this.config = config
}

fun schemaIndexSignature(
    keyName: NodeRef<String>? = null,
    value: NodeRef<Expr>? = null,
    anyOther: Boolean = false,
    keyTy: NodeRef<Type>? = null,
    valueTy: NodeRef<Type>? = null,
): SchemaIndexSignature = SchemaIndexSignature().apply {
    this.keyName = keyName
    this.value = value
    this.isAnyOther = anyOther
    this.keyTy = keyTy
    this.valueTy = valueTy
}

/** A comment. The payload is `{"text": …}`, never the bare string. */
fun comment(text: String): Comment = Comment().apply { this.text = text }

fun memberOrIndexOf(name: String): MemberOrIndex = Member(nodeRef(name))

fun indexOf(value: NodeRef<Expr>): MemberOrIndex = Index(value)

// --- Types: `tag = "type", content = "value"` -------------------------------
//
// The `Type` variants that carry a struct hold it in a nested `…TypeValue`
// exposed as `value`, because that is where `content = "value"` puts it on the
// wire. `Any` and `Basic` are fieldless enums and hold the bare variant name
// there instead.

/** `Type::Any` — the one unit variant, so the tag is the whole document. */
fun anyType(): AnyType = AnyType().apply { value = AnyType.AnyTypeEnum.Any }

fun basicType(name: BasicType.BasicTypeEnum): BasicType = BasicType().apply { value = name }

fun basicIntType() = basicType(BasicType.BasicTypeEnum.Int)
fun basicStrType() = basicType(BasicType.BasicTypeEnum.Str)
fun basicBoolType() = basicType(BasicType.BasicTypeEnum.Bool)
fun basicFloatType() = basicType(BasicType.BasicTypeEnum.Float)

fun namedType(name: String): NamedType = NamedType().apply {
    value = NamedType.NamedTypeValue().apply { setNames(listOf(nameRef(name))) }
}

fun listType(innerType: NodeRef<Type>): ListType = ListType().apply {
    value = ListType.ListTypeValue().apply { this.innerType = Optional.of(innerType) }
}

fun dictType(keyType: NodeRef<Type>, valueType: NodeRef<Type>): DictType = DictType().apply {
    value = DictType.DictTypeValue().apply {
        this.keyType = Optional.of(keyType)
        this.valueType = Optional.of(valueType)
    }
}

fun unionType(vararg elements: NodeRef<Type>): UnionType = UnionType().apply {
    value = UnionType.UnionTypeValue().apply { typeElements = elements.toList() }
}

/**
 * `Type::Literal`. `LiteralType` is tagged again inside `value`, so this is
 * the one `Type` that nests a second tagged document:
 * `{"type":"Literal","value":{"type":"Int","value":{"value":1,"suffix":null}}}`.
 */
fun literalType(value: LiteralTypeValue): LiteralType = LiteralType().apply { this.value = value }

fun literalIntType(value: Long, suffix: NumberBinarySuffix? = null): LiteralType = literalType(
    IntLiteralType().apply {
        this.value = IntLiteralType.IntLiteralTypeValue().apply {
            this.value = value
            this.suffix = suffix?.let { Optional.of(it) } ?: Optional.empty()
        }
    },
)

fun literalStrType(value: String): LiteralType = literalType(StrLiteralType().apply { this.value = value })
fun literalBoolType(value: Boolean): LiteralType = literalType(BoolLiteralType().apply { setValue(value) })
fun literalFloatType(value: Double): LiteralType = literalType(FloatLiteralType().apply { this.value = value })

/**
 * `Type::Function`. `params_ty` is `Option<Vec<NodeRef<Type>>>`: the parser
 * only ever produces `None` or `Some(non-empty)` (`crates/parser/src/parser/ty.rs`),
 * so the default is `Optional.empty()` and there is deliberately no factory
 * for the empty-list case — writing one would put a document on the wire the
 * parser never emits.
 */
@JvmOverloads
fun functionType(
    paramsTy: Optional<List<NodeRef<Type>>> = Optional.empty(),
    retTy: Optional<NodeRef<Type>> = Optional.empty(),
): FunctionType = FunctionType().apply {
    value = FunctionType.FunctionTypeValue().apply {
        this.paramsTy = paramsTy
        this.retTy = retTy
    }
}

// --- Expressions -----------------------------------------------------------

fun targetExpr(name: String, pkgpath: String = "", paths: List<MemberOrIndex> = emptyList()): TargetExpr =
    TargetExpr().apply {
        setName(nameRef(name))
        this.pkgpath = pkgpath
        this.paths = paths
    }

fun identifierExpr(vararg names: String, pkgpath: String = "", ctx: ExprContext? = ExprContext.Load): IdentifierExpr =
    IdentifierExpr().apply {
        setNames(names.map { nameRef(it) })
        this.pkgpath = pkgpath
        this.ctx = ctx
    }

fun unaryExpr(op: UnaryOp, operand: NodeRef<Expr>? = null): UnaryExpr = UnaryExpr().apply {
    this.op = op
    this.operand = operand
}

fun binaryExpr(left: NodeRef<Expr>? = null, op: BinOp, right: NodeRef<Expr>? = null): BinaryExpr = BinaryExpr().apply {
    this.left = left
    this.op = op
    this.right = right
}

fun ifExpr(body: NodeRef<Expr>? = null, cond: NodeRef<Expr>? = null, orelse: NodeRef<Expr>? = null): IfExpr = IfExpr().apply {
    this.body = body
    this.cond = cond
    this.orelse = orelse
}

fun selectorExpr(
    value: NodeRef<Expr>? = null,
    attr: NodeRef<Identifier>? = null,
    ctx: ExprContext? = ExprContext.Load,
    hasQuestion: Boolean = false,
): SelectorExpr = SelectorExpr().apply {
    this.value = value
    this.attr = attr
    this.ctx = ctx
    this.isHasQuestion = hasQuestion
}

fun callExpr(
    func: NodeRef<Expr>? = null,
    args: List<NodeRef<Expr>> = emptyList(),
    keywords: List<NodeRef<Keyword>> = emptyList(),
): CallExpr = CallExpr().apply {
    this.func = func
    this.args = args
    this.keywords = keywords
}

fun parenExpr(expr: NodeRef<Expr>? = null): ParenExpr = ParenExpr().apply { this.expr = expr }

fun quantExpr(
    target: NodeRef<Expr>? = null,
    variables: List<NodeRef<Identifier>> = emptyList(),
    op: QuantOperation? = null,
    test: NodeRef<Expr>? = null,
    ifCond: NodeRef<Expr>? = null,
    ctx: ExprContext? = ExprContext.Load,
): QuantExpr = QuantExpr().apply {
    this.target = target
    this.variables = variables
    this.op = op
    this.test = test
    this.ifCond = ifCond
    this.ctx = ctx
}

fun listExpr(elts: List<NodeRef<Expr>> = emptyList(), ctx: ExprContext? = ExprContext.Load): ListExpr = ListExpr().apply {
    this.elts = elts
    this.ctx = ctx
}

fun listIfItemExpr(
    ifCond: NodeRef<Expr>? = null,
    exprs: List<NodeRef<Expr>> = emptyList(),
    orelse: NodeRef<Expr>? = null,
): ListIfItemExpr = ListIfItemExpr().apply {
    this.ifCond = ifCond
    this.exprs = exprs
    this.orelse = orelse
}

fun listComp(elt: NodeRef<Expr>? = null, generators: List<NodeRef<CompClause>> = emptyList()): ListComp = ListComp().apply {
    this.elt = elt
    this.generators = generators
}

fun starredExpr(value: NodeRef<Expr>? = null, ctx: ExprContext? = ExprContext.Load): StarredExpr = StarredExpr().apply {
    this.value = value
    this.ctx = ctx
}

/** `entry` is a bare `ConfigEntry` — no `type` key, no `node` wrapper. */
fun dictComp(entry: ConfigEntry, generators: List<NodeRef<CompClause>> = emptyList()): DictComp = DictComp().apply {
    this.entry = entry
    this.generators = generators
}

fun configIfEntryExpr(
    ifCond: NodeRef<Expr>? = null,
    items: List<NodeRef<ConfigEntry>> = emptyList(),
    orelse: NodeRef<Expr>? = null,
): ConfigIfEntryExpr = ConfigIfEntryExpr().apply {
    this.ifCond = ifCond
    this.items = items
    this.orelse = orelse
}

fun schemaExpr(
    name: NodeRef<Identifier>? = null,
    args: List<NodeRef<Expr>> = emptyList(),
    kwargs: List<NodeRef<Keyword>> = emptyList(),
    config: NodeRef<Expr>? = null,
): SchemaExpr = SchemaExpr().apply {
    this.name = name
    this.args = args
    this.kwargs = kwargs
    this.config = config
}

fun configExpr(items: List<NodeRef<ConfigEntry>> = emptyList()): ConfigExpr = ConfigExpr().apply { this.items = items }

fun lambdaExpr(
    args: NodeRef<Arguments>? = null,
    body: List<NodeRef<Stmt>> = emptyList(),
    returnTy: NodeRef<Type>? = null,
): LambdaExpr = LambdaExpr().apply {
    this.args = args
    this.body = body
    this.returnTy = returnTy
}

/**
 * A slice keeps its bounds: `lower`/`upper`/`step` are `Option<NodeRef<Expr>>`
 * and are all `null` for a plain `a[0]`.
 */
@JvmOverloads
fun subscript(
    value: NodeRef<Expr>? = null,
    index: NodeRef<Expr>? = null,
    lower: NodeRef<Expr>? = null,
    upper: NodeRef<Expr>? = null,
    step: NodeRef<Expr>? = null,
    ctx: ExprContext? = ExprContext.Load,
    hasQuestion: Boolean = false,
): Subscript = Subscript().apply {
    this.value = value
    this.index = index
    this.lower = lower
    this.upper = upper
    this.step = step
    this.ctx = ctx
    this.isHasQuestion = hasQuestion
}

fun compare(
    left: NodeRef<Expr>? = null,
    ops: List<CmpOp> = emptyList(),
    comparators: List<NodeRef<Expr>> = emptyList(),
): Compare = Compare().apply {
    this.left = left
    this.ops = ops
    this.comparators = comparators
}

fun numberLit(value: NumberLitValue, binarySuffix: NumberBinarySuffix? = null): NumberLit = NumberLit().apply {
    this.value = value
    this.binarySuffix = binarySuffix?.let { Optional.of(it) } ?: Optional.empty()
}

fun intNumberLit(value: Long): NumberLit = numberLit(IntNumberLitValue().apply { this.value = value })

fun floatNumberLit(value: Double): NumberLit = numberLit(FloatNumberLitValue().apply { this.value = value })

fun stringLit(value: String, isLongString: Boolean = false, rawValue: String? = null): StringLit = StringLit().apply {
    this.value = value
    this.isLongString = isLongString
    this.rawValue = rawValue ?: quoted(value, isLongString)
}

fun nameConstantLit(value: NameConstant): NameConstantLit = NameConstantLit().apply { this.value = value }

fun joinedString(
    values: List<NodeRef<Expr>> = emptyList(),
    rawValue: String? = null,
    isLongString: Boolean = false,
): JoinedString = JoinedString().apply {
    this.values = values
    this.rawValue = rawValue
    this.isLongString = isLongString
}

fun formattedValue(
    value: NodeRef<Expr>? = null,
    formatSpec: String? = null,
    isLongString: Boolean = false,
): FormattedValue = FormattedValue().apply {
    this.value = value
    this.formatSpec = formatSpec
    this.isLongString = isLongString
}

/** `Expr::Missing` — a unit struct, so the tag is the whole object. */
fun missingExpr(): MissingExpr = MissingExpr()

// --- Statements ------------------------------------------------------------

fun typeAliasStmt(
    typeName: NodeRef<Identifier>? = null,
    typeValue: NodeRef<String>? = null,
    ty: NodeRef<Type>? = null,
): TypeAliasStmt = TypeAliasStmt().apply {
    this.typeName = typeName
    this.typeValue = typeValue
    this.ty = ty
}

fun exprStmt(vararg exprs: NodeRef<Expr>): ExprStmt = ExprStmt().apply { this.exprs = exprs.toList() }

fun unificationStmt(target: NodeRef<Identifier>? = null, value: NodeRef<SchemaConfig>? = null): UnificationStmt =
    UnificationStmt().apply {
        this.target = target
        this.value = value
    }

fun assignStmt(
    targets: List<NodeRef<Target>> = emptyList(),
    value: NodeRef<Expr>? = null,
    ty: NodeRef<Type>? = null,
): AssignStmt = AssignStmt().apply {
    this.targets = targets
    this.value = value
    this.ty = ty
}

fun augAssignStmt(target: NodeRef<Target>? = null, value: NodeRef<Expr>? = null, op: AugOp? = null): AugAssignStmt =
    AugAssignStmt().apply {
        this.target = target
        this.value = value
        this.op = op
    }

fun assertStmt(test: NodeRef<Expr>? = null, ifCond: NodeRef<Expr>? = null, msg: NodeRef<Expr>? = null): AssertStmt =
    AssertStmt().apply {
        this.test = test
        this.ifCond = ifCond
        this.msg = msg
    }

fun ifStmt(
    body: List<NodeRef<Stmt>> = emptyList(),
    cond: NodeRef<Expr>? = null,
    orelse: List<NodeRef<Stmt>> = emptyList(),
): IfStmt = IfStmt().apply {
    this.body = body
    this.cond = cond
    this.orelse = orelse
}

fun importStmt(
    path: NodeRef<String>? = null,
    rawpath: String? = null,
    name: String? = null,
    asname: NodeRef<String>? = null,
    pkgName: String? = null,
): ImportStmt = ImportStmt().apply {
    this.path = path
    this.rawpath = rawpath
    this.name = name
    this.asname = asname
    this.pkgName = pkgName
}

fun schemaAttr(
    name: NodeRef<String>? = null,
    doc: String? = null,
    op: AugOp? = null,
    value: NodeRef<Expr>? = null,
    isOptional: Boolean = false,
    decorators: List<NodeRef<Decorator>> = emptyList(),
    ty: NodeRef<Type>? = null,
): SchemaAttr = SchemaAttr().apply {
    this.name = name
    // `SchemaAttr::doc` is a `String`, so it is written as `""` rather than
    // dropped — unlike `SchemaStmt`'s, which is an `Option<NodeRef<String>>`.
    this.doc = doc ?: ""
    this.op = op
    this.value = value
    this.isOptional = isOptional
    this.decorators = decorators
    this.ty = ty
}

fun schemaStmt(
    name: NodeRef<String>? = null,
    doc: NodeRef<String>? = null,
    parentName: NodeRef<Identifier>? = null,
    forHostName: NodeRef<Identifier>? = null,
    isMixin: Boolean = false,
    isProtocol: Boolean = false,
    args: NodeRef<Arguments>? = null,
    mixins: List<NodeRef<Identifier>> = emptyList(),
    body: List<NodeRef<Stmt>> = emptyList(),
    decorators: List<NodeRef<Decorator>> = emptyList(),
    checks: List<NodeRef<CheckExpr>> = emptyList(),
    indexSignature: NodeRef<SchemaIndexSignature>? = null,
): SchemaStmt = SchemaStmt().apply {
    this.name = name
    this.doc = doc
    this.parentName = parentName
    this.forHostName = forHostName
    this.isMixin = isMixin
    this.isProtocol = isProtocol
    this.args = args
    this.mixins = mixins
    this.body = body
    this.decorators = decorators
    this.checks = checks
    this.indexSignature = indexSignature
}

fun ruleStmt(
    name: NodeRef<String>? = null,
    doc: NodeRef<String>? = null,
    parentRules: List<NodeRef<Identifier>> = emptyList(),
    decorators: List<NodeRef<CallExpr>> = emptyList(),
    checks: List<NodeRef<CheckExpr>> = emptyList(),
    args: NodeRef<Arguments>? = null,
    forHostName: NodeRef<Identifier>? = null,
): RuleStmt = RuleStmt().apply {
    this.name = name
    this.doc = doc
    this.parentRules = parentRules
    this.decorators = decorators
    this.checks = checks
    this.args = args
    this.forHostName = forHostName
}

// --- Module ----------------------------------------------------------------

fun module(
    filename: String,
    doc: NodeRef<String>? = null,
    body: List<NodeRef<Stmt>> = emptyList(),
    comments: List<NodeRef<Comment>> = emptyList(),
): Module = Module().apply {
    this.filename = filename
    this.doc = doc
    this.body = body
    this.comments = comments
}

/**
 * The source spelling of a string literal, which Rust carries beside the
 * decoded value as `raw_value`. Not escaped the way a KCL literal is: this is
 * the convenience default for [stringLit], and a caller that cares can pass
 * the exact text.
 */
private fun quoted(value: String, isLongString: Boolean): String =
    if (isLongString) "\"\"\"$value\"\"\"" else "\"$value\""
