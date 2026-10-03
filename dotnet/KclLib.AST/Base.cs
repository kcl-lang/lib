// Base.cs — Pos, NodeRef<T>, Comment, and the top-level parse helpers.
//
// Mirrors `ast::Pos` / `NodeRef<T>` / `Comment` in `crates/ast/src/ast.rs`.

using System.Text.Json;

namespace KclLib.AST;

public record Pos(string Filename, long Line, long Column, long EndLine, long EndColumn)
{
    /// <summary>
    /// The position Rust's <c>Node::dummy_node</c> gives a node that was built
    /// rather than parsed. Serde always writes all five keys of a wrapper, so
    /// a node assembled programmatically needs a position to be written at
    /// all; this is the one to give it when there is nothing better.
    /// </summary>
    public static readonly Pos Default = new("", 1, 1, 1, 1);
}

/// <summary>
/// Wraps a value of type T with source position information — <c>NodeRef&lt;T&gt;</c> in Rust.
/// Named <c>NodeRef</c> (not <c>Node</c>) to avoid the C# rule that a record's
/// positional property name must differ from the enclosing type name.
/// </summary>
/// <remarks>
/// The primary constructor takes the payload and an optional <see cref="Pos"/>;
/// the static members below are the convenience spellings a caller building a
/// tree by hand reaches for.
/// </remarks>
public record NodeRef<T>(T Node, Pos? Position = null)
{
    /// <summary>Wrap <paramref name="node"/> with no position information.</summary>
    public static NodeRef<T> Of(T node) => new(node);

    /// <summary>
    /// Wrap <paramref name="node"/> at an explicit position. This is the shape
    /// the wire carries: the five <c>Pos</c> keys are flattened onto the
    /// wrapper beside <c>node</c>, they are not nested under a <c>pos</c> key.
    /// </summary>
    public static NodeRef<T> At(T node, string filename, long line, long column, long endLine, long endColumn)
        => new(node, new Pos(filename, line, column, endLine, endColumn));

    /// <summary>
    /// A wrapper that is present but holds nothing — the <c>"node": null</c> of
    /// Rust's <c>Node&lt;T&gt;</c>, whose <c>node</c> field is not an
    /// <c>Option</c> and is therefore written as <c>null</c> rather than
    /// dropped. Distinct from a <c>null</c> <c>NodeRef</c>, which is the
    /// <c>Option::None</c> at the outer level and serialises as the field
    /// itself being <c>null</c>.
    /// </summary>
    public static NodeRef<T> Empty(Pos? position = null) => new(default!, position);
}

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

    // The loader is declared `Func<JsonElement, T?>` because every decoder in
    // this package is handed a `JsonElement` it may not be able to read, and
    // the honest answer there is null. `T` is the unconstrained form, so a
    // `Func<JsonElement, T>` would not accept a nullable-returning method group
    // and every call site would need a cast.
    public static NodeRef<T>? NodeFromWire<T>(JsonElement el, Func<JsonElement, T?> load)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        var inner = el.GetProperty("node");
        var pos = PosFromWire(el);
        return new NodeRef<T>(load(inner)!, pos);
    }

    public static List<NodeRef<T>>? NodeListFromWire<T>(JsonElement el, Func<JsonElement, T?> load)
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

    /// <summary>
    /// Re-wrap a <c>NodeRef&lt;T&gt;</c> as the <c>NodeRef&lt;object&gt;</c> the
    /// polymorphic fields are declared with. <c>Expr</c>, <c>Stmt</c> and
    /// <c>Type</c> have no common base record here, so a field holding one of
    /// the untagged DTOs — an <c>Identifier</c>, a <c>Keyword</c>, a
    /// <c>ConfigEntry</c> — still has to be stored as <c>object</c>, and
    /// <c>NodeRef&lt;T&gt;</c> is invariant in <c>T</c>.
    /// </summary>
    public static NodeRef<object>? Box<T>(NodeRef<T>? node) =>
        node == null ? null : new NodeRef<object>(node.Node!, node.Position);

    /// <summary><see cref="Box{T}"/> over a whole list.</summary>
    public static List<NodeRef<object>>? BoxAll<T>(List<NodeRef<T>>? nodes) =>
        nodes?.Select(n => new NodeRef<object>(n.Node!, n.Position)).ToList();

    /// <summary>
    /// An <c>Option&lt;Vec&lt;NodeRef&lt;T&gt;&gt;&gt;</c>: <c>null</c> when the key
    /// holds <c>null</c>, and a decoded list otherwise. This is not
    /// <c>OptList</c>, which hands back raw <c>JsonElement</c>s — reading a
    /// node list that way yields a list of wrappers nobody can descend into.
    /// </summary>
    public static List<NodeRef<object>>? OptNodeList<T>(JsonElement el, Func<JsonElement, T?> load) =>
        el.ValueKind != JsonValueKind.Array ? null : NodeListFromWire<object>(el, e => load(e));

    /// <summary>
    /// A JSON scalar as a CLR value, for the payloads that are tagged but
    /// carry no object of their own — the <c>1</c> of
    /// <c>{"type":"Int","value":1}</c>.
    /// </summary>
    public static object? ScalarFromWire(JsonElement el) => el.ValueKind switch
    {
        JsonValueKind.Null or JsonValueKind.Undefined => null,
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.String => el.GetString(),
        JsonValueKind.Number => el.TryGetInt64(out var l) ? l : el.GetDouble(),
        _ => JsonSerializer.Deserialize<object>(el.GetRawText()),
    };
}