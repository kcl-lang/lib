// Loader.cs — Polymorphic dispatcher registry.
//
// Both Expr.cs and Dto.cs reference `Loaders.ExprFromWire` /
// `Loaders.TypeFromWire` (for the cycle). The actual implementations live
// in `ExprLoader` and `TypeLoader` (defined in their own files); this file
// just exposes them under a single static class so the cycle resolves
// cleanly.

using System.Text.Json;

namespace KclLib.AST;

internal static class Loaders
{
    public static Func<JsonElement, object?> ExprFromWire => ExprLoader.ExprFromWire;
    public static Func<JsonElement, object?> TypeFromWire => TypeLoader.TypeFromWire;
    public static Func<JsonElement, object?> StmtFromWire => StmtLoader.StmtFromWire;
}