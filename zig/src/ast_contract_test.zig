//! ast_contract_test.zig — the AST wire contract, asserted.
//!
//! The typed AST in `src/ast/` is a hand-written decoder for the JSON the KCL
//! parser emits, and a wrong guess about that JSON fails *silently*: an object
//! with no `type` key falls through to `Expr.unknown`, so a binding that keys
//! the registry on `"CheckExpression"` (the spelling `Expr::type_name_long`
//! returns, which is a diagnostic name and not the serde tag) still returns a
//! plausible-looking tree full of unknowns.
//!
//! These tests decode `testdata/ast/alignment.json` — the real parser's output
//! for `testdata/ast/alignment.k`, which exercises every node shape — and
//! assert the contract documented in that directory's README. Decoding the
//! captured JSON rather than calling `ParseProgram` keeps this a pure test of
//! the decoder: it needs no native runtime, and it does not depend on the
//! parser staying byte-identical.

const std = @import("std");
const testing = std.testing;
const ast = @import("ast.zig");
const base = @import("ast/base.zig");
const expr = @import("ast/expr.zig");
const test_options = @import("test_options");

/// The only failure mode of the unknown-variant walk. Named explicitly so
/// the two mutually recursive helpers do not form an inferred-error-set cycle.
const ContractError = error{UnknownExprVariant, LambdaBodyIsNotAStatement};

/// Decode the captured parser output once; every test reads the same tree.
fn goldenModule(a: std.mem.Allocator) !*ast.Module {
    // `ast_contract_golden` is absolute (resolved by build.zig), and
    // `Dir.readFileAlloc` takes a path relative to its own directory, so split
    // the two rather than reaching for the whole thing as one sub-path.
    const path = test_options.ast_contract_golden;
    var dir = try std.Io.Dir.openDirAbsolute(
        testing.io,
        std.fs.path.dirname(path) orelse ".",
        .{},
    );
    defer dir.close(testing.io);
    const source = try dir.readFileAlloc(
        testing.io,
        std.fs.path.basename(path),
        a,
        .limited(1 << 30),
    );
    return ast.parseModule(a, source);
}

/// The top-level statement list of the golden module.
fn goldenStmts(module: *ast.Module) []const *ast.StmtNode {
    const out = module.body.items;
    return out[0..];
}

/// The top-level statement whose assignment target is `name`.
///
/// Switch captures copy the payload, so the helpers hand back values rather
/// than pointers into the tree.
fn assigned(stmts: []const *ast.StmtNode, name: []const u8) !ast.AssignStmt {
    for (stmts) |ref| {
        switch (ref.node) {
            .assign => |a| {
                const first = a.targets.items[0];
                const target_name = first.node.name orelse continue;
                if (std.mem.eql(u8, target_name.node, name)) return a;
            },
            else => {},
        }
    }
    return error.StatementNotFound;
}

/// The top-level schema named `name`.
fn findSchema(stmts: []const *ast.StmtNode, name: []const u8) !ast.SchemaStmt {
    for (stmts) |ref| {
        switch (ref.node) {
            .schema => |s| {
                const n = s.name orelse continue;
                if (std.mem.eql(u8, n.node, name)) return s;
            },
            else => {},
        }
    }
    return error.StatementNotFound;
}

/// The top-level type alias named `name`.
fn findTypeAlias(stmts: []const *ast.StmtNode, name: []const u8) !ast.TypeAliasStmt {
    for (stmts) |ref| {
        switch (ref.node) {
            .type_alias => |t| {
                const n = t.type_name orelse continue;
                const first = n.node.names.items[0];
                if (std.mem.eql(u8, first.node, name)) return t;
            },
            else => {},
        }
    }
    return error.StatementNotFound;
}

