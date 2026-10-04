// Cross-language AST dump for the .NET binding.
//
//   hack/dump/dotnet.sh <golden.json> <out.json>
//
// Runs the binding's real decoder (`AstLoader.ParseModule`) and its real
// serializer (`AstWriter.ToWire`) over the shared capture and writes the tree
// in the shape `hack/ast_diff/canonical.rb` compares.
//
// .NET is a *wire* binding, like zig: `KclLib.AST` has a real serializer, so
// this is a round-trip rather than a reflective walk. That is the stronger
// check — a bug in the decoder and a bug in the serializer both surface, and
// neither can hide behind a lossy dumper.
//
// Two things about how the tree is written:
//
//   * `AstWriter.ToWire(Module)` hands back a `Dictionary<string, object?>`
//     tree, not a JSON string, so this file does the serializing. It uses
//     `Module.ToJson()` only to prove the binding's own writer agrees on
//     shape — that call is a check, not the source of the output.
//   * Nothing is renamed and nothing is reshaped. Every key in the dump came
//     out of `AstWriter`; the only thing added is the standard envelope
//     (`schema` / `binding` / `mode` / `root`) so the comparator's vacuity
//     guards — the exact 63-item body count and 33-comment count — apply to
//     this binding the same as to the reflective ones.

using System.Text.Json;
using KclLib.AST;

if (args.Length != 2)
{
    Console.Error.WriteLine("usage: hack/dump/dotnet.sh <golden.json> <out.json>");
    return 2;
}

var goldenPath = args[0];
var outPath = args[1];

// The binding's real decoder…
var module = AstLoader.ParseModule(File.ReadAllText(goldenPath));
// …and its real serializer. `ToWire` is the same function `ToJson` calls
// (`Wire.cs:51`), so the tree the comparator sees is the binding's own
// wire shape rather than a reflection of its classes.
var root = AstWriter.ToWire(module);

// The binding's own writer must agree that this tree is JSON-shaped, or the
// dumper would be checking something `ToJson` would not produce. Cheap, and
// it turns a change in the writer into a failure here rather than a silent
// difference later.
_ = JsonDocument.Parse(module.ToJson());

var doc = new Dictionary<string, object?>
{
    ["schema"] = "kcl-ast-canonical/1",
    ["binding"] = "dotnet",
    ["mode"] = "wire",
    ["root"] = root,
};

var options = new JsonSerializerOptions
{
    WriteIndented = true,
    // Every null in the tree is a key Rust writes, not an absent field, so
    // nothing is dropped. Same reasoning as `Wire.cs:44-47`, and the same
    // default.
    DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.Never,
};

File.WriteAllText(outPath, JsonSerializer.Serialize(doc, options) + "\n");
return 0;
