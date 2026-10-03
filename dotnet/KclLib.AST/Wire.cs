// Wire.cs — The write side: typed AST objects back to the JSON Rust emits.
//
// `AstLoader` turns `ast_json` into records; this turns records back into the
// same bytes. That symmetry is the point: a caller can build a tree by hand
// and hand it to anything that reads a KCL AST, and a decode/encode cycle is a
// fixed point, which is what makes a dropped field visible at all.
//
// Three wire shapes, and picking the wrong one is silent rather than loud:
//
//   1. `Stmt` and `Expr` are `#[serde(tag = "type")]`, and every variant is a
//      newtype over a struct, so serde *flattens* the struct's fields beside
//      the tag: `{"type":"Identifier","names":[…],"pkgpath":"","ctx":"Load"}`.
//      There is no `identifier` wrapper key to descend through, and emitting
//      one is the single most common way a writer gets this wrong.
//   2. `Type` is `#[serde(tag = "type", content = "value")]` — adjacently
//      tagged. The tag names the *shape* and the payload lives under `value`,
//      so `BasicType` is `{"type":"Basic","value":"Int"}` and never
//      `{"type":"Int"}`. `Any` is a unit variant: `{"type":"Any"}` with no
//      `value` key at all.
//   3. Everything else is a plain struct with no tag and cannot be dispatched
//      on. `Decorator` is a field-identical twin of untagged `CallExpr`;
//      `SchemaConfig` of untagged `SchemaExpr`; `MemberOrIndex` is tag +
//      content again.
//
// A `NodeRef<T>` is optional at two levels and they are not the same thing: a
// null `NodeRef` is the field itself being `null` (`Option<NodeRef<T>>` is
// `None`), while a present wrapper holding no value is `{"node": null, …}` and
// keeps its position keys. `Vec<Option<…>>` fields — `Arguments.defaults` and
// `Arguments.ty_list` among them — keep their nulls, because a null there
// occupies a slot and is meaningful.

using System.Text.Json;

namespace KclLib.AST;

