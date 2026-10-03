// Dto.cs — Plain struct payloads that the wire carries with no `type` tag.
//
// Every record here is a Rust struct declared with a struct field or a
// `Vec` element rather than an enum variant, so nothing about it can be
// dispatched on and nothing about it carries a tag. Three of them are
// field-identical twins of a tagged variant, and the twin is the documented
// spelling:
//
//   Decorator  == CallExpr     — a decorator is a call.
//   SchemaConfig == SchemaExpr — `UnificationStmt.value` is a `SchemaExpr`
//                                 reached through a struct-typed field.
//   CompClause                  — `Expr::CompClause` is a newtype over it.
//
// They are separate types here because the call sites want different
// constructors, and collapsing them would hide which of the two shapes a
// field actually has.

using System.Text.Json;

namespace KclLib.AST;

/// <summary>
/// <c>ast::Identifier</c> struct — <c>a</c>, <c>_c</c>, <c>pkg.a</c>. A plain
/// struct with no tag, so it is a <c>NodeRef&lt;Identifier&gt;</c> and never
/// an <c>Expr</c>.
/// </summary>
public record Identifier(List<NodeRef<string>>? Names = null, string Pkgpath = "", string? Ctx = null)
{
    /// <summary>
    /// Each argument is one dotted segment of the name, so <c>pkg.a</c> is
    /// <c>Of("pkg", "a")</c> — the <c>params</c> array is the <c>names</c>
    /// list, not a name and a package path.
    /// </summary>
    public static Identifier Of(params string[] names) =>
        new(names.Select(n => new NodeRef<string>(n)).ToList());
    public static Identifier Of(List<NodeRef<string>>? names, string pkgpath = "", string? ctx = "Load")
        => new(names, pkgpath, ctx);
}

/// <summary>
/// <c>ast::Target</c> struct — the left-hand side of an assignment.
/// Untagged, and distinct from the tagged <see cref="TargetExpr"/>.
/// </summary>
public record Target(NodeRef<string>? Name = null, List<MemberOrIndex>? Paths = null, string Pkgpath = "")
{
    public static Target Of(string name) => new(new NodeRef<string>(name));
}

/// <summary>
/// <c>ast::Keyword</c> struct — <c>name=value</c> in a call. <c>arg</c> is a
/// <c>NodeRef&lt;Identifier&gt;</c> and <c>value</c> is optional.
/// </summary>
public record Keyword(NodeRef<Identifier>? Arg = null, NodeRef<object>? Value = null)
{
    public static Keyword Of(string arg, NodeRef<object>? value = null) => new(new NodeRef<Identifier>(Identifier.Of(arg)), value);
}

/// <summary>
/// <c>ast::Arguments</c> struct — a lambda's parameter list.
/// <c>args</c> is <c>Vec&lt;NodeRef&lt;Identifier&gt;&gt;</c>: a parameter name is
/// the untagged <c>Identifier</c> struct, so <c>lambda p: p</c> writes
/// <c>{"names":[…],"pkgpath":"","ctx":"Load"}</c> under <c>args[0].node</c>
/// with no <c>"type":"Identifier"</c> beside it — unlike the same name used
/// as an expression, which is tagged.
/// <c>defaults</c> and <c>ty_list</c> are <c>Vec&lt;Option&lt;NodeRef&lt;…&gt;&gt;&gt;</c>,
/// i.e. every slot is meaningful: <c>[null]</c> is an unnamed parameter with
/// no default, not an empty list, so those nulls are kept and written back.
/// <c>ty_list</c> holds a <c>Type</c>, not an <c>Expr</c> — the two are
/// separate enums with separate tags, and a <c>{"type":"Basic","value":"Int"}>
/// read as an expression is an unknown node.
/// </summary>
public record Arguments(
    List<NodeRef<Identifier>>? Args = null,
    List<NodeRef<object>?>? Defaults = null,
    List<NodeRef<object>?>? TyList = null)
{
    public static Arguments Of(params string[] args) =>
        new(
            args.Select(a => new NodeRef<Identifier>(Identifier.Of(a))).ToList(),
            // The parser gives `defaults` and `ty_list` one slot per
            // parameter — `lambda x, y` is `"defaults":[null, null]` — because
            // they are indexed by argument position, not merely kept alongside.
            // A constructor that left them empty would write `[]` and a
            // consumer indexing slot 1 would find nothing there.
            Enumerable.Repeat<NodeRef<object>?>(null, args.Length).ToList(),
            Enumerable.Repeat<NodeRef<object>?>(null, args.Length).ToList());
}

