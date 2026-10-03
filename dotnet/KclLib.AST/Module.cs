// Module.cs — Module AST node + public ParseModule / ParseProgram entry points
// and their write-side counterparts.
//
// Mirrors `ast::Module` in `crates/ast/src/ast.rs`. The Rust struct has no
// `pkg` field — the Java/Go bindings previously exposed one and were aligned
// to drop it.

using System.Text.Json;

namespace KclLib.AST;

/// <summary>
/// Top-level AST node for a single KCL file.
/// </summary>
public record Module(string Filename, NodeRef<string>? Doc = null, List<NodeRef<object>>? Body = null, List<NodeRef<Comment>>? Comments = null)
{
    public static Module Of(string filename,
        NodeRef<string>? doc = null,
        List<NodeRef<object>>? body = null,
        List<NodeRef<Comment>>? comments = null)
        => new(filename, doc, body, comments);

    /// <summary>
    /// The wire shape — <c>{"filename":…,"doc":…,"body":[…],"comments":[…]}</c>
    /// — and nothing else. A <c>pkg</c> key here would be a key Rust does not
    /// write, and <c>AstLoader.ParseModule</c> does not read it back.
    /// </summary>
    public string ToJson() => AstWriter.WriteJson(this);
}

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

    /// <summary>
    /// Write a program envelope back out in the shape
    /// <c>API.ParseProgram</c> emits, so a parsed program can be round-tripped
    /// through <see cref="ParseProgram"/> without losing its grouping.
    /// </summary>
    public static string WriteProgramJson(IEnumerable<Module> modules, string root = "__main__") =>
        AstWriter.WriteJson(new Dictionary<string, object?>
        {
            ["root"] = root,
            ["pkgs"] = new Dictionary<string, object?> { [root] = modules.Select(m => (object?)AstWriter.ToWire(m)).ToList() },
        });

    private static Module ModuleFromWire(JsonElement el)
    {
        return new Module(
            Filename: WireHelpers.OptString(el, "filename") ?? "",
            Doc: WireHelpers.NodeFromWire<string>(el.GetProperty("doc"), x => x.GetString()!),
            Body: WireHelpers.NodeListFromWire<object>(el.GetProperty("body"), Loaders.StmtFromWire),
            Comments: WireHelpers.NodeListFromWire<Comment>(el.GetProperty("comments"), DtoLoader.CommentFromWire!)
        );
    }
}
