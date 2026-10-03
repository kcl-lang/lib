//! Typed AST package for the Zig binding — mirrors `kcl_lib.ast` (Python)
//! and `ast.lua` (Lua).
//!
//! Deserialize the `ast_json` strings returned by `parseFile` /
//! `parseProgram` into a typed node tree (`Module` / `Stmt` / `Expr` /
//! `Type` plus the flat DTOs), navigate it with Zig unions, and serialize it
//! back to wire-shaped JSON for round-trips.
//!
//! ```zig
//! const ast = @import("ast.zig");
//!
//! var arena = std.heap.ArenaAllocator.init(gpa);
//! defer arena.deinit();
//!
//! const result = try kcl.parseFile(arena.allocator(), .{ .path = "main.k" });
//! const module = try ast.parseModule(arena.allocator(), result.ast_json);
//! for (module.body.items) |stmt_ref| {
//!     switch (stmt_ref.node) {
//!         .schema => |s| std.debug.print("schema {s}\n", .{s.name.?.node}),
//!         else => {},
//!     }
//! }
//! ```
//!
//! All nodes are allocated from the supplied allocator; use an arena and free
//! it once when the tree is no longer needed.

const std = @import("std");
const base = @import("ast/base.zig");

pub const Error = base.Error;

pub const Pos = base.Pos;
pub const Node = base.Node;

pub const Module = @import("ast/module.zig").Module;
pub const Program = @import("ast/module.zig").Program;
pub const Comment = @import("ast/module.zig").Comment;

pub const Stmt = @import("ast/stmt.zig").Stmt;
pub const StmtNode = @import("ast/stmt.zig").StmtNode;
pub const ExprStmt = @import("ast/stmt.zig").ExprStmt;
pub const UnificationStmt = @import("ast/stmt.zig").UnificationStmt;
pub const AssignStmt = @import("ast/stmt.zig").AssignStmt;
pub const SchemaStmt = @import("ast/stmt.zig").SchemaStmt;
pub const SchemaAttr = @import("ast/stmt.zig").SchemaAttr;
pub const RuleStmt = @import("ast/stmt.zig").RuleStmt;
pub const ImportStmt = @import("ast/stmt.zig").ImportStmt;
pub const AugAssignStmt = @import("ast/stmt.zig").AugAssignStmt;
pub const IfStmt = @import("ast/stmt.zig").IfStmt;
pub const TypeAliasStmt = @import("ast/stmt.zig").TypeAliasStmt;
pub const AssertStmt = @import("ast/stmt.zig").AssertStmt;

pub const Expr = @import("ast/expr.zig").Expr;
pub const ExprNode = @import("ast/expr.zig").ExprNode;
pub const UnaryExpr = @import("ast/expr.zig").UnaryExpr;
pub const BinaryExpr = @import("ast/expr.zig").BinaryExpr;
pub const IfExpr = @import("ast/expr.zig").IfExpr;
pub const SelectorExpr = @import("ast/expr.zig").SelectorExpr;
pub const CallExpr = @import("ast/expr.zig").CallExpr;
pub const ParenExpr = @import("ast/expr.zig").ParenExpr;
pub const QuantExpr = @import("ast/expr.zig").QuantExpr;
pub const ListExpr = @import("ast/expr.zig").ListExpr;
pub const ListIfItemExpr = @import("ast/expr.zig").ListIfItemExpr;
pub const ListCompExpr = @import("ast/expr.zig").ListCompExpr;
pub const StarredExpr = @import("ast/expr.zig").StarredExpr;
pub const DictCompExpr = @import("ast/expr.zig").DictCompExpr;
pub const ConfigIfEntryExpr = @import("ast/expr.zig").ConfigIfEntryExpr;
pub const SchemaExpr = @import("ast/expr.zig").SchemaExpr;
pub const ConfigExpr = @import("ast/expr.zig").ConfigExpr;
pub const LambdaExpr = @import("ast/expr.zig").LambdaExpr;
pub const SubscriptExpr = @import("ast/expr.zig").SubscriptExpr;
pub const CompareExpr = @import("ast/expr.zig").CompareExpr;
pub const NumberLitExpr = @import("ast/expr.zig").NumberLitExpr;
pub const StringLitExpr = @import("ast/expr.zig").StringLitExpr;
pub const NameConstantLitExpr = @import("ast/expr.zig").NameConstantLitExpr;
pub const JoinedStringExpr = @import("ast/expr.zig").JoinedStringExpr;
pub const FormattedValueExpr = @import("ast/expr.zig").FormattedValueExpr;
pub const MissingExpr = @import("ast/expr.zig").MissingExpr;
pub const CheckExpr = @import("ast/expr.zig").CheckExpr;