/// <summary>
/// <c>ast::CallExpr</c> struct. <c>func</c> is a <c>NodeRef&lt;Expr&gt;</c> — an
/// identifier or a selector, not a <c>NodeRef&lt;Identifier&gt;</c> — and the
/// only distinction from a tagged <see cref="CallExpr"/> is the <c>type</c>
/// key a decorator is written without.
/// </summary>
public record CallDto(NodeRef<object>? Func = null, List<NodeRef<object>>? Args = null, List<NodeRef<object>>? Keywords = null)
{
    public static CallDto Of(NodeRef<object>? func = null, List<NodeRef<object>>? args = null, List<NodeRef<object>>? keywords = null)
        => new(func, args, keywords);
}

/// <summary>
/// A decorator is a call. This is the untagged <c>ast::Decorator</c>:
/// field-identical to <see cref="CallDto"/> and reached through a
/// <c>Vec&lt;NodeRef&lt;Decorator&gt;&gt;</c> rather than through the
/// <c>Expr</c> switch, so on the wire it is <c>{"func":…,"args":[…],
/// "keywords":[…]}</c> with no <c>"type":"Call"</c> beside it.
/// </summary>
public record Decorator(NodeRef<object>? Func = null, List<NodeRef<object>>? Args = null, List<NodeRef<object>>? Keywords = null)
{
    public static Decorator Of(NodeRef<object>? func = null, List<NodeRef<object>>? args = null, List<NodeRef<object>>? keywords = null)
        => new(func, args, keywords);
}

/// <summary>
/// <c>ast::CheckExpr</c> struct — the body of a <c>check:</c> block. Untagged:
/// the same struct is the payload of the <c>Expr::Check</c> variant, but the
/// parser only ever reaches it through a field.
/// </summary>
public record CheckExpr(NodeRef<object>? Test = null, NodeRef<object>? IfCond = null, NodeRef<object>? Msg = null)
{
    public static CheckExpr Of(NodeRef<object>? test = null, NodeRef<object>? ifCond = null, NodeRef<object>? msg = null)
        => new(test, ifCond, msg);
}

/// <summary>
/// <c>ast::ConfigEntry</c> struct — one <c>key = value</c> in a config.
/// <c>is_shorthand</c> is <c>Option&lt;bool&gt;</c> with
/// <c>skip_serializing_if = "is_false"</c>, so it is omitted entirely when
/// false and written only when true.
/// </summary>
public record ConfigEntry(NodeRef<object>? Key = null, NodeRef<object>? Value = null, string Operation = "Override", bool IsShorthand = false)
{
    public static ConfigEntry Of(NodeRef<object>? key = null, NodeRef<object>? value = null, string operation = "Override")
        => new(key, value, operation);
}

/// <summary>
/// <c>ast::CompClause</c> struct — <c>for … in …</c> inside a comprehension.
/// Untagged, and the same struct the tagged <c>Expr::CompClause</c> variant
/// is a newtype over.
/// </summary>
public record CompClause(
    List<NodeRef<Identifier>>? Targets = null,
    NodeRef<object>? Iter = null,
    List<NodeRef<object>>? Ifs = null)
{
    public static CompClause Of(List<NodeRef<Identifier>>? targets = null, NodeRef<object>? iter = null, List<NodeRef<object>>? ifs = null)
        => new(targets, iter, ifs);
}

