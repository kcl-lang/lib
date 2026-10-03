// Stmt.cs — Statement hierarchy. Mirrors `ast::Stmt` in `crates/ast/src/ast.rs`.
//
// Rust uses `#[serde(tag = "type")]`, so each variant appears in JSON as
// `{"type": "<Variant>", ...}`. `StmtLoader.StmtFromWire` dispatches on that
// tag, and — as in Expr.cs — serde flattens each variant's struct fields into
// the tagged object rather than nesting them under a wrapper key.

using System.Text.Json;

namespace KclLib.AST;

public record ExprStmt(string Type, List<NodeRef<object>>? Exprs = null)
{
    public const string Tag = "Expr";
    public static ExprStmt Of(List<NodeRef<object>>? exprs = null) => new(Tag, exprs);
}

// `target` is a single `NodeRef<Identifier>` — the declaration name, not a
// `Target` path and not an array. Reading it with `OptList` handed back raw
// `JsonElement`s of a key that is not there, so the field was always null.
//
// `value` is a `NodeRef<SchemaConfig>`: `UnificationStmt` is a plain struct
// whose field is declared with the `SchemaExpr` struct, so the payload under
// `node` carries no `type` key. See Dto.cs.
public record UnificationStmt(string Type, NodeRef<Identifier>? Target = null, NodeRef<SchemaConfig>? Value = null)
{
    public const string Tag = "Unification";
    public static UnificationStmt Of(NodeRef<Identifier>? target = null, NodeRef<SchemaConfig>? value = null)
        => new(Tag, target, value);
}

public record AssignStmt(string Type, List<NodeRef<Target>>? Targets = null, NodeRef<object>? Ty = null, NodeRef<object>? Value = null)
{
    public const string Tag = "Assign";
    public static AssignStmt Of(List<NodeRef<Target>>? targets = null, NodeRef<object>? value = null, NodeRef<object>? ty = null)
        => new(Tag, targets, ty, value);
}

// `target` is singular here where `AssignStmt` has it plural, and it is a
// `Target` rather than an `Identifier`.
public record AugAssignStmt(string Type, NodeRef<Target>? Target = null, NodeRef<object>? Value = null, string? Op = null)
{
    public const string Tag = "AugAssign";
    public static AugAssignStmt Of(NodeRef<Target>? target = null, NodeRef<object>? value = null, string? op = null)
        => new(Tag, target, value, op);
}

public record AssertStmt(string Type, NodeRef<object>? Test = null, NodeRef<object>? IfCond = null, NodeRef<object>? Msg = null)
{
    public const string Tag = "Assert";
    public static AssertStmt Of(NodeRef<object>? test = null, NodeRef<object>? ifCond = null, NodeRef<object>? msg = null)
        => new(Tag, test, ifCond, msg);
}

// `orelse` is a `Vec`, not a single node — the same field on `IfExpr` is one.
public record IfStmt(string Type, List<NodeRef<object>>? Body = null, NodeRef<object>? Cond = null, List<NodeRef<object>>? Orelse = null)
{
    public const string Tag = "If";
    public static IfStmt Of(List<NodeRef<object>>? body = null, NodeRef<object>? cond = null, List<NodeRef<object>>? orelse = null)
        => new(Tag, body, cond, orelse);
}

public record TypeAliasStmt(string Type, NodeRef<Identifier>? TypeName = null, NodeRef<string>? TypeValue = null, NodeRef<object>? Ty = null)
{
    public const string Tag = "TypeAlias";
    public static TypeAliasStmt Of(NodeRef<Identifier>? typeName = null, NodeRef<string>? typeValue = null, NodeRef<object>? ty = null)
        => new(Tag, typeName, typeValue, ty);
}

public record SchemaStmt(string Type,
    NodeRef<string>? Doc = null,
    NodeRef<string>? Name = null,
    NodeRef<Identifier>? ParentName = null,
    NodeRef<Identifier>? ForHostName = null,
    bool IsMixin = false,
    bool IsProtocol = false,
    NodeRef<Arguments>? Args = null,
    List<NodeRef<Identifier>>? Mixins = null,
    List<NodeRef<object>>? Body = null,
    List<NodeRef<Decorator>>? Decorators = null,
    List<NodeRef<object>>? Checks = null,
    NodeRef<SchemaIndexSignature>? IndexSignature = null)
{
    public const string Tag = "Schema";
    public static SchemaStmt Of(NodeRef<string>? name = null,
        NodeRef<string>? doc = null,
        NodeRef<Identifier>? parentName = null,
        NodeRef<Identifier>? forHostName = null,
        bool isMixin = false,
        bool isProtocol = false,
        NodeRef<Arguments>? args = null,
        List<NodeRef<Identifier>>? mixins = null,
        List<NodeRef<object>>? body = null,
        List<NodeRef<Decorator>>? decorators = null,
        List<NodeRef<object>>? checks = null,
        NodeRef<SchemaIndexSignature>? indexSignature = null)
        => new(Tag, doc, name, parentName, forHostName, isMixin, isProtocol, args, mixins, body, decorators, checks, indexSignature);
}

