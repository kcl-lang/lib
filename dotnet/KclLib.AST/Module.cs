// Module.cs — Module AST node + public ParseModule / ParseProgram entry points.
//
// Mirrors `ast::Module` in `crates/ast/src/ast.rs`. The Rust struct has no
// `pkg` field — the Java/Go bindings previously exposed one and were aligned
// to drop it.

using System.Text.Json;

namespace KclLib.AST;

/// <summary>
/// Top-level AST node for a single KCL file.
/// </summary>
public record Module(string Filename, NodeRef<string>? Doc = null, List<NodeRef<object>>? Body = null, List<Comment>? Comments = null);

/// <summary>
/// Public entry point for parsing the <c>astJson</c> string emitted by
/// <c>API.ParseFile</c> / <c>API.ParseProgram</c> into typed AST objects.
/// </summary>
public static class AstLoader
{
    /// <summary>Parse an <c>ast_json</c> string into a Module.</summary>
    public static Module ParseModule(string astJson)
    {
        using var doc = JsonDocument.Parse(astJson);
        return ModuleFromWire(doc.RootElement);
    }

    /// <summary>Parse a program envelope into a list of Modules.</summary>
    public static List<Module> ParseProgram(string programJson)
    {
        using var doc = JsonDocument.Parse(programJson);
        var root = doc.RootElement;
        if (root.ValueKind == JsonValueKind.Array)
        {
            return root.EnumerateArray().Select(ModuleFromWire).ToList();
        }
        // Program envelope: `{"root": str, "pkgs": {"__main__": [Module, ...]}}`.
        List<Module> modules = new();
        if (root.TryGetProperty("pkgs", out var pkgs) &&
            pkgs.TryGetProperty("__main__", out var main) &&
            main.ValueKind == JsonValueKind.Array)
        {
            foreach (var m in main.EnumerateArray())
            {
                modules.Add(ModuleFromWire(m));
            }
        }
        return modules;
    }

    private static Module ModuleFromWire(JsonElement el)
    {
        List<Comment>? comments = null;
        if (el.TryGetProperty("comments", out var commentsEl) && commentsEl.ValueKind == JsonValueKind.Array)
        {
            comments = new List<Comment>();
            foreach (var c in commentsEl.EnumerateArray())
            {
                var pos = WireHelpers.PosFromWire(c);
                var node = WireHelpers.OptString(c, "node");
                if (node != null) comments.Add(new Comment(node, pos));
            }
        }
        return new Module(
            Filename: WireHelpers.OptString(el, "filename") ?? "",
            Doc: WireHelpers.NodeFromWire<string>(el.GetProperty("doc"), x => x.GetString()!),
            Body: WireHelpers.NodeListFromWire<object>(el.GetProperty("body"), Loaders.StmtFromWire),
            Comments: comments
        );
    }
}