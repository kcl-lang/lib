// AstWireRoundTripTest.cs — The write side of the AST package, asserted against
// the real parser's output.
//
// `testdata/ast/alignment.json` is a capture of `ast_json` for
// `testdata/ast/alignment.k`, which exercises every node shape the package
// models. Decoding that capture rather than calling `API.ParseFile` keeps this a
// pure test of the writer: it needs no native runtime, and it does not break
// every time the fixture grows a new section.
//
// The strongest assertion available is a fixed point — decode the capture,
// write it back, and require the two documents to be equal — because any field
// the writer forgets to emit shows up as a difference rather than as a
// silently-defaulted node. The per-shape tests below then pin the individual
// decisions a fixed point alone would not explain: which tag, which wrapper,
// which null.

namespace KclLib.Tests;

using System.Text.Json;
using System.Text.Json.Nodes;
using KclLib.AST;

[TestClass]
public class AstWireRoundTripTest
{
    /// <summary>
    /// The capture lives at the repository root, two directories above the test
    /// project. Searched for rather than counted out, so the test still finds it
    /// when the runner's working directory is the build output rather than the
    /// project.
    /// </summary>
    private static readonly string GoldenPath = FindGolden();

    private static string FindGolden()
    {
        var relative = Path.Combine("testdata", "ast", "alignment.json");
        for (var dir = FindCsprojInParentDirectory(Environment.CurrentDirectory);
             dir != null;
             dir = Path.GetDirectoryName(dir))
        {
            var candidate = Path.Combine(dir, relative);
            if (File.Exists(candidate)) return candidate;
        }
        throw new FileNotFoundException(
            $"Could not find {relative} in any parent directory of {Environment.CurrentDirectory}");
    }

    private static string GoldenJson() => File.ReadAllText(GoldenPath);

    private static JsonNode Parse(string json) => JsonNode.Parse(json)!;

    /// <summary>
    /// The positions the parser gave `Person(1, name = "Bob")` on line 53 of
    /// `alignment.k`. A node built by hand has no source text to point at, so
    /// comparing a from-scratch build against the capture means carrying the
    /// capture's positions over — which is exactly what a caller restoring a
    /// saved AST would do.
    /// </summary>
    private static Pos At(int line, int column, int endColumn) =>
        new("testdata/ast/alignment.k", line, column, line, endColumn);

    private static NodeRef<T> Wrap<T>(T node, Pos? pos = null) => new(node, pos);

    // -----------------------------------------------------------------------
    // The fixed point
    // -----------------------------------------------------------------------

    [TestMethod]
    public void DecodeEncodeIsAFixedPoint()
    {
        var golden = Parse(GoldenJson());
        var written = Parse(AstWriter.WriteJson(AstLoader.ParseModule(GoldenJson())));
        AssertJsonEqual(golden, written);
    }

    [TestMethod]
    public void DecodeEncodeIsAFixedPointTwiceOver()
    {
        // Writing, re-reading and writing again must produce the same bytes as
        // the first write. A key the writer emits that the reader ignores (or
        // vice versa) shows up here and nowhere else.
        var once = AstWriter.WriteJson(AstLoader.ParseModule(GoldenJson()));
        var twice = AstWriter.WriteJson(AstLoader.ParseModule(once));
        AssertJsonEqual(Parse(once), Parse(twice));
    }

    [TestMethod]
    public void TheWrittenModuleCarriesNoPkgKey()
    {
        // Rust's `Module` has no `pkg` field. Emitting one, or dropping the
        // four it does have, would both break a strict consumer.
        var written = Parse(AstWriter.WriteJson(AstLoader.ParseModule(GoldenJson())));
        var keys = written.AsObject().Select(p => p.Key).OrderBy(k => k, StringComparer.Ordinal).ToList();
        CollectionAssert.AreEqual(new[] { "body", "comments", "doc", "filename" }, keys);
    }

    [TestMethod]
    public void ProgramEnvelopeRoundTrips()
    {
        // `SerializeProgram` is `{root, pkgs: {<pkg>: [Module, …]}}` — a
        // different envelope from a single `Module`, and the one
        // `AstLoader.ParseProgram` reads.
        var modules = AstLoader.ParseProgram(AstLoader.WriteProgramJson(new[]
        {
            new Module("a.k"), new Module("b.k"),
        }));
        Assert.AreEqual(2, modules.Count);
        CollectionAssert.AreEqual(new[] { "a.k", "b.k" }, modules.Select(m => m.Filename).ToList());
    }

