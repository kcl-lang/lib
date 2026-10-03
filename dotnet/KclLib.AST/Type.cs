// Type.cs — Type hierarchy. Mirrors `ast::Type` in `crates/ast/src/ast.rs`.
//
// Rust uses `#[serde(tag = "type", content = "value")]`, so the tag says which
// variant and that variant's own fields sit under `value`:
// `{"type": "List", "value": {"inner_type": …}}`. A unit variant carries no
// `value` at all. `Loaders.TypeFromWire` dispatches on the tag and hands each
// decoder the *payload*, never the wrapper.
//
// The tag names the *shape*, not the type: `BasicType` is a fieldless Rust
// enum, so a basic type is `{"type": "Basic", "value": "Int"}` and never
// `{"type": "Int"}`. `LiteralType` is `tag = "type", content = "value"` as
// well, so it is doubly nested:
// `{"type":"Literal","value":{"type":"Int","value":{"value":1,"suffix":null}}}`.

using System.Text.Json;

namespace KclLib.AST;

/// `Type::Any` — the one variant with no payload, so its whole object is the
/// tag. `{"type": "Any", "value": null}` would not survive a strict consumer.
public record AnyType(string Type)
{
    public const string Tag = "Any";
    public static AnyType Of() => new(Tag);
}

/// <summary>
/// `Type::Basic(BasicType)`. <c>BasicType</c> is a fieldless Rust enum, so it
/// serialises as the bare string in the payload, spelled as the Rust variant:
/// <c>"Bool"</c>, <c>"Int"</c>, <c>"Float"</c> or <c>"Str"</c>.
/// </summary>
public record BasicType(string Type, string? Name = null)
{
    public const string Tag = "Basic";
    public static BasicType Of(string name) => new(Tag, name);
    public static BasicType Int() => new(Tag, "Int");
    public static BasicType Str() => new(Tag, "Str");
    public static BasicType Bool() => new(Tag, "Bool");
    public static BasicType Float() => new(Tag, "Float");
}

/// <summary>
/// `Type::Named(Identifier)` — the payload is an untagged <c>Identifier</c>,
/// inlined into <c>value</c>: <c>{"type":"Named","value":{"names":[…],
/// "pkgpath":"","ctx":"Load"}}</c>. No extra wrapper key, and no position.
/// </summary>
public record NamedType(string Type, Identifier? Identifier = null)
{
    public const string Tag = "Named";
    public static NamedType Of(Identifier identifier) => new(Tag, identifier);
}

/// <summary>`Type::List(ListType)` — <c>inner_type</c> is an
/// <c>Option&lt;NodeRef&lt;Type&gt;&gt;</c> and is written <c>null</c> for a
/// bare <c>[]</c>.</summary>
public record ListType(string Type, NodeRef<object>? InnerType = null)
{
    public const string Tag = "List";
    public static ListType Of(NodeRef<object>? innerType = null) => new(Tag, innerType);
}

/// <summary>`Type::Dict(DictType)` — both sides are
/// <c>Option&lt;NodeRef&lt;Type&gt;&gt;</c>.</summary>
public record DictType(string Type, NodeRef<object>? KeyType = null, NodeRef<object>? ValueType = null)
{
    public const string Tag = "Dict";
    public static DictType Of(NodeRef<object>? keyType = null, NodeRef<object>? valueType = null) => new(Tag, keyType, valueType);
}

/// <summary>`Type::Union(UnionType)` — a <c>Vec</c>, so always an array, and
/// the Rust field is <c>type_elements</c>, not <c>types</c>.</summary>
public record UnionType(string Type, List<NodeRef<object>>? TypeElements = null)
{
    public const string Tag = "Union";
    public static UnionType Of(List<NodeRef<object>>? typeElements = null) => new(Tag, typeElements);
}

/// <summary>
/// `Type::Function(FunctionType)`. <c>params_ty</c> is
/// <c>Option&lt;Vec&lt;NodeRef&lt;Type&gt;&gt;&gt;</c>, which looks three-state in
/// the type. It is not: <c>crates/parser/src/parser/ty.rs</c> only ever builds
/// <c>None</c> or <c>Some(non-empty)</c>, so the wire carries
/// <c>"params_ty": null</c> for <c>() -&gt; T</c> and never <c>[]</c>. There is
/// no empty-list case to construct, so there is no factory for one either.
/// </summary>
public record FunctionType(string Type, List<NodeRef<object>>? ParamsTy = null, NodeRef<object>? RetTy = null)
{
    public const string Tag = "Function";
    public static FunctionType Of(List<NodeRef<object>>? paramsTy, NodeRef<object>? retTy = null) => new(Tag, paramsTy, retTy);
    public static FunctionType NoParams(NodeRef<object>? retTy = null) => new(Tag, null, retTy);
}

/// <summary>
/// The payload of an integer literal type — <c>LiteralType::Int(IntLiteralType)</c>,
/// the one literal variant that is a struct rather than a bare scalar.
/// </summary>
public record IntLiteralTypeValue(long Value, string? Suffix = null)
{
    public static IntLiteralTypeValue Of(long value, string? suffix = null) => new(value, suffix);
}