/// <summary>
/// <c>ast::SchemaExpr</c> struct — <c>Person{name = "Alice"}</c>. Untagged.
/// </summary>
public record SchemaConfig(NodeRef<Identifier>? Name = null, List<NodeRef<object>>? Args = null, List<NodeRef<object>>? Kwargs = null, NodeRef<object>? Config = null)
{
    public static SchemaConfig Of(NodeRef<Identifier>? name = null, List<NodeRef<object>>? args = null, List<NodeRef<object>>? kwargs = null, NodeRef<object>? config = null)
        => new(name, args, kwargs, config);
}

/// <summary>
/// <c>ast::SchemaIndexSignature</c> struct — the <c>[k: str]: T</c> line of a
/// schema. Untagged.
/// </summary>
public record SchemaIndexSignature(
    NodeRef<string>? KeyName = null,
    NodeRef<object>? Value = null,
    bool AnyOther = false,
    NodeRef<object>? KeyTy = null,
    NodeRef<object>? ValueTy = null)
{
    public static SchemaIndexSignature Of(NodeRef<string>? keyName = null, NodeRef<object>? value = null, bool anyOther = false, NodeRef<object>? keyTy = null, NodeRef<object>? valueTy = null)
        => new(keyName, value, anyOther, keyTy, valueTy);
}

/// <summary>
/// <c>ast::Comment</c> struct — a single <c>#</c> line. It is a plain struct
/// with one <c>String</c> field, so the object under <c>node</c> is
/// <c>{"text": "…"}</c> and not the text itself. Declaring it as a
/// <c>NodeRef&lt;string&gt;</c> and reading <c>node</c> as a string therefore
/// drops every comment in the file. The position lives on the enclosing
/// <c>NodeRef&lt;Comment&gt;</c>, not on this record.
/// </summary>
public record Comment(string Text)
{
    public static Comment Of(string text) => new(text);
}

/// <summary>
/// <c>ast::MemberOrIndex</c> — the tail of <c>target.paths</c>, e.g. the
/// <c>.b</c> of <c>a.b = 1</c>. Like <c>Type</c> it is
/// <c>tag = "type", content = "value"</c>, so the tag names the shape and the
/// node sits under <c>value</c>. The two variants are modelled as two optional
/// fields rather than as a tag plus a loosely typed payload, so
/// <see cref="Tag"/> reconstructs the wire spelling from whichever is set.
/// </summary>
public record MemberOrIndex(NodeRef<string>? Member = null, NodeRef<object>? Index = null)
{
    public const string MemberTag = "Member";
    public const string IndexTag = "Index";

    /// <summary>The wire tag, recovered from whichever branch is populated.</summary>
    public string Tag => Member != null ? MemberTag : IndexTag;

    public static MemberOrIndex Member_(NodeRef<string> member) => new(member, null);
    public static MemberOrIndex Index_(NodeRef<object> index) => new(null, index);
}

