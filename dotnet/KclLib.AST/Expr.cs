// Expr.cs — Expression hierarchy. Mirrors `ast::Expr` in `crates/ast/src/ast.rs`.
//
// Rust uses `#[serde(tag = "type")]` so each variant appears in JSON as
// `{"type": "<Variant>", ...}`. `Loaders.ExprFromWire` dispatches on that tag.

using System.Text.Json;

namespace KclLib.AST;

// We use records with `Type` as the discriminator. The `Type` field is
// populated by the dispatcher so downstream code can detect the variant
// even though C# records aren't class-tagged.

public record TargetExpr(string Type, NodeRef<string>? Name = null, List<MemberOrIndex>? Paths = null, string Pkgpath = "");
public record IdentifierExpr(string Type, List<NodeRef<string>>? Names = null, string Pkgpath = "", string? Ctx = null);
public record UnaryExpr(string Type, string? Op = null, NodeRef<object>? Operand = null);
public record BinaryExpr(string Type, NodeRef<object>? Left = null, string? Op = null, NodeRef<object>? Right = null);
public record IfExpr(string Type, NodeRef<object>? Body = null, NodeRef<object>? Cond = null, NodeRef<object>? Orelse = null);
public record SelectorExpr(string Type, NodeRef<object>? Value = null, NodeRef<object>? Attr = null, string? Ctx = null, bool HasQuestion = false);
public record CallExpr(string Type, NodeRef<object>? Func = null, List<NodeRef<object>>? Args = null, List<NodeRef<object>>? Keywords = null);
public record ParenExpr(string Type, NodeRef<object>? Expr = null);
public record QuantExpr(string Type, NodeRef<object>? Target = null, List<NodeRef<object>>? Variables = null, string? Op = null, NodeRef<object>? Test = null, NodeRef<object>? IfCond = null, string? Ctx = null);
public record ListExpr(string Type, List<NodeRef<object>>? Elts = null, string? Ctx = null);
public record ListIfItemExpr(string Type, NodeRef<object>? IfCond = null, List<NodeRef<object>>? Exprs = null, NodeRef<object>? Orelse = null);
public record ListComp(string Type, NodeRef<object>? Elt = null, List<NodeRef<object>>? Generators = null);
public record StarredExpr(string Type, NodeRef<object>? Value = null, string? Ctx = null);
public record DictComp(string Type, NodeRef<object>? EntryKey = null, NodeRef<object>? Key = null, NodeRef<object>? Value = null, List<NodeRef<object>>? Generators = null);
public record ConfigIfEntryExpr(string Type, NodeRef<object>? IfCond = null, List<NodeRef<object>>? Items = null, NodeRef<object>? Orelse = null);
public record CompClause(string Type, List<NodeRef<object>>? Targets = null, NodeRef<object>? Iter = null, List<NodeRef<object>>? Ifs = null);
public record SchemaExpr(string Type, NodeRef<object>? Name = null, List<NodeRef<object>>? Args = null, List<NodeRef<object>>? Kwargs = null, NodeRef<object>? Config = null);
public record ConfigExpr(string Type, List<NodeRef<object>>? Items = null);
public record LambdaExpr(string Type, NodeRef<Arguments>? Args = null, List<NodeRef<object>>? Body = null, NodeRef<object>? ReturnTy = null);
public record Subscript(string Type, NodeRef<object>? Value = null, NodeRef<object>? Index = null, string? Ctx = null);
public record Compare(string Type, NodeRef<object>? Left = null, List<string>? Ops = null, List<NodeRef<object>>? Comparators = null);
public record NumberLit(string Type, string? BinarySuffix = null, object? Value = null);
public record StringLit(string Type, bool IsLongString = false, string RawValue = "\"\"", string Value = "");
public record NameConstantLit(string Type, string? Value = null);
public record JoinedString(string Type, List<NodeRef<object>>? Values = null);
public record FormattedValue(string Type, NodeRef<object>? Value = null, string? Conversion = null, NodeRef<object>? FormatSpec = null);
public record MissingExpr(string Type);

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
            "Missing" => new MissingExpr("Missing"),
            _ => new BasicType(variant),
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
            Type: "Target",
            Name: WireHelpers.NodeFromWire<string>(o.GetProperty("name"), x => x.GetString()!),
            Paths: paths,
            Pkgpath: WireHelpers.OptString(o, "pkgpath") ?? ""
        );
    }

    private static IdentifierExpr IdentifierFromWire(JsonElement o) => new(
        Type: "Identifier",
        Names: WireHelpers.NodeListFromWire<string>(o.GetProperty("names"), x => x.GetString()!),
        Pkgpath: WireHelpers.OptString(o, "pkgpath") ?? "",
        Ctx: WireHelpers.OptString(o, "ctx")
    );

    private static UnaryExpr UnaryFromWire(JsonElement o) => new(
        Type: "Unary",
        Op: WireHelpers.OptString(o, "op"),
        Operand: WireHelpers.NodeFromWire<object>(o.GetProperty("operand"), Loaders.ExprFromWire)
    );

    private static BinaryExpr BinaryFromWire(JsonElement o) => new(
        Type: "Binary",
        Left: WireHelpers.NodeFromWire<object>(o.GetProperty("left"), Loaders.ExprFromWire),
        Op: WireHelpers.OptString(o, "op"),
        Right: WireHelpers.NodeFromWire<object>(o.GetProperty("right"), Loaders.ExprFromWire)
    );

    private static IfExpr IfFromWire(JsonElement o) => new(
        Type: "If",
        Body: WireHelpers.NodeFromWire<object>(o.GetProperty("body"), Loaders.ExprFromWire),
        Cond: WireHelpers.NodeFromWire<object>(o.GetProperty("cond"), Loaders.ExprFromWire),
        Orelse: WireHelpers.NodeFromWire<object>(o.GetProperty("orelse"), Loaders.ExprFromWire)
    );

    private static SelectorExpr SelectorFromWire(JsonElement o) => new(
        Type: "Selector",
        Value: WireHelpers.NodeFromWire<object>(o.GetProperty("value"), Loaders.ExprFromWire),
        Attr: WireHelpers.NodeFromWire<object>(o.GetProperty("attr"), Loaders.ExprFromWire),
        Ctx: WireHelpers.OptString(o, "ctx"),
        HasQuestion: WireHelpers.OptBool(o, "has_question")
    );

    private static CallExpr CallFromWire(JsonElement o) => new(
        Type: "Call",
        Func: WireHelpers.NodeFromWire<object>(o.GetProperty("func"), Loaders.ExprFromWire),
        Args: WireHelpers.NodeListFromWire<object>(o.GetProperty("args"), Loaders.ExprFromWire),
        Keywords: WireHelpers.NodeListFromWire<object>(o.GetProperty("keywords"), DtoLoader.KeywordFromWire)
    );

    private static ParenExpr ParenFromWire(JsonElement o) => new(
        Type: "Paren",
        Expr: WireHelpers.NodeFromWire<object>(o.GetProperty("expr"), Loaders.ExprFromWire)
    );

    private static QuantExpr QuantFromWire(JsonElement o) => new(
        Type: "Quant",
        Target: WireHelpers.NodeFromWire<object>(o.GetProperty("target"), Loaders.ExprFromWire),
        Variables: WireHelpers.NodeListFromWire<object>(o.GetProperty("variables"), Loaders.ExprFromWire),
        Op: WireHelpers.OptString(o, "op"),
        Test: WireHelpers.NodeFromWire<object>(o.GetProperty("test"), Loaders.ExprFromWire),
        IfCond: WireHelpers.NodeFromWire<object>(o.GetProperty("if_cond"), Loaders.ExprFromWire),
        Ctx: WireHelpers.OptString(o, "ctx")
    );

    private static ListExpr ListFromWire(JsonElement o) => new(
        Type: "List",
        Elts: WireHelpers.NodeListFromWire<object>(o.GetProperty("elts"), Loaders.ExprFromWire),
        Ctx: WireHelpers.OptString(o, "ctx")
    );

    private static ListIfItemExpr ListIfItemFromWire(JsonElement o) => new(
        Type: "ListIfItem",
        IfCond: WireHelpers.NodeFromWire<object>(o.GetProperty("if_cond"), Loaders.ExprFromWire),
        Exprs: WireHelpers.NodeListFromWire<object>(o.GetProperty("exprs"), Loaders.ExprFromWire),
        Orelse: WireHelpers.NodeFromWire<object>(o.GetProperty("orelse"), Loaders.ExprFromWire)
    );

    private static ListComp ListCompFromWire(JsonElement o) => new(
        Type: "ListComp",
        Elt: WireHelpers.NodeFromWire<object>(o.GetProperty("elt"), Loaders.ExprFromWire),
        Generators: WireHelpers.NodeListFromWire<object>(o.GetProperty("generators"), Loaders.ExprFromWire)
    );

    private static StarredExpr StarredFromWire(JsonElement o) => new(
        Type: "Starred",
        Value: WireHelpers.NodeFromWire<object>(o.GetProperty("value"), Loaders.ExprFromWire),
        Ctx: WireHelpers.OptString(o, "ctx")
    );

    private static DictComp DictCompFromWire(JsonElement o) => new(
        Type: "DictComp",
        EntryKey: WireHelpers.NodeFromWire<object>(o.GetProperty("entry_key"), Loaders.ExprFromWire),
        Key: WireHelpers.NodeFromWire<object>(o.GetProperty("key"), Loaders.ExprFromWire),
        Value: WireHelpers.NodeFromWire<object>(o.GetProperty("value"), Loaders.ExprFromWire),
        Generators: WireHelpers.NodeListFromWire<object>(o.GetProperty("generators"), Loaders.ExprFromWire)
    );

    private static ConfigIfEntryExpr ConfigIfEntryFromWire(JsonElement o) => new(
        Type: "ConfigIfEntry",
        IfCond: WireHelpers.NodeFromWire<object>(o.GetProperty("if_cond"), Loaders.ExprFromWire),
        Items: WireHelpers.NodeListFromWire<object>(o.GetProperty("items"), DtoLoader.ConfigEntryFromWire),
        Orelse: WireHelpers.NodeFromWire<object>(o.GetProperty("orelse"), Loaders.ExprFromWire)
    );

    private static CompClause CompClauseFromWire(JsonElement o) => new(
        Type: "CompClause",
        Targets: WireHelpers.NodeListFromWire<object>(o.GetProperty("targets"), Loaders.ExprFromWire),
        Iter: WireHelpers.NodeFromWire<object>(o.GetProperty("iter"), Loaders.ExprFromWire),
        Ifs: WireHelpers.NodeListFromWire<object>(o.GetProperty("ifs"), Loaders.ExprFromWire)
    );

    private static SchemaExpr SchemaFromWire(JsonElement o) => new(
        Type: "Schema",
        Name: WireHelpers.NodeFromWire<object>(o.GetProperty("name"), Loaders.ExprFromWire),
        Args: WireHelpers.NodeListFromWire<object>(o.GetProperty("args"), Loaders.ExprFromWire),
        Kwargs: WireHelpers.NodeListFromWire<object>(o.GetProperty("kwargs"), DtoLoader.KeywordFromWire),
        Config: WireHelpers.NodeFromWire<object>(o.GetProperty("config"), Loaders.ExprFromWire)
    );

    private static ConfigExpr ConfigFromWire(JsonElement o) => new(
        Type: "Config",
        Items: WireHelpers.NodeListFromWire<object>(o.GetProperty("items"), DtoLoader.ConfigEntryFromWire)
    );

    private static LambdaExpr LambdaFromWire(JsonElement o) => new(
        Type: "Lambda",
        Args: WireHelpers.NodeFromWire<Arguments>(o.GetProperty("args"), DtoLoader.ArgumentsFromWire!),
        Body: WireHelpers.NodeListFromWire<object>(o.GetProperty("body"), Loaders.ExprFromWire),
        ReturnTy: WireHelpers.NodeFromWire<object>(o.GetProperty("return_ty"), Loaders.TypeFromWire)
    );

    private static Subscript SubscriptFromWire(JsonElement o) => new(
        Type: "Subscript",
        Value: WireHelpers.NodeFromWire<object>(o.GetProperty("value"), Loaders.ExprFromWire),
        Index: WireHelpers.NodeFromWire<object>(o.GetProperty("index"), Loaders.ExprFromWire),
        Ctx: WireHelpers.OptString(o, "ctx")
    );

    private static Compare CompareFromWire(JsonElement o) => new(
        Type: "Compare",
        Left: WireHelpers.NodeFromWire<object>(o.GetProperty("left"), Loaders.ExprFromWire),
        Ops: WireHelpers.OptList<string>(o, "ops"),
        Comparators: WireHelpers.NodeListFromWire<object>(o.GetProperty("comparators"), Loaders.ExprFromWire)
    );

    private static NumberLit NumberLitFromWire(JsonElement o) => new(
        Type: "NumberLit",
        BinarySuffix: WireHelpers.OptString(o, "binary_suffix"),
        Value: o.TryGetProperty("value", out var v) ? JsonSerializer.Deserialize<object>(v.GetRawText()) : null
    );

    private static StringLit StringLitFromWire(JsonElement o) => new(
        Type: "StringLit",
        IsLongString: WireHelpers.OptBool(o, "is_long_string"),
        RawValue: WireHelpers.OptString(o, "raw_value") ?? "\"\"",
        Value: WireHelpers.OptString(o, "value") ?? ""
    );

    private static NameConstantLit NameConstantLitFromWire(JsonElement o) => new(
        Type: "NameConstantLit",
        Value: WireHelpers.OptString(o, "value")
    );

    private static JoinedString JoinedStringFromWire(JsonElement o) => new(
        Type: "JoinedString",
        Values: WireHelpers.NodeListFromWire<object>(o.GetProperty("values"), Loaders.ExprFromWire)
    );

    private static FormattedValue FormattedValueFromWire(JsonElement o) => new(
        Type: "FormattedValue",
        Value: WireHelpers.NodeFromWire<object>(o.GetProperty("value"), Loaders.ExprFromWire),
        Conversion: WireHelpers.OptString(o, "conversion"),
        FormatSpec: WireHelpers.NodeFromWire<object>(o.GetProperty("format_spec"), Loaders.ExprFromWire)
    );
}