//! Statement hierarchy — mirrors `ast::Stmt` in
//! `kcl-lang/kcl/crates/ast/src/ast.rs` with the internally-tagged
//! representation (`{"type": "<Variant>", ...}`) the Rust serde layer emits.

const std = @import("std");
const base = @import("base.zig");
const dto = @import("dto.zig");
const expr = @import("expr.zig");
const types = @import("types.zig");

const Allocator = std.mem.Allocator;
const Error = base.Error;
const Value = std.json.Value;

pub const StringNode = base.Node([]const u8);
pub const StmtNode = base.Node(Stmt);
pub const ExprNode = base.Node(expr.Expr);
pub const TypeNode = base.Node(types.Type);
pub const IdentifierNode = dto.IdentifierNode;
pub const DecoratorNode = dto.DecoratorNode;
pub const TargetNode = dto.TargetNode;
pub const ArgumentsNode = dto.ArgumentsNode;
pub const SchemaConfigNode = dto.SchemaConfigNode;
pub const SchemaIndexSignatureNode = dto.SchemaIndexSignatureNode;

pub const Stmt = union(enum) {
    expr: ExprStmt,
    unification: UnificationStmt,
    assign: AssignStmt,
    schema: SchemaStmt,
    schema_attr: SchemaAttr,
    rule: RuleStmt,
    import: ImportStmt,
    aug_assign: AugAssignStmt,
    @"if": IfStmt,
    type_alias: TypeAliasStmt,
    assert_stmt: AssertStmt,
    /// Forward-compatible fallback (see `expr.Expr.unknown`).
    unknown: base.RawUnknown(Value),
};

pub const ExprStmt = struct {
    exprs: std.ArrayList(*ExprNode),

    fn parse(alloc: Allocator, v: Value) Error!ExprStmt {
        return .{
            .exprs = try base.parseNodeRefList(alloc, base.getField(v, "exprs") orelse .null, expr.Expr, expr.parseExprPayload),
        };
    }

    fn dump(alloc: Allocator, s: ExprStmt) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        var exprs: std.json.Array = std.json.Array.init(alloc);
        for (s.exprs.items) |n| {
            try exprs.append(try base.dumpNodeRef(alloc, n, expr.dumpExprPayload));
        }
        try obj.put(alloc, "exprs", .{ .array = exprs });
        return .{ .object = obj };
    }
};

pub const UnificationStmt = struct {
    target: ?*IdentifierNode,
    value: ?*SchemaConfigNode,

    fn parse(alloc: Allocator, v: Value) Error!UnificationStmt {
        return .{
            .target = try base.parseOptionalNodeRef(alloc, base.getField(v, "target") orelse .null, dto.Identifier, dto.Identifier.parse),
            .value = try base.parseOptionalNodeRef(alloc, base.getField(v, "value") orelse .null, dto.SchemaConfig, dto.SchemaConfig.parse),
        };
    }

    fn dump(alloc: Allocator, s: UnificationStmt) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "target", try base.dumpOptionalNodeRef(alloc, s.target, dto.Identifier.dump));
        try obj.put(alloc, "value", try base.dumpOptionalNodeRef(alloc, s.value, dto.SchemaConfig.dump));
        return .{ .object = obj };
    }
};

pub const AssignStmt = struct {
    targets: std.ArrayList(*TargetNode),
    ty: ?*TypeNode,
    value: ?*ExprNode,

    fn parse(alloc: Allocator, v: Value) Error!AssignStmt {
        return .{
            .targets = try base.parseNodeRefList(alloc, base.getField(v, "targets") orelse .null, dto.Target, dto.Target.parse),
            .ty = try base.parseOptionalNodeRef(alloc, base.getField(v, "ty") orelse .null, types.Type, types.parseTypePayload),
            .value = try base.parseOptionalNodeRef(alloc, base.getField(v, "value") orelse .null, expr.Expr, expr.parseExprPayload),
        };
    }

    fn dump(alloc: Allocator, s: AssignStmt) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        var targets: std.json.Array = std.json.Array.init(alloc);
        for (s.targets.items) |n| {
            try targets.append(try base.dumpNodeRef(alloc, n, dto.Target.dump));
        }
        try obj.put(alloc, "targets", .{ .array = targets });
        try obj.put(alloc, "ty", try base.dumpOptionalNodeRef(alloc, s.ty, types.dumpTypePayload));
        try obj.put(alloc, "value", try base.dumpOptionalNodeRef(alloc, s.value, expr.dumpExprPayload));
        return .{ .object = obj };
    }
};

pub const SchemaStmt = struct {
    doc: ?*StringNode,
    name: ?*StringNode,
    parent_name: ?*IdentifierNode,
    for_host_name: ?*IdentifierNode,
    is_mixin: bool,
    is_protocol: bool,
    args: ?*ArgumentsNode,
    mixins: std.ArrayList(*IdentifierNode),
    body: std.ArrayList(*StmtNode),
    decorators: std.ArrayList(*DecoratorNode),
    checks: std.ArrayList(*expr.CheckExprNode),
    index_signature: ?*SchemaIndexSignatureNode,

    fn parse(alloc: Allocator, v: Value) Error!SchemaStmt {
        return .{
            .doc = try base.parseOptionalNodeRef(alloc, base.getField(v, "doc") orelse .null, []const u8, dto.parseStringPayload),
            .name = try base.parseOptionalNodeRef(alloc, base.getField(v, "name") orelse .null, []const u8, dto.parseStringPayload),
            .parent_name = try base.parseOptionalNodeRef(alloc, base.getField(v, "parent_name") orelse .null, dto.Identifier, dto.Identifier.parse),
            .for_host_name = try base.parseOptionalNodeRef(alloc, base.getField(v, "for_host_name") orelse .null, dto.Identifier, dto.Identifier.parse),
            .is_mixin = base.getBool(v, "is_mixin") orelse false,
            .is_protocol = base.getBool(v, "is_protocol") orelse false,
            .args = try base.parseOptionalNodeRef(alloc, base.getField(v, "args") orelse .null, dto.Arguments, dto.Arguments.parse),
            .mixins = try base.parseNodeRefList(alloc, base.getField(v, "mixins") orelse .null, dto.Identifier, dto.Identifier.parse),
            .body = try base.parseNodeRefList(alloc, base.getField(v, "body") orelse .null, Stmt, parseStmtPayload),
            .decorators = try base.parseNodeRefList(alloc, base.getField(v, "decorators") orelse .null, dto.Decorator, dto.parseDecoratorPayload),
            .checks = try base.parseNodeRefList(alloc, base.getField(v, "checks") orelse .null, expr.CheckExpr, expr.parseCheckExprPayload),
            .index_signature = try base.parseOptionalNodeRef(alloc, base.getField(v, "index_signature") orelse .null, dto.SchemaIndexSignature, dto.SchemaIndexSignature.parse),
        };
    }

    fn dump(alloc: Allocator, s: SchemaStmt) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "doc", try base.dumpOptionalNodeRef(alloc, s.doc, dto.dumpStringPayload));
        try obj.put(alloc, "name", try base.dumpOptionalNodeRef(alloc, s.name, dto.dumpStringPayload));
        try obj.put(alloc, "parent_name", try base.dumpOptionalNodeRef(alloc, s.parent_name, dto.Identifier.dump));
        try obj.put(alloc, "for_host_name", try base.dumpOptionalNodeRef(alloc, s.for_host_name, dto.Identifier.dump));
        try obj.put(alloc, "is_mixin", .{ .bool = s.is_mixin });
        try obj.put(alloc, "is_protocol", .{ .bool = s.is_protocol });
        try obj.put(alloc, "args", try base.dumpOptionalNodeRef(alloc, s.args, dto.Arguments.dump));
        var mixins: std.json.Array = std.json.Array.init(alloc);
        for (s.mixins.items) |n| {
            try mixins.append(try base.dumpNodeRef(alloc, n, dto.Identifier.dump));
        }
        try obj.put(alloc, "mixins", .{ .array = mixins });
        var body: std.json.Array = std.json.Array.init(alloc);
        for (s.body.items) |n| {
            try body.append(try base.dumpNodeRef(alloc, n, dumpStmtPayload));
        }
        try obj.put(alloc, "body", .{ .array = body });
        var decorators: std.json.Array = std.json.Array.init(alloc);
        for (s.decorators.items) |n| {
            try decorators.append(try base.dumpNodeRef(alloc, n, dto.dumpDecoratorPayload));
        }
        try obj.put(alloc, "decorators", .{ .array = decorators });
        var checks: std.json.Array = std.json.Array.init(alloc);
        for (s.checks.items) |n| {
            try checks.append(try base.dumpNodeRef(alloc, n, expr.dumpCheckExprPayload));
        }
        try obj.put(alloc, "checks", .{ .array = checks });
        try obj.put(alloc, "index_signature", try base.dumpOptionalNodeRef(alloc, s.index_signature, dto.SchemaIndexSignature.dump));
        return .{ .object = obj };
    }
};

pub const SchemaAttr = struct {
    doc: []const u8,
    name: ?*StringNode,
    op: ?[]const u8,
    value: ?*ExprNode,
    is_optional: bool,
    decorators: std.ArrayList(*DecoratorNode),
    ty: ?*TypeNode,

    fn parse(alloc: Allocator, v: Value) Error!SchemaAttr {
        return .{
            .doc = try base.dupeString(alloc, base.getString(v, "doc") orelse ""),
            .name = try base.parseOptionalNodeRef(alloc, base.getField(v, "name") orelse .null, []const u8, dto.parseStringPayload),
            .op = if (base.getString(v, "op")) |s| try base.dupeString(alloc, s) else null,
            .value = try base.parseOptionalNodeRef(alloc, base.getField(v, "value") orelse .null, expr.Expr, expr.parseExprPayload),
            .is_optional = base.getBool(v, "is_optional") orelse false,
            .decorators = try base.parseNodeRefList(alloc, base.getField(v, "decorators") orelse .null, dto.Decorator, dto.parseDecoratorPayload),
            .ty = try base.parseOptionalNodeRef(alloc, base.getField(v, "ty") orelse .null, types.Type, types.parseTypePayload),
        };
    }

    fn dump(alloc: Allocator, s: SchemaAttr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "doc", .{ .string = s.doc });
        try obj.put(alloc, "name", try base.dumpOptionalNodeRef(alloc, s.name, dto.dumpStringPayload));
        if (s.op) |op| {
            try obj.put(alloc, "op", .{ .string = op });
        } else {
            try obj.put(alloc, "op", .null);
        }
        try obj.put(alloc, "value", try base.dumpOptionalNodeRef(alloc, s.value, expr.dumpExprPayload));
        try obj.put(alloc, "is_optional", .{ .bool = s.is_optional });
        var decorators: std.json.Array = std.json.Array.init(alloc);
        for (s.decorators.items) |n| {
            try decorators.append(try base.dumpNodeRef(alloc, n, dto.dumpDecoratorPayload));
        }
        try obj.put(alloc, "decorators", .{ .array = decorators });
        try obj.put(alloc, "ty", try base.dumpOptionalNodeRef(alloc, s.ty, types.dumpTypePayload));
        return .{ .object = obj };
    }
};

pub const RuleStmt = struct {
    doc: ?*StringNode,
    name: ?*StringNode,
    parent_rules: std.ArrayList(*IdentifierNode),
    decorators: std.ArrayList(*DecoratorNode),
    checks: std.ArrayList(*expr.CheckExprNode),
    args: ?*ArgumentsNode,
    for_host_name: ?*IdentifierNode,

    fn parse(alloc: Allocator, v: Value) Error!RuleStmt {
        return .{
            .doc = try base.parseOptionalNodeRef(alloc, base.getField(v, "doc") orelse .null, []const u8, dto.parseStringPayload),
            .name = try base.parseOptionalNodeRef(alloc, base.getField(v, "name") orelse .null, []const u8, dto.parseStringPayload),
            .parent_rules = try base.parseNodeRefList(alloc, base.getField(v, "parent_rules") orelse .null, dto.Identifier, dto.Identifier.parse),
            .decorators = try base.parseNodeRefList(alloc, base.getField(v, "decorators") orelse .null, dto.Decorator, dto.parseDecoratorPayload),
            .checks = try base.parseNodeRefList(alloc, base.getField(v, "checks") orelse .null, expr.CheckExpr, expr.parseCheckExprPayload),
            .args = try base.parseOptionalNodeRef(alloc, base.getField(v, "args") orelse .null, dto.Arguments, dto.Arguments.parse),
            .for_host_name = try base.parseOptionalNodeRef(alloc, base.getField(v, "for_host_name") orelse .null, dto.Identifier, dto.Identifier.parse),
        };
    }

    fn dump(alloc: Allocator, s: RuleStmt) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "doc", try base.dumpOptionalNodeRef(alloc, s.doc, dto.dumpStringPayload));
        try obj.put(alloc, "name", try base.dumpOptionalNodeRef(alloc, s.name, dto.dumpStringPayload));
        var parents: std.json.Array = std.json.Array.init(alloc);
        for (s.parent_rules.items) |n| {
            try parents.append(try base.dumpNodeRef(alloc, n, dto.Identifier.dump));
        }
        try obj.put(alloc, "parent_rules", .{ .array = parents });
        var decorators: std.json.Array = std.json.Array.init(alloc);
        for (s.decorators.items) |n| {
            try decorators.append(try base.dumpNodeRef(alloc, n, dto.dumpDecoratorPayload));
        }
        try obj.put(alloc, "decorators", .{ .array = decorators });
        var checks: std.json.Array = std.json.Array.init(alloc);
        for (s.checks.items) |n| {
            try checks.append(try base.dumpNodeRef(alloc, n, expr.dumpCheckExprPayload));
        }
        try obj.put(alloc, "checks", .{ .array = checks });
        try obj.put(alloc, "args", try base.dumpOptionalNodeRef(alloc, s.args, dto.Arguments.dump));
        try obj.put(alloc, "for_host_name", try base.dumpOptionalNodeRef(alloc, s.for_host_name, dto.Identifier.dump));
        return .{ .object = obj };
    }
};

pub const ImportStmt = struct {
    path: ?*StringNode,
    rawpath: []const u8,
    name: []const u8,
    asname: ?[]const u8,
    pkg_name: []const u8,

    fn parse(alloc: Allocator, v: Value) Error!ImportStmt {
        return .{
            .path = try base.parseOptionalNodeRef(alloc, base.getField(v, "path") orelse .null, []const u8, dto.parseStringPayload),
            .rawpath = try base.dupeString(alloc, base.getString(v, "rawpath") orelse ""),
            .name = try base.dupeString(alloc, base.getString(v, "name") orelse ""),
            .asname = if (base.getString(v, "asname")) |s| try base.dupeString(alloc, s) else null,
            .pkg_name = try base.dupeString(alloc, base.getString(v, "pkg_name") orelse ""),
        };
    }

    fn dump(alloc: Allocator, s: ImportStmt) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "path", try base.dumpOptionalNodeRef(alloc, s.path, dto.dumpStringPayload));
        try obj.put(alloc, "rawpath", .{ .string = s.rawpath });
        try obj.put(alloc, "name", .{ .string = s.name });
        if (s.asname) |a| {
            try obj.put(alloc, "asname", .{ .string = a });
        } else {
            try obj.put(alloc, "asname", .null);
        }
        try obj.put(alloc, "pkg_name", .{ .string = s.pkg_name });
        return .{ .object = obj };
    }
};

pub const AugAssignStmt = struct {
    target: ?*TargetNode,
    op: []const u8,
    value: ?*ExprNode,

    fn parse(alloc: Allocator, v: Value) Error!AugAssignStmt {
        return .{
            .target = try base.parseOptionalNodeRef(alloc, base.getField(v, "target") orelse .null, dto.Target, dto.Target.parse),
            .op = try base.dupeString(alloc, base.getString(v, "op") orelse ""),
            .value = try base.parseOptionalNodeRef(alloc, base.getField(v, "value") orelse .null, expr.Expr, expr.parseExprPayload),
        };
    }

    fn dump(alloc: Allocator, s: AugAssignStmt) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "target", try base.dumpOptionalNodeRef(alloc, s.target, dto.Target.dump));
        try obj.put(alloc, "op", .{ .string = s.op });
        try obj.put(alloc, "value", try base.dumpOptionalNodeRef(alloc, s.value, expr.dumpExprPayload));
        return .{ .object = obj };
    }
};

pub const IfStmt = struct {
    cond: ?*ExprNode,
    body: std.ArrayList(*StmtNode),
    orelse_: std.ArrayList(*StmtNode),

    fn parse(alloc: Allocator, v: Value) Error!IfStmt {
        return .{
            .cond = try base.parseOptionalNodeRef(alloc, base.getField(v, "cond") orelse .null, expr.Expr, expr.parseExprPayload),
            .body = try base.parseNodeRefList(alloc, base.getField(v, "body") orelse .null, Stmt, parseStmtPayload),
            .orelse_ = try base.parseNodeRefList(alloc, base.getField(v, "orelse") orelse .null, Stmt, parseStmtPayload),
        };
    }

    fn dump(alloc: Allocator, s: IfStmt) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "cond", try base.dumpOptionalNodeRef(alloc, s.cond, expr.dumpExprPayload));
        var body: std.json.Array = std.json.Array.init(alloc);
        for (s.body.items) |n| {
            try body.append(try base.dumpNodeRef(alloc, n, dumpStmtPayload));
        }
        try obj.put(alloc, "body", .{ .array = body });
        var orelse_: std.json.Array = std.json.Array.init(alloc);
        for (s.orelse_.items) |n| {
            try orelse_.append(try base.dumpNodeRef(alloc, n, dumpStmtPayload));
        }
        try obj.put(alloc, "orelse", .{ .array = orelse_ });
        return .{ .object = obj };
    }
};

pub const TypeAliasStmt = struct {
    type_name: ?*IdentifierNode,
    type_value: ?*StringNode,
    ty: ?*TypeNode,

    fn parse(alloc: Allocator, v: Value) Error!TypeAliasStmt {
        return .{
            .type_name = try base.parseOptionalNodeRef(alloc, base.getField(v, "type_name") orelse .null, dto.Identifier, dto.Identifier.parse),
            .type_value = try base.parseOptionalNodeRef(alloc, base.getField(v, "type_value") orelse .null, []const u8, dto.parseStringPayload),
            .ty = try base.parseOptionalNodeRef(alloc, base.getField(v, "ty") orelse .null, types.Type, types.parseTypePayload),
        };
    }

    fn dump(alloc: Allocator, s: TypeAliasStmt) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "type_name", try base.dumpOptionalNodeRef(alloc, s.type_name, dto.Identifier.dump));
        try obj.put(alloc, "type_value", try base.dumpOptionalNodeRef(alloc, s.type_value, dto.dumpStringPayload));
        try obj.put(alloc, "ty", try base.dumpOptionalNodeRef(alloc, s.ty, types.dumpTypePayload));
        return .{ .object = obj };
    }
};

pub const AssertStmt = struct {
    test_: ?*ExprNode,
    msg: ?*ExprNode,
    if_cond: ?*ExprNode,

    fn parse(alloc: Allocator, v: Value) Error!AssertStmt {
        return .{
            .test_ = try base.parseOptionalNodeRef(alloc, base.getField(v, "test") orelse .null, expr.Expr, expr.parseExprPayload),
            .msg = try base.parseOptionalNodeRef(alloc, base.getField(v, "msg") orelse .null, expr.Expr, expr.parseExprPayload),
            .if_cond = try base.parseOptionalNodeRef(alloc, base.getField(v, "if_cond") orelse .null, expr.Expr, expr.parseExprPayload),
        };
    }

    fn dump(alloc: Allocator, s: AssertStmt) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "test", try base.dumpOptionalNodeRef(alloc, s.test_, expr.dumpExprPayload));
        try obj.put(alloc, "msg", try base.dumpOptionalNodeRef(alloc, s.msg, expr.dumpExprPayload));
        try obj.put(alloc, "if_cond", try base.dumpOptionalNodeRef(alloc, s.if_cond, expr.dumpExprPayload));
        return .{ .object = obj };
    }
};

pub fn parseStmtPayload(alloc: Allocator, v: Value) Error!Stmt {
    if (v == .null) return error.UnexpectedWireShape;
    const tag = try base.variantTag(v);
    const eql = std.mem.eql;
    if (eql(u8, tag, "Expr")) return .{ .expr = try ExprStmt.parse(alloc, v) };
    if (eql(u8, tag, "Unification")) return .{ .unification = try UnificationStmt.parse(alloc, v) };
    if (eql(u8, tag, "Assign")) return .{ .assign = try AssignStmt.parse(alloc, v) };
    if (eql(u8, tag, "Schema")) return .{ .schema = try SchemaStmt.parse(alloc, v) };
    if (eql(u8, tag, "SchemaAttr")) return .{ .schema_attr = try SchemaAttr.parse(alloc, v) };
    if (eql(u8, tag, "Rule")) return .{ .rule = try RuleStmt.parse(alloc, v) };
    if (eql(u8, tag, "Import")) return .{ .import = try ImportStmt.parse(alloc, v) };
    if (eql(u8, tag, "AugAssign")) return .{ .aug_assign = try AugAssignStmt.parse(alloc, v) };
    if (eql(u8, tag, "If")) return .{ .@"if" = try IfStmt.parse(alloc, v) };
    if (eql(u8, tag, "TypeAlias")) return .{ .type_alias = try TypeAliasStmt.parse(alloc, v) };
    if (eql(u8, tag, "Assert")) return .{ .assert_stmt = try AssertStmt.parse(alloc, v) };
    return .{
        .unknown = .{
            .tag = try base.dupeString(alloc, tag),
            .value = try base.cloneValue(alloc, v),
        },
    };
}

pub fn stmtTag(s: Stmt) []const u8 {
    return switch (s) {
        .expr => "Expr",
        .unification => "Unification",
        .assign => "Assign",
        .schema => "Schema",
        .schema_attr => "SchemaAttr",
        .rule => "Rule",
        .import => "Import",
        .aug_assign => "AugAssign",
        .@"if" => "If",
        .type_alias => "TypeAlias",
        .assert_stmt => "Assert",
        .unknown => |u| u.tag,
    };
}

pub fn dumpStmtPayload(alloc: Allocator, s: Stmt) Error!Value {
    const inner: Value = switch (s) {
        .expr => |x| try ExprStmt.dump(alloc, x),
        .unification => |x| try UnificationStmt.dump(alloc, x),
        .assign => |x| try AssignStmt.dump(alloc, x),
        .schema => |x| try SchemaStmt.dump(alloc, x),
        .schema_attr => |x| try SchemaAttr.dump(alloc, x),
        .rule => |x| try RuleStmt.dump(alloc, x),
        .import => |x| try ImportStmt.dump(alloc, x),
        .aug_assign => |x| try AugAssignStmt.dump(alloc, x),
        .@"if" => |x| try IfStmt.dump(alloc, x),
        .type_alias => |x| try TypeAliasStmt.dump(alloc, x),
        .assert_stmt => |x| try AssertStmt.dump(alloc, x),
        .unknown => |x| return x.value,
    };
    const obj = base.expectObject(inner) catch return inner;
    var out: std.json.ObjectMap = .empty;
    var it = obj.iterator();
    while (it.next()) |entry| {
        try out.put(alloc, entry.key_ptr.*, entry.value_ptr.*);
    }
    try out.put(alloc, "type", .{ .string = stmtTag(s) });
    return .{ .object = out };
}
