// Expr.cs — Expression hierarchy. Mirrors `ast::Expr` in `crates/ast/src/ast.rs`.
//
// Rust uses `#[serde(tag = "type")]` so each variant appears in JSON as
// `{"type": "<Variant>", ...}`. `Loaders.ExprFromWire` dispatches on that tag.
//
// Every variant is a *newtype over a struct*, so serde flattens the struct's
// fields into the tagged object rather than nesting them under a wrapper key:
// `Expr::Call(CallExpr)` is `{"type":"Call","func":…,"args":[…],"keywords":[…]}`
// and not `{"type":"Call","call":{…}}`. `AstWriter` in Wire.cs has to flatten
// the same way, and the `Of()` constructor on each record is what stamps the
// tag so a caller never spells it out by hand.

using System.Text.Json;

namespace KclLib.AST;

// We use records with `Type` as the discriminator. The `Type` field is
// populated by the dispatcher so downstream code can detect the variant
// even though C# records aren't class-tagged. Each record also exposes its tag
// as a `const`, so the spelling lives in exactly one place and the decoders
// and the `Of()` constructors cannot drift apart.

public record TargetExpr(string Type, NodeRef<string>? Name = null, List<MemberOrIndex>? Paths = null, string Pkgpath = "")
{
    public const string Tag = "Target";
    public static TargetExpr Of(NodeRef<string>? name = null, List<MemberOrIndex>? paths = null, string pkgpath = "")
        => new(Tag, name, paths, pkgpath);
}

public record IdentifierExpr(string Type, List<NodeRef<string>>? Names = null, string Pkgpath = "", string? Ctx = null)
{
    public const string Tag = "Identifier";
    public static IdentifierExpr Of(List<NodeRef<string>>? names = null, string pkgpath = "", string? ctx = "Load")
        => new(Tag, names, pkgpath, ctx);

    /// <summary>
    /// Each argument is one dotted segment of the name, so <c>pkg.a</c> is
    /// <c>Of("pkg", "a")</c> — the <c>params</c> array is the <c>names</c>
    /// list, not a name and a package path.
    /// </summary>
    public static IdentifierExpr Of(params string[] names) =>
        new(Tag, names.Select(n => new NodeRef<string>(n)).ToList());
}

public record UnaryExpr(string Type, string? Op = null, NodeRef<object>? Operand = null)
{
    public const string Tag = "Unary";
    public static UnaryExpr Of(string? op = null, NodeRef<object>? operand = null) => new(Tag, op, operand);
}

public record BinaryExpr(string Type, NodeRef<object>? Left = null, string? Op = null, NodeRef<object>? Right = null)
{
    public const string Tag = "Binary";
    public static BinaryExpr Of(NodeRef<object>? left = null, string? op = null, NodeRef<object>? right = null)
        => new(Tag, left, op, right);
}

public record IfExpr(string Type, NodeRef<object>? Body = null, NodeRef<object>? Cond = null, NodeRef<object>? Orelse = null)
{
    public const string Tag = "If";
    public static IfExpr Of(NodeRef<object>? body = null, NodeRef<object>? cond = null, NodeRef<object>? orelse = null)
        => new(Tag, body, cond, orelse);
}

public record SelectorExpr(string Type, NodeRef<object>? Value = null, NodeRef<object>? Attr = null, string? Ctx = null, bool HasQuestion = false)
{
    public const string Tag = "Selector";
    public static SelectorExpr Of(NodeRef<object>? value = null, NodeRef<object>? attr = null, string? ctx = null, bool hasQuestion = false)
        => new(Tag, value, attr, ctx, hasQuestion);
}

public record CallExpr(string Type, NodeRef<object>? Func = null, List<NodeRef<object>>? Args = null, List<NodeRef<object>>? Keywords = null)
{
    public const string Tag = "Call";
    public static CallExpr Of(NodeRef<object>? func = null, List<NodeRef<object>>? args = null, List<NodeRef<object>>? keywords = null)
        => new(Tag, func, args, keywords);
}

