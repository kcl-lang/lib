// Cross-language AST dump for the Kotlin binding.
//
//   hack/dump/kotlin.sh <golden.json> <out.json>
//
// Kotlin is a *wire* binding, like zig and .NET: `AstWire.kt` is a real
// serializer, so this is a round-trip rather than a reflective walk. That is
// the stronger check — a bug in the decoder and a bug in the serializer both
// surface, and neither can hide behind a lossy dumper.
//
// The two halves are the binding's own, and they are the two halves kotlin
// actually contributes:
//
//   * `com.kcl.ast.parseModule` (AstJson.kt) — the Jackson decode. kotlin
//     compiles the same `com.kcl.ast` classes java does, so this is the same
//     decoder; what kotlin adds is the single-module entry point java lacks.
//   * `com.kcl.ast.toWire` (AstWire.kt) — the encode, 649 lines that exist in
//     no other binding but the .NET `Wire.cs` it is written to mirror. Its
//     header explains at length why Jackson cannot do this job despite the
//     classes already being Jackson-annotated: `Stmt`/`Expr` are
//     `#[serde(tag = "type")]` newtypes whose struct serde flattens beside the
//     tag, `Type` is adjacently tagged, and `@JsonInclude(NON_NULL)` drops
//     every `Option` that serde writes as an explicit `null`.
//
// That last point is the reason this binding was worth wiring up at all:
// `AstWire.kt` is 649 lines of hand-written shape restoration with no
// cross-language check on it, and its own docstring claims a decode/encode
// cycle is a fixed point. This is where that claim gets tested.
//
// Nothing here renames or reshapes anything. The tree under `root` is
// `toWire`'s own output; the only addition is the standard envelope so the
// comparator's vacuity guards — the exact 63-item body and 33-comment counts —
// apply here as they do to the reflective bindings.

package astdump

import com.fasterxml.jackson.databind.ObjectMapper
import com.kcl.ast.parseModule
import com.kcl.ast.toJson
import com.kcl.ast.toWire
import java.io.File

fun main(args: Array<String>) {
    if (args.size != 2) {
        System.err.println("usage: hack/dump/kotlin.sh <golden.json> <out.json>")
        kotlin.system.exitProcess(2)
    }

    val golden = File(args[0]).readText()

    // The binding's real decoder…
    val module = parseModule(golden)
    // …and its real serializer. `toJson` is `toWire` followed by a Jackson
    // write, so the tree the comparator sees is the binding's own wire shape
    // rather than a reflection of its classes.
    val root = toWire(module)

    // The binding's own writer must produce something that parses as JSON, or
    // the dumper would be checking a tree `toJson` would not emit. Cheap, and
    // it turns a change in the writer into a failure here rather than a silent
    // difference later. Same cross-check `hack/dump/dotnet/Program.cs` makes.
    val mapper = ObjectMapper()
    mapper.readTree(module.toJson())

    val doc = linkedMapOf<String, Any?>(
        "schema" to "kcl-ast-canonical/1",
        "binding" to "kotlin",
        "mode" to "wire",
        "root" to root,
    )

    // Nulls are keys Rust writes, not absent fields, so nothing is dropped.
    File(args[1]).writeText(mapper.writerWithDefaultPrettyPrinter().writeValueAsString(doc) + "\n")
}