test "coverage: decodes every Stmt variant" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const stmts = goldenStmts(try goldenModule(a));

    // TypeAlias, Unification, Assign, AugAssign, Assert, If, Import, Rule
    var seen_type_alias = false;
    var seen_unification = false;
    var seen_assign = false;
    var seen_aug_assign = false;
    var seen_assert = false;
    var seen_if = false;
    var seen_import = false;
    var seen_rule = false;
    var seen_schema = false;
    var seen_schema_attr = false;
    var seen_expr = false;
    for (stmts) |ref| {
        switch (ref.node) {
            .type_alias => seen_type_alias = true,
            .unification => seen_unification = true,
            .assign => seen_assign = true,
            .aug_assign => seen_aug_assign = true,
            .assert_stmt => seen_assert = true,
            .@"if" => seen_if = true,
            .import => seen_import = true,
            .rule => seen_rule = true,
            .schema => |s| {
                seen_schema = true;
                for (s.body.items) |b| {
                    if (b.node == .schema_attr) seen_schema_attr = true;
                }
            },
            .expr => seen_expr = true,
            .schema_attr => {}, // only ever nested inside a schema body
            .unknown => return error.UnknownTopLevelStmt,
        }
    }
    try testing.expect(seen_type_alias);
    try testing.expect(seen_unification);
    try testing.expect(seen_assign);
    try testing.expect(seen_aug_assign);
    try testing.expect(seen_assert);
    try testing.expect(seen_if);
    try testing.expect(seen_import);
    try testing.expect(seen_rule);
    try testing.expect(seen_schema);
    try testing.expect(seen_schema_attr);
    try testing.expect(seen_expr);

    // Nothing may have fallen through to `unknown` anywhere in the tree.
    try expectNoUnknownExpr((try assigned(stmts, "paren")).value.?.node);
}

test "the three serde shapes: a Type is tagged with its shape, not its type" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    // The trap: keying a registry on `"Int"` / `"Str"` silently yields no type
    // at all, because `BasicType` is a fieldless enum with no struct wrapper —
    // the value lands directly in `value`.
    const basic = (try findTypeAlias(stmts, "TBasic")).ty.?.node;
    try testing.expect(basic == .basic);
    try testing.expectEqualStrings("Str", basic.basic.value);

    const any = (try findTypeAlias(stmts, "TAny")).ty.?.node;
    try testing.expect(any == .any);
}

test "the three serde shapes: Type payloads nest under `value`" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    const list = (try findTypeAlias(stmts, "TList")).ty.?.node;
    try testing.expect(list == .list);
    try testing.expectEqualStrings("Int", list.list.inner_type.?.node.basic.value);

    const dict = (try findTypeAlias(stmts, "TDict")).ty.?.node;
    try testing.expect(dict == .dict);
    try testing.expectEqualStrings("Str", dict.dict.key_type.?.node.basic.value);
    try testing.expectEqualStrings("Int", dict.dict.value_type.?.node.basic.value);

    // `UnionType.type_elements`, not `types`.
    const union_ty = (try findTypeAlias(stmts, "TUnion")).ty.?.node;
    try testing.expect(union_ty == .union_);
    try testing.expectEqual(@as(usize, 2), union_ty.union_.type_elements.items.len);
    try testing.expectEqualStrings("Int", union_ty.union_.type_elements.items[0].node.basic.value);
    try testing.expectEqualStrings("Str", union_ty.union_.type_elements.items[1].node.basic.value);

    const func = (try findTypeAlias(stmts, "TFunc")).ty.?.node;
    try testing.expect(func == .function);
    try testing.expectEqual(@as(usize, 2), func.function.params_ty.items.len);
    try testing.expectEqualStrings("Int", func.function.params_ty.items[0].node.basic.value);
    try testing.expectEqualStrings("Str", func.function.params_ty.items[1].node.basic.value);
    try testing.expectEqualStrings("Bool", func.function.ret_ty.?.node.basic.value);

    // `Type::Named(Identifier)` is a newtype over a newtype, so the identifier
    // sits directly in `value` with no wrapper key.
    const named = (try findTypeAlias(stmts, "TNamed")).ty.?.node;
    try testing.expect(named == .named);
    try testing.expectEqualStrings("Cloud", named.named.value.names.items[0].node);
}