/// <summary>
/// `Type::Literal(LiteralType)`. <c>LiteralType</c> is itself adjacently
/// tagged, so the payload nests one level deeper — and the four variants do not
/// agree on a shape: <c>Int</c> carries <c>{"value":1,"suffix":null}</c> while
/// <c>Str</c>, <c>Float</c> and <c>Bool</c> carry a bare scalar. Hence
/// <see cref="Variant"/> plus a loosely typed <see cref="Value"/> rather than
/// four classes.
/// </summary>
public record LiteralType(string Type, string? Variant = null, object? Value = null)
{
    public const string Tag = "Literal";
    public const string IntVariant = "Int";
    public const string FloatVariant = "Float";
    public const string StrVariant = "Str";
    public const string BoolVariant = "Bool";

    public static LiteralType Of(string variant, object? value) => new(Tag, variant, value);
    public static LiteralType Int(long value, string? suffix = null) => new(Tag, IntVariant, IntLiteralTypeValue.Of(value, suffix));
    public static LiteralType Float(double value) => new(Tag, FloatVariant, value);
    public static LiteralType Str(string value) => new(Tag, StrVariant, value);
    public static LiteralType Bool(bool value) => new(Tag, BoolVariant, value);
}

/// <summary>
/// A tag this build claims no variant for. Kept rather than dropped, so a
/// caller can still see what the parser emitted. Used by the `Expr` and `Stmt`
/// dispatchers too, which is why it is not specific to a `Type`.
/// </summary>
public record UnknownNode(string Type);

internal static class TypeLoader
{
    // The keys are the variants Rust's `Type` actually declares. A tag that is
    // not one of them belongs to a different enum: `Bool` / `Int` / `Float` /
    // `Str` are the *literal* type nested inside `Literal`, and nothing emits
    // `SchemaRef`, `KeyValue`, `None`, `Void` or `Undefined` as a `Type`.
    // Keying the registry on those matched no `Type` in any AST, so every
    // variant — including `Basic` and `Named`, which are the common ones —
    // fell through to the catch-all below.
    private static readonly Dictionary<string, Func<JsonElement, object>> Registry = new()
    {
        [BasicType.Tag] = o => new BasicType(BasicType.Tag, o.GetString()),
        [NamedType.Tag] = o => new NamedType(NamedType.Tag, DtoLoader.IdentifierFromWire(o)!),
        [ListType.Tag] = o => new ListType(ListType.Tag,
            WireHelpers.NodeFromWire<object>(o.GetProperty("inner_type"), Loaders.TypeFromWire)),
        [DictType.Tag] = o => new DictType(DictType.Tag,
            WireHelpers.NodeFromWire<object>(o.GetProperty("key_type"), Loaders.TypeFromWire),
            WireHelpers.NodeFromWire<object>(o.GetProperty("value_type"), Loaders.TypeFromWire)),
        [UnionType.Tag] = o => new UnionType(UnionType.Tag,
            WireHelpers.NodeListFromWire<object>(o.GetProperty("type_elements"), Loaders.TypeFromWire)),
        [FunctionType.Tag] = o => new FunctionType(FunctionType.Tag,
            WireHelpers.OptNodeList<object>(o.GetProperty("params_ty"), Loaders.TypeFromWire),
            WireHelpers.NodeFromWire<object>(o.GetProperty("ret_ty"), Loaders.TypeFromWire)),
        [LiteralType.Tag] = o => new LiteralType(LiteralType.Tag,
            WireHelpers.OptString(o, "type"),
            LiteralValueFromWire(o.GetProperty("value"), WireHelpers.OptString(o, "type"))),
    };

    public static object? TypeFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        var variant = WireHelpers.OptString(el, "type");
        if (variant == null) return null;

        // `Any` is a unit variant and has no payload. Every other variant keeps
        // its fields under `value`; a decoder handed the wrapper reads the tag
        // where a field name belongs, finds nothing, and the payload decodes to
        // null fields without ever raising.
        if (variant == AnyType.Tag) return new AnyType(AnyType.Tag);
        if (!el.TryGetProperty("value", out var payload)) return null;
        return Registry.TryGetValue(variant, out var load) ? load(payload) : new UnknownNode(variant);
    }

    // The inner `LiteralType` document, read through the tag already lifted
    // off it. `Int` is the only variant whose `value` is an object, and the
    // only one that carries a suffix.
    private static object? LiteralValueFromWire(JsonElement el, string? variant)
    {
        if (el.ValueKind == JsonValueKind.Undefined) return null;
        if (variant == LiteralType.IntVariant && el.ValueKind == JsonValueKind.Object)
        {
            return new IntLiteralTypeValue(
                el.GetProperty("value").GetInt64(),
                WireHelpers.OptString(el, "suffix"));
        }
        return WireHelpers.ScalarFromWire(el);
    }
}