    // -----------------------------------------------------------------------
    // Built by hand, compared with the capture
    // -----------------------------------------------------------------------

    [TestMethod]
    public void CallExprBuiltByHandEqualsTheCapturedCall()
    {
        // `Expr::Call(CallExpr)` is a newtype over a struct, so serde flattens
        // the struct's fields beside the tag. There is no `call` wrapper key to
        // descend through and none to emit — a writer that nests one produces a
        // document the parser would not recognise.
        //
        // The comparison is against the payload rather than a wrapper because
        // the call is the *value* of an assignment, so the capture has no
        // `Node` around it. The keyword's `arg` carries its own position and
        // `"ctx":"Load"` in the capture, so those are built here too: a
        // hand-built node that can reproduce the parser's bytes is the claim
        // being tested, and a `Keyword` assembled from a bare string would
        // differ in exactly the two fields a shape check does not look at.
        var call = new CallExpr(
            Type: CallExpr.Tag,
            Func: Ast.Expr(
                IdentifierExpr.Of(new List<NodeRef<string>> { new("Person", At(53, 4, 10)) }),
                At(53, 4, 10)),
            Args: Ast.List(Ast.Expr(NumberLit.Of(1L), At(53, 11, 12))),
            Keywords: Ast.List(Ast.Expr(
                new Keyword(
                    Arg: new NodeRef<Identifier>(
                        Identifier.Of(new List<NodeRef<string>> { new("name", At(53, 14, 18)) }, "", "Load"),
                        At(53, 14, 18)),
                    Value: Ast.Expr(StringLit.Of("Bob"), At(53, 21, 26))),
                At(53, 14, 26))));

        AssertJsonEqual(Parse(AstWriter.WriteJson(call)), Parse(FindFirstGolden("Call")));
    }

    [TestMethod]
    public void TypeAliasBuiltByHandEqualsTheCapturedAlias()
    {
        // `Type` is adjacently tagged and `Type::List` is not a unit variant,
        // so the payload lives under `value` — and the tag names the *shape*:
        // `Basic` with the variant as a bare string, not `Int`.
        var alias = TypeAliasStmt.Of(
            typeName: Wrap(Identifier.Of(new List<NodeRef<string>> { new("TList", At(22, 5, 10)) }), At(22, 5, 10)),
            typeValue: Wrap("[int]", At(22, 13, 18)),
            ty: Ast.Type(ListType.Of(Ast.Type(BasicType.Int(), At(22, 14, 17))), At(22, 13, 18)));

        AssertJsonEqual(
            Parse(AstWriter.WriteJson(Ast.Stmt(alias, At(22, 5, 18)))),
            Parse(FindGoldenStatement("TList")));
    }

    [TestMethod]
    public void CommentsBuiltByHandCarryTheirTextAsAnObject()
    {
        // `Comment` is a plain struct with one `String` field, so the object
        // under `node` is `{"text": "…"}` and not the text. A writer that emits
        // the bare string produces a document no decoder can read back — the
        // bug that has shipped in four bindings.
        var comment = Wrap(Comment.Of("# Every AST node shape the language bindings model, in one file."),
            new Pos("testdata/ast/alignment.k", 1, 0, 1, 64));

        var written = Parse(AstWriter.WriteJson(AstWriter.ToWire(comment)));
        var node = written["node"]!.AsObject();
        CollectionAssert.AreEqual(new[] { "text" }, node.Select(p => p.Key).ToList());
        Assert.AreEqual("# Every AST node shape the language bindings model, in one file.", node["text"]!.GetValue<string>());
    }

    [TestMethod]
    public void TheCapturedCommentsSurviveWithTheirText()
    {
        // Both directions matter and neither shows up in a shape check: a
        // decoder that unwraps `node` again reads a key the payload does not
        // have, and one that reads the payload as the text gets an object where
        // it promised a string. Both yield "" for every comment in the file.
        var module = AstLoader.ParseModule(GoldenJson());
        Assert.IsNotNull(module.Comments, "no comments decoded at all");
        Assert.IsTrue(module.Comments!.Count > 0, "every comment was dropped");
        foreach (var c in module.Comments)
        {
            Assert.IsNotNull(c.Node.Text, "a comment came back with no text");
            Assert.IsTrue(c.Node.Text.StartsWith("#"), $"a comment lost its text: '{c.Node.Text}'");
        }

        var golden = Parse(GoldenJson());
        var written = Parse(AstWriter.WriteJson(module));
        AssertJsonEqual(golden["comments"]!, written["comments"]!);
    }