// `doc` is a plain `String` here and an `Option<NodeRef<String>>` on
// `SchemaStmt` — `SchemaAttr::doc` is `String` in Rust, not `Option<String>`,
// so it is written as `""` rather than dropped.
public record SchemaAttr(string Type,
    string Doc = "",
    NodeRef<string>? Name = null,
    string? Op = null,
    NodeRef<object>? Value = null,
    bool IsOptional = false,
    List<NodeRef<Decorator>>? Decorators = null,
    NodeRef<object>? Ty = null)
{
    public const string Tag = "SchemaAttr";
    public static SchemaAttr Of(NodeRef<string>? name = null,
        string doc = "",
        string? op = null,
        NodeRef<object>? value = null,
        bool isOptional = false,
        List<NodeRef<Decorator>>? decorators = null,
        NodeRef<object>? ty = null)
        => new(Tag, doc, name, op, value, isOptional, decorators, ty);
}

public record RuleStmt(string Type,
    NodeRef<string>? Doc = null,
    NodeRef<string>? Name = null,
    List<NodeRef<Identifier>>? ParentRules = null,
    List<NodeRef<Decorator>>? Decorators = null,
    List<NodeRef<object>>? Checks = null,
    NodeRef<Arguments>? Args = null,
    NodeRef<Identifier>? ForHostName = null)
{
    public const string Tag = "Rule";
    public static RuleStmt Of(NodeRef<string>? name = null,
        NodeRef<string>? doc = null,
        List<NodeRef<Identifier>>? parentRules = null,
        List<NodeRef<Decorator>>? decorators = null,
        List<NodeRef<object>>? checks = null,
        NodeRef<Arguments>? args = null,
        NodeRef<Identifier>? forHostName = null)
        => new(Tag, doc, name, parentRules, decorators, checks, args, forHostName);
}

// An `ImportStmt` is a tagged statement, so its fields sit on the statement
// object itself: there is no `node` wrapper to descend through. `path` and
// `asname` *are* `NodeRef<string>`, and `asname` is spelled without the
// separator the wire uses everywhere else.
public record ImportStmt(string Type, NodeRef<string>? Path = null, string RawPath = "", string Name = "", NodeRef<string>? AsName = null, string PkgName = "")
{
    public const string Tag = "Import";
    public static ImportStmt Of(NodeRef<string>? path = null, string rawPath = "", string name = "", NodeRef<string>? asName = null, string pkgName = "")
        => new(Tag, path, rawPath, name, asName, pkgName);
}