/// <summary>
/// The write side of the AST package: typed objects to the JSON Rust's serde
/// produces. <see cref="AstLoader"/> is the mirror image.
/// </summary>
public static class AstWriter
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        // Every null in the tree is a key Rust writes, not an absent field, so
        // nothing is dropped. That is also the default; saying so keeps a
        // future default from quietly changing it.
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.Never,
    };

    /// <summary>Serialize an AST object to the JSON the parser emits.</summary>
    public static string WriteJson(object? node) => JsonSerializer.Serialize(ToWire(node), JsonOptions);

    public static object? ToWire(Module module) => new Dictionary<string, object?>
    {
        // The Rust `Module` has no `pkg` field, so neither does this.
        ["filename"] = module.Filename,
        ["doc"] = NodeWire(module.Doc, s => (object?)s),
        ["body"] = ListWire(module.Body, StmtWire),
        ["comments"] = ListWire(module.Comments, CommentWire),
    };

    public static object? ToWire(MemberOrIndex moi) => MemberOrIndexWire(moi);
    public static object? ToWire(Comment comment) => CommentWire(comment);

    /// <summary>
    /// The wire tree for an AST object, as nested
    /// <see cref="Dictionary{TKey,TValue}"/>/<c>List</c>/scalars — useful when
    /// the AST is going to be embedded in a larger document rather than
    /// serialized on its own.
    /// </summary>
    /// <remarks>
    /// This is the only conversion entry point, and it is total: every value in
    /// the package can be handed to it, whatever its static type.
    /// <c>Expr</c>, <c>Stmt</c> and <c>Type</c> are three Rust enums with no
    /// C# base record between them, so a field holding one of them is declared
    /// as <c>object</c> and the record type is the dispatch key. The untagged
    /// DTOs are reached the same way, which is why this one method serves
    /// every <c>NodeRef&lt;object&gt;</c> in the package: a lambda body holds
    /// statements, a return type holds a type, and a call's keywords hold
    /// untagged <c>Keyword</c> structs, all in the same slot. <c>NodeRef</c>
    /// itself is matched by its closed type below, so a wrapper that reaches
    /// this method as a bare <c>object</c> — which is what
    /// <see cref="Ast.Expr"/> produces — is unwrapped rather than mistaken
    /// for a payload.
    /// <para/>
    /// A value that is <em>already</em> a wire tree — the nested
    /// <see cref="Dictionary{TKey,TValue}"/>/<c>List</c>/scalar shape this
    /// method returns — is passed through unchanged, so the two entry points
    /// compose: <c>WriteJson(ToWire(x))</c> is the same document as
    /// <c>WriteJson(x)</c> rather than a second conversion pass that finds no
    /// AST record and writes <c>null</c>. A JSON scalar passes through for the
    /// same reason, and because a bare string <em>is</em> the right wire shape
    /// for the payloads that are strings.
    /// </para>
    /// </remarks>
    public static object? ToWire(object? node) => node switch
    {
        null => null,
        Dictionary<string, object?> or List<object?> or string or bool or long or double
            => node,
        // The closed `NodeRef` types, in the order the package declares them.
        // A `NodeRef<T>` for some other `T` — a wrapper round a concrete record
        // rather than one of the boxed DTOs — is what `Ast.Expr` avoids by
        // lifting the payload first.
        NodeRef<string> n => NodeWire(n, s => (object?)s),
        NodeRef<Comment> n => NodeWire(n, CommentWire),
        NodeRef<object> n => NodeWire(n, Wire),
        NodeRef<Identifier> n => NodeWire(n, IdentifierWire),
        NodeRef<Target> n => NodeWire(n, TargetWire),
        NodeRef<Arguments> n => NodeWire(n, ArgumentsWire),
        NodeRef<Keyword> n => NodeWire(n, KeywordWire),
        NodeRef<ConfigEntry> n => NodeWire(n, ConfigEntryWire),
        NodeRef<Decorator> n => NodeWire(n, DecoratorWire),
        NodeRef<CheckExpr> n => NodeWire(n, CheckWire),
        NodeRef<CompClause> n => NodeWire(n, CompClauseWire),
        NodeRef<SchemaConfig> n => NodeWire(n, SchemaConfigWire),
        NodeRef<SchemaIndexSignature> n => NodeWire(n, IndexSignatureWire),
        Module m => ToWire(m),
        // Types before statements before expressions: a record of one kind is
        // never a record of another, and the three families share no base.
        AnyType or NamedType or BasicType or ListType or DictType or UnionType or LiteralType or FunctionType
            => TypeWire(node),
        TypeAliasStmt or ExprStmt or UnificationStmt or AssignStmt or AugAssignStmt or AssertStmt
            or IfStmt or SchemaStmt or SchemaAttr or RuleStmt or ImportStmt
            => StmtWire(node),
        // The untagged plain structs, which cannot be dispatched on because
        // they carry no tag of their own.
        Comment c => CommentWire(c),
        Identifier i => IdentifierWire(i),
        Target t => TargetWire(t),
        Keyword k => KeywordWire(k),
        Arguments a => ArgumentsWire(a),
        ConfigEntry c => ConfigEntryWire(c),
        Decorator d => DecoratorWire(d),
        CallDto c => CallWire(c),
        CheckExpr c => CheckWire(c),
        CompClause c => CompClauseWire(c),
        SchemaConfig s => SchemaConfigWire(s),
        SchemaIndexSignature s => IndexSignatureWire(s),
        MemberOrIndex m => MemberOrIndexWire(m),
        // A tag this build claims no variant for still round-trips as itself.
        UnknownNode u => new Dictionary<string, object?> { ["type"] = u.Type },
        _ => ExprWire(node),
    };

    /// <summary>The single internal dispatcher every <c>NodeRef&lt;object&gt;</c> goes through.</summary>
    private static object? Wire(object payload) => ToWire(payload);

    // -----------------------------------------------------------------------
    // NodeRef
    // -----------------------------------------------------------------------

    /// <summary>
    /// A <c>NodeRef&lt;T&gt;</c>. The five <c>Pos</c> keys are flattened onto
    /// the wrapper beside <c>node</c> — there is no <c>pos</c> key on the
    /// wire — and they are written whenever a position is known. Rust's
    /// <c>Node&lt;T&gt;</c> also has an <c>id</c> field, but serde only writes
    /// it under <c>SHOULD_SERIALIZE_ID</c>, which is off, so it is not emitted
    /// here either.
    /// </summary>
    private static Dictionary<string, object?>? NodeWire<T>(NodeRef<T>? node, Func<T, object?> payload)
    {
        if (node == null) return null;
        var wire = new Dictionary<string, object?> { ["node"] = payload(node.Node) };
        if (node.Position is Pos pos)
        {
            wire["filename"] = pos.Filename;
            wire["line"] = pos.Line;
            wire["column"] = pos.Column;
            wire["end_line"] = pos.EndLine;
            wire["end_column"] = pos.EndColumn;
        }
        return wire;
    }

    /// <summary>
    /// A <c>Vec&lt;NodeRef&lt;T&gt;&gt;</c>. A Rust <c>Vec</c> is never absent,
    /// so a null list is written as an empty array rather than as <c>null</c>.
    /// </summary>
    private static List<object?> ListWire<T>(IEnumerable<NodeRef<T>>? nodes, Func<T, object?> payload)
    {
        var wire = new List<object?>();
        if (nodes == null) return wire;
        foreach (var n in nodes) wire.Add(NodeWire(n, payload));
        return wire;
    }

    /// <summary>
    /// A <c>Vec&lt;Option&lt;NodeRef&lt;T&gt;&gt;&gt;</c>. A null slot is data — an
    /// unnamed lambda parameter with no default and no annotation is
    /// <c>"defaults":[null, null]</c>, not <c>[]</c> — so the nulls are kept
    /// and the slot order is preserved.
    /// </summary>
    private static List<object?> OptSlotWire<T>(IEnumerable<NodeRef<T>?>? nodes, Func<T, object?> payload) =>
        nodes == null ? new List<object?>() : nodes.Select(n => (object?)NodeWire(n, payload)).ToList();

    // -----------------------------------------------------------------------
    // Types — adjacently tagged
    // -----------------------------------------------------------------------

    /// <summary>
    /// <c>Type</c> is <c>tag = "type", content = "value"</c>: the tag and the
    /// payload are siblings, and the tag names the shape rather than the type
    /// inside. A newtype payload is inlined into <c>value</c>, so
    /// <c>Named(Identifier)</c> is
    /// <c>{"type":"Named","value":{…identifier…}}</c> with no extra wrapper.
    /// </summary>
    private static object? TypeWire(object? ty) => ty switch
    {
        // A unit variant: the tag is the whole document. Writing
        // `{"type":"Any","value":null}` adds a key serde does not emit.
        AnyType => new Dictionary<string, object?> { ["type"] = AnyType.Tag },
        // `BasicType` is a fieldless enum, so its payload is the bare variant
        // name: "Int", not "int" and not {"name": "int"}.
        BasicType b => new Dictionary<string, object?> { ["type"] = BasicType.Tag, ["value"] = b.Name },
        NamedType n => new Dictionary<string, object?> { ["type"] = NamedType.Tag, ["value"] = IdentifierWire(n.Identifier) },
        ListType l => new Dictionary<string, object?>
        {
            ["type"] = ListType.Tag,
            ["value"] = new Dictionary<string, object?> { ["inner_type"] = NodeWire(l.InnerType, Wire) },
        },
        DictType d => new Dictionary<string, object?>
        {
            ["type"] = DictType.Tag,
            ["value"] = new Dictionary<string, object?>
            {
                ["key_type"] = NodeWire(d.KeyType, Wire),
                ["value_type"] = NodeWire(d.ValueType, Wire),
            },
        },
        UnionType u => new Dictionary<string, object?>
        {
            ["type"] = UnionType.Tag,
            ["value"] = new Dictionary<string, object?> { ["type_elements"] = ListWire(u.TypeElements, Wire) },
        },
        // `LiteralType` is `tag + content` as well, so it nests one level
        // deeper than the rest.
        LiteralType lit => new Dictionary<string, object?>
        {
            ["type"] = LiteralType.Tag,
            ["value"] = new Dictionary<string, object?>
            {
                ["type"] = lit.Variant,
                // `Int` is the one variant that is a struct rather than a bare
                // scalar; `Str`/`Float`/`Bool` carry the scalar itself.
                ["value"] = lit.Value is IntLiteralTypeValue i
                    ? new Dictionary<string, object?> { ["value"] = i.Value, ["suffix"] = i.Suffix }
                    : lit.Value,
            },
        },
        FunctionType f => new Dictionary<string, object?>
        {
            ["type"] = FunctionType.Tag,
            ["value"] = new Dictionary<string, object?>
            {
                // `Option<Vec<…>>`, so this one is genuinely nullable — a `Vec`
                // field would be an empty array here instead.
                ["params_ty"] = f.ParamsTy == null ? null : ListWire(f.ParamsTy, Wire),
                ["ret_ty"] = NodeWire(f.RetTy, Wire),
            },
        },
        _ => null,
    };

    // -----------------------------------------------------------------------
    // Statements — internally tagged, struct fields flattened
    // -----------------------------------------------------------------------

    private static object? StmtWire(object? stmt) => stmt switch
    {
        TypeAliasStmt t => new Dictionary<string, object?>
        {
            ["type"] = TypeAliasStmt.Tag,
            ["type_name"] = NodeWire(t.TypeName, IdentifierWire),
            ["type_value"] = NodeWire(t.TypeValue, s => (object?)s),
            ["ty"] = NodeWire(t.Ty, Wire),
        },
        ExprStmt e => new Dictionary<string, object?>
        {
            ["type"] = ExprStmt.Tag,
            ["exprs"] = ListWire(e.Exprs, Wire),
        },
        UnificationStmt u => new Dictionary<string, object?>
        {
            ["type"] = UnificationStmt.Tag,
            ["target"] = NodeWire(u.Target, IdentifierWire),
            // Untagged: the field is declared with the `SchemaExpr` struct, so
            // the payload carries no `type` key.
            ["value"] = NodeWire(u.Value, SchemaConfigWire),
        },
        AssignStmt a => new Dictionary<string, object?>
        {
            ["type"] = AssignStmt.Tag,
            ["targets"] = ListWire(a.Targets, TargetWire),
            ["value"] = NodeWire(a.Value, Wire),
            ["ty"] = NodeWire(a.Ty, Wire),
        },
        AugAssignStmt a => new Dictionary<string, object?>
        {
            ["type"] = AugAssignStmt.Tag,
            ["target"] = NodeWire(a.Target, TargetWire),
            ["value"] = NodeWire(a.Value, Wire),
            ["op"] = a.Op,
        },
        AssertStmt a => new Dictionary<string, object?>
        {
            ["type"] = AssertStmt.Tag,
            ["test"] = NodeWire(a.Test, Wire),
            ["if_cond"] = NodeWire(a.IfCond, Wire),
            ["msg"] = NodeWire(a.Msg, Wire),
        },
        IfStmt i => new Dictionary<string, object?>
        {
            ["type"] = IfStmt.Tag,
            ["body"] = ListWire(i.Body, Wire),
            ["cond"] = NodeWire(i.Cond, Wire),
            ["orelse"] = ListWire(i.Orelse, Wire),
        },
        SchemaStmt s => new Dictionary<string, object?>
        {
            ["type"] = SchemaStmt.Tag,
            ["doc"] = NodeWire(s.Doc, d => (object?)d),
            ["name"] = NodeWire(s.Name, n => (object?)n),
            ["parent_name"] = NodeWire(s.ParentName, IdentifierWire),
            ["for_host_name"] = NodeWire(s.ForHostName, IdentifierWire),
            ["is_mixin"] = s.IsMixin,
            ["is_protocol"] = s.IsProtocol,
            ["args"] = NodeWire(s.Args, ArgumentsWire),
            ["mixins"] = ListWire(s.Mixins, IdentifierWire),
            ["body"] = ListWire(s.Body, StmtWire),
            ["decorators"] = ListWire(s.Decorators, DecoratorWire),
            ["checks"] = ListWire(s.Checks, Wire),
            ["index_signature"] = NodeWire(s.IndexSignature, IndexSignatureWire),
        },
        SchemaAttr a => new Dictionary<string, object?>
        {
            ["type"] = SchemaAttr.Tag,
            // `SchemaAttr::doc` is a `String`, not an `Option<String>`, so it
            // is written as `""` rather than dropped — unlike `SchemaStmt`'s.
            ["doc"] = a.Doc,
            ["name"] = NodeWire(a.Name, n => (object?)n),
            ["op"] = a.Op,
            ["value"] = NodeWire(a.Value, Wire),
            ["is_optional"] = a.IsOptional,
            ["decorators"] = ListWire(a.Decorators, DecoratorWire),
            ["ty"] = NodeWire(a.Ty, Wire),
        },
        RuleStmt r => new Dictionary<string, object?>
        {
            ["type"] = RuleStmt.Tag,
            ["doc"] = NodeWire(r.Doc, d => (object?)d),
            ["name"] = NodeWire(r.Name, n => (object?)n),
            ["parent_rules"] = ListWire(r.ParentRules, IdentifierWire),
            ["decorators"] = ListWire(r.Decorators, DecoratorWire),
            ["checks"] = ListWire(r.Checks, Wire),
            ["args"] = NodeWire(r.Args, ArgumentsWire),
            ["for_host_name"] = NodeWire(r.ForHostName, IdentifierWire),
        },
        ImportStmt i => new Dictionary<string, object?>
        {
            ["type"] = ImportStmt.Tag,
            ["path"] = NodeWire(i.Path, p => (object?)p),
            ["rawpath"] = i.RawPath,
            ["name"] = i.Name,
            // Spelled `asname` on the wire, with no separator, even though the
            // C# property is `AsName`.
            ["asname"] = NodeWire(i.AsName, a => (object?)a),
            ["pkg_name"] = i.PkgName,
        },
        _ => null,
    };

    // -----------------------------------------------------------------------
    // Expressions — internally tagged, struct fields flattened
    // -----------------------------------------------------------------------

    private static object? ExprWire(object? expr) => expr switch
    {
        // `Expr::Call(CallExpr)` is a newtype over a struct, so serde flattens
        // `func`/`args`/`keywords` beside the tag. There is no `call` key.
        CallExpr c => new Dictionary<string, object?>
        {
            ["type"] = CallExpr.Tag,
            ["func"] = NodeWire(c.Func, Wire),
            ["args"] = ListWire(c.Args, Wire),
            ["keywords"] = ListWire(c.Keywords, Wire),
        },
        TargetExpr t => new Dictionary<string, object?>
        {
            ["type"] = TargetExpr.Tag,
            ["name"] = NodeWire(t.Name, n => (object?)n),
            ["paths"] = (t.Paths ?? new List<MemberOrIndex>()).Select(m => MemberOrIndexWire(m)!).ToList(),
            ["pkgpath"] = t.Pkgpath,
        },
        IdentifierExpr i => new Dictionary<string, object?>
        {
            ["type"] = IdentifierExpr.Tag,
            ["names"] = ListWire(i.Names, n => (object?)n),
            ["pkgpath"] = i.Pkgpath,
            ["ctx"] = i.Ctx,
        },
        UnaryExpr u => new Dictionary<string, object?>
        {
            ["type"] = UnaryExpr.Tag,
            ["op"] = u.Op,
            ["operand"] = NodeWire(u.Operand, Wire),
        },
        BinaryExpr b => new Dictionary<string, object?>
        {
            ["type"] = BinaryExpr.Tag,
            ["left"] = NodeWire(b.Left, Wire),
            ["op"] = b.Op,
            ["right"] = NodeWire(b.Right, Wire),
        },
        IfExpr f => new Dictionary<string, object?>
        {
            ["type"] = IfExpr.Tag,
            ["body"] = NodeWire(f.Body, Wire),
            ["cond"] = NodeWire(f.Cond, Wire),
            ["orelse"] = NodeWire(f.Orelse, Wire),
        },
        SelectorExpr s => new Dictionary<string, object?>
        {
            ["type"] = SelectorExpr.Tag,
            ["value"] = NodeWire(s.Value, Wire),
            ["attr"] = NodeWire(s.Attr, Wire),
            ["ctx"] = s.Ctx,
            ["has_question"] = s.HasQuestion,
        },
        ParenExpr p => new Dictionary<string, object?>
        {
            ["type"] = ParenExpr.Tag,
            ["expr"] = NodeWire(p.Expr, Wire),
        },
        QuantExpr q => new Dictionary<string, object?>
        {
            ["type"] = QuantExpr.Tag,
            ["target"] = NodeWire(q.Target, Wire),
            ["variables"] = ListWire(q.Variables, Wire),
            ["op"] = q.Op,
            ["test"] = NodeWire(q.Test, Wire),
            ["if_cond"] = NodeWire(q.IfCond, Wire),
            ["ctx"] = q.Ctx,
        },
        ListExpr l => new Dictionary<string, object?>
        {
            ["type"] = ListExpr.Tag,
            ["elts"] = ListWire(l.Elts, Wire),
            ["ctx"] = l.Ctx,
        },
        ListIfItemExpr li => new Dictionary<string, object?>
        {
            ["type"] = ListIfItemExpr.Tag,
            ["if_cond"] = NodeWire(li.IfCond, Wire),
            ["exprs"] = ListWire(li.Exprs, Wire),
            ["orelse"] = NodeWire(li.Orelse, Wire),
        },
        ListComp lc => new Dictionary<string, object?>
        {
            ["type"] = ListComp.Tag,
            ["elt"] = NodeWire(lc.Elt, Wire),
            ["generators"] = ListWire(lc.Generators, CompClauseWire),
        },
        StarredExpr s => new Dictionary<string, object?>
        {
            ["type"] = StarredExpr.Tag,
            ["value"] = NodeWire(s.Value, Wire),
            ["ctx"] = s.Ctx,
        },
        // `entry` is a bare `ConfigEntry` — no `type` key, no `node` wrapper.
        DictComp d => new Dictionary<string, object?>
        {
            ["type"] = DictComp.Tag,
            ["entry"] = ConfigEntryWire(d.Entry),
            ["generators"] = ListWire(d.Generators, CompClauseWire),
        },
        ConfigIfEntryExpr c => new Dictionary<string, object?>
        {
            ["type"] = ConfigIfEntryExpr.Tag,
            ["if_cond"] = NodeWire(c.IfCond, Wire),
            ["items"] = ListWire(c.Items, Wire),
            ["orelse"] = NodeWire(c.Orelse, Wire),
        },
        SchemaExpr s => new Dictionary<string, object?>
        {
            ["type"] = SchemaExpr.Tag,
            ["name"] = NodeWire(s.Name, Wire),
            ["args"] = ListWire(s.Args, Wire),
            ["kwargs"] = ListWire(s.Kwargs, Wire),
            ["config"] = NodeWire(s.Config, Wire),
        },
        ConfigExpr c => new Dictionary<string, object?>
        {
            ["type"] = ConfigExpr.Tag,
            ["items"] = ListWire(c.Items, Wire),
        },
        LambdaExpr l => new Dictionary<string, object?>
        {
            ["type"] = LambdaExpr.Tag,
            ["args"] = NodeWire(l.Args, ArgumentsWire),
            ["body"] = ListWire(l.Body, Wire),
            ["return_ty"] = NodeWire(l.ReturnTy, Wire),
        },
        // A slice keeps its bounds in `lower`/`upper`/`step`; each is an
        // `Option<NodeRef<Expr>>` and each is null for a plain `a[0]`.
        Subscript s => new Dictionary<string, object?>
        {
            ["type"] = Subscript.Tag,
            ["value"] = NodeWire(s.Value, Wire),
            ["index"] = NodeWire(s.Index, Wire),
            ["lower"] = NodeWire(s.Lower, Wire),
            ["upper"] = NodeWire(s.Upper, Wire),
            ["step"] = NodeWire(s.Step, Wire),
            ["ctx"] = s.Ctx,
            ["has_question"] = s.HasQuestion,
        },
        Compare c => new Dictionary<string, object?>
        {
            ["type"] = Compare.Tag,
            ["left"] = NodeWire(c.Left, Wire),
            ["ops"] = (c.Ops ?? new List<string>()).Cast<object?>().ToList(),
            ["comparators"] = ListWire(c.Comparators, Wire),
        },
        // Doubly tagged: the number is a `{"type":"Int","value":1}` object of
        // its own, not the bare number.
        NumberLit n => new Dictionary<string, object?>
        {
            ["type"] = NumberLit.Tag,
            ["binary_suffix"] = n.BinarySuffix,
            ["value"] = n.Value == null
                ? null
                : new Dictionary<string, object?> { ["type"] = n.Value.Type, ["value"] = n.Value.Value },
        },
        StringLit s => new Dictionary<string, object?>
        {
            ["type"] = StringLit.Tag,
            ["is_long_string"] = s.IsLongString,
            ["raw_value"] = s.RawValue,
            ["value"] = s.Value,
        },
        NameConstantLit n => new Dictionary<string, object?>
        {
            ["type"] = NameConstantLit.Tag,
            ["value"] = n.Value,
        },
        JoinedString j => new Dictionary<string, object?>
        {
            ["type"] = JoinedString.Tag,
            ["is_long_string"] = j.IsLongString,
            ["values"] = ListWire(j.Values, Wire),
            ["raw_value"] = j.RawValue,
        },
        // `format_spec` is an `Option<String>` — the text after the `:`, with
        // no position and no wrapper around it.
        FormattedValue f => new Dictionary<string, object?>
        {
            ["type"] = FormattedValue.Tag,
            ["is_long_string"] = f.IsLongString,
            ["value"] = NodeWire(f.Value, Wire),
            ["format_spec"] = f.FormatSpec,
        },
        // A unit struct: the tag is the whole object.
        MissingExpr _ => new Dictionary<string, object?> { ["type"] = MissingExpr.Tag },
        _ => null,
    };

    // -----------------------------------------------------------------------
    // Untagged plain structs
    // -----------------------------------------------------------------------

    private static object? IdentifierWire(Identifier? i) => i == null ? null : new Dictionary<string, object?>
    {
        ["names"] = ListWire(i.Names, n => (object?)n),
        ["pkgpath"] = i.Pkgpath,
        ["ctx"] = i.Ctx,
    };

    private static object? TargetWire(Target? t) => t == null ? null : new Dictionary<string, object?>
    {
        ["name"] = NodeWire(t.Name, n => (object?)n),
        ["paths"] = (t.Paths ?? new List<MemberOrIndex>()).Select(m => MemberOrIndexWire(m)!).ToList(),
        ["pkgpath"] = t.Pkgpath,
    };

    private static object? KeywordWire(Keyword? k) => k == null ? null : new Dictionary<string, object?>
    {
        ["arg"] = NodeWire(k.Arg, IdentifierWire),
        ["value"] = NodeWire(k.Value, Wire),
    };

    private static object? ArgumentsWire(Arguments? a) => a == null ? null : new Dictionary<string, object?>
    {
        // A parameter name is the untagged `Identifier` struct, so it is
        // written without a `type` key — the same name reached as an
        // expression carries `"type":"Identifier"`.
        ["args"] = ListWire(a.Args, IdentifierWire),
        // `Vec<Option<…>>`: the nulls are slots, and a missing key is an empty
        // list because a `Vec` is never absent.
        ["defaults"] = OptSlotWire(a.Defaults, Wire),
        ["ty_list"] = OptSlotWire(a.TyList, Wire),
    };

    private static object? DecoratorWire(Decorator? d) => d == null ? null : new Dictionary<string, object?>
    {
        ["func"] = NodeWire(d.Func, Wire),
        ["args"] = ListWire(d.Args, Wire),
        ["keywords"] = ListWire(d.Keywords, Wire),
    };

    private static object? CallWire(CallDto? c) => c == null ? null : new Dictionary<string, object?>
    {
        ["func"] = NodeWire(c.Func, Wire),
        ["args"] = ListWire(c.Args, Wire),
        ["keywords"] = ListWire(c.Keywords, Wire),
    };

    private static object? CheckWire(CheckExpr? c) => c == null ? null : new Dictionary<string, object?>
    {
        ["test"] = NodeWire(c.Test, Wire),
        ["if_cond"] = NodeWire(c.IfCond, Wire),
        ["msg"] = NodeWire(c.Msg, Wire),
    };

    private static object? ConfigEntryWire(ConfigEntry? c)
    {
        if (c == null) return null;
        var wire = new Dictionary<string, object?>
        {
            ["key"] = NodeWire(c.Key, Wire),
            ["value"] = NodeWire(c.Value, Wire),
            ["operation"] = c.Operation,
        };
        // `#[serde(skip_serializing_if = "is_false")]` — omitted when false,
        // present when true. Writing `"is_shorthand": false` puts a key Rust
        // never writes next to the three it does.
        if (c.IsShorthand) wire["is_shorthand"] = true;
        return wire;
    }

    private static object? CompClauseWire(CompClause? c) => c == null ? null : new Dictionary<string, object?>
    {
        ["targets"] = ListWire(c.Targets, IdentifierWire),
        ["iter"] = NodeWire(c.Iter, Wire),
        ["ifs"] = ListWire(c.Ifs, Wire),
    };

    private static object? SchemaConfigWire(SchemaConfig? s) => s == null ? null : new Dictionary<string, object?>
    {
        ["name"] = NodeWire(s.Name, Wire),
        ["args"] = ListWire(s.Args, Wire),
        ["kwargs"] = ListWire(s.Kwargs, Wire),
        ["config"] = NodeWire(s.Config, Wire),
    };

    private static object? IndexSignatureWire(SchemaIndexSignature? s) => s == null ? null : new Dictionary<string, object?>
    {
        ["key_name"] = NodeWire(s.KeyName, k => (object?)k),
        ["value"] = NodeWire(s.Value, Wire),
        ["any_other"] = s.AnyOther,
        ["key_ty"] = NodeWire(s.KeyTy, Wire),
        ["value_ty"] = NodeWire(s.ValueTy, Wire),
    };

    /// <summary>
    /// <c>Comment</c> is a plain struct with one <c>String</c> field, so the
    /// object under <c>node</c> is <c>{"text": "…"}</c> and <em>not</em> the
    /// text. A writer that emits the bare string here produces a document no
    /// decoder can read back — the bug that has shipped in four bindings.
    /// </summary>
    private static object? CommentWire(Comment? c) => c == null ? null : new Dictionary<string, object?>
    {
        ["text"] = c.Text,
    };

    /// <summary>
    /// <c>MemberOrIndex</c> is <c>tag = "type", content = "value"</c> like
    /// <c>Type</c>, so the node sits under <c>value</c> beside the tag.
    /// </summary>
    private static object? MemberOrIndexWire(MemberOrIndex? m)
    {
        if (m == null) return null;
        return new Dictionary<string, object?>
        {
            ["type"] = m.Tag,
            ["value"] = m.Member != null
                ? NodeWire(m.Member, n => (object?)n)
                : NodeWire(m.Index, Wire),
        };
    }
}