    // -----------------------------------------------------------------------
    // The individual decisions a fixed point would not explain
    // -----------------------------------------------------------------------

    [TestMethod]
    public void TaggedExprFlattensItsStructFieldsBesideTheTag()
    {
        var written = Parse(AstWriter.WriteJson(AstWriter.ToWire(new CallExpr(CallExpr.Tag))));
        var keys = written.AsObject().Select(p => p.Key).OrderBy(k => k, StringComparer.Ordinal).ToList();
        CollectionAssert.AreEqual(new[] { "args", "func", "keywords", "type" }, keys);
        Assert.IsFalse(written.AsObject().ContainsKey("call"), "the struct was nested under a wrapper key");
    }

    [TestMethod]
    public void TaggedStmtIsNotWrappedInANode()
    {
        // `Stmt` variants are tagged statements: their fields sit on the
        // statement object itself, so there is no `node` key to descend into
        // and none to write.
        var written = Parse(AstWriter.WriteJson(AstWriter.ToWire(ExprStmt.Of(new List<NodeRef<object>>()))));
        var keys = written.AsObject().Select(p => p.Key).OrderBy(k => k, StringComparer.Ordinal).ToList();
        CollectionAssert.AreEqual(new[] { "exprs", "type" }, keys);
    }

    [TestMethod]
    public void BasicTypeIsAdjacentlyTaggedWithABareStringPayload()
    {
        // The tag names the *shape*, so `BasicType::Int` is
        // `{"type":"Basic","value":"Int"}` and never `{"type":"Int"}`. A
        // registry keyed on the variant name matches nothing.
        var written = Parse(AstWriter.WriteJson(BasicType.Int()));
        Assert.AreEqual("Basic", written["type"]!.GetValue<string>());
        Assert.AreEqual("Int", written["value"]!.GetValue<string>());
    }

    [TestMethod]
    public void AnyTypeIsTheBareTagWithNoValueKey()
    {
        // The only unit variant of `Type`. serde's adjacently-tagged
        // representation of a unit variant is the tag alone, so
        // `{"type":"Any","value":null}` would put a key serde never writes.
        var written = Parse(AstWriter.WriteJson(AnyType.Of()));
        CollectionAssert.AreEqual(new[] { "type" }, written.AsObject().Select(p => p.Key).ToList());
    }

    [TestMethod]
    public void LiteralTypeNestsASecondTaggedDocument()
    {
        // `LiteralType` is `tag + content` as well, so `Type::Literal` nests
        // one level deeper than the rest, and `Int` is the only variant whose
        // payload is a struct rather than a bare scalar.
        var written = Parse(AstWriter.WriteJson(LiteralType.Int(1)));
        Assert.AreEqual("Literal", written["type"]!.GetValue<string>());
        var inner = written["value"]!.AsObject();
        Assert.AreEqual("Int", inner["type"]!.GetValue<string>());
        CollectionAssert.AreEqual(
            new[] { "suffix", "value" },
            inner["value"]!.AsObject().Select(p => p.Key).OrderBy(k => k, StringComparer.Ordinal).ToList());
        Assert.AreEqual(1L, inner["value"]!["value"]!.GetValue<long>());
        Assert.IsNull(inner["value"]!["suffix"]);

        var str = Parse(AstWriter.WriteJson(LiteralType.Str("s")));
        Assert.AreEqual("Str", str["value"]!["type"]!.GetValue<string>());
        Assert.AreEqual("s", str["value"]!["value"]!.GetValue<string>());
    }

    [TestMethod]
    public void NumberLitIsDoublyTaggedToo()
    {
        var written = Parse(AstWriter.WriteJson(NumberLit.Of(1L)));
        Assert.AreEqual("NumberLit", written["type"]!.GetValue<string>());
        Assert.IsNull(written["binary_suffix"], "binary_suffix is Option, so null is written");
        Assert.AreEqual("Int", written["value"]!["type"]!.GetValue<string>());
        Assert.AreEqual(1L, written["value"]!["value"]!.GetValue<long>());
    }

