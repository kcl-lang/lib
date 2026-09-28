//! AstJsonAlignmentTest — Zig counterpart of the Java `AstJsonAlignmentTest`,
//! Go `TestAstJsonAlignment_ParseFile`, Python `tests/ast_test.py`, Swift
//! `AstJsonAlignmentTest`, etc.
//!
//! Parses the shared fixture (`test_data/ast_alignment/main.k`, copied from
//! `c/test_data/ast_alignment/`) through the native runtime via
//! `KclService.ParseProgram`, deserializes the emitted `ast_json` into the
//! typed AST, serializes it back, and compares both documents as
//! `std.json.Value` trees (field order and formatting differences do not
//! affect the comparison).

const std = @import("std");
const testing = std.testing;
const root = @import("root.zig");
const ast = @import("ast.zig");
const test_options = @import("test_options");

const Value = std.json.Value;

/// Order-insensitive, type-strict deep equality for `std.json.Value` trees.
fn jsonEqual(a: Value, b: Value) bool {
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
                if (!jsonEqual(x, y)) return false;
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
                if (!jsonEqual(entry.value_ptr.*, other)) return false;
            }
            return true;
        },
    }
}

fn parseFixtureModule(a: std.mem.Allocator) !*ast.Module {
    const program = try ast.parseProgram(a, try parseProgramAstJson(a));
    try testing.expect(program.modules.items.len > 0);
    return program.modules.items[0];
}

fn parseProgramAstJson(a: std.mem.Allocator) ![]u8 {
    var paths: std.ArrayList([]const u8) = .empty;
    try paths.append(a, test_options.ast_alignment_fixture);
    var result = try root.parseProgram(a, .{ .paths = paths });
    defer result.deinit(a);
    try testing.expectEqual(@as(usize, 0), result.errors.items.len);
    return a.dupe(u8, result.ast_json);
}

test "AST alignment: typed round-trip matches the runtime ast_json" {
    const allocator = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const ast_json = try parseProgramAstJson(a);
    var original = try std.json.parseFromSlice(Value, a, ast_json, .{});
    defer original.deinit();

    const program = try ast.parseProgram(a, ast_json);
    try testing.expectEqual(@as(usize, 1), program.modules.items.len);

    const round_tripped_value = try ast.Program.dump(a, program);
    var out: std.Io.Writer.Allocating = .init(a);
    try std.json.Stringify.value(round_tripped_value, .{}, &out.writer);
    var round_tripped = try std.json.parseFromSlice(Value, a, out.written(), .{});
    defer round_tripped.deinit();

    if (!jsonEqual(original.value, round_tripped.value)) {
        std.debug.print("round-trip mismatch:\noriginal: {s}\nround-trip: {s}\n", .{
            ast_json,
            out.written(),
        });
        try testing.expect(false);
    }
}

test "AST alignment: module has no pkg field and keeps filename" {
    const allocator = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const module = try parseFixtureModule(a);
    try testing.expect(std.mem.endsWith(u8, module.filename, "main.k"));

    const dumped = try ast.Module.dump(a, module);
    try testing.expect(ast.getField(dumped, "pkg") == null);
}