internal static class DtoLoader
{
    public static Identifier? IdentifierFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new Identifier(
            Names: WireHelpers.NodeListFromWire<string>(el.GetProperty("names"), x => x.GetString()!),
            Pkgpath: WireHelpers.OptString(el, "pkgpath") ?? "",
            Ctx: WireHelpers.OptString(el, "ctx")
        );
    }

    public static Target? TargetFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new Target(
            Name: WireHelpers.NodeFromWire<string>(el.GetProperty("name"), x => x.GetString()!),
            Paths: MemberOrIndexListFromWire(el),
            Pkgpath: WireHelpers.OptString(el, "pkgpath") ?? ""
        );
    }

    public static Keyword? KeywordFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new Keyword(
            Arg: WireHelpers.NodeFromWire<Identifier>(el.GetProperty("arg"), IdentifierFromWire!),
            Value: WireHelpers.NodeFromWire<object>(el.GetProperty("value"), Loaders.ExprFromWire)
        );
    }

    public static Arguments? ArgumentsFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new Arguments(
            // A parameter name is the untagged `Identifier` struct, and the
            // annotation is a `Type`. Both were read as expressions, which
            // silently yields null for a name and an unknown node for
            // `{"type":"Basic","value":"Int"}` — neither of which raises.
            Args: WireHelpers.NodeListFromWire<Identifier>(el.GetProperty("args"), IdentifierFromWire!),
            Defaults: OptNodeListFromWire(el, "defaults", Loaders.ExprFromWire),
            TyList: OptNodeListFromWire(el, "ty_list", Loaders.TypeFromWire)
        );
    }

    /// <summary>
    /// A <c>Vec&lt;Option&lt;NodeRef&lt;Expr&gt;&gt;&gt;</c>. A JSON <c>null</c>
    /// here is a slot that occupies a position and says "nothing here", not an
    /// absent list — <c>lambda x, y</c> gives <c>"defaults":[null, null]</c>,
    /// and reading this with the plain list decoder either throws or drops the
    /// nulls and shortens the parameter list.
    /// </summary>
    public static List<NodeRef<object>?>? OptNodeListFromWire(JsonElement el, string key, Func<JsonElement, object?> load)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        if (!el.TryGetProperty(key, out var arr) || arr.ValueKind != JsonValueKind.Array) return null;
        var list = new List<NodeRef<object>?>();
        foreach (var item in arr.EnumerateArray())
        {
            list.Add(item.ValueKind == JsonValueKind.Null ? null : WireHelpers.NodeFromWire<object>(item, load));
        }
        return list;
    }

    /// <summary>Reads the <c>Decorator</c> fields; the struct is untagged.</summary>
    public static Decorator? DecoratorFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new Decorator(
            Func: WireHelpers.NodeFromWire<object>(el.GetProperty("func"), Loaders.ExprFromWire),
            Args: WireHelpers.NodeListFromWire<object>(el.GetProperty("args"), Loaders.ExprFromWire),
            Keywords: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<Keyword>(el.GetProperty("keywords"), KeywordFromWire))
        );
    }

    /// <summary>Reads the <c>CallExpr</c> fields; the struct is untagged.</summary>
    public static CallDto? CallDtoFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new CallDto(
            Func: WireHelpers.NodeFromWire<object>(el.GetProperty("func"), Loaders.ExprFromWire),
            Args: WireHelpers.NodeListFromWire<object>(el.GetProperty("args"), Loaders.ExprFromWire),
            Keywords: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<Keyword>(el.GetProperty("keywords"), KeywordFromWire))
        );
    }

    /// <summary>Reads the <c>CheckExpr</c> fields; the struct is untagged.</summary>
    public static CheckExpr? CheckExprFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new CheckExpr(
            Test: WireHelpers.NodeFromWire<object>(el.GetProperty("test"), Loaders.ExprFromWire),
            IfCond: WireHelpers.NodeFromWire<object>(el.GetProperty("if_cond"), Loaders.ExprFromWire),
            Msg: WireHelpers.NodeFromWire<object>(el.GetProperty("msg"), Loaders.ExprFromWire)
        );
    }

    /// <summary>Reads the <c>ConfigEntry</c> fields; the struct is untagged.</summary>
    public static ConfigEntry? ConfigEntryFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new ConfigEntry(
            Key: WireHelpers.NodeFromWire<object>(el.GetProperty("key"), Loaders.ExprFromWire),
            Value: WireHelpers.NodeFromWire<object>(el.GetProperty("value"), Loaders.ExprFromWire),
            Operation: WireHelpers.OptString(el, "operation") ?? "Override",
            IsShorthand: WireHelpers.OptBool(el, "is_shorthand")
        );
    }

    /// <summary>Reads the <c>CompClause</c> fields; the struct is untagged.</summary>
    public static CompClause? CompClauseFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new CompClause(
            Targets: WireHelpers.NodeListFromWire<Identifier>(el.GetProperty("targets"), IdentifierFromWire!),
            Iter: WireHelpers.NodeFromWire<object>(el.GetProperty("iter"), Loaders.ExprFromWire),
            Ifs: WireHelpers.NodeListFromWire<object>(el.GetProperty("ifs"), Loaders.ExprFromWire)
        );
    }

    /// <summary>Reads the <c>SchemaExpr</c> fields; the struct is untagged.</summary>
    public static SchemaConfig? SchemaConfigFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new SchemaConfig(
            Name: WireHelpers.NodeFromWire<Identifier>(el.GetProperty("name"), IdentifierFromWire!),
            Args: WireHelpers.NodeListFromWire<object>(el.GetProperty("args"), Loaders.ExprFromWire),
            Kwargs: WireHelpers.BoxAll(WireHelpers.NodeListFromWire<Keyword>(el.GetProperty("kwargs"), KeywordFromWire)),
            Config: WireHelpers.NodeFromWire<object>(el.GetProperty("config"), Loaders.ExprFromWire)
        );
    }

    /// <summary>Reads the <c>SchemaIndexSignature</c> fields; untagged.</summary>
    public static SchemaIndexSignature? SchemaIndexSignatureFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new SchemaIndexSignature(
            KeyName: WireHelpers.NodeFromWire<string>(el.GetProperty("key_name"), x => x.GetString()!),
            Value: WireHelpers.NodeFromWire<object>(el.GetProperty("value"), Loaders.ExprFromWire),
            AnyOther: WireHelpers.OptBool(el, "any_other"),
            KeyTy: WireHelpers.NodeFromWire<object>(el.GetProperty("key_ty"), Loaders.TypeFromWire),
            ValueTy: WireHelpers.NodeFromWire<object>(el.GetProperty("value_ty"), Loaders.TypeFromWire)
        );
    }

    /// <summary>
    /// <c>Comment</c> is a plain struct with a single <c>String</c> field, so
    /// the object under <c>node</c> is <c>{"text": "…"}</c> — one level in
    /// from the wrapper. Reading <c>node</c> as a string yields null for every
    /// comment in the file and the array empties out silently.
    /// </summary>
    public static Comment? CommentFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        return new Comment(WireHelpers.OptString(el, "text") ?? "");
    }

    /// <summary>
    /// <c>MemberOrIndex</c> is <c>tag = "type", content = "value"</c>, so the
    /// tag is read off the wrapper and the node lives under <c>value</c>.
    /// </summary>
    public static MemberOrIndex? MemberOrIndexFromWire(JsonElement el)
    {
        if (el.ValueKind != JsonValueKind.Object) return null;
        var tag = WireHelpers.OptString(el, "type");
        if (tag == null) return null;
        if (!el.TryGetProperty("value", out var value)) return null;
        return tag switch
        {
            MemberOrIndex.MemberTag => new MemberOrIndex(
                Member: WireHelpers.NodeFromWire<string>(value, x => x.GetString()!)),
            MemberOrIndex.IndexTag => new MemberOrIndex(
                Index: WireHelpers.NodeFromWire<object>(value, Loaders.ExprFromWire)),
            _ => new MemberOrIndex(),
        };
    }

    private static List<MemberOrIndex>? MemberOrIndexListFromWire(JsonElement el)
    {
        if (!el.TryGetProperty("paths", out var arr) || arr.ValueKind != JsonValueKind.Array) return null;
        var list = new List<MemberOrIndex>();
        foreach (var item in arr.EnumerateArray())
        {
            var mi = MemberOrIndexFromWire(item);
            if (mi != null) list.Add(mi);
        }
        return list;
    }
}
