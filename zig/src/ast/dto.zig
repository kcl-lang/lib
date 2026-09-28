//! Flat DTOs — helper structs nested under `NodeRef<T>` where the payload has
//! no polymorphic `"type"` discriminator on the wire.
//!
//! This mirrors the `_dto.py` module of the Python binding and AST_DRIFT.md
//! note A in the `kcl-lang/lib` repo: positions like `SchemaStmt.decorators`
//! or `UnificationStmt.value` carry the *flat* payload, unlike the same
//! shapes appearing as `Expr` variants which gain the discriminator.

const std = @import("std");
const base = @import("base.zig");
const types = @import("types.zig");
const expr = @import("expr.zig");

const Allocator = std.mem.Allocator;
const Error = base.Error;
const Value = std.json.Value;

pub const StringNode = base.Node([]const u8);
pub const ExprNode = base.Node(expr.Expr);
pub const TypeNode = base.Node(types.Type);

pub const parseStringNodeRef = base.parseNodeRef;
pub const parseExprNodeRef = base.parseNodeRef;
pub const parseTypeNodeRef = base.parseNodeRef;

/// Flat identifier payload (`{names, pkgpath, ctx}`) — no `"type"` tag.
/// Appears untagged in `Keyword.arg`, `Quant.variables`, `Arguments.args`,
/// `Type::Named`, `TypeAlias.type_name`, `SchemaStmt.parent_name` /
/// `mixins` / `for_host_name`, and tagged as `Expr::Identifier`.
pub const Identifier = struct {
    names: std.ArrayList(*StringNode),
    pkgpath: []const u8,
    ctx: []const u8,

    pub fn parse(alloc: Allocator, v: Value) Error!Identifier {
        return .{
            .names = try base.parseNodeRefList(alloc, base.getField(v, "names") orelse .null, []const u8, parseStringPayload),
            .pkgpath = base.getString(v, "pkgpath") orelse "",
            .ctx = base.getString(v, "ctx") orelse "",
        };
    }

    pub fn dump(alloc: Allocator, id: Identifier) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        var names: std.json.Array = std.json.Array.init(alloc);
        for (id.names.items) |n| {
            try names.append(try base.dumpNodeRef(alloc, n, dumpStringPayload));
        }
        try obj.put(alloc, "names", .{ .array = names });
        try obj.put(alloc, "pkgpath", .{ .string = id.pkgpath });
        try obj.put(alloc, "ctx", .{ .string = id.ctx });
        return .{ .object = obj };
    }
};

pub const IdentifierNode = base.Node(Identifier);

pub fn parseStringPayload(alloc: Allocator, v: Value) Error![]const u8 {
    return base.dupeString(alloc, try base.expectString(v));
}

pub fn dumpStringPayload(alloc: Allocator, s: []const u8) Error!Value {
    _ = alloc;
    return .{ .string = s };
}

/// `@deprecated(strict=True)` — the flat decorator payload used in
/// `SchemaStmt.decorators` / `SchemaAttr.decorators`. Note `func` carries a
/// fully tagged `Expr` payload on the wire.
pub const Decorator = struct {
    func: ?*ExprNode,
    args: std.ArrayList(*ExprNode),
    keywords: std.ArrayList(*KeywordNode),

    pub fn parse(alloc: Allocator, v: Value) Error!Decorator {
        return .{
            .func = try base.parseOptionalNodeRef(alloc, base.getField(v, "func") orelse .null, expr.Expr, expr.parseExprPayload),
            .args = try base.parseNodeRefList(alloc, base.getField(v, "args") orelse .null, expr.Expr, expr.parseExprPayload),
            .keywords = try base.parseNodeRefList(alloc, base.getField(v, "keywords") orelse .null, Keyword, parseKeywordPayload),
        };
    }

    pub fn dump(alloc: Allocator, d: Decorator) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "func", try base.dumpOptionalNodeRef(alloc, d.func, expr.dumpExprPayload));
        var args: std.json.Array = std.json.Array.init(alloc);
        for (d.args.items) |a| {
            try args.append(try base.dumpNodeRef(alloc, a, expr.dumpExprPayload));
        }
        try obj.put(alloc, "args", .{ .array = args });
        var kws: std.json.Array = std.json.Array.init(alloc);
        for (d.keywords.items) |k| {
            try kws.append(try base.dumpNodeRef(alloc, k, dumpKeywordPayload));
        }
        try obj.put(alloc, "keywords", .{ .array = kws });
        return .{ .object = obj };
    }
};

pub const DecoratorNode = base.Node(Decorator);

pub fn parseDecoratorPayload(alloc: Allocator, v: Value) Error!Decorator {
    return Decorator.parse(alloc, v);
}