pub const Type = @import("ast/types.zig").Type;
pub const TypeNode = @import("ast/types.zig").TypeNode;
pub const BasicType = @import("ast/types.zig").BasicType;
pub const ListType = @import("ast/types.zig").ListType;
pub const DictType = @import("ast/types.zig").DictType;
pub const FunctionType = @import("ast/types.zig").FunctionType;
pub const UnionType = @import("ast/types.zig").UnionType;
pub const NamedType = @import("ast/types.zig").NamedType;
pub const LiteralType = @import("ast/types.zig").LiteralType;
pub const SchemaRefType = @import("ast/types.zig").SchemaRefType;

pub const Identifier = @import("ast/dto.zig").Identifier;
pub const IdentifierNode = @import("ast/dto.zig").IdentifierNode;
/// A decorator is an `ast::CallExpr`; there is no separate `Decorator` DTO.
pub const Decorator = @import("ast/dto.zig").CallExpr;
pub const DecoratorNode = @import("ast/dto.zig").CallExprNode;
/// `UnificationStmt.value` is a `NodeRef<SchemaExpr>`; there is no separate
/// `SchemaConfig` DTO.
pub const SchemaConfig = @import("ast/dto.zig").SchemaExpr;
pub const SchemaConfigNode = @import("ast/dto.zig").SchemaExprNode;
pub const ConfigEntry = @import("ast/dto.zig").ConfigEntry;
pub const KeyValuePair = @import("ast/dto.zig").KeyValuePair;
pub const MemberOrIndex = @import("ast/dto.zig").MemberOrIndex;
pub const Target = @import("ast/dto.zig").Target;
pub const Keyword = @import("ast/dto.zig").Keyword;
pub const Arguments = @import("ast/dto.zig").Arguments;
pub const SchemaIndexSignature = @import("ast/dto.zig").SchemaIndexSignature;
pub const CompClause = @import("ast/dto.zig").CompClause;

pub const StringNode = base.Node([]const u8);

pub const parseModule = base.parseModule;
pub const parseProgram = base.parseProgram;

// Wire helpers re-exported for assertions against serialized documents.
pub const getField = base.getField;
pub const getString = base.getString;
pub const getBool = base.getBool;
pub const getInteger = base.getInteger;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

test "parseModule rejects invalid JSON" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    try testing.expectError(error.JsonSyntax, parseModule(arena.allocator(), "{not json"));
}

test "Module round-trips without a pkg field" {
    const alloc = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const a = arena.allocator();

    const module = try Module.parse(a, .{
        .object = blk: {
            var o: std.json.ObjectMap = .empty;
            try o.put(a, "filename", .{ .string = "main.k" });
            try o.put(a, "doc", .null);
            try o.put(a, "body", .{ .array = std.json.Array.init(a) });
            try o.put(a, "comments", .{ .array = std.json.Array.init(a) });
            break :blk o;
        },
    });
    const out = try Module.dump(a, module);
    try testing.expect(base.getString(out, "filename") != null);
    try testing.expect(base.getField(out, "pkg") == null);
}

test "ConfigEntry is_shorthand follows serde skip_serializing_if" {
    const alloc = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const a = arena.allocator();

    const plain = try ConfigEntry.dump(a, .{ .key = null, .value = null, .operation = "Union" });
    try testing.expect(base.getField(plain, "is_shorthand") == null);

    const shorthand = try ConfigEntry.dump(a, .{ .key = null, .value = null, .operation = "Union", .is_shorthand = true });
    try testing.expectEqual(true, base.getBool(shorthand, "is_shorthand"));
}
