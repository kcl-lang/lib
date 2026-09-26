// Stmt.cs — Statement hierarchy. Mirrors `ast::Stmt` in `crates/ast/src/ast.rs`.
//
// Rust uses `#[serde(tag = "type")]`, so each variant appears in JSON as
// `{"type": "<Variant>", ...}`. `StmtLoader.StmtFromWire` dispatches on that tag.

using System.Text.Json;

namespace KclLib.AST;

public record ExprStmt(string Type, List<NodeRef<object>>? Exprs = null);

public record UnificationStmt(string Type, object? Target = null, NodeRef<SchemaConfig>? Value = null);

public record AssignStmt(string Type, List<NodeRef<Target>>? Targets = null, NodeRef<object>? Ty = null, NodeRef<object>? Value = null);

public record SchemaStmt(string Type,
    NodeRef<string>? Doc = null,
    NodeRef<string>? Name = null,
    object? ParentName = null,
    object? ForHostName = null,
    bool IsMixin = false,
    bool IsProtocol = false,
    NodeRef<Arguments>? Args = null,
    List<object>? Mixins = null,
    List<NodeRef<object>>? Body = null,
    List<NodeRef<Decorator>>? Decorators = null,
    List<NodeRef<object>>? Checks = null,
    object? IndexSignature = null);

public record SchemaAttr(string Type,
    string Doc = "",
    NodeRef<string>? Name = null,
    string? Op = null,
    NodeRef<object>? Value = null,
    bool IsOptional = false,
    List<NodeRef<Decorator>>? Decorators = null,
    NodeRef<object>? Ty = null);

public record RuleStmt(string Type,
    NodeRef<string>? Doc = null,
    NodeRef<string>? Name = null,
    List<object>? ParentRules = null,
    List<NodeRef<Decorator>>? Decorators = null,
    List<NodeRef<object>>? Checks = null,
    NodeRef<Arguments>? Args = null,
    object? ForHostName = null);

public record ImportStmt(string Type, string? Path = null, string? AsName = null, string? PkgName = null, string? PkgRoot = null);

internal static class StmtLoader
{
    public static object? StmtFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        var variant = WireHelpers.OptString(el, "type");
        if (variant == null) return null;
        return variant switch
        {
            "Expr" => new ExprStmt("Expr", WireHelpers.NodeListFromWire<object>(el.GetProperty("exprs"), Loaders.ExprFromWire)),
            "Unification" => new UnificationStmt(
                "Unification",
                Target: WireHelpers.OptList<object>(el, "target"),
                Value: WireHelpers.NodeFromWire<SchemaConfig>(el.GetProperty("value"), DtoLoader.SchemaConfigFromWire!)),
            "Assign" => new AssignStmt(
                "Assign",
                Targets: WireHelpers.NodeListFromWire<Target>(el.GetProperty("targets"), DtoLoader.TargetFromWire!),
                Ty: WireHelpers.NodeFromWire<object>(el.GetProperty("ty"), Loaders.TypeFromWire),
                Value: WireHelpers.NodeFromWire<object>(el.GetProperty("value"), Loaders.ExprFromWire)),
            "Schema" => SchemaStmtFromWire(el),
            "SchemaAttr" => SchemaAttrFromWire(el),
            "Rule" => RuleStmtFromWire(el),
            "Import" => ImportStmtFromWire(el),
            _ => new BasicType(variant),
        };
    }

    private static SchemaStmt SchemaStmtFromWire(JsonElement o) => new(
        Type: "Schema",
        Doc: WireHelpers.NodeFromWire<string>(o.GetProperty("doc"), x => x.GetString()!),
        Name: WireHelpers.NodeFromWire<string>(o.GetProperty("name"), x => x.GetString()!),
        ParentName: WireHelpers.OptList<object>(o, "parent_name"),
        ForHostName: WireHelpers.OptList<object>(o, "for_host_name"),
        IsMixin: WireHelpers.OptBool(o, "is_mixin"),
        IsProtocol: WireHelpers.OptBool(o, "is_protocol"),
        Args: WireHelpers.NodeFromWire<Arguments>(o.GetProperty("args"), DtoLoader.ArgumentsFromWire!),
        Mixins: WireHelpers.OptList<object>(o, "mixins"),
        Body: WireHelpers.NodeListFromWire<object>(o.GetProperty("body"), StmtFromWire),
        Decorators: WireHelpers.NodeListFromWire<Decorator>(o.GetProperty("decorators"), DtoLoader.DecoratorFromWire!),
        Checks: WireHelpers.NodeListFromWire<object>(o.GetProperty("checks"), Loaders.ExprFromWire),
        IndexSignature: WireHelpers.OptList<object>(o, "index_signature")
    );

    private static SchemaAttr SchemaAttrFromWire(JsonElement o) => new(
        Type: "SchemaAttr",
        Doc: WireHelpers.OptString(o, "doc") ?? "",
        Name: WireHelpers.NodeFromWire<string>(o.GetProperty("name"), x => x.GetString()!),
        Op: WireHelpers.OptString(o, "op"),
        Value: WireHelpers.NodeFromWire<object>(o.GetProperty("value"), Loaders.ExprFromWire),
        IsOptional: WireHelpers.OptBool(o, "is_optional"),
        Decorators: WireHelpers.NodeListFromWire<Decorator>(o.GetProperty("decorators"), DtoLoader.DecoratorFromWire!),
        Ty: WireHelpers.NodeFromWire<object>(o.GetProperty("ty"), Loaders.TypeFromWire)
    );

    private static RuleStmt RuleStmtFromWire(JsonElement o) => new(
        Type: "Rule",
        Doc: WireHelpers.NodeFromWire<string>(o.GetProperty("doc"), x => x.GetString()!),
        Name: WireHelpers.NodeFromWire<string>(o.GetProperty("name"), x => x.GetString()!),
        ParentRules: WireHelpers.OptList<object>(o, "parent_rules"),
        Decorators: WireHelpers.NodeListFromWire<Decorator>(o.GetProperty("decorators"), DtoLoader.DecoratorFromWire!),
        Checks: WireHelpers.NodeListFromWire<object>(o.GetProperty("checks"), Loaders.ExprFromWire),
        Args: WireHelpers.NodeFromWire<Arguments>(o.GetProperty("args"), DtoLoader.ArgumentsFromWire!),
        ForHostName: WireHelpers.OptList<object>(o, "for_host_name")
    );

    private static ImportStmt ImportStmtFromWire(JsonElement o)
    {
        var hasNode = o.TryGetProperty("node", out var nodeEl) && nodeEl.ValueKind == JsonValueKind.Object;
        var node = hasNode ? nodeEl : default;
        return new ImportStmt(
            Type: "Import",
            Path: hasNode ? WireHelpers.OptString(node, "path") : null,
            AsName: hasNode ? WireHelpers.OptString(node, "as_name") : null,
            PkgName: hasNode ? WireHelpers.OptString(node, "pkg_name") : null,
            PkgRoot: hasNode ? WireHelpers.OptString(node, "pkg_root") : null
        );
    }
}