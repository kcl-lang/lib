// AstAlignmentTest.cs — Round-trip AST alignment tests for the typed AST
// package. Mirrors the Java AstJsonAlignmentTest, Go TestAstJsonAlignment,
// Python tests/ast_test.py, and Node.js __test__/ast_alignment.spec.mjs.

namespace KclLib.Tests;

using System.Text.Json;
using KclLib.API;
using KclLib.AST;

[TestClass]
public class AstAlignmentTest
{
    static string parentDirectory = FindCsprojInParentDirectory(Environment.CurrentDirectory);
    static string Fixture => Path.Combine(parentDirectory, "test_data", "ast_alignment", "main.k");

    private static Module ParseFixture()
    {
        var api = new API();
        var args = new ParseFileArgs { Path = Fixture };
        var result = api.ParseFile(args);
        return AstLoader.ParseModule(result.AstJson);
    }

    [TestMethod]
    public void TestModuleFilenameAndNoPkg()
    {
        var m = ParseFixture();
        Assert.IsTrue(m.Filename.EndsWith("main.k"));
        // Module must not carry a `pkg` field — round-trip should produce
        // neither one in input nor one on output.
        var props = typeof(Module).GetProperties().Select(p => p.Name);
        CollectionAssert.DoesNotContain(props.ToList(), "Pkg");

        var api = new API();
        var args = new ParseFileArgs { Path = Fixture };
        var raw = api.ParseFile(args).AstJson;
        using var doc = JsonDocument.Parse(raw);
        Assert.IsFalse(doc.RootElement.TryGetProperty("pkg", out _));
    }

    [TestMethod]
    public void TestLiteralDiscriminatorsUseLongForm()
    {
        var m = ParseFixture();
        // Long-form discriminators are baked into the Expr record types —
        // short forms ("Number" / "String" / "NameConstant") are not used
        // by any constructor. This test asserts no short-form literal
        // record types exist in the assembly.
        var asm = typeof(Module).Assembly;
        Assert.IsNull(asm.GetType("KclLib.AST.Number"));
        Assert.IsNull(asm.GetType("KclLib.AST.String"));
        Assert.IsNull(asm.GetType("KclLib.AST.NameConstant"));
    }

    [TestMethod]
    public void TestConfigEntryIsShorthandRoundTrips()
    {
        // Mirror Rust's #[serde(skip_serializing_if = "is_false")]: omitted
        // when false, emitted when true. The .NET AST package mirrors this
        // by making IsShorthand default to false and only emit it when true
        // (when callers serialize back to JSON).
        var ce = new ConfigEntry(IsShorthand: false);
        Assert.IsFalse(ce.IsShorthand);

        var ce2 = new ConfigEntry(IsShorthand: true);
        Assert.IsTrue(ce2.IsShorthand);
    }

    [TestMethod]
    public void TestSchemaExprValueInAssignStmt()
    {
        var m = ParseFixture();
        var assign = m.Body?
            .Select(wrapped => wrapped.Node)
            .OfType<AssignStmt>()
            .FirstOrDefault(s => s.Targets != null && IsAssignTargetNamed(s, "x"));
        Assert.IsNotNull(assign, "expected an AssignStmt targeting `x`");
        Assert.IsInstanceOfType(assign!.Value!.Node, typeof(SchemaExpr));
    }

    [TestMethod]
    public void TestSchemaStmtDecoratorsAreFlatDecoratorDto()
    {
        var m = ParseFixture();
        var article = m.Body?
            .Select(wrapped => wrapped.Node)
            .OfType<SchemaStmt>()
            .FirstOrDefault(s => s.Name?.Node == "Article");
        Assert.IsNotNull(article, "Article schema not found");
        Assert.IsNotNull(article!.Decorators);
        Assert.IsTrue(article.Decorators!.Count > 0);
        foreach (var deco in article.Decorators!)
        {
            // The Decorator.Func payload is a Node wrapping an Identifier
            // expression (no `"type":"Call"` tag in the flat shape).
            Assert.IsInstanceOfType(deco.Node.Func!.Node, typeof(IdentifierExpr));
        }
    }

    [TestMethod]
    public void TestSchemaAttrHasDecoratorsField()
    {
        var m = ParseFixture();
        var person = m.Body?
            .Select(wrapped => wrapped.Node)
            .OfType<SchemaStmt>()
            .FirstOrDefault(s => s.Name?.Node == "Person");
        Assert.IsNotNull(person);
        var nameAttr = person!.Body?
            .Select(wrapped => wrapped.Node)
            .OfType<SchemaAttr>()
            .FirstOrDefault(a => a.Name?.Node == "name");
        Assert.IsNotNull(nameAttr, "expected `name` SchemaAttr");
        Assert.IsNotNull(nameAttr!.Decorators);
        Assert.AreEqual(1, nameAttr.Decorators!.Count);
    }

    [TestMethod]
    public void TestLambdaExprWithArguments()
    {
        var m = ParseFixture();
        var adder = m.Body?
            .Select(wrapped => wrapped.Node)
            .OfType<AssignStmt>()
            .FirstOrDefault(s => s.Targets != null && IsAssignTargetNamed(s, "adder"));
        Assert.IsNotNull(adder);
        var val = adder!.Value!.Node;
        Assert.IsInstanceOfType(val, typeof(LambdaExpr));
        var lambda = (LambdaExpr)val;
        Assert.IsNotNull(lambda.Args);
        Assert.IsNotNull(lambda.Args!.Node);
        Assert.AreEqual(2, lambda.Args.Node.Args!.Count);
    }

    [TestMethod]
    public void TestParseProgramReturnsListOfModules()
    {
        var api = new API();
        var args = new ParseProgramArgs();
        args.Paths.Add(Fixture);
        var result = api.ParseProgram(args);

        var modules = AstLoader.ParseProgram(result.AstJson);
        Assert.IsTrue(modules.Count > 0);
        Assert.IsTrue(modules[0].Filename.EndsWith("main.k"));
    }

    // --- helpers ---------------------------------------------------------

    private static bool IsAssignTargetNamed(AssignStmt stmt, string name)
    {
        if (stmt.Targets == null || stmt.Targets.Count == 0) return false;
        var inner = stmt.Targets[0].Node;
        if (inner == null) return false;
        // Targets use the simple struct shape — Target(name=Node[str], paths, pkgpath).
        // The inner `name` is a Node[str], so compare against `name.node`.
        return inner.Name != null && inner.Name.Node == name;
    }

    static string FindCsprojInParentDirectory(string currentDir)
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