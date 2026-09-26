// Base.cs — Pos, NodeRef<T>, Comment, and the top-level parse helpers.
//
// Mirrors `ast::Pos` / `NodeRef<T>` / `Comment` in `crates/ast/src/ast.rs`.

using System.Text.Json;

namespace KclLib.AST;

public record Pos(string Filename, long Line, long Column, long EndLine, long EndColumn);

/// <summary>
/// Wraps a value of type T with source position information — <c>NodeRef&lt;T&gt;</c> in Rust.
/// Named <c>NodeRef</c> (not <c>Node</c>) to avoid the C# rule that a record's
/// positional property name must differ from the enclosing type name.
/// </summary>
public record NodeRef<T>(T Node, Pos? Position = null);

public record Comment(string Node, Pos? Position = null) : NodeRef<string>(Node, Position);

internal static class WireHelpers
{
    public static Pos? PosFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new Pos(
            Filename: el.GetProperty("filename").GetString()!,
            Line: el.GetProperty("line").GetInt64(),
            Column: el.GetProperty("column").GetInt64(),
            EndLine: el.GetProperty("end_line").GetInt64(),
            EndColumn: el.GetProperty("end_column").GetInt64()
        );
    }

    public static NodeRef<T>? NodeFromWire<T>(JsonElement el, Func<JsonElement, T> load)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        var inner = el.GetProperty("node");
        var pos = PosFromWire(el);
        return new NodeRef<T>(load(inner), pos);
    }

    public static List<NodeRef<T>>? NodeListFromWire<T>(JsonElement el, Func<JsonElement, T> load)
    {
        if (el.ValueKind != JsonValueKind.Array) return null;
        var list = new List<NodeRef<T>>();
        foreach (var item in el.EnumerateArray())
        {
            var n = NodeFromWire<T>(item, load);
            if (n != null) list.Add(n);
        }
        return list;
    }

    public static string? OptString(JsonElement el, string key)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        if (!el.TryGetProperty(key, out var p)) return null;
        return p.ValueKind == JsonValueKind.String ? p.GetString() : null;
    }

    public static bool OptBool(JsonElement el, string key)
    {
        if (el.ValueKind != JsonValueKind.Object) return false;
        if (!el.TryGetProperty(key, out var p)) return false;
        return p.ValueKind == JsonValueKind.True;
    }

    public static List<T>? OptList<T>(JsonElement el, string key)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        if (!el.TryGetProperty(key, out var p)) return null;
        if (p.ValueKind != JsonValueKind.Array) return null;
        return JsonSerializer.Deserialize<List<T>>(p.GetRawText());
    }
}