test "the three serde shapes: LiteralType is itself tagged, so doubly nested" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    const lit = (try findTypeAlias(stmts, "TLitInt")).ty.?.node;
    try testing.expect(lit == .literal);
    // `LiteralType` is itself `tag = "type", content = "value"`, so the
    // `Type::Literal` payload is a *second* tagged document. This binding keeps
    // it verbatim rather than modelling a variant per literal kind.
    const inner = lit.literal.value;
    try testing.expectEqualStrings("Int", base.getString(inner, "type").?);
    const payload = base.getField(inner, "value").?;
    try testing.expectEqual(@as(i64, 1), base.getInteger(payload, "value").?);
    // `suffix: Option<NumberBinarySuffix>` serializes as an explicit null.
    try testing.expect(base.getField(payload, "suffix") == null or base.getField(payload, "suffix").? == .null);
}

test "newtype variants are flattened, not wrapped" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    // `Expr::Identifier(Identifier)` is `{"type":"Identifier","names":[...]}` —
    // there is no `identifier` wrapper key. Reading through one yields an empty
    // identifier, silently.
    const paren = (try assigned(stmts, "paren")).value.?.node;
    try testing.expect(paren == .paren);
    const inner = paren.paren.expr.?.node;
    try testing.expect(inner == .identifier);
    try testing.expectEqualStrings("a", inner.identifier.names.items[0].node);

    // Same for `Expr::Target(Target)`, `Expr::Check`, `Expr::Keyword` and
    // `Expr::Arguments`.
    const target = (try assigned(stmts, "a")).targets.items[0].node;
    try testing.expectEqualStrings("a", target.name.?.node);

    const quant = (try assigned(stmts, "quant")).value.?.node;
    try testing.expect(quant == .quant);
    // `Quant.variables` is `Vec<NodeRef<Identifier>>`, not a vector of Exprs.
    const variable = quant.quant.variables.items[0].node;
    try testing.expectEqualStrings("v", variable.names.items[0].node);

    const call = (try assigned(stmts, "call")).value.?.node;
    try testing.expect(call == .call);
    // `CallExpr.keywords` is `Vec<NodeRef<Keyword>>`, so `arg` wraps the flat
    // (untagged) identifier.
    const keyword = call.call.keywords.items[0].node;
    try testing.expectEqualStrings("k", keyword.arg.?.node.names.items[0].node);
}

test "per-statement field names: ImportStmt is flat" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    var first: ?ast.ImportStmt = null;
    var second: ?ast.ImportStmt = null;
    var n: usize = 0;
    for (stmts) |ref| {
        switch (ref.node) {
            .import => |imp| {
                n += 1;
                if (n == 1) first = imp else second = imp;
            },
            else => {},
        }
    }
    const one = first.?;
    const two = second.?;
    // `path` is a `Node<String>`; `rawpath`, `name` and `pkg_name` are plain
    // strings sitting next to it. There is no `node` wrapper object and no
    // `as_name` / `pkg_root` field.
    try testing.expectEqualStrings("data.cloud", one.path.?.node);
    try testing.expectEqualStrings("data.cloud", one.rawpath);
    try testing.expectEqualStrings("cloud", one.name);
    try testing.expectEqualStrings("__main__", one.pkg_name);
    try testing.expect(one.asname == null);
    try testing.expectEqualStrings("fb", two.asname.?.node);
}

test "per-statement field names: AugAssign has a singular target, Assign a plural one" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    var aug: ?ast.AugAssignStmt = null;
    for (stmts) |ref| {
        switch (ref.node) {
            .aug_assign => |x| aug = x,
            else => {},
        }
    }
    const x = aug.?;
    try testing.expectEqualStrings("a", x.target.?.node.name.?.node);
    try testing.expectEqualStrings("Add", x.op);
    try testing.expect(x.value.?.node == .number_lit);
    try testing.expectEqual(@as(i64, 2), x.value.?.node.number_lit.intValue().?);

    try testing.expect((try assigned(stmts, "a")).targets.items.len >= 1);
}

test "per-statement field names: UnificationStmt.value is an untagged SchemaExpr" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    var uni: ?ast.UnificationStmt = null;
    for (stmts) |ref| {
        switch (ref.node) {
            .unification => |u| uni = u,
            else => {},
        }
    }
    const u = uni.?;
    try testing.expectEqualStrings("u", u.target.?.node.names.items[0].node);
    // `SchemaExpr` is a plain struct, so it arrives with no `"type":"Schema"`
    // tag here and has to be decoded by its own loader. Routing it through the
    // `Expr` registry would fail the tag lookup and yield nothing.
    const value = u.value.?.node;
    try testing.expectEqualStrings("Person", value.name.?.node.names.items[0].node);
}