internal static class StmtLoader
{
    public static object? StmtFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        var variant = WireHelpers.OptString(el, "type");
        if (variant == null) return null;
        return variant switch
        {
            "Expr" => new ExprStmt(ExprStmt.Tag, WireHelpers.NodeListFromWire<object>(el.GetProperty("exprs"), Loaders.ExprFromWire)),
            "Unification" => new UnificationStmt(
                UnificationStmt.Tag,
                Target: WireHelpers.NodeFromWire<Identifier>(el.GetProperty("target"), DtoLoader.IdentifierFromWire!),
                Value: WireHelpers.NodeFromWire<SchemaConfig>(el.GetProperty("value"), DtoLoader.SchemaConfigFromWire!)),
            "Assign" => new AssignStmt(
                AssignStmt.Tag,
                Targets: WireHelpers.NodeListFromWire<Target>(el.GetProperty("targets"), DtoLoader.TargetFromWire!),
                Ty: WireHelpers.NodeFromWire<object>(el.GetProperty("ty"), Loaders.TypeFromWire),
                Value: WireHelpers.NodeFromWire<object>(el.GetProperty("value"), Loaders.ExprFromWire)),
            "AugAssign" => new AugAssignStmt(
                AugAssignStmt.Tag,
                Target: WireHelpers.NodeFromWire<Target>(el.GetProperty("target"), DtoLoader.TargetFromWire!),
                Value: WireHelpers.NodeFromWire<object>(el.GetProperty("value"), Loaders.ExprFromWire),
                Op: WireHelpers.OptString(el, "op")),
            "Assert" => new AssertStmt(
                AssertStmt.Tag,
                Test: WireHelpers.NodeFromWire<object>(el.GetProperty("test"), Loaders.ExprFromWire),
                IfCond: WireHelpers.NodeFromWire<object>(el.GetProperty("if_cond"), Loaders.ExprFromWire),
                Msg: WireHelpers.NodeFromWire<object>(el.GetProperty("msg"), Loaders.ExprFromWire)),
            "If" => new IfStmt(
                IfStmt.Tag,
                Body: WireHelpers.NodeListFromWire<object>(el.GetProperty("body"), StmtFromWire),
                Cond: WireHelpers.NodeFromWire<object>(el.GetProperty("cond"), Loaders.ExprFromWire),
                Orelse: WireHelpers.NodeListFromWire<object>(el.GetProperty("orelse"), StmtFromWire)),
            "TypeAlias" => new TypeAliasStmt(
                TypeAliasStmt.Tag,
                TypeName: WireHelpers.NodeFromWire<Identifier>(el.GetProperty("type_name"), DtoLoader.IdentifierFromWire!),
                TypeValue: WireHelpers.NodeFromWire<string>(el.GetProperty("type_value"), x => x.GetString()!),
                Ty: WireHelpers.NodeFromWire<object>(el.GetProperty("ty"), Loaders.TypeFromWire)),
            "Schema" => SchemaStmtFromWire(el),
            "SchemaAttr" => SchemaAttrFromWire(el),
            "Rule" => RuleStmtFromWire(el),
            "Import" => ImportStmtFromWire(el),
            _ => new UnknownNode(variant),
        };
    }

    private static SchemaStmt SchemaStmtFromWire(JsonElement o) => new(
        Type: SchemaStmt.Tag,
        Doc: WireHelpers.NodeFromWire<string>(o.GetProperty("doc"), x => x.GetString()!),
        Name: WireHelpers.NodeFromWire<string>(o.GetProperty("name"), x => x.GetString()!),
        ParentName: WireHelpers.NodeFromWire<Identifier>(o.GetProperty("parent_name"), DtoLoader.IdentifierFromWire!),
        ForHostName: WireHelpers.NodeFromWire<Identifier>(o.GetProperty("for_host_name"), DtoLoader.IdentifierFromWire!),
        IsMixin: WireHelpers.OptBool(o, "is_mixin"),
        IsProtocol: WireHelpers.OptBool(o, "is_protocol"),
        Args: WireHelpers.NodeFromWire<Arguments>(o.GetProperty("args"), DtoLoader.ArgumentsFromWire!),
        Mixins: WireHelpers.NodeListFromWire<Identifier>(o.GetProperty("mixins"), DtoLoader.IdentifierFromWire!),
        Body: WireHelpers.NodeListFromWire<object>(o.GetProperty("body"), StmtFromWire),
        Decorators: WireHelpers.NodeListFromWire<Decorator>(o.GetProperty("decorators"), DtoLoader.DecoratorFromWire!),
        Checks: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<CheckExpr>(o.GetProperty("checks"), DtoLoader.CheckExprFromWire!)),
        IndexSignature: WireHelpers.NodeFromWire<SchemaIndexSignature>(o.GetProperty("index_signature"), DtoLoader.SchemaIndexSignatureFromWire!)
    );

    private static SchemaAttr SchemaAttrFromWire(JsonElement o) => new(
        Type: SchemaAttr.Tag,
        Doc: WireHelpers.OptString(o, "doc") ?? "",
        Name: WireHelpers.NodeFromWire<string>(o.GetProperty("name"), x => x.GetString()!),
        Op: WireHelpers.OptString(o, "op"),
        Value: WireHelpers.NodeFromWire<object>(o.GetProperty("value"), Loaders.ExprFromWire),
        IsOptional: WireHelpers.OptBool(o, "is_optional"),
        Decorators: WireHelpers.NodeListFromWire<Decorator>(o.GetProperty("decorators"), DtoLoader.DecoratorFromWire!),
        Ty: WireHelpers.NodeFromWire<object>(o.GetProperty("ty"), Loaders.TypeFromWire)
    );

    private static RuleStmt RuleStmtFromWire(JsonElement o) => new(
        Type: RuleStmt.Tag,
        Doc: WireHelpers.NodeFromWire<string>(o.GetProperty("doc"), x => x.GetString()!),
        Name: WireHelpers.NodeFromWire<string>(o.GetProperty("name"), x => x.GetString()!),
        ParentRules: WireHelpers.NodeListFromWire<Identifier>(o.GetProperty("parent_rules"), DtoLoader.IdentifierFromWire!),
        Decorators: WireHelpers.NodeListFromWire<Decorator>(o.GetProperty("decorators"), DtoLoader.DecoratorFromWire!),
        Checks: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<CheckExpr>(o.GetProperty("checks"), DtoLoader.CheckExprFromWire!)),
        Args: WireHelpers.NodeFromWire<Arguments>(o.GetProperty("args"), DtoLoader.ArgumentsFromWire!),
        ForHostName: WireHelpers.NodeFromWire<Identifier>(o.GetProperty("for_host_name"), DtoLoader.IdentifierFromWire!)
    );

    private static ImportStmt ImportStmtFromWire(JsonElement o)
    {
        // An `ImportStmt` is a tagged statement, so its fields sit on the
        // statement object itself. There is no `node` wrapper to descend
        // through, and `asname` is spelled without the separator the wire uses
        // everywhere else.
        return new ImportStmt(
            Type: ImportStmt.Tag,
            Path: WireHelpers.NodeFromWire<string>(o.GetProperty("path"), x => x.GetString()!),
            RawPath: WireHelpers.OptString(o, "rawpath") ?? "",
            Name: WireHelpers.OptString(o, "name") ?? "",
            AsName: WireHelpers.NodeFromWire<string>(o.GetProperty("asname"), x => x.GetString()!),
            PkgName: WireHelpers.OptString(o, "pkg_name") ?? ""
        );
    }
}