public record ParenExpr(string Type, NodeRef<object>? Expr = null)
{
    public const string Tag = "Paren";
    public static ParenExpr Of(NodeRef<object>? expr = null) => new(Tag, expr);
}

public record QuantExpr(string Type, NodeRef<object>? Target = null, List<NodeRef<object>>? Variables = null, string? Op = null, NodeRef<object>? Test = null, NodeRef<object>? IfCond = null, string? Ctx = null)
{
    public const string Tag = "Quant";
    public static QuantExpr Of(NodeRef<object>? target = null, List<NodeRef<object>>? variables = null, string? op = null,
        NodeRef<object>? test = null, NodeRef<object>? ifCond = null, string? ctx = null)
        => new(Tag, target, variables, op, test, ifCond, ctx);
}

public record ListExpr(string Type, List<NodeRef<object>>? Elts = null, string? Ctx = null)
{
    public const string Tag = "List";
    public static ListExpr Of(List<NodeRef<object>>? elts = null, string? ctx = null) => new(Tag, elts, ctx);
}

public record ListIfItemExpr(string Type, NodeRef<object>? IfCond = null, List<NodeRef<object>>? Exprs = null, NodeRef<object>? Orelse = null)
{
    public const string Tag = "ListIfItem";
    public static ListIfItemExpr Of(NodeRef<object>? ifCond = null, List<NodeRef<object>>? exprs = null, NodeRef<object>? orelse = null)
        => new(Tag, ifCond, exprs, orelse);
}

public record ListComp(string Type, NodeRef<object>? Elt = null, List<NodeRef<CompClause>>? Generators = null)
{
    public const string Tag = "ListComp";
    public static ListComp Of(NodeRef<object>? elt = null, List<NodeRef<CompClause>>? generators = null)
        => new(Tag, elt, generators);
}

public record StarredExpr(string Type, NodeRef<object>? Value = null, string? Ctx = null)
{
    public const string Tag = "Starred";
    public static StarredExpr Of(NodeRef<object>? value = null, string? ctx = null) => new(Tag, value, ctx);
}

/// <summary>
/// <c>DictComp</c> — <c>{k: v for k, v in xs}</c>. <c>entry</c> is a bare
/// <see cref="ConfigEntry"/>: <c>DictComp</c> is a plain struct and the field
/// is declared with the struct, so on the wire it carries no <c>type</c> tag
/// and no <c>{node: …}</c> wrapper.
/// </summary>
public record DictComp(string Type, ConfigEntry? Entry = null, List<NodeRef<CompClause>>? Generators = null)
{
    public const string Tag = "DictComp";
    public static DictComp Of(ConfigEntry? entry = null, List<NodeRef<CompClause>>? generators = null)
        => new(Tag, entry, generators);
}

public record ConfigIfEntryExpr(string Type, NodeRef<object>? IfCond = null, List<NodeRef<object>>? Items = null, NodeRef<object>? Orelse = null)
{
    public const string Tag = "ConfigIfEntry";
    public static ConfigIfEntryExpr Of(NodeRef<object>? ifCond = null, List<NodeRef<object>>? items = null, NodeRef<object>? orelse = null)
        => new(Tag, ifCond, items, orelse);
}

// There is no `CompClause` record here. The untagged plain struct of that name
// lives in Dto.cs, it is what `ListComp.generators` and `DictComp.generators`
// carry, and it is the one both the decoder and the writer reach for. Rust
// does declare a tagged `Expr::CompClause` variant, but it is a newtype over
// that same struct, so the two differ by the `type` key alone and the parser
// never routes one through the `Expr` switch. Declaring both here is what
// made this package fail to compile.