    [TestMethod]
    public void FunctionParamsTyIsNullOrAListAndNeverAnEmptyOne()
    {
        // `Option<Vec<NodeRef<Type>>>` looks three-state in the type, but
        // `crates/parser/src/parser/ty.rs` only ever builds `None` or
        // `Some(non-empty)`. There is no empty-list case on the wire, so there
        // is no factory for one either.
        var noArgs = Parse(AstWriter.WriteJson(FunctionType.NoParams()));
        Assert.IsNull(noArgs["value"]!["params_ty"]);

        var one = Parse(AstWriter.WriteJson(FunctionType.Of(
            new List<NodeRef<object>> { Ast.Type(BasicType.Int(), Pos.Default) })));
        Assert.AreEqual(1, one["value"]!["params_ty"]!.AsArray().Count);
        Assert.AreEqual("Basic", one["value"]!["params_ty"]![0]!["node"]!["type"]!.GetValue<string>());
    }

    [TestMethod]
    public void ArgumentDefaultsKeepTheirNullSlots()
    {
        // `Vec<Option<NodeRef<Expr>>>`: a null occupies a slot and says "this
        // parameter has no default". Writing `[]` instead would shorten the
        // parameter list.
        var written = Parse(AstWriter.WriteJson(Arguments.Of("x", "y")));
        Assert.AreEqual(2, written["args"]!.AsArray().Count);
        Assert.AreEqual(2, written["defaults"]!.AsArray().Count);
        foreach (var slot in written["defaults"]!.AsArray())
        {
            Assert.IsNull(slot);
        }
    }

    [TestMethod]
    public void ConfigEntryDropsIsShorthandWhenItIsFalse()
    {
        // `#[serde(skip_serializing_if = "is_false")]` — omitted when false,
        // present when true.
        var plain = Parse(AstWriter.WriteJson(ConfigEntry.Of()));
        CollectionAssert.AreEqual(
            new[] { "key", "operation", "value" },
            plain.AsObject().Select(p => p.Key).OrderBy(k => k, StringComparer.Ordinal).ToList());

        var shorthand = Parse(AstWriter.WriteJson(new ConfigEntry(Operation: "Override", IsShorthand: true)));
        Assert.IsTrue(shorthand["is_shorthand"]!.GetValue<bool>());
    }

    [TestMethod]
    public void UnificationValueIsUntagged()
    {
        // `UnificationStmt.value` is a `NodeRef<SchemaExpr>` reached through a
        // struct-typed field, so the payload carries no `type` key — the one
        // place a `SchemaExpr` appears without one, even though the tagged
        // `Expr::Schema` writes `"type":"Schema"`.
        var written = Parse(AstWriter.WriteJson(UnificationStmt.Of(
            target: Wrap(Identifier.Of(new List<NodeRef<string>> { new("u") }, "Store")),
            value: Wrap(SchemaConfig.Of(
                name: Wrap(Identifier.Of("Person")),
                config: Ast.Expr(ConfigExpr.Of(Ast.List(
                    Ast.Expr(ConfigEntry.Of(
                        Ast.Expr(IdentifierExpr.Of("name")),
                        Ast.Expr(StringLit.Of("Bob"))))))))))));
        var value = written["value"]!["node"]!.AsObject();
        CollectionAssert.AreEqual(
            new[] { "args", "config", "kwargs", "name" },
            value.Select(p => p.Key).OrderBy(k => k, StringComparer.Ordinal).ToList());
        Assert.IsFalse(value.ContainsKey("type"), "the payload picked up a tag it does not have");
    }

    [TestMethod]
    public void SchemaAttrDocIsAStringAndSchemaStmtDocIsOptional()
    {
        // `SchemaAttr::doc` is a `String` in Rust, so it is written as `""`
        // rather than dropped; `SchemaStmt::doc` is an `Option<NodeRef<String>>`
        // and is written as `null` when absent. Same field name, two shapes.
        var attr = Parse(AstWriter.WriteJson(AstWriter.ToWire(SchemaAttr.Of(name: Wrap("name")))));
        Assert.AreEqual("", attr["doc"]!.GetValue<string>());

        var schema = Parse(AstWriter.WriteJson(AstWriter.ToWire(SchemaStmt.Of(name: Wrap("Person")))));
        Assert.IsNull(schema["doc"]);
    }

    [TestMethod]
    public void ASubscriptKeepsItsSliceBounds()
    {
        // `lower`/`upper`/`step` are `Option<NodeRef<Expr>>` and are all `null`
        // for a plain `a[0]`. Dropping them would leave a document whose keys
        // do not match the struct.
        var plain = Parse(AstWriter.WriteJson(AstWriter.ToWire(Subscript.Of(index: Ast.Expr(NumberLit.Of(0L))))));
        CollectionAssert.AreEqual(
            new[] { "ctx", "has_question", "index", "lower", "step", "type", "upper", "value" },
            plain.AsObject().Select(p => p.Key).OrderBy(k => k, StringComparer.Ordinal).ToList());
        Assert.IsNull(plain["lower"]);

        var slice = Parse(AstWriter.WriteJson(AstWriter.ToWire(Subscript.Of(
            lower: Ast.Expr(NumberLit.Of(0L)), upper: Ast.Expr(NumberLit.Of(2L))))));
        Assert.AreEqual(0L, slice["lower"]!["node"]!["value"]!["value"]!.GetValue<long>());
        Assert.IsNull(slice["step"]);
    }