test "per-statement field names: Assert reads test / if_cond / msg" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    var asserts: std.ArrayList(ast.AssertStmt) = .empty;
    for (stmts) |ref| {
        switch (ref.node) {
            .assert_stmt => |x| try asserts.append(a, x),
            else => {},
        }
    }
    try testing.expectEqual(@as(usize, 2), asserts.items.len);
    try testing.expect(asserts.items[0].test_.?.node == .compare);
    try testing.expect(asserts.items[0].if_cond == null);
    try testing.expect(asserts.items[1].if_cond.?.node == .identifier);
    const msg = asserts.items[1].msg.?.node;
    try testing.expectEqualStrings("a must be positive", msg.string_lit.value);
}

test "per-statement field names: IfStmt branches are lists of statements" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    var stmt: ?ast.IfStmt = null;
    for (stmts) |ref| {
        switch (ref.node) {
            .@"if" => |x| stmt = x,
            else => {},
        }
    }
    const s = stmt.?;
    try testing.expect(s.body.items[0].node == .assign);
    try testing.expect(s.orelse_.items[0].node == .assign);
}

test "per-statement field names: Selector.attr and Quant.variables are Identifiers" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    // `x.name.deep` is a single dotted Identifier; a Selector only appears once
    // a subscript or a `?` breaks the chain.
    const sel = (try assigned(stmts, "selector")).value.?.node;
    try testing.expect(sel == .selector);
    try testing.expect(sel.selector.value.?.node == .subscript);
    try testing.expectEqualStrings("name", sel.selector.attr.?.node.names.items[0].node);
    try testing.expectEqual(false, sel.selector.has_question);

    const optional = (try assigned(stmts, "optional")).value.?.node;
    try testing.expectEqual(true, optional.selector.has_question);
}

test "per-statement field names: Subscript carries lower / upper / step" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    const plain = (try assigned(stmts, "subscript")).value.?.node;
    try testing.expect(plain.subscript.index != null);
    try testing.expect(plain.subscript.lower == null);

    const slice = (try assigned(stmts, "subscript_slice")).value.?.node;
    try testing.expect(slice.subscript.index == null);
    try testing.expectEqual(@as(i64, 0), slice.subscript.lower.?.node.number_lit.intValue().?);
    try testing.expectEqual(@as(i64, 2), slice.subscript.upper.?.node.number_lit.intValue().?);

    const stepped = (try assigned(stmts, "subscript_step")).value.?.node;
    try testing.expect(stepped.subscript.step != null);
}

test "per-statement field names: a Lambda body is statements, its args are Identifiers" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    const lam = (try assigned(stmts, "lambda_expr")).value.?.node;
    try testing.expect(lam == .lambda);
    const args = lam.lambda.args.?.node;
    try testing.expectEqual(@as(usize, 1), args.args.items.len);
    try testing.expectEqualStrings("p", args.args.items[0].node.names.items[0].node);
    try testing.expectEqualStrings("Int", lam.lambda.return_ty.?.node.basic.value);
    // A lambda body is `Vec<NodeRef<Stmt>>`, not a vector of expressions.
    try testing.expect(lam.lambda.body.items[0].node == .expr);
}

test "per-statement field names: comprehension generators are untagged CompClauses" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    const lc = (try assigned(stmts, "list_if")).value.?.node;
    try testing.expect(lc == .list_comp);
    const gen = lc.list_comp.generators.items[0].node;
    try testing.expectEqualStrings("i", gen.targets.items[0].node.names.items[0].node);
    try testing.expect(gen.iter.?.node == .identifier);
    try testing.expect(gen.ifs.items[0].node == .compare);

    const dc = (try assigned(stmts, "dict_comp")).value.?.node;
    try testing.expect(dc == .dict_comp);
    // A DictComp has exactly one `entry: ConfigEntry` — not
    // key/value/entry_key.
    try testing.expect(dc.dict_comp.entry.key.?.node == .identifier);
    try testing.expectEqualStrings("Union", dc.dict_comp.entry.operation);
}