public record SchemaExpr(string Type, NodeRef<object>? Name = null, List<NodeRef<object>>? Args = null, List<NodeRef<object>>? Kwargs = null, NodeRef<object>? Config = null)
{
    public const string Tag = "Schema";
    public static SchemaExpr Of(NodeRef<object>? name = null, List<NodeRef<object>>? args = null,
        List<NodeRef<object>>? kwargs = null, NodeRef<object>? config = null)
        => new(Tag, name, args, kwargs, config);
}

public record ConfigExpr(string Type, List<NodeRef<object>>? Items = null)
{
    public const string Tag = "Config";
    public static ConfigExpr Of(List<NodeRef<object>>? items = null) => new(Tag, items);
}

public record LambdaExpr(string Type, NodeRef<Arguments>? Args = null, List<NodeRef<object>>? Body = null, NodeRef<object>? ReturnTy = null)
{
    public const string Tag = "Lambda";
    public static LambdaExpr Of(NodeRef<Arguments>? args = null, List<NodeRef<object>>? body = null, NodeRef<object>? returnTy = null)
        => new(Tag, args, body, returnTy);
}

/// <summary>
/// <c>Subscript</c> — <c>a[0]</c>, <c>a[0:2]</c>, <c>a?[0]</c>. A slice keeps
/// its bounds in <c>lower</c>/<c>upper</c>/<c>step</c>, each an
/// <c>Option&lt;NodeRef&lt;Expr&gt;&gt;</c> and each <c>null</c> for a plain
/// index; <c>has_question</c> is the <c>?</c> of <c>a?[0]</c>.
/// </summary>
public record Subscript(string Type, NodeRef<object>? Value = null, NodeRef<object>? Index = null, NodeRef<object>? Lower = null, NodeRef<object>? Upper = null, NodeRef<object>? Step = null, string? Ctx = null, bool HasQuestion = false)
{
    public const string Tag = "Subscript";
    public static Subscript Of(NodeRef<object>? value = null, NodeRef<object>? index = null, NodeRef<object>? lower = null,
        NodeRef<object>? upper = null, NodeRef<object>? step = null, string? ctx = null, bool hasQuestion = false)
        => new(Tag, value, index, lower, upper, step, ctx, hasQuestion);
}

public record Compare(string Type, NodeRef<object>? Left = null, List<string>? Ops = null, List<NodeRef<object>>? Comparators = null)
{
    public const string Tag = "Compare";
    public static Compare Of(NodeRef<object>? left = null, List<string>? ops = null, List<NodeRef<object>>? comparators = null)
        => new(Tag, left, ops, comparators);
}

/// <summary>
/// <c>ast::NumberLitValue</c> — <c>#[serde(tag = "type", content = "value")]</c>
/// as well, so the number of a <see cref="NumberLit"/> is doubly tagged:
/// <c>{"type":"NumberLit","binary_suffix":null,"value":{"type":"Int","value":1}}</c>.
/// The inner tag is <c>Int</c> or <c>Float</c>, never <c>NumberLit</c> again.
/// </summary>
public record NumberLitValue(string Type, object? Value = null)
{
    public const string IntTag = "Int";
    public const string FloatTag = "Float";
    public static NumberLitValue Int(long value) => new(IntTag, value);
    public static NumberLitValue Float(double value) => new(FloatTag, value);
}

public record NumberLit(string Type, string? BinarySuffix = null, NumberLitValue? Value = null)
{
    public const string Tag = "NumberLit";
    public static NumberLit Of(long value, string? binarySuffix = null) => new(Tag, binarySuffix, NumberLitValue.Int(value));
    public static NumberLit Of(double value, string? binarySuffix = null) => new(Tag, binarySuffix, NumberLitValue.Float(value));
}

public record StringLit(string Type, bool IsLongString = false, string RawValue = "\"\"", string Value = "")
{
    public const string Tag = "StringLit";
    public static StringLit Of(string value) => new(Tag, false, JsonSerializer.Serialize(value), value);
    public static StringLit Of(string value, string rawValue, bool isLongString = false) => new(Tag, isLongString, rawValue, value);
}

