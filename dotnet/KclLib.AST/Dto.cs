// Dto.cs — Flat DTOs for positions nested under NodeRef<T> where the wire
// shape lacks the polymorphic `type` discriminator. Mirrors the Java/Go
// bindings (see AST_DRIFT.md note A).
//
// The cycle between this file and Expr.cs is broken with late-bound loaders
// — the polymorphic `Load` functions are looked up via the `Loaders` static
// class.

using System.Text.Json;

namespace KclLib.AST;

/// <summary>
/// Flat decorator payload — <c>@deprecated(strict=True)</c>.
/// </summary>
public record Decorator(NodeRef<object>? Func = null, List<NodeRef<object>>? Args = null, List<NodeRef<object>>? Keywords = null);

/// <summary>
/// Inline schema instantiation payload — <c>ASchema(args) { ... }</c>.
/// </summary>
public record SchemaConfig(NodeRef<object>? Name = null, List<NodeRef<object>>? Args = null, List<NodeRef<object>>? Kwargs = null, NodeRef<object>? Config = null);

/// <summary>
/// One config entry — <c>key = value</c> or <c>key: value</c>.
/// </summary>
public record ConfigEntry(NodeRef<object>? Key = null, NodeRef<object>? Value = null, string? Operation = null, bool IsShorthand = false);

/// <summary>
/// Keyword argument — <c>arg = value</c>.
/// </summary>
public record Keyword(NodeRef<object>? Arg = null, NodeRef<object>? Value = null);

/// <summary>
/// Lambda parameter list.
/// </summary>
public record Arguments(List<NodeRef<object>>? Args = null, List<NodeRef<object>>? Defaults = null, List<NodeRef<object>>? TyList = null);

/// <summary>
/// Member or index — <c>a.b</c> or <c>a[0]</c>.
/// </summary>
public record MemberOrIndex(NodeRef<string>? Member = null, NodeRef<object>? Index = null);

/// <summary>
/// <c>ast::Target</c> struct — <c>a.b.c</c>.
/// </summary>
public record Target(NodeRef<string>? Name = null, List<MemberOrIndex>? Paths = null, string Pkgpath = "");

internal static class DtoLoader
{
    public static Decorator? DecoratorFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new Decorator(
            Func: WireHelpers.NodeFromWire<object>(el.GetProperty("func"), Loaders.ExprFromWire),
            Args: WireHelpers.NodeListFromWire<object>(el.GetProperty("args"), Loaders.ExprFromWire),
            Keywords: WireHelpers.NodeListFromWire<object>(el.GetProperty("keywords"), KeywordFromWire)
        );
    }

    public static SchemaConfig? SchemaConfigFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new SchemaConfig(
            Name: WireHelpers.NodeFromWire<object>(el.GetProperty("name"), Loaders.ExprFromWire),
            Args: WireHelpers.NodeListFromWire<object>(el.GetProperty("args"), Loaders.ExprFromWire),
            Kwargs: WireHelpers.NodeListFromWire<object>(el.GetProperty("kwargs"), KeywordFromWire),
            Config: WireHelpers.NodeFromWire<object>(el.GetProperty("config"), Loaders.ExprFromWire)
        );
    }

    public static ConfigEntry? ConfigEntryFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new ConfigEntry(
            Key: WireHelpers.NodeFromWire<object>(el.GetProperty("key"), Loaders.ExprFromWire),
            Value: WireHelpers.NodeFromWire<object>(el.GetProperty("value"), Loaders.ExprFromWire),
            Operation: WireHelpers.OptString(el, "operation"),
            IsShorthand: WireHelpers.OptBool(el, "is_shorthand")
        );
    }

    public static Keyword? KeywordFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new Keyword(
            Arg: WireHelpers.NodeFromWire<object>(el.GetProperty("arg"), Loaders.ExprFromWire),
            Value: WireHelpers.NodeFromWire<object>(el.GetProperty("value"), Loaders.ExprFromWire)
        );
    }

    public static Arguments? ArgumentsFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new Arguments(
            Args: WireHelpers.NodeListFromWire<object>(el.GetProperty("args"), Loaders.ExprFromWire),
            Defaults: WireHelpers.NodeListFromWire<object>(el.GetProperty("defaults"), Loaders.ExprFromWire),
            TyList: WireHelpers.NodeListFromWire<object>(el.GetProperty("ty_list"), Loaders.TypeFromWire)
        );
    }

    public static MemberOrIndex? MemberOrIndexFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        var variant = WireHelpers.OptString(el, "type");
        var value = el.GetProperty("value");
        return variant switch
        {
            "Member" => new MemberOrIndex(Member: WireHelpers.NodeFromWire<string>(value, x => x.GetString()!)),
            "Index" => new MemberOrIndex(Index: WireHelpers.NodeFromWire<object>(value, Loaders.ExprFromWire)),
            _ => new MemberOrIndex()
        };
    }

    public static Target? TargetFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        List<MemberOrIndex>? paths = null;
        if (el.TryGetProperty("paths", out var pathsEl) && pathsEl.ValueKind == JsonValueKind.Array)
        {
            paths = new List<MemberOrIndex>();
            foreach (var p in pathsEl.EnumerateArray())
            {
                var mi = MemberOrIndexFromWire(p);
                if (mi != null) paths.Add(mi);
            }
        }
        return new Target(
            Name: WireHelpers.NodeFromWire<string>(el.GetProperty("name"), x => x.GetString()!),
            Paths: paths,
            Pkgpath: WireHelpers.OptString(el, "pkgpath") ?? ""
        );
    }
}