test "flat DTOs: SchemaStmt.checks are untagged Checks, not tagged Exprs" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    const person = try findSchema(stmts, "Person");
    try testing.expect(person.checks.items.len >= 2);
    const first = person.checks.items[0].node;
    try testing.expect(first.test_.?.node == .compare);
    try testing.expect(first.if_cond == null);
    const second = person.checks.items[1].node;
    try testing.expect(second.if_cond.?.node == .identifier);
    try testing.expectEqualStrings("age must be a sane number", second.msg.?.node.string_lit.value);
}

test "flat DTOs: a decorator is a CallExpr, not a bespoke Decorator DTO" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    const person = try findSchema(stmts, "Person");
    var name_attr: ?ast.SchemaAttr = null;
    for (person.body.items) |b| {
        switch (b.node) {
            .schema_attr => |attr| {
                const n = attr.name orelse continue;
                if (std.mem.eql(u8, n.node, "name")) name_attr = attr;
            },
            else => {},
        }
    }
    const attr = name_attr.?;
    try testing.expectEqual(@as(usize, 2), attr.decorators.items.len);
    // `func` wraps an Identifier expression, and the element itself carries no
    // `"type":"Call"` key, because only the `Expr` enum is tagged.
    try testing.expect(attr.decorators.items[0].node.func.?.node == .identifier);
    try testing.expectEqualStrings("deprecated", attr.decorators.items[0].node.func.?.node.identifier.names.items[0].node);
    const kw = attr.decorators.items[1].node.keywords.items[0].node;
    try testing.expectEqualStrings("kwargs", kw.arg.?.node.names.items[0].node);
}

test "flat DTOs: SchemaIndexSignature reads off the schema body" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    const sig = (try findSchema(stmts, "Bag")).index_signature.?.node;
    try testing.expectEqualStrings("k", sig.key_name.?.node);
    try testing.expectEqualStrings("Str", sig.key_ty.?.node.basic.value);
    try testing.expectEqualStrings("Int", sig.value_ty.?.node.basic.value);
    try testing.expectEqual(false, sig.any_other);
    // `value` is the `[k: str]: int = 0` default: an `Option<NodeRef<Expr>>`,
    // not a `NodeRef<Type>`.
    try testing.expect(sig.value.?.node == .number_lit);
    try testing.expectEqual(@as(i64, 0), sig.value.?.node.number_lit.intValue().?);
}

test "flat DTOs: MemberOrIndex is tagged and keeps its value as a NodeRef" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    var paths: ?ast.Target = null;
    for (stmts) |ref| {
        switch (ref.node) {
            .assign => |asg| {
                const t = asg.targets.items[0].node;
                const n = t.name orelse continue;
                if (std.mem.eql(u8, n.node, "x") and t.paths.items.len == 2) paths = t;
            },
            else => {},
        }
    }
    const p = paths.?;
    try testing.expect(p.paths.items[0] == .member);
    try testing.expectEqualStrings("name", p.paths.items[0].member.node);
    try testing.expect(p.paths.items[1] == .member);
    try testing.expectEqualStrings("deep", p.paths.items[1].member.node);
}

test "flat DTOs: ConfigEntry.is_shorthand is omitted on the wire when false" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    // Rust's `#[serde(skip_serializing_if = "is_false")]`, so the key is simply
    // absent — reading it as a missing boolean still has to yield `false`.
    // `{a = 1, b: 2}` mixes the two operations in one config: `=` sets
    // (`Override`) and `:` unions (`Union`).
    const plain = (try assigned(stmts, "config")).value.?.node;
    try testing.expectEqual(@as(usize, 2), plain.config.items.items.len);
    try testing.expectEqual(false, plain.config.items.items[0].node.is_shorthand);
    try testing.expectEqualStrings("Override", plain.config.items.items[0].node.operation);
    try testing.expectEqual(false, plain.config.items.items[1].node.is_shorthand);
    try testing.expectEqualStrings("Union", plain.config.items.items[1].node.operation);

    // `{lit_int, lit_str}` is pure shorthand: every entry overrides, and the
    // key *is* emitted because it is true.
    const shorthand = (try assigned(stmts, "config_shorthand")).value.?.node;
    try testing.expectEqual(true, shorthand.config.items.items[0].node.is_shorthand);
    try testing.expectEqualStrings("Override", shorthand.config.items.items[0].node.operation);
}