public record NameConstantLit(string Type, string? Value = null)
{
    public const string Tag = "NameConstantLit";
    public static NameConstantLit Of(string value) => new(Tag, value);
}

/// <summary>
/// <c>JoinedString</c> — <c>"hi ${x.name}"</c>. <c>raw_value</c> is the whole
/// source text of the literal and <c>is_long_string</c> says whether it was
/// written <c>"""…"""</c>.
/// </summary>
public record JoinedString(string Type, List<NodeRef<object>>? Values = null, string RawValue = "", bool IsLongString = false)
{
    public const string Tag = "JoinedString";
    public static JoinedString Of(List<NodeRef<object>>? values = null, string rawValue = "", bool isLongString = false)
        => new(Tag, values, rawValue, isLongString);
}

/// <summary>
/// <c>FormattedValue</c> — the <c>x.name</c> of <c>"hi ${x.name}"</c>.
/// <c>format_spec</c> is an <c>Option&lt;String&gt;</c>, <em>not</em> a
/// <c>NodeRef&lt;Expr&gt;</c>: it is the text after the <c>:</c>, with no
/// position and no wrapper around it.
/// </summary>
public record FormattedValue(string Type, NodeRef<object>? Value = null, string? FormatSpec = null, bool IsLongString = false)
{
    public const string Tag = "FormattedValue";
    public static FormattedValue Of(NodeRef<object>? value = null, string? formatSpec = null, bool isLongString = false)
        => new(Tag, value, formatSpec, isLongString);
}

/// <summary>A place holder for expression parse error — <c>MissingExpr</c>,
/// a Rust unit struct, so its object is the tag and nothing else.</summary>
public record MissingExpr(string Type)
{
    public const string Tag = "Missing";
    public static MissingExpr Of() => new(Tag);
}

