// Builders.cs — the lifts a caller needs to assemble a tree by hand.
//
// `Expr`, `Stmt` and `Type` are three Rust enums with no C# base record between
// them, so a field holding one of them is declared as `object` and the record
// type is the dispatch key — for both `AstLoader` and `AstWriter`. That is what
// keeps the two in step, but it has a cost on the building side: `NodeRef<T>`
// is invariant in `T`, so a `NumberLit` cannot be put in a `NodeRef<object>`
// without a conversion at every single level of the tree. `Ast.Expr` is that
// conversion, once, with a name.
//
// The `Of(...)` factory on each record is the other half: it stamps the `type`
// tag from the record's own `Tag` constant, so a caller never spells `"Call"`
// or `"NumberLit"`, and the decoder and the constructor cannot disagree about
// which spelling is right.

namespace KclLib.AST;

/// <summary>
/// Constructor helpers for the polymorphic slots of the AST. See the note on
/// <see cref="NodeRef{T}"/> above for why these exist.
/// </summary>
public static class Ast
{
    /// <summary>Wrap an expression payload for a <c>NodeRef&lt;object&gt;</c> field.</summary>
    public static NodeRef<object> Expr(object expr, Pos? position = null) => new(expr, position);

    /// <summary>Wrap a statement payload for a <c>NodeRef&lt;object&gt;</c> field.</summary>
    public static NodeRef<object> Stmt(object stmt, Pos? position = null) => new(stmt, position);

    /// <summary>Wrap a type payload for a <c>NodeRef&lt;object&gt;</c> field.</summary>
    public static NodeRef<object> Type(object ty, Pos? position = null) => new(ty, position);

    /// <summary>
    /// Wrap a string payload. <c>NodeRef&lt;String&gt;</c> reaches the wire as
    /// an object like every other node — <c>{"node":"Person", …}</c> — so it is
    /// not the bare string, and the two are not interchangeable on the way out.
    /// </summary>
    public static NodeRef<string> Str(string value, Pos? position = null) => new(value, position);

    /// <summary>
    /// A list of node payloads, for the <c>Vec&lt;NodeRef&lt;T&gt;&gt;</c> fields
    /// that are declared as <c>List&lt;NodeRef&lt;object&gt;&gt;</c>.
    /// </summary>
    public static List<NodeRef<object>> List(params NodeRef<object>[] nodes) => nodes.ToList();
}