test "flat DTOs: Arguments defaults and ty_list stay aligned positionally" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const stmts = goldenStmts(try goldenModule(a));

    const args = (try assigned(stmts, "lambda_expr")).value.?.node.lambda.args.?.node;
    try testing.expectEqual(@as(usize, 1), args.args.items.len);
    // `Vec<Option<...>>` fields: a dropped slot would shift every later
    // annotation one position to the left, so the length must be preserved
    // even where the element is `null`.
    try testing.expectEqual(@as(usize, 1), args.defaults.items.len);
    try testing.expect(args.defaults.items[0] == null);
    try testing.expectEqual(@as(usize, 1), args.ty_list.items.len);
    try testing.expectEqualStrings("Int", args.ty_list.items[0].?.node.basic.value);
}

test "direct loader checks: the wire shape each DTO loader is given" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const identifier = try ast.Identifier.parse(a, try jsonObject(a, &.{
        .{ "names", .{ .array = std.json.Array.init(a) } },
        .{ "pkgpath", .{ .string = "p" } },
        .{ "ctx", .{ .string = "Store" } },
    }));
    try testing.expectEqualStrings("Store", identifier.ctx);

    const target = try ast.Target.parse(a, try jsonObject(a, &.{
        .{ "name", try jsonObject(a, &.{
            .{ "node", .{ .string = "a" } },
        }) },
        .{ "paths", .{ .array = std.json.Array.init(a) } },
        .{ "pkgpath", .{ .string = "" } },
    }));
    try testing.expectEqualStrings("a", target.name.?.node);
    try testing.expectEqual(@as(usize, 0), target.paths.items.len);

    const keyword = try ast.Keyword.parse(a, try jsonObject(a, &.{
        .{ "arg", .null },
        .{ "value", .null },
    }));
    try testing.expect(keyword.arg == null);
    try testing.expect(keyword.value == null);

    const arguments = try ast.Arguments.parse(a, try jsonObject(a, &.{
        .{ "args", .{ .array = std.json.Array.init(a) } },
        .{ "defaults", .{ .array = std.json.Array.init(a) } },
        .{ "ty_list", .{ .array = std.json.Array.init(a) } },
    }));
    try testing.expectEqual(@as(usize, 0), arguments.args.items.len);

    const entry = try ast.ConfigEntry.parse(a, try jsonObject(a, &.{
        .{ "key", .null },
        .{ "value", .null },
        .{ "operation", .{ .string = "Union" } },
    }));
    try testing.expectEqual(false, entry.is_shorthand);
}

test "direct loader checks: an unrecognised tag is kept, not dropped" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // Forward compatibility: a tag this build predates must survive the
    // round trip with its raw payload intact rather than erroring out.
    const future = try expr.parseExprPayload(a, try jsonObject(a, &.{
        .{ "type", .{ .string = "Future" } },
    }));
    try testing.expect(future == .unknown);
    try testing.expectEqualStrings("Future", future.unknown.tag);
}

test "round trip: re-serializing the golden module preserves the wire shape" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const module = try goldenModule(a);
    const out = try ast.Module.dump(a, module);
    // Re-decoding what we just wrote must be a fixed point: no tag lookup
    // fails on the second pass either.
    const again = try ast.Module.parse(a, out);
    const out2 = try ast.Module.dump(a, again);
    try testing.expect(deepEqual(out, out2));
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