internal static class ExprLoader
{
    public static object? ExprFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        var variant = WireHelpers.OptString(el, "type");
        if (variant == null) return null;
        return variant switch
        {
            "Target" => TargetFromWire(el),
            "Identifier" => IdentifierFromWire(el),
            "Unary" => UnaryFromWire(el),
            "Binary" => BinaryFromWire(el),
            "If" => IfFromWire(el),
            "Selector" => SelectorFromWire(el),
            "Call" => CallFromWire(el),
            "Paren" => ParenFromWire(el),
            "Quant" => QuantFromWire(el),
            "List" => ListFromWire(el),
            "ListIfItem" => ListIfItemFromWire(el),
            "ListComp" => ListCompFromWire(el),
            "Starred" => StarredFromWire(el),
            "DictComp" => DictCompFromWire(el),
            "ConfigIfEntry" => ConfigIfEntryFromWire(el),
            "CompClause" => CompClauseFromWire(el),
            "Schema" => SchemaFromWire(el),
            "Config" => ConfigFromWire(el),
            "Lambda" => LambdaFromWire(el),
            "Subscript" => SubscriptFromWire(el),
            "Compare" => CompareFromWire(el),
            "NumberLit" => NumberLitFromWire(el),
            "StringLit" => StringLitFromWire(el),
            "NameConstantLit" => NameConstantLitFromWire(el),
            "JoinedString" => JoinedStringFromWire(el),
            "FormattedValue" => FormattedValueFromWire(el),
            "Missing" => new MissingExpr(MissingExpr.Tag),
            _ => new UnknownNode(variant),
        };
    }

    private static TargetExpr TargetFromWire(JsonElement o)
    {
        List<MemberOrIndex>? paths = null;
        if (o.TryGetProperty("paths", out var pathsEl) && pathsEl.ValueKind == JsonValueKind.Array)
        {
            paths = new List<MemberOrIndex>();
            foreach (var p in pathsEl.EnumerateArray())
            {
                var mi = DtoLoader.MemberOrIndexFromWire(p);
                if (mi != null) paths.Add(mi);
            }
        }
        return new TargetExpr(
            Type: TargetExpr.Tag,
            Name: WireHelpers.NodeFromWire<string>(o.GetProperty("name"), x => x.GetString()!),
            Paths: paths,
            Pkgpath: WireHelpers.OptString(o, "pkgpath") ?? ""
        );
    }

    private static IdentifierExpr IdentifierFromWire(JsonElement o) => new(
        Type: IdentifierExpr.Tag,
        Names: WireHelpers.NodeListFromWire<string>(o.GetProperty("names"), x => x.GetString()!),
        Pkgpath: WireHelpers.OptString(o, "pkgpath") ?? "",
        Ctx: WireHelpers.OptString(o, "ctx")
    );

    private static UnaryExpr UnaryFromWire(JsonElement o) => new(
        Type: UnaryExpr.Tag,
        Op: WireHelpers.OptString(o, "op"),
        Operand: WireHelpers.NodeFromWire<object>(o.GetProperty("operand"), Loaders.ExprFromWire)
    );

    private static BinaryExpr BinaryFromWire(JsonElement o) => new(
        Type: BinaryExpr.Tag,
        Left: WireHelpers.NodeFromWire<object>(o.GetProperty("left"), Loaders.ExprFromWire),
        Op: WireHelpers.OptString(o, "op"),
        Right: WireHelpers.NodeFromWire<object>(o.GetProperty("right"), Loaders.ExprFromWire)
    );

    private static IfExpr IfFromWire(JsonElement o) => new(
        Type: IfExpr.Tag,
        Body: WireHelpers.NodeFromWire<object>(o.GetProperty("body"), Loaders.ExprFromWire),
        Cond: WireHelpers.NodeFromWire<object>(o.GetProperty("cond"), Loaders.ExprFromWire),
        Orelse: WireHelpers.NodeFromWire<object>(o.GetProperty("orelse"), Loaders.ExprFromWire)
    );

    private static SelectorExpr SelectorFromWire(JsonElement o) => new(
        Type: SelectorExpr.Tag,
        Value: WireHelpers.NodeFromWire<object>(o.GetProperty("value"), Loaders.ExprFromWire),
        Attr: WireHelpers.Box(WireHelpers.NodeFromWire<Identifier>(o.GetProperty("attr"), DtoLoader.IdentifierFromWire!)),
        Ctx: WireHelpers.OptString(o, "ctx"),
        HasQuestion: WireHelpers.OptBool(o, "has_question")
    );

    private static CallExpr CallFromWire(JsonElement o) => new(
        Type: CallExpr.Tag,
        Func: WireHelpers.NodeFromWire<object>(o.GetProperty("func"), Loaders.ExprFromWire),
        Args: WireHelpers.NodeListFromWire<object>(o.GetProperty("args"), Loaders.ExprFromWire),
        Keywords: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<Keyword>(o.GetProperty("keywords"), DtoLoader.KeywordFromWire))
    );

    private static ParenExpr ParenFromWire(JsonElement o) => new(
        Type: ParenExpr.Tag,
        Expr: WireHelpers.NodeFromWire<object>(o.GetProperty("expr"), Loaders.ExprFromWire)
    );

    private static QuantExpr QuantFromWire(JsonElement o) => new(
        Type: QuantExpr.Tag,
        Target: WireHelpers.NodeFromWire<object>(o.GetProperty("target"), Loaders.ExprFromWire),
        Variables: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<Identifier>(o.GetProperty("variables"), DtoLoader.IdentifierFromWire!)),
        Op: WireHelpers.OptString(o, "op"),
        Test: WireHelpers.NodeFromWire<object>(o.GetProperty("test"), Loaders.ExprFromWire),
        IfCond: WireHelpers.NodeFromWire<object>(o.GetProperty("if_cond"), Loaders.ExprFromWire),
        Ctx: WireHelpers.OptString(o, "ctx")
    );

    private static ListExpr ListFromWire(JsonElement o) => new(
        Type: ListExpr.Tag,
        Elts: WireHelpers.NodeListFromWire<object>(o.GetProperty("elts"), Loaders.ExprFromWire),
        Ctx: WireHelpers.OptString(o, "ctx")
    );

    private static ListIfItemExpr ListIfItemFromWire(JsonElement o) => new(
        Type: ListIfItemExpr.Tag,
        IfCond: WireHelpers.NodeFromWire<object>(o.GetProperty("if_cond"), Loaders.ExprFromWire),
        Exprs: WireHelpers.NodeListFromWire<object>(o.GetProperty("exprs"), Loaders.ExprFromWire),
        Orelse: WireHelpers.NodeFromWire<object>(o.GetProperty("orelse"), Loaders.ExprFromWire)
    );

    private static ListComp ListCompFromWire(JsonElement o) => new(
        Type: ListComp.Tag,
        Elt: WireHelpers.NodeFromWire<object>(o.GetProperty("elt"), Loaders.ExprFromWire),
        Generators: WireHelpers.NodeListFromWire<CompClause>(o.GetProperty("generators"), DtoLoader.CompClauseFromWire!)
    );

    private static StarredExpr StarredFromWire(JsonElement o) => new(
        Type: StarredExpr.Tag,
        Value: WireHelpers.NodeFromWire<object>(o.GetProperty("value"), Loaders.ExprFromWire),
        Ctx: WireHelpers.OptString(o, "ctx")
    );

    // `entry` is a bare `ConfigEntry`: `DictComp` is a plain struct, so the
    // field is written as-is — no `type` key, no `{node: …}` wrapper, no
    // position. There is nothing to descend through here.
    private static DictComp DictCompFromWire(JsonElement o) => new(
        Type: DictComp.Tag,
        Entry: DtoLoader.ConfigEntryFromWire(o.GetProperty("entry")),
        Generators: WireHelpers.NodeListFromWire<CompClause>(o.GetProperty("generators"), DtoLoader.CompClauseFromWire!)
    );

    private static ConfigIfEntryExpr ConfigIfEntryFromWire(JsonElement o) => new(
        Type: ConfigIfEntryExpr.Tag,
        IfCond: WireHelpers.NodeFromWire<object>(o.GetProperty("if_cond"), Loaders.ExprFromWire),
        Items: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<ConfigEntry>(o.GetProperty("items"), DtoLoader.ConfigEntryFromWire)),
        Orelse: WireHelpers.NodeFromWire<object>(o.GetProperty("orelse"), Loaders.ExprFromWire)
    );

    // `"type":"CompClause"` reaches this arm, but the struct it fills is the
    // untagged `DtoLoader` one: the tagged variant is a newtype over it, so
    // the two objects differ by the `type` key alone.
    private static CompClause CompClauseFromWire(JsonElement o) => new(
        Targets: WireHelpers.NodeListFromWire<Identifier>(o.GetProperty("targets"), DtoLoader.IdentifierFromWire!),
        Iter: WireHelpers.NodeFromWire<object>(o.GetProperty("iter"), Loaders.ExprFromWire),
        Ifs: WireHelpers.NodeListFromWire<object>(o.GetProperty("ifs"), Loaders.ExprFromWire)
    );

    private static SchemaExpr SchemaFromWire(JsonElement o) => new(
        Type: SchemaExpr.Tag,
        Name: WireHelpers.Box(WireHelpers.NodeFromWire<Identifier>(o.GetProperty("name"), DtoLoader.IdentifierFromWire!)),
        Args: WireHelpers.NodeListFromWire<object>(o.GetProperty("args"), Loaders.ExprFromWire),
        Kwargs: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<Keyword>(o.GetProperty("kwargs"), DtoLoader.KeywordFromWire)),
        Config: WireHelpers.NodeFromWire<object>(o.GetProperty("config"), Loaders.ExprFromWire)
    );

    private static ConfigExpr ConfigFromWire(JsonElement o) => new(
        Type: ConfigExpr.Tag,
        Items: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<ConfigEntry>(o.GetProperty("items"), DtoLoader.ConfigEntryFromWire))
    );

    private static LambdaExpr LambdaFromWire(JsonElement o) => new(
        Type: LambdaExpr.Tag,
        Args: WireHelpers.NodeFromWire<Arguments>(o.GetProperty("args"), DtoLoader.ArgumentsFromWire!),
        Body: WireHelpers.NodeListFromWire<object>(o.GetProperty("body"), Loaders.StmtFromWire),
        ReturnTy: WireHelpers.NodeFromWire<object>(o.GetProperty("return_ty"), Loaders.TypeFromWire)
    );

    private static Subscript SubscriptFromWire(JsonElement o) => new(
        Type: Subscript.Tag,
        Value: WireHelpers.NodeFromWire<object>(o.GetProperty("value"), Loaders.ExprFromWire),
        Index: WireHelpers.NodeFromWire<object>(o.GetProperty("index"), Loaders.ExprFromWire),
        Lower: WireHelpers.NodeFromWire<object>(o.GetProperty("lower"), Loaders.ExprFromWire),
        Upper: WireHelpers.NodeFromWire<object>(o.GetProperty("upper"), Loaders.ExprFromWire),
        Step: WireHelpers.NodeFromWire<object>(o.GetProperty("step"), Loaders.ExprFromWire),
        Ctx: WireHelpers.OptString(o, "ctx"),
        HasQuestion: WireHelpers.OptBool(o, "has_question")
    );

    private static Compare CompareFromWire(JsonElement o) => new(
        Type: Compare.Tag,
        Left: WireHelpers.NodeFromWire<object>(o.GetProperty("left"), Loaders.ExprFromWire),
        Ops: WireHelpers.OptList<string>(o, "ops"),
        Comparators: WireHelpers.NodeListFromWire<object>(o.GetProperty("comparators"), Loaders.ExprFromWire)
    );

    private static NumberLit NumberLitFromWire(JsonElement o) => new(
        Type: NumberLit.Tag,
        BinarySuffix: WireHelpers.OptString(o, "binary_suffix"),
        Value: NumberLitValueFromWire(o.GetProperty("value"))
    );

    private static StringLit StringLitFromWire(JsonElement o) => new(
        Type: StringLit.Tag,
        IsLongString: WireHelpers.OptBool(o, "is_long_string"),
        RawValue: WireHelpers.OptString(o, "raw_value") ?? "\"\"",
        Value: WireHelpers.OptString(o, "value") ?? ""
    );

    private static NameConstantLit NameConstantLitFromWire(JsonElement o) => new(
        Type: NameConstantLit.Tag,
        Value: WireHelpers.OptString(o, "value")
    );

    private static JoinedString JoinedStringFromWire(JsonElement o) => new(
        Type: JoinedString.Tag,
        Values: WireHelpers.NodeListFromWire<object>(o.GetProperty("values"), Loaders.ExprFromWire),
        RawValue: WireHelpers.OptString(o, "raw_value") ?? "",
        IsLongString: WireHelpers.OptBool(o, "is_long_string")
    );

    private static FormattedValue FormattedValueFromWire(JsonElement o) => new(
        Type: FormattedValue.Tag,
        Value: WireHelpers.NodeFromWire<object>(o.GetProperty("value"), Loaders.ExprFromWire),
        FormatSpec: WireHelpers.OptString(o, "format_spec"),
        IsLongString: WireHelpers.OptBool(o, "is_long_string")
    );

    // `NumberLitValue` is tag + content too, so `NumberLit.value` arrives as
    // an object `{"type":"Int","value":1}` rather than as the number itself.
    private static NumberLitValue NumberLitValueFromWire(JsonElement el) => new(
        Type: WireHelpers.OptString(el, "type") ?? NumberLitValue.IntTag,
        Value: WireHelpers.ScalarFromWire(el.GetProperty("value"))
    );
}