    [TestMethod]
    public void APresentWrapperWithNoValueIsDistinctFromAnAbsentOne()
    {
        // `NodeRef<T>` is optional at two levels and they are not the same
        // thing: a null wrapper is the field itself being `null`, while a
        // present wrapper holding nothing is `{"node": null, …}` and keeps its
        // position keys. Rust's `Node<T>.node` is not an `Option`, so serde
        // writes the key rather than dropping it.
        var absent = Parse(AstWriter.WriteJson(AstWriter.ToWire((NodeRef<Identifier>)null!)));
        Assert.IsNull(absent);

        var present = Parse(AstWriter.WriteJson(AstWriter.ToWire(
            NodeRef<Identifier>.Empty(Pos.Default))));
        var keys = present.AsObject().Select(p => p.Key).OrderBy(k => k, StringComparer.Ordinal).ToList();
        CollectionAssert.AreEqual(
            new[] { "column", "end_column", "end_line", "filename", "line", "node" }, keys);
        Assert.IsNull(present["node"]);
    }

    [TestMethod]
    public void NodePositionsAreFlattenedOntoTheWrapperNotNestedUnderPos()
    {
        var written = Parse(AstWriter.WriteJson(AstWriter.ToWire(Wrap(Comment.Of("# x"), At(3, 2, 5)))));
        CollectionAssert.AreEqual(
            new[] { "column", "end_column", "end_line", "filename", "line", "node" },
            written.AsObject().Select(p => p.Key).OrderBy(k => k, StringComparer.Ordinal).ToList());
        Assert.AreEqual("testdata/ast/alignment.k", written["filename"]!.GetValue<string>());
        Assert.AreEqual(3L, written["line"]!.GetValue<long>());
    }

    [TestMethod]
    public void NodeIdsAreNeverWritten()
    {
        // Rust's `Node<T>` has an `id`, but serde only writes it under
        // `SHOULD_SERIALIZE_ID`, which is off, so `id` never appears on the
        // wire and must not appear here.
        var written = Parse(AstWriter.WriteJson(AstLoader.ParseModule(GoldenJson())));
        Assert.IsFalse(ContainsKey(written, "id"), "an `id` key leaked into the written document");
    }

    [TestMethod]
    public void MemberOrIndexIsTagPlusContent()
    {
        var member = Parse(AstWriter.WriteJson(MemberOrIndex.Member_(Wrap("b", Pos.Default))));
        Assert.AreEqual("Member", member["type"]!.GetValue<string>());
        Assert.AreEqual("b", member["value"]!["node"]!.GetValue<string>());

        var index = Parse(AstWriter.WriteJson(MemberOrIndex.Index_(Ast.Expr(NumberLit.Of(0L), Pos.Default))));
        Assert.AreEqual("Index", index["type"]!.GetValue<string>());
        Assert.AreEqual(0L, index["value"]!["node"]!["value"]!["value"]!.GetValue<long>());
    }

    [TestMethod]
    public void ACommaListIsWrittenAsAListOfOps()
    {
        // `Compare.ops` is a `Vec<CmpOp>` beside the node, not a `NodeRef`, so
        // it is a bare array of strings.
        var written = Parse(AstWriter.WriteJson(Compare.Of(ops: new List<string> { "Gt" })));
        Assert.AreEqual(1, written["ops"]!.AsArray().Count);
        Assert.AreEqual("Gt", written["ops"]![0]!.GetValue<string>());
        // A `CmpOp` is a fieldless enum, not a node: writing it as
        // `{"node":"Gt"}` would put a wrapper key where serde writes a scalar.
        Assert.AreEqual(JsonValueKind.String, written["ops"]![0]!.GetValue<JsonElement>().ValueKind);
    }