/// Walk an expression tree and fail on any `unknown` variant. A wrong registry
/// key is otherwise invisible: the payload decodes to an empty struct and every
/// field assertion above simply returns null.
fn expectNoUnknownExpr(e: ast.Expr) ContractError!void {
    switch (e) {
        .unknown => return error.UnknownExprVariant,
        .paren => |x| try expectOptNoUnknownExpr(x.expr),
        .unary => |x| try expectOptNoUnknownExpr(x.operand),
        .binary => |x| {
            try expectOptNoUnknownExpr(x.left);
            try expectOptNoUnknownExpr(x.right);
        },
        .@"if" => |x| {
            try expectOptNoUnknownExpr(x.body);
            try expectOptNoUnknownExpr(x.cond);
            try expectOptNoUnknownExpr(x.orelse_);
        },
        .selector => |x| try expectOptNoUnknownExpr(x.value),
        .call => |x| {
            try expectOptNoUnknownExpr(x.func);
            for (x.args.items) |n| try expectNoUnknownExpr(n.node);
        },
        .quant => |x| try expectOptNoUnknownExpr(x.target),
        .list => |x| {
            for (x.elts.items) |n| try expectNoUnknownExpr(n.node);
        },
        .list_if_item => |x| {
            try expectOptNoUnknownExpr(x.if_cond);
            for (x.exprs.items) |n| try expectNoUnknownExpr(n.node);
            try expectOptNoUnknownExpr(x.orelse_);
        },
        .list_comp => |x| try expectOptNoUnknownExpr(x.elt),
        .starred => |x| try expectOptNoUnknownExpr(x.value),
        .dict_comp => |x| {
            try expectOptNoUnknownExpr(x.entry.key);
            try expectOptNoUnknownExpr(x.entry.value);
        },
        .config_if_entry => |x| {
            try expectOptNoUnknownExpr(x.if_cond);
            try expectOptNoUnknownExpr(x.orelse_);
        },
        .schema => |x| {
            for (x.args.items) |n| try expectNoUnknownExpr(n.node);
            try expectOptNoUnknownExpr(x.config);
        },
        .config => |x| {
            for (x.items.items) |n| {
                try expectOptNoUnknownExpr(n.node.key);
                try expectOptNoUnknownExpr(n.node.value);
            }
        },
        .lambda => |x| {
            for (x.body.items) |n| {
                switch (n.node) {
                    .expr => |x2| for (x2.exprs.items) |inner| try expectNoUnknownExpr(inner.node),
                    else => return error.LambdaBodyIsNotAStatement,
                }
            }
        },
        .subscript => |x| {
            try expectOptNoUnknownExpr(x.value);
            try expectOptNoUnknownExpr(x.index);
            try expectOptNoUnknownExpr(x.lower);
            try expectOptNoUnknownExpr(x.upper);
            try expectOptNoUnknownExpr(x.step);
        },
        .compare => |x| {
            try expectOptNoUnknownExpr(x.left);
            for (x.comparators.items) |n| try expectNoUnknownExpr(n.node);
        },
        .joined_string => |x| {
            for (x.values.items) |n| try expectNoUnknownExpr(n.node);
        },
        .formatted_value => |x| try expectOptNoUnknownExpr(x.value),
        else => {},
    }
}

fn expectOptNoUnknownExpr(e: ?*ast.ExprNode) ContractError!void {
    if (e) |n| try expectNoUnknownExpr(n.node);
}

fn jsonObject(a: std.mem.Allocator, fields: []const struct { []const u8, std.json.Value }) !std.json.Value {
    var o: std.json.ObjectMap = .empty;
    for (fields) |f| try o.put(a, f[0], f[1]);
    return .{ .object = o };
}

/// Order-insensitive deep equality for `std.json.Value` trees.
fn deepEqual(a: std.json.Value, b: std.json.Value) bool {
    switch (a) {
        .null => return b == .null,
        .bool => |x| return b == .bool and b.bool == x,
        .integer => |x| return b == .integer and b.integer == x,
        .float => |x| return b == .float and b.float == x,
        .number_string => |x| return b == .number_string and std.mem.eql(u8, b.number_string, x),
        .string => |x| return b == .string and std.mem.eql(u8, b.string, x),
        .array => |arr_a| {
            if (b != .array) return false;
            const arr_b = b.array;
            if (arr_a.items.len != arr_b.items.len) return false;
            for (arr_a.items, arr_b.items) |x, y| {
                if (!deepEqual(x, y)) return false;
            }
            return true;
        },
        .object => |obj_a| {
            if (b != .object) return false;
            const obj_b = b.object;
            if (obj_a.count() != obj_b.count()) return false;
            var it = obj_a.iterator();
            while (it.next()) |entry| {
                const other = obj_b.get(entry.key_ptr.*) orelse return false;
                if (!deepEqual(entry.value_ptr.*, other)) return false;
            }
            return true;
        },
    }
}