test "AST alignment: literal discriminators use the long form" {
    const allocator = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const module = try parseFixtureModule(a);
    var found_string_lit = false;
    for (module.body.items) |stmt_ref| {
        switch (stmt_ref.node) {
            .schema => |s| {
                for (s.body.items) |attr_ref| {
                    switch (attr_ref.node) {
                        .schema_attr => |attr| {
                            if (attr.value) |v| {
                                switch (v.node) {
                                    .string_lit => |lit| {
                                        found_string_lit = true;
                                        try testing.expect(!lit.is_long_string);
                                    },
                                    else => {},
                                }
                            }
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }
    }
    try testing.expect(found_string_lit);
}

test "AST alignment: schema decorators are flat DTOs with tagged func" {
    const allocator = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const module = try parseFixtureModule(a);
    var article: ?*const ast.SchemaStmt = null;
    var person: ?*const ast.SchemaStmt = null;
    for (module.body.items) |stmt_ref| {
        switch (stmt_ref.node) {
            .schema => |*s| {
                const name = if (s.name) |n| n.node else "";
                if (std.mem.eql(u8, name, "Article")) article = s;
                if (std.mem.eql(u8, name, "Person")) person = s;
            },
            else => {},
        }
    }

    // @deprecated on `schema Article(HasTimestamp)` — flat Decorator payload
    // whose func is a fully tagged Identifier expr.
    try testing.expect(article != null);
    try testing.expect(article.?.decorators.items.len > 0);
    const deco = article.?.decorators.items[0].node;
    try testing.expect(deco.func != null);
    switch (deco.func.?.node) {
        .identifier => |id| {
            try testing.expectEqualStrings("deprecated", id.names.items[0].node);
        },
        else => try testing.expect(false),
    }

    // `schema Article(HasTimestamp)` carries its parent as a flat identifier.
    try testing.expect(person != null);
    try testing.expect(person.?.parent_name == null);
    try testing.expect(article.?.parent_name != null);
    try testing.expectEqualStrings("HasTimestamp", article.?.parent_name.?.node.names.items[0].node);
}

test "AST alignment: schema attr decorators and Person.name value" {
    const allocator = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const module = try parseFixtureModule(a);
    for (module.body.items) |stmt_ref| {
        switch (stmt_ref.node) {
            .schema => |s| {
                const name = if (s.name) |n| n.node else "";
                if (!std.mem.eql(u8, name, "Person")) continue;
                var name_attr: ?ast.SchemaAttr = null;
                for (s.body.items) |attr_ref| {
                    switch (attr_ref.node) {
                        .schema_attr => |attr| {
                            const attr_name = if (attr.name) |n| n.node else "";
                            if (std.mem.eql(u8, attr_name, "name")) name_attr = attr;
                        },
                        else => {},
                    }
                }
                try testing.expect(name_attr != null);
                try testing.expectEqual(@as(usize, 1), name_attr.?.decorators.items.len);
                try testing.expectEqualStrings("anonymous", name_attr.?.value.?.node.string_lit.value);
            },
            else => {},
        }
    }
}

test "AST alignment: lambda has typed arguments and return type" {
    const allocator = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const module = try parseFixtureModule(a);
    for (module.body.items) |stmt_ref| {
        switch (stmt_ref.node) {
            .assign => |assign| {
                const target_name = assign.targets.items[0].node.name.?.node;
                if (!std.mem.eql(u8, target_name, "adder")) continue;
                switch (assign.value.?.node) {
                    .lambda => |lambda| {
                        const arguments = lambda.args.?.node;
                        try testing.expectEqual(@as(usize, 2), arguments.args.items.len);
                        try testing.expectEqualStrings("x", arguments.args.items[0].node.names.items[0].node);
                        try testing.expectEqualStrings("y", arguments.args.items[1].node.names.items[0].node);
                        // Both parameters are annotated `int`.
                        try testing.expectEqual(@as(usize, 2), arguments.ty_list.items.len);
                        try testing.expectEqualStrings("Int", arguments.ty_list.items[0].node.basic.value);
                        // `-> int` return type.
                        try testing.expectEqualStrings("Int", lambda.return_ty.?.node.basic.value);
                        // defaults align positionally with args (null here).
                        try testing.expectEqual(@as(usize, 2), arguments.defaults.items.len);
                        try testing.expect(arguments.defaults.items[0] == null);
                    },
                    else => try testing.expect(false),
                }
            },
            else => {},
        }
    }
}

test "AST alignment: parseProgram returns the program envelope" {
    const allocator = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const ast_json = try parseProgramAstJson(a);
    const program = try ast.parseProgram(a, ast_json);
    try testing.expect(program.modules.items.len > 0);
    try testing.expect(std.mem.endsWith(u8, program.modules.items[0].filename, ".k"));

    // The serialized envelope keeps the `root` / `pkgs.__main__` shape.
    const dumped = try ast.Program.dump(a, program);
    try testing.expect(ast.getField(dumped, "root") != null);
    const pkgs = ast.getField(dumped, "pkgs").?;
    try testing.expect(ast.getField(pkgs, "__main__") != null);
}

test "AST alignment: schema check is a CheckExpr with quantified if_cond" {
    const allocator = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const module = try parseFixtureModule(a);
    for (module.body.items) |stmt_ref| {
        switch (stmt_ref.node) {
            .schema => |s| {
                const name = if (s.name) |n| n.node else "";
                if (!std.mem.eql(u8, name, "Person")) continue;
                try testing.expectEqual(@as(usize, 1), s.checks.items.len);
                const check = s.checks.items[0].node;
                try testing.expect(check.if_cond != null);
                try testing.expect(check.msg != null);
                try testing.expectEqualStrings("age must be non-negative", check.msg.?.node.string_lit.value);
                // `age >= 0` compares `age` against an integer literal.
                const test_expr = check.test_.?;
                switch (test_expr.node) {
                    .compare => |cmp| {
                        try testing.expectEqual(@as(usize, 1), cmp.ops.items.len);
                        try testing.expectEqualStrings("GtE", cmp.ops.items[0]);
                        try testing.expectEqual(@as(i64, 0), cmp.comparators.items[0].node.number_lit.intValue().?);
                    },
                    else => try testing.expect(false),
                }
            },
            else => {},
        }
    }
}