    [TestMethod]
    public void AnEmptyVecIsWrittenAsAnArrayAndNotAsNull()
    {
        // A Rust `Vec` is never absent, so an empty one is `[]` where a `Vec`
        // field and `null` where an `Option<Vec<_>>` field — the two sit on
        // adjacent records here, which is exactly where the difference is easy
        // to get backwards.
        var call = Parse(AstWriter.WriteJson(AstWriter.ToWire(CallExpr.Of())));
        Assert.IsNotNull(call["args"]);
        Assert.AreEqual(0, call["args"]!.AsArray().Count);

        var fn = Parse(AstWriter.WriteJson(FunctionType.Of(null)));
        Assert.IsNull(fn["value"]!["params_ty"]);
    }

    [TestMethod]
    public void AnImportSpellsAsnameWithoutASeparator()
    {
        var written = Parse(AstWriter.WriteJson(AstWriter.ToWire(
            ImportStmt.Of(path: Wrap("data.cloud", Pos.Default), rawPath: "data.cloud", name: "cloud", pkgName: "__main__"))));
        CollectionAssert.AreEqual(
            new[] { "asname", "name", "path", "pkg_name", "rawpath", "type" },
            written.AsObject().Select(p => p.Key).OrderBy(k => k, StringComparer.Ordinal).ToList());
        Assert.IsNull(written["asname"]);
    }

    [TestMethod]
    public void ACommentIsWrittenUnderANodeKeyAndABareCommentIsNotAnOption()
    {
        // A module's comments are `Vec<NodeRef<Comment>>`; a comment on its own
        // is a payload, and writing it bare would be a different document.
        var wrapped = Parse(AstWriter.WriteJson(AstWriter.ToWire(Wrap(Comment.Of("# x"), Pos.Default))));
        var bare = Parse(AstWriter.WriteJson(Comment.Of("# x")));
        Assert.IsTrue(wrapped.AsObject().ContainsKey("node"));
        CollectionAssert.AreEqual(new[] { "text" }, bare.AsObject().Select(p => p.Key).ToList());
    }

    // -----------------------------------------------------------------------
    // helpers
    // -----------------------------------------------------------------------

    private static void AssertJsonEqual(JsonNode expected, JsonNode actual)
    {
        Assert.IsTrue(
            JsonNode.DeepEquals(expected, actual),
            $"written document differs from the capture.\n--- expected ---\n{expected.ToJsonString()}\n--- actual ---\n{actual.ToJsonString()}");
    }

    private static bool ContainsKey(JsonNode node, string key)
    {
        if (node is JsonObject obj)
        {
            if (obj.ContainsKey(key)) return true;
            return obj.Any(p => p.Value != null && ContainsKey(p.Value, key));
        }
        if (node is JsonArray arr) return arr.Any(v => v != null && ContainsKey(v, key));
        return false;
    }

    /// <summary>The first object in the capture carrying this `type` tag.</summary>
    private static string FindFirstGolden(string type)
    {
        var golden = Parse(GoldenJson());
        var found = FirstWithType(golden, type);
        Assert.IsNotNull(found, $"the capture carries no `{type}` node");
        return found!.ToJsonString();
    }

    /// <summary>The `type TName = …` statement for one alias in the capture.</summary>
    private static string FindGoldenStatement(string aliasName)
    {
        var body = Parse(GoldenJson())["body"]!.AsArray();
        foreach (var stmt in body)
        {
            var node = stmt?["node"];
            if (node?["type"]?.GetValue<string>() != "TypeAlias") continue;
            var name = node["type_name"]!["node"]!["names"]![0]!["node"]!.GetValue<string>();
            if (name == aliasName) return stmt!.ToJsonString();
        }
        Assert.Fail($"the capture carries no `type {aliasName} = …` statement");
        return "";
    }

    private static JsonNode? FirstWithType(JsonNode node, string type)
    {
        if (node is JsonObject obj)
        {
            if (obj["type"]?.GetValue<string>() == type) return obj.DeepClone();
            foreach (var v in obj.Select(p => p.Value))
            {
                if (v == null) continue;
                var hit = FirstWithType(v, type);
                if (hit != null) return hit;
            }
        }
        else if (node is JsonArray arr)
        {
            foreach (var v in arr)
            {
                var hit = FirstWithType(v!, type);
                if (hit != null) return hit;
            }
        }
        return null;
    }

    private static string FindCsprojInParentDirectory(string currentDir)
    {
        while (currentDir != null)
        {
            var candidate = Path.Combine(currentDir, "KclLib.Tests.csproj");
            if (File.Exists(candidate)) return currentDir;
            currentDir = Path.GetDirectoryName(currentDir);
        }
        throw new FileNotFoundException("Could not find KclLib.Tests.csproj in parent directories");
    }
}
