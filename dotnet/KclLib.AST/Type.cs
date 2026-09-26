// Type.cs — Type hierarchy. Mirrors `ast::Type` in `crates/ast/src/ast.rs`.
//
// Rust uses `#[serde(tag = "type")]` so each variant appears in JSON as
// `{"type": "<Variant>", ...}`. `Loaders.TypeFromWire` dispatches on that tag.

using System.Text.Json;

namespace KclLib.AST;

public record BasicType(string Type, bool IsLiteral = false);

public record ListType(string Type, object? InnerType = null);

public record DictType(string Type, object? KeyType = null, object? ValueType = null);

public record SchemaRefType(string Type, string? SchemaName = null, string? Pkgpath = null);

public record LiteralType(string Type, object? Value = null);

public record FunctionType(string Type, object? Params = null, object? ReturnTy = null);

public record UnionType(string Type, List<object>? Types = null);

public record KeyValueType(string Type, object? Key = null, object? Value = null);

internal static class TypeLoader
{
    private static readonly Dictionary<string, Func<JsonElement, object>> Registry = new()
    {
        ["Bool"] = o => new BasicType(o.GetProperty("type").GetString()!, WireHelpers.OptBool(o, "is_literal")),
        ["Int"] = o => new BasicType(o.GetProperty("type").GetString()!, WireHelpers.OptBool(o, "is_literal")),
        ["Float"] = o => new BasicType(o.GetProperty("type").GetString()!, WireHelpers.OptBool(o, "is_literal")),
        ["Str"] = o => new BasicType(o.GetProperty("type").GetString()!, WireHelpers.OptBool(o, "is_literal")),
        ["None"] = o => new BasicType(o.GetProperty("type").GetString()!, WireHelpers.OptBool(o, "is_literal")),
        ["Any"] = o => new BasicType(o.GetProperty("type").GetString()!, WireHelpers.OptBool(o, "is_literal")),
        ["Void"] = o => new BasicType(o.GetProperty("type").GetString()!, WireHelpers.OptBool(o, "is_literal")),
        ["Undefined"] = o => new BasicType(o.GetProperty("type").GetString()!, WireHelpers.OptBool(o, "is_literal")),
        ["List"] = o => new ListType(o.GetProperty("type").GetString()!),
        ["Dict"] = o => new DictType(o.GetProperty("type").GetString()!),
        ["SchemaRef"] = o => new SchemaRefType(o.GetProperty("type").GetString()!, WireHelpers.OptString(o, "schema_name"), WireHelpers.OptString(o, "pkgpath")),
        ["Literal"] = o => new LiteralType(o.GetProperty("type").GetString()!),
        ["Function"] = o => new FunctionType(o.GetProperty("type").GetString()!),
        ["Union"] = o => new UnionType(o.GetProperty("type").GetString()!),
        ["KeyValue"] = o => new KeyValueType(o.GetProperty("type").GetString()!),
    };

    public static object? TypeFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        var variant = WireHelpers.OptString(el, "type");
        if (variant == null) return null;
        if (Registry.TryGetValue(variant, out var loader)) return loader(el);
        return new BasicType(variant);
    }
}