pub fn dumpDecoratorPayload(alloc: Allocator, d: Decorator) Error!Value {
    return Decorator.dump(alloc, d);
}

/// `ASchema(args) { ... }` — the flat schema-instantiation payload used in
/// `UnificationStmt.value` (the `Expr::Schema` variant gains the tag).
pub const SchemaConfig = struct {
    name: ?*IdentifierNode,
    args: std.ArrayList(*ExprNode),
    kwargs: std.ArrayList(*KeywordNode),
    config: ?*ExprNode,

    pub fn parse(alloc: Allocator, v: Value) Error!SchemaConfig {
        return .{
            .name = try base.parseOptionalNodeRef(alloc, base.getField(v, "name") orelse .null, Identifier, Identifier.parse),
            .args = try base.parseNodeRefList(alloc, base.getField(v, "args") orelse .null, expr.Expr, expr.parseExprPayload),
            .kwargs = try base.parseNodeRefList(alloc, base.getField(v, "kwargs") orelse .null, Keyword, parseKeywordPayload),
            .config = try base.parseOptionalNodeRef(alloc, base.getField(v, "config") orelse .null, expr.Expr, expr.parseExprPayload),
        };
    }

    pub fn dump(alloc: Allocator, s: SchemaConfig) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "name", try base.dumpOptionalNodeRef(alloc, s.name, Identifier.dump));
        var args: std.json.Array = std.json.Array.init(alloc);
        for (s.args.items) |a| {
            try args.append(try base.dumpNodeRef(alloc, a, expr.dumpExprPayload));
        }
        try obj.put(alloc, "args", .{ .array = args });
        var kws: std.json.Array = std.json.Array.init(alloc);
        for (s.kwargs.items) |k| {
            try kws.append(try base.dumpNodeRef(alloc, k, dumpKeywordPayload));
        }
        try obj.put(alloc, "kwargs", .{ .array = kws });
        try obj.put(alloc, "config", try base.dumpOptionalNodeRef(alloc, s.config, expr.dumpExprPayload));
        return .{ .object = obj };
    }
};

pub const SchemaConfigNode = base.Node(SchemaConfig);

/// One entry in a config expression (`key = value`) or a dict-comprehension
/// `entry`. `is_shorthand` follows Rust's `#[serde(skip_serializing_if =
/// "is_false")]`: omitted unless true.
pub const ConfigEntry = struct {
    key: ?*ExprNode,
    value: ?*ExprNode,
    operation: []const u8,
    is_shorthand: bool = false,

    pub fn parse(alloc: Allocator, v: Value) Error!ConfigEntry {
        return .{
            .key = try base.parseOptionalNodeRef(alloc, base.getField(v, "key") orelse .null, expr.Expr, expr.parseExprPayload),
            .value = try base.parseOptionalNodeRef(alloc, base.getField(v, "value") orelse .null, expr.Expr, expr.parseExprPayload),
            .operation = base.getString(v, "operation") orelse "",
            .is_shorthand = base.getBool(v, "is_shorthand") orelse false,
        };
    }

    pub fn dump(alloc: Allocator, e: ConfigEntry) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "key", try base.dumpOptionalNodeRef(alloc, e.key, expr.dumpExprPayload));
        try obj.put(alloc, "value", try base.dumpOptionalNodeRef(alloc, e.value, expr.dumpExprPayload));
        try obj.put(alloc, "operation", .{ .string = e.operation });
        if (e.is_shorthand) {
            try obj.put(alloc, "is_shorthand", .{ .bool = true });
        }
        return .{ .object = obj };
    }
};

/// Alias documenting the `DictComp.entry` position — same wire shape.
pub const KeyValuePair = ConfigEntry;

pub const ConfigEntryNode = base.Node(ConfigEntry);

pub fn parseConfigEntryPayload(alloc: Allocator, v: Value) Error!ConfigEntry {
    return ConfigEntry.parse(alloc, v);
}

pub fn dumpConfigEntryPayload(alloc: Allocator, e: ConfigEntry) Error!Value {
    return ConfigEntry.dump(alloc, e);
}

/// Internally-tagged (`{"type":"Member","value":...}`) segment of a
/// `Target.paths` chain.
pub const MemberOrIndex = union(enum) {
    member: *StringNode,
    index: *ExprNode,

    pub fn parse(alloc: Allocator, v: Value) Error!MemberOrIndex {
        const tag = try base.variantTag(v);
        if (std.mem.eql(u8, tag, "Member")) {
            return .{ .member = try base.parseNodeRef(alloc, base.getField(v, "value") orelse .null, []const u8, parseStringPayload) };
        } else if (std.mem.eql(u8, tag, "Index")) {
            return .{ .index = try base.parseNodeRef(alloc, base.getField(v, "value") orelse .null, expr.Expr, expr.parseExprPayload) };
        }
        return error.UnexpectedWireShape;
    }

    pub fn dump(alloc: Allocator, m: MemberOrIndex) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        switch (m) {
            .member => |n| {
                try obj.put(alloc, "type", .{ .string = "Member" });
                try obj.put(alloc, "value", try base.dumpNodeRef(alloc, n, dumpStringPayload));
            },
            .index => |n| {
                try obj.put(alloc, "type", .{ .string = "Index" });
                try obj.put(alloc, "value", try base.dumpNodeRef(alloc, n, expr.dumpExprPayload));
            },
        }
        return .{ .object = obj };
    }
};

/// `a.b.c` — the flat `ast::Target` struct used in `AssignStmt.targets` /
/// `AugAssignStmt.target`. `Expr::Target` reuses the same payload with the
/// discriminator added.
pub const Target = struct {
    name: ?*StringNode,
    paths: std.ArrayList(MemberOrIndex),
    pkgpath: []const u8,

    pub fn parse(alloc: Allocator, v: Value) Error!Target {
        var paths: std.ArrayList(MemberOrIndex) = .empty;
        if (base.getField(v, "paths")) |p| {
            if (p != .null) {
                const arr = try base.expectArray(p);
                for (arr.items) |item| {
                    try paths.append(alloc, try MemberOrIndex.parse(alloc, item));
                }
            }
        }
        return .{
            .name = try base.parseOptionalNodeRef(alloc, base.getField(v, "name") orelse .null, []const u8, parseStringPayload),
            .paths = paths,
            .pkgpath = base.getString(v, "pkgpath") orelse "",
        };
    }

    pub fn dump(alloc: Allocator, t: Target) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "name", try base.dumpOptionalNodeRef(alloc, t.name, dumpStringPayload));
        var paths: std.json.Array = std.json.Array.init(alloc);
        for (t.paths.items) |p| {
            try paths.append(try MemberOrIndex.dump(alloc, p));
        }
        try obj.put(alloc, "paths", .{ .array = paths });
        try obj.put(alloc, "pkgpath", .{ .string = t.pkgpath });
        return .{ .object = obj };
    }
};

pub const TargetNode = base.Node(Target);

/// A keyword argument `arg = value` — flat payload inside `CallExpr.keywords`
/// / `SchemaConfig.kwargs`. `arg` wraps the flat (untagged) identifier.
pub const Keyword = struct {
    arg: ?*IdentifierNode,
    value: ?*ExprNode,

    pub fn parse(alloc: Allocator, v: Value) Error!Keyword {
        return .{
            .arg = try base.parseOptionalNodeRef(alloc, base.getField(v, "arg") orelse .null, Identifier, Identifier.parse),
            .value = try base.parseOptionalNodeRef(alloc, base.getField(v, "value") orelse .null, expr.Expr, expr.parseExprPayload),
        };
    }

    pub fn dump(alloc: Allocator, k: Keyword) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "arg", try base.dumpOptionalNodeRef(alloc, k.arg, Identifier.dump));
        try obj.put(alloc, "value", try base.dumpOptionalNodeRef(alloc, k.value, expr.dumpExprPayload));
        return .{ .object = obj };
    }
};

pub const KeywordNode = base.Node(Keyword);

pub fn parseKeywordPayload(alloc: Allocator, v: Value) Error!Keyword {
    return Keyword.parse(alloc, v);
}

pub fn dumpKeywordPayload(alloc: Allocator, k: Keyword) Error!Value {
    return Keyword.dump(alloc, k);
}

/// Lambda parameter list `x: int, y: int = 1` — flat payload inside
/// `LambdaExpr.args`. `defaults` aligns positionally with `args` and may
/// contain explicit `null`s.
pub const Arguments = struct {
    args: std.ArrayList(*IdentifierNode),
    defaults: std.ArrayList(?*ExprNode),
    ty_list: std.ArrayList(*TypeNode),

    pub fn parse(alloc: Allocator, v: Value) Error!Arguments {
        return .{
            .args = try base.parseNodeRefList(alloc, base.getField(v, "args") orelse .null, Identifier, Identifier.parse),
            .defaults = try base.parseOptionalNodeRefList(alloc, base.getField(v, "defaults") orelse .null, expr.Expr, expr.parseExprPayload),
            .ty_list = try base.parseNodeRefList(alloc, base.getField(v, "ty_list") orelse .null, types.Type, types.parseTypePayload),
        };
    }

    pub fn dump(alloc: Allocator, a: Arguments) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        var args: std.json.Array = std.json.Array.init(alloc);
        for (a.args.items) |n| {
            try args.append(try base.dumpNodeRef(alloc, n, Identifier.dump));
        }
        try obj.put(alloc, "args", .{ .array = args });
        var defaults: std.json.Array = std.json.Array.init(alloc);
        for (a.defaults.items) |n| {
            if (n) |nn| {
                try defaults.append(try base.dumpNodeRef(alloc, nn, expr.dumpExprPayload));
            } else {
                try defaults.append(.null);
            }
        }
        try obj.put(alloc, "defaults", .{ .array = defaults });
        var tys: std.json.Array = std.json.Array.init(alloc);
        for (a.ty_list.items) |n| {
            try tys.append(try base.dumpNodeRef(alloc, n, types.dumpTypePayload));
        }
        try obj.put(alloc, "ty_list", .{ .array = tys });
        return .{ .object = obj };
    }
};

pub const ArgumentsNode = base.Node(Arguments);

/// `[name: str]: T` — the schema index-signature payload.
pub const SchemaIndexSignature = struct {
    key_name: ?*StringNode,
    value: ?*TypeNode,
    any_other: bool,
    key_ty: ?*TypeNode,
    value_ty: ?*TypeNode,

    pub fn parse(alloc: Allocator, v: Value) Error!SchemaIndexSignature {
        return .{
            .key_name = try base.parseOptionalNodeRef(alloc, base.getField(v, "key_name") orelse .null, []const u8, parseStringPayload),
            .value = try base.parseOptionalNodeRef(alloc, base.getField(v, "value") orelse .null, types.Type, types.parseTypePayload),
            .any_other = base.getBool(v, "any_other") orelse false,
            .key_ty = try base.parseOptionalNodeRef(alloc, base.getField(v, "key_ty") orelse .null, types.Type, types.parseTypePayload),
            .value_ty = try base.parseOptionalNodeRef(alloc, base.getField(v, "value_ty") orelse .null, types.Type, types.parseTypePayload),
        };
    }

    pub fn dump(alloc: Allocator, s: SchemaIndexSignature) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "key_name", try base.dumpOptionalNodeRef(alloc, s.key_name, dumpStringPayload));
        try obj.put(alloc, "value", try base.dumpOptionalNodeRef(alloc, s.value, types.dumpTypePayload));
        try obj.put(alloc, "any_other", .{ .bool = s.any_other });
        try obj.put(alloc, "key_ty", try base.dumpOptionalNodeRef(alloc, s.key_ty, types.dumpTypePayload));
        try obj.put(alloc, "value_ty", try base.dumpOptionalNodeRef(alloc, s.value_ty, types.dumpTypePayload));
        return .{ .object = obj };
    }
};

pub const SchemaIndexSignatureNode = base.Node(SchemaIndexSignature);

/// One `for` clause of a list/dict comprehension — flat payload (no `"type"`
/// tag) inside `ListComp.generators` / `DictComp.generators`.
pub const CompClause = struct {
    targets: std.ArrayList(*IdentifierNode),
    iter: ?*ExprNode,
    ifs: std.ArrayList(*ExprNode),

    pub fn parse(alloc: Allocator, v: Value) Error!CompClause {
        return .{
            .targets = try base.parseNodeRefList(alloc, base.getField(v, "targets") orelse .null, Identifier, Identifier.parse),
            .iter = try base.parseOptionalNodeRef(alloc, base.getField(v, "iter") orelse .null, expr.Expr, expr.parseExprPayload),
            .ifs = try base.parseNodeRefList(alloc, base.getField(v, "ifs") orelse .null, expr.Expr, expr.parseExprPayload),
        };
    }

    pub fn dump(alloc: Allocator, c: CompClause) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        var targets: std.json.Array = std.json.Array.init(alloc);
        for (c.targets.items) |n| {
            try targets.append(try base.dumpNodeRef(alloc, n, Identifier.dump));
        }
        try obj.put(alloc, "targets", .{ .array = targets });
        try obj.put(alloc, "iter", try base.dumpOptionalNodeRef(alloc, c.iter, expr.dumpExprPayload));
        var ifs: std.json.Array = std.json.Array.init(alloc);
        for (c.ifs.items) |n| {
            try ifs.append(try base.dumpNodeRef(alloc, n, expr.dumpExprPayload));
        }
        try obj.put(alloc, "ifs", .{ .array = ifs });
        return .{ .object = obj };
    }
};

pub const CompClauseNode = base.Node(CompClause);
