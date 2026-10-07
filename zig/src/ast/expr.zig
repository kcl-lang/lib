//! Expression hierarchy — mirrors `ast::Expr` in
//! `kcl-lang/kcl/crates/ast/src/ast.rs`.
//!
//! The Rust enum is internally tagged (`#[serde(tag = "type")]`), so every
//! variant appears on the wire as `{"type": "<Variant>", ...}` inside the
//! enclosing `Node` wrapper. `parseExprPayload` dispatches on that tag;
//! unknown tags are kept as raw JSON for forward-compatible round-trips.
//!
//! Note: `CompClause` never carries the tag on the wire (it is a flat DTO
//! inside comprehensions, see `dto.zig`); it is still listed here so the
//! variant set mirrors the other language bindings.

const std = @import("std");
const base = @import("base.zig");
const dto = @import("dto.zig");
const types = @import("types.zig");
// Circular by design: `LambdaExpr.body` is a list of *statements*, and
// `stmt.zig` needs the expression registry to fill in an `ExprStmt`. Zig
// resolves container-level imports lazily, so the cycle only works because
// neither module reads the other at load time — every reference is inside a
// function body.
const stmt = @import("stmt.zig");

const Allocator = std.mem.Allocator;
const Error = base.Error;
const Value = std.json.Value;

pub const StringNode = base.Node([]const u8);
pub const ExprNode = base.Node(Expr);
pub const TypeNode = base.Node(types.Type);
pub const IdentifierNode = dto.IdentifierNode;
pub const KeywordNode = dto.KeywordNode;
pub const ArgumentsNode = dto.ArgumentsNode;
pub const ConfigEntryNode = dto.ConfigEntryNode;
pub const CompClauseNode = dto.CompClauseNode;

pub const Expr = union(enum) {
    target: dto.Target,
    identifier: dto.Identifier,
    unary: UnaryExpr,
    binary: BinaryExpr,
    @"if": IfExpr,
    selector: SelectorExpr,
    call: CallExpr,
    paren: ParenExpr,
    quant: QuantExpr,
    list: ListExpr,
    list_if_item: ListIfItemExpr,
    list_comp: ListCompExpr,
    starred: StarredExpr,
    dict_comp: DictCompExpr,
    config_if_entry: ConfigIfEntryExpr,
    comp_clause: dto.CompClause,
    schema: SchemaExpr,
    config: ConfigExpr,
    lambda: LambdaExpr,
    subscript: SubscriptExpr,
    compare: CompareExpr,
    number_lit: NumberLitExpr,
    string_lit: StringLitExpr,
    name_constant_lit: NameConstantLitExpr,
    joined_string: JoinedStringExpr,
    formatted_value: FormattedValueExpr,
    missing: MissingExpr,
    check_expr: CheckExpr,
    keyword: dto.Keyword,
    arguments: dto.Arguments,
    /// Forward-compatible fallback: unknown variant keeps its tag and raw
    /// payload so it serializes back exactly as received.
    unknown: base.RawUnknown(Value),
};

pub const UnaryExpr = struct {
    op: []const u8,
    operand: ?*ExprNode,

    fn parse(alloc: Allocator, v: Value) Error!UnaryExpr {
        return .{
            .op = base.getString(v, "op") orelse "",
            .operand = try base.parseOptionalNodeRef(alloc, base.getField(v, "operand") orelse .null, Expr, parseExprPayload),
        };
    }

    fn dump(alloc: Allocator, e: UnaryExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "op", .{ .string = e.op });
        try obj.put(alloc, "operand", try base.dumpOptionalNodeRef(alloc, e.operand, dumpExprPayload));
        return .{ .object = obj };
    }
};

pub const BinaryExpr = struct {
    left: ?*ExprNode,
    op: []const u8,
    right: ?*ExprNode,

    fn parse(alloc: Allocator, v: Value) Error!BinaryExpr {
        return .{
            .left = try base.parseOptionalNodeRef(alloc, base.getField(v, "left") orelse .null, Expr, parseExprPayload),
            .op = base.getString(v, "op") orelse "",
            .right = try base.parseOptionalNodeRef(alloc, base.getField(v, "right") orelse .null, Expr, parseExprPayload),
        };
    }

    fn dump(alloc: Allocator, e: BinaryExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "left", try base.dumpOptionalNodeRef(alloc, e.left, dumpExprPayload));
        try obj.put(alloc, "op", .{ .string = e.op });
        try obj.put(alloc, "right", try base.dumpOptionalNodeRef(alloc, e.right, dumpExprPayload));
        return .{ .object = obj };
    }
};

pub const IfExpr = struct {
    body: ?*ExprNode,
    cond: ?*ExprNode,
    orelse_: ?*ExprNode,

    fn parse(alloc: Allocator, v: Value) Error!IfExpr {
        return .{
            .body = try base.parseOptionalNodeRef(alloc, base.getField(v, "body") orelse .null, Expr, parseExprPayload),
            .cond = try base.parseOptionalNodeRef(alloc, base.getField(v, "cond") orelse .null, Expr, parseExprPayload),
            .orelse_ = try base.parseOptionalNodeRef(alloc, base.getField(v, "orelse") orelse .null, Expr, parseExprPayload),
        };
    }

    fn dump(alloc: Allocator, e: IfExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "body", try base.dumpOptionalNodeRef(alloc, e.body, dumpExprPayload));
        try obj.put(alloc, "cond", try base.dumpOptionalNodeRef(alloc, e.cond, dumpExprPayload));
        try obj.put(alloc, "orelse", try base.dumpOptionalNodeRef(alloc, e.orelse_, dumpExprPayload));
        return .{ .object = obj };
    }
};

pub const SelectorExpr = struct {
    value: ?*ExprNode,
    attr: ?*IdentifierNode,
    ctx: []const u8,
    has_question: bool,

    fn parse(alloc: Allocator, v: Value) Error!SelectorExpr {
        return .{
            .value = try base.parseOptionalNodeRef(alloc, base.getField(v, "value") orelse .null, Expr, parseExprPayload),
            .attr = try base.parseOptionalNodeRef(alloc, base.getField(v, "attr") orelse .null, dto.Identifier, dto.Identifier.parse),
            .ctx = base.getString(v, "ctx") orelse "",
            .has_question = base.getBool(v, "has_question") orelse false,
        };
    }

    fn dump(alloc: Allocator, e: SelectorExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "value", try base.dumpOptionalNodeRef(alloc, e.value, dumpExprPayload));
        try obj.put(alloc, "attr", try base.dumpOptionalNodeRef(alloc, e.attr, dto.Identifier.dump));
        try obj.put(alloc, "ctx", .{ .string = e.ctx });
        try obj.put(alloc, "has_question", .{ .bool = e.has_question });
        return .{ .object = obj };
    }
};

/// `ast::CallExpr`. Also the payload of every decorator:
/// `SchemaStmt.decorators` is `Vec<NodeRef<CallExpr>>` and its elements carry
/// no `"type"` key, so `dto.zig` re-exports `parseCallExprPayload` for them.
pub const CallExpr = struct {
    func: ?*ExprNode,
    args: std.ArrayList(*ExprNode) = .empty,
    keywords: std.ArrayList(*KeywordNode) = .empty,

    pub fn parse(alloc: Allocator, v: Value) Error!CallExpr {
        return .{
            .func = try base.parseOptionalNodeRef(alloc, base.getField(v, "func") orelse .null, Expr, parseExprPayload),
            .args = try base.parseNodeRefList(alloc, base.getField(v, "args") orelse .null, Expr, parseExprPayload),
            .keywords = try base.parseNodeRefList(alloc, base.getField(v, "keywords") orelse .null, dto.Keyword, dto.parseKeywordPayload),
        };
    }

    pub fn dump(alloc: Allocator, e: CallExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "func", try base.dumpOptionalNodeRef(alloc, e.func, dumpExprPayload));
        var args: std.json.Array = std.json.Array.init(alloc);
        for (e.args.items) |n| {
            try args.append(try base.dumpNodeRef(alloc, n, dumpExprPayload));
        }
        try obj.put(alloc, "args", .{ .array = args });
        var kws: std.json.Array = std.json.Array.init(alloc);
        for (e.keywords.items) |n| {
            try kws.append(try base.dumpNodeRef(alloc, n, dto.dumpKeywordPayload));
        }
        try obj.put(alloc, "keywords", .{ .array = kws });
        return .{ .object = obj };
    }
};

/// Payload helpers for the flat (untagged) uses of `CallExpr` — i.e. the
/// `decorators` lists, whose elements are `NodeRef<CallExpr>` with no tag.
pub fn parseCallExprPayload(alloc: Allocator, v: Value) Error!CallExpr {
    return CallExpr.parse(alloc, v);
}

pub fn dumpCallExprPayload(alloc: Allocator, e: CallExpr) Error!Value {
    return CallExpr.dump(alloc, e);
}

pub const ParenExpr = struct {
    expr: ?*ExprNode,

    fn parse(alloc: Allocator, v: Value) Error!ParenExpr {
        return .{
            .expr = try base.parseOptionalNodeRef(alloc, base.getField(v, "expr") orelse .null, Expr, parseExprPayload),
        };
    }

    fn dump(alloc: Allocator, e: ParenExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "expr", try base.dumpOptionalNodeRef(alloc, e.expr, dumpExprPayload));
        return .{ .object = obj };
    }
};

pub const QuantExpr = struct {
    target: ?*ExprNode,
    variables: std.ArrayList(*IdentifierNode) = .empty,
    op: []const u8,
    test_: ?*ExprNode,
    if_cond: ?*ExprNode,
    ctx: []const u8,

    fn parse(alloc: Allocator, v: Value) Error!QuantExpr {
        return .{
            .target = try base.parseOptionalNodeRef(alloc, base.getField(v, "target") orelse .null, Expr, parseExprPayload),
            .variables = try base.parseNodeRefList(alloc, base.getField(v, "variables") orelse .null, dto.Identifier, dto.Identifier.parse),
            .op = base.getString(v, "op") orelse "",
            .test_ = try base.parseOptionalNodeRef(alloc, base.getField(v, "test") orelse .null, Expr, parseExprPayload),
            .if_cond = try base.parseOptionalNodeRef(alloc, base.getField(v, "if_cond") orelse .null, Expr, parseExprPayload),
            .ctx = base.getString(v, "ctx") orelse "",
        };
    }

    fn dump(alloc: Allocator, e: QuantExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "target", try base.dumpOptionalNodeRef(alloc, e.target, dumpExprPayload));
        var vars: std.json.Array = std.json.Array.init(alloc);
        for (e.variables.items) |n| {
            try vars.append(try base.dumpNodeRef(alloc, n, dto.Identifier.dump));
        }
        try obj.put(alloc, "variables", .{ .array = vars });
        try obj.put(alloc, "op", .{ .string = e.op });
        try obj.put(alloc, "test", try base.dumpOptionalNodeRef(alloc, e.test_, dumpExprPayload));
        try obj.put(alloc, "if_cond", try base.dumpOptionalNodeRef(alloc, e.if_cond, dumpExprPayload));
        try obj.put(alloc, "ctx", .{ .string = e.ctx });
        return .{ .object = obj };
    }
};

pub const ListExpr = struct {
    elts: std.ArrayList(*ExprNode) = .empty,
    ctx: []const u8,

    fn parse(alloc: Allocator, v: Value) Error!ListExpr {
        return .{
            .elts = try base.parseNodeRefList(alloc, base.getField(v, "elts") orelse .null, Expr, parseExprPayload),
            .ctx = base.getString(v, "ctx") orelse "",
        };
    }

    fn dump(alloc: Allocator, e: ListExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        var elts: std.json.Array = std.json.Array.init(alloc);
        for (e.elts.items) |n| {
            try elts.append(try base.dumpNodeRef(alloc, n, dumpExprPayload));
        }
        try obj.put(alloc, "elts", .{ .array = elts });
        try obj.put(alloc, "ctx", .{ .string = e.ctx });
        return .{ .object = obj };
    }
};

pub const ListIfItemExpr = struct {
    if_cond: ?*ExprNode,
    exprs: std.ArrayList(*ExprNode) = .empty,
    orelse_: ?*ExprNode,

    fn parse(alloc: Allocator, v: Value) Error!ListIfItemExpr {
        return .{
            .if_cond = try base.parseOptionalNodeRef(alloc, base.getField(v, "if_cond") orelse .null, Expr, parseExprPayload),
            .exprs = try base.parseNodeRefList(alloc, base.getField(v, "exprs") orelse .null, Expr, parseExprPayload),
            .orelse_ = try base.parseOptionalNodeRef(alloc, base.getField(v, "orelse") orelse .null, Expr, parseExprPayload),
        };
    }

    fn dump(alloc: Allocator, e: ListIfItemExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "if_cond", try base.dumpOptionalNodeRef(alloc, e.if_cond, dumpExprPayload));
        var exprs: std.json.Array = std.json.Array.init(alloc);
        for (e.exprs.items) |n| {
            try exprs.append(try base.dumpNodeRef(alloc, n, dumpExprPayload));
        }
        try obj.put(alloc, "exprs", .{ .array = exprs });
        try obj.put(alloc, "orelse", try base.dumpOptionalNodeRef(alloc, e.orelse_, dumpExprPayload));
        return .{ .object = obj };
    }
};

pub const ListCompExpr = struct {
    elt: ?*ExprNode,
    generators: std.ArrayList(*CompClauseNode) = .empty,

    fn parse(alloc: Allocator, v: Value) Error!ListCompExpr {
        return .{
            .elt = try base.parseOptionalNodeRef(alloc, base.getField(v, "elt") orelse .null, Expr, parseExprPayload),
            .generators = try base.parseNodeRefList(alloc, base.getField(v, "generators") orelse .null, dto.CompClause, dto.CompClause.parse),
        };
    }

    fn dump(alloc: Allocator, e: ListCompExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "elt", try base.dumpOptionalNodeRef(alloc, e.elt, dumpExprPayload));
        var gens: std.json.Array = std.json.Array.init(alloc);
        for (e.generators.items) |n| {
            try gens.append(try base.dumpNodeRef(alloc, n, dto.CompClause.dump));
        }
        try obj.put(alloc, "generators", .{ .array = gens });
        return .{ .object = obj };
    }
};

pub const StarredExpr = struct {
    value: ?*ExprNode,
    ctx: []const u8,

    fn parse(alloc: Allocator, v: Value) Error!StarredExpr {
        return .{
            .value = try base.parseOptionalNodeRef(alloc, base.getField(v, "value") orelse .null, Expr, parseExprPayload),
            .ctx = base.getString(v, "ctx") orelse "",
        };
    }

    fn dump(alloc: Allocator, e: StarredExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "value", try base.dumpOptionalNodeRef(alloc, e.value, dumpExprPayload));
        try obj.put(alloc, "ctx", .{ .string = e.ctx });
        return .{ .object = obj };
    }
};

pub const DictCompExpr = struct {
    /// `DictComp.entry` is a bare `ConfigEntry`, not a `NodeRef<ConfigEntry>`:
    /// Rust declares it `pub entry: ConfigEntry`, so the wire carries the
    /// payload inline with no `{"node": ...}` wrapper to unwrap. Wrapping it
    /// would silently decode the whole entry as empty.
    entry: dto.ConfigEntry,
    generators: std.ArrayList(*CompClauseNode) = .empty,

    fn parse(alloc: Allocator, v: Value) Error!DictCompExpr {
        return .{
            .entry = try dto.parseConfigEntryPayload(alloc, base.getField(v, "entry") orelse .null),
            .generators = try base.parseNodeRefList(alloc, base.getField(v, "generators") orelse .null, dto.CompClause, dto.CompClause.parse),
        };
    }

    fn dump(alloc: Allocator, e: DictCompExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "entry", try dto.dumpConfigEntryPayload(alloc, e.entry));
        var gens: std.json.Array = std.json.Array.init(alloc);
        for (e.generators.items) |n| {
            try gens.append(try base.dumpNodeRef(alloc, n, dto.CompClause.dump));
        }
        try obj.put(alloc, "generators", .{ .array = gens });
        return .{ .object = obj };
    }
};

pub const ConfigIfEntryExpr = struct {
    if_cond: ?*ExprNode,
    items: std.ArrayList(*ConfigEntryNode) = .empty,
    orelse_: ?*ExprNode,

    fn parse(alloc: Allocator, v: Value) Error!ConfigIfEntryExpr {
        return .{
            .if_cond = try base.parseOptionalNodeRef(alloc, base.getField(v, "if_cond") orelse .null, Expr, parseExprPayload),
            .items = try base.parseNodeRefList(alloc, base.getField(v, "items") orelse .null, dto.ConfigEntry, dto.parseConfigEntryPayload),
            .orelse_ = try base.parseOptionalNodeRef(alloc, base.getField(v, "orelse") orelse .null, Expr, parseExprPayload),
        };
    }

    fn dump(alloc: Allocator, e: ConfigIfEntryExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "if_cond", try base.dumpOptionalNodeRef(alloc, e.if_cond, dumpExprPayload));
        var items: std.json.Array = std.json.Array.init(alloc);
        for (e.items.items) |n| {
            try items.append(try base.dumpNodeRef(alloc, n, dto.dumpConfigEntryPayload));
        }
        try obj.put(alloc, "items", .{ .array = items });
        try obj.put(alloc, "orelse", try base.dumpOptionalNodeRef(alloc, e.orelse_, dumpExprPayload));
        return .{ .object = obj };
    }
};

/// `ast::SchemaExpr` — the payload of the `Schema` expression variant and of
/// `UnificationStmt.value`. Being a plain struct, the latter arrives with no
/// `"type":"Schema"` key.
pub const SchemaExpr = struct {
    name: ?*IdentifierNode,
    args: std.ArrayList(*ExprNode) = .empty,
    kwargs: std.ArrayList(*KeywordNode) = .empty,
    config: ?*ExprNode,

    pub fn parse(alloc: Allocator, v: Value) Error!SchemaExpr {
        return .{
            .name = try base.parseOptionalNodeRef(alloc, base.getField(v, "name") orelse .null, dto.Identifier, dto.Identifier.parse),
            .args = try base.parseNodeRefList(alloc, base.getField(v, "args") orelse .null, Expr, parseExprPayload),
            .kwargs = try base.parseNodeRefList(alloc, base.getField(v, "kwargs") orelse .null, dto.Keyword, dto.parseKeywordPayload),
            .config = try base.parseOptionalNodeRef(alloc, base.getField(v, "config") orelse .null, Expr, parseExprPayload),
        };
    }

    pub fn dump(alloc: Allocator, e: SchemaExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "name", try base.dumpOptionalNodeRef(alloc, e.name, dto.Identifier.dump));
        var args: std.json.Array = std.json.Array.init(alloc);
        for (e.args.items) |n| {
            try args.append(try base.dumpNodeRef(alloc, n, dumpExprPayload));
        }
        try obj.put(alloc, "args", .{ .array = args });
        var kws: std.json.Array = std.json.Array.init(alloc);
        for (e.kwargs.items) |n| {
            try kws.append(try base.dumpNodeRef(alloc, n, dto.dumpKeywordPayload));
        }
        try obj.put(alloc, "kwargs", .{ .array = kws });
        try obj.put(alloc, "config", try base.dumpOptionalNodeRef(alloc, e.config, dumpExprPayload));
        return .{ .object = obj };
    }
};

/// Payload helpers for the flat (untagged) uses of `SchemaExpr` — chiefly
/// `UnificationStmt.value`, which is a `NodeRef<SchemaExpr>` and so arrives
/// with no `"type":"Schema"` key.
pub fn parseSchemaExprPayload(alloc: Allocator, v: Value) Error!SchemaExpr {
    return SchemaExpr.parse(alloc, v);
}

pub fn dumpSchemaExprPayload(alloc: Allocator, e: SchemaExpr) Error!Value {
    return SchemaExpr.dump(alloc, e);
}

pub const ConfigExpr = struct {
    items: std.ArrayList(*ConfigEntryNode) = .empty,

    fn parse(alloc: Allocator, v: Value) Error!ConfigExpr {
        return .{
            .items = try base.parseNodeRefList(alloc, base.getField(v, "items") orelse .null, dto.ConfigEntry, dto.parseConfigEntryPayload),
        };
    }

    fn dump(alloc: Allocator, e: ConfigExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        var items: std.json.Array = std.json.Array.init(alloc);
        for (e.items.items) |n| {
            try items.append(try base.dumpNodeRef(alloc, n, dto.dumpConfigEntryPayload));
        }
        try obj.put(alloc, "items", .{ .array = items });
        return .{ .object = obj };
    }
};

pub const LambdaExpr = struct {
    args: ?*ArgumentsNode,
    /// `Vec<NodeRef<Stmt>>` in Rust — a lambda body is statements, not
    /// expressions. Routing it through the `Expr` registry would look for a
    /// tag like `"Expr"` / `"Assign"`, find nothing, and yield an `unknown`
    /// that looks like an empty tree.
    body: std.ArrayList(*stmt.StmtNode) = .empty,
    return_ty: ?*TypeNode,

    fn parse(alloc: Allocator, v: Value) Error!LambdaExpr {
        return .{
            .args = try base.parseOptionalNodeRef(alloc, base.getField(v, "args") orelse .null, dto.Arguments, dto.Arguments.parse),
            .body = try base.parseNodeRefList(alloc, base.getField(v, "body") orelse .null, stmt.Stmt, stmt.parseStmtPayload),
            .return_ty = try base.parseOptionalNodeRef(alloc, base.getField(v, "return_ty") orelse .null, types.Type, types.parseTypePayload),
        };
    }

    fn dump(alloc: Allocator, e: LambdaExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "args", try base.dumpOptionalNodeRef(alloc, e.args, dto.Arguments.dump));
        var body: std.json.Array = std.json.Array.init(alloc);
        for (e.body.items) |n| {
            try body.append(try base.dumpNodeRef(alloc, n, stmt.dumpStmtPayload));
        }
        try obj.put(alloc, "body", .{ .array = body });
        try obj.put(alloc, "return_ty", try base.dumpOptionalNodeRef(alloc, e.return_ty, types.dumpTypePayload));
        return .{ .object = obj };
    }
};

pub const SubscriptExpr = struct {
    value: ?*ExprNode,
    index: ?*ExprNode,
    lower: ?*ExprNode,
    upper: ?*ExprNode,
    step: ?*ExprNode,
    ctx: []const u8,
    has_question: bool,

    fn parse(alloc: Allocator, v: Value) Error!SubscriptExpr {
        return .{
            .value = try base.parseOptionalNodeRef(alloc, base.getField(v, "value") orelse .null, Expr, parseExprPayload),
            .index = try base.parseOptionalNodeRef(alloc, base.getField(v, "index") orelse .null, Expr, parseExprPayload),
            .lower = try base.parseOptionalNodeRef(alloc, base.getField(v, "lower") orelse .null, Expr, parseExprPayload),
            .upper = try base.parseOptionalNodeRef(alloc, base.getField(v, "upper") orelse .null, Expr, parseExprPayload),
            .step = try base.parseOptionalNodeRef(alloc, base.getField(v, "step") orelse .null, Expr, parseExprPayload),
            .ctx = base.getString(v, "ctx") orelse "",
            .has_question = base.getBool(v, "has_question") orelse false,
        };
    }

    fn dump(alloc: Allocator, e: SubscriptExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "value", try base.dumpOptionalNodeRef(alloc, e.value, dumpExprPayload));
        try obj.put(alloc, "index", try base.dumpOptionalNodeRef(alloc, e.index, dumpExprPayload));
        try obj.put(alloc, "lower", try base.dumpOptionalNodeRef(alloc, e.lower, dumpExprPayload));
        try obj.put(alloc, "upper", try base.dumpOptionalNodeRef(alloc, e.upper, dumpExprPayload));
        try obj.put(alloc, "step", try base.dumpOptionalNodeRef(alloc, e.step, dumpExprPayload));
        try obj.put(alloc, "ctx", .{ .string = e.ctx });
        try obj.put(alloc, "has_question", .{ .bool = e.has_question });
        return .{ .object = obj };
    }
};

pub const CompareExpr = struct {
    left: ?*ExprNode,
    ops: std.ArrayList([]const u8) = .empty,
    comparators: std.ArrayList(*ExprNode) = .empty,

    fn parse(alloc: Allocator, v: Value) Error!CompareExpr {
        var ops: std.ArrayList([]const u8) = .empty;
        if (base.getField(v, "ops")) |f| {
            if (f != .null) {
                const arr = try base.expectArray(f);
                for (arr.items) |item| {
                    try ops.append(alloc, try base.dupeString(alloc, try base.expectString(item)));
                }
            }
        }
        return .{
            .left = try base.parseOptionalNodeRef(alloc, base.getField(v, "left") orelse .null, Expr, parseExprPayload),
            .ops = ops,
            .comparators = try base.parseNodeRefList(alloc, base.getField(v, "comparators") orelse .null, Expr, parseExprPayload),
        };
    }

    fn dump(alloc: Allocator, e: CompareExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "left", try base.dumpOptionalNodeRef(alloc, e.left, dumpExprPayload));
        var ops: std.json.Array = std.json.Array.init(alloc);
        for (e.ops.items) |op| {
            try ops.append(.{ .string = op });
        }
        try obj.put(alloc, "ops", .{ .array = ops });
        var comps: std.json.Array = std.json.Array.init(alloc);
        for (e.comparators.items) |n| {
            try comps.append(try base.dumpNodeRef(alloc, n, dumpExprPayload));
        }
        try obj.put(alloc, "comparators", .{ .array = comps });
        return .{ .object = obj };
    }
};

pub const NumberLitExpr = struct {
    binary_suffix: ?[]const u8,
    /// The typed numeric value (`{"type": "Int"|"Float"|"Decimal",
    /// "value": ...}`) kept verbatim so arbitrary-precision literals
    /// round-trip exactly. Use `intValue` / `floatValue` for typed access.
    value: Value,

    pub fn intValue(self: *const NumberLitExpr) ?i64 {
        return switch (self.value) {
            .object => |o| switch (o.get("value") orelse .null) {
                .integer => |i| i,
                else => null,
            },
            else => null,
        };
    }

    pub fn floatValue(self: *const NumberLitExpr) ?f64 {
        return switch (self.value) {
            .object => |o| switch (o.get("value") orelse .null) {
                .float => |f| f,
                .integer => |i| @floatFromInt(i),
                else => null,
            },
            else => null,
        };
    }

    fn parse(alloc: Allocator, v: Value) Error!NumberLitExpr {
        const raw = base.getField(v, "value") orelse Value.null;
        return .{
            .binary_suffix = if (base.getString(v, "binary_suffix")) |s| try base.dupeString(alloc, s) else null,
            .value = try base.cloneValue(alloc, raw),
        };
    }

    fn dump(alloc: Allocator, e: NumberLitExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        if (e.binary_suffix) |s| {
            try obj.put(alloc, "binary_suffix", .{ .string = s });
        } else {
            try obj.put(alloc, "binary_suffix", .null);
        }
        try obj.put(alloc, "value", e.value);
        return .{ .object = obj };
    }
};

pub const StringLitExpr = struct {
    is_long_string: bool,
    raw_value: []const u8,
    value: []const u8,

    fn parse(alloc: Allocator, v: Value) Error!StringLitExpr {
        return .{
            .is_long_string = base.getBool(v, "is_long_string") orelse false,
            .raw_value = try base.dupeString(alloc, base.getString(v, "raw_value") orelse "\"\""),
            .value = try base.dupeString(alloc, base.getString(v, "value") orelse ""),
        };
    }

    fn dump(alloc: Allocator, e: StringLitExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "is_long_string", .{ .bool = e.is_long_string });
        try obj.put(alloc, "raw_value", .{ .string = e.raw_value });
        try obj.put(alloc, "value", .{ .string = e.value });
        return .{ .object = obj };
    }
};

pub const NameConstantLitExpr = struct {
    value: []const u8,

    fn parse(alloc: Allocator, v: Value) Error!NameConstantLitExpr {
        return .{
            .value = try base.dupeString(alloc, base.getString(v, "value") orelse ""),
        };
    }

    fn dump(alloc: Allocator, e: NameConstantLitExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "value", .{ .string = e.value });
        return .{ .object = obj };
    }
};

pub const JoinedStringExpr = struct {
    is_long_string: bool,
    raw_value: []const u8,
    values: std.ArrayList(*ExprNode) = .empty,

    fn parse(alloc: Allocator, v: Value) Error!JoinedStringExpr {
        return .{
            .is_long_string = base.getBool(v, "is_long_string") orelse false,
            .raw_value = try base.dupeString(alloc, base.getString(v, "raw_value") orelse "\"\""),
            .values = try base.parseNodeRefList(alloc, base.getField(v, "values") orelse .null, Expr, parseExprPayload),
        };
    }

    fn dump(alloc: Allocator, e: JoinedStringExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "is_long_string", .{ .bool = e.is_long_string });
        try obj.put(alloc, "raw_value", .{ .string = e.raw_value });
        var values: std.json.Array = std.json.Array.init(alloc);
        for (e.values.items) |n| {
            try values.append(try base.dumpNodeRef(alloc, n, dumpExprPayload));
        }
        try obj.put(alloc, "values", .{ .array = values });
        return .{ .object = obj };
    }
};

pub const FormattedValueExpr = struct {
    is_long_string: bool,
    value: ?*ExprNode,
    /// `format_spec` is a plain `Option<String>`, not a `NodeRef<Expr>`.
    format_spec: ?[]const u8,

    fn parse(alloc: Allocator, v: Value) Error!FormattedValueExpr {
        return .{
            .is_long_string = base.getBool(v, "is_long_string") orelse false,
            .value = try base.parseOptionalNodeRef(alloc, base.getField(v, "value") orelse .null, Expr, parseExprPayload),
            .format_spec = if (base.getString(v, "format_spec")) |s| try base.dupeString(alloc, s) else null,
        };
    }

    fn dump(alloc: Allocator, e: FormattedValueExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "is_long_string", .{ .bool = e.is_long_string });
        try obj.put(alloc, "value", try base.dumpOptionalNodeRef(alloc, e.value, dumpExprPayload));
        if (e.format_spec) |s| {
            try obj.put(alloc, "format_spec", .{ .string = s });
        } else {
            try obj.put(alloc, "format_spec", .null);
        }
        return .{ .object = obj };
    }
};

pub const MissingExpr = struct {
    fn parse(alloc: Allocator, v: Value) Error!MissingExpr {
        _ = alloc;
        _ = v;
        return .{};
    }

    fn dump(alloc: Allocator, e: MissingExpr) Error!Value {
        _ = alloc;
        _ = e;
        return .{ .object = .empty };
    }
};

pub const CheckExprNode = base.Node(CheckExpr);

/// Flat payload wrapper: `Schema.checks` / `Rule.checks` entries carry no
/// `"type"` discriminator on the wire, because `SchemaStmt.checks` is
/// `Vec<NodeRef<CheckExpr>>` and only the `Expr` enum is tagged. The `Expr::Check`
/// variant, which *is* tagged, uses `"Check"` — not `"CheckExpression"`; that
/// longer spelling is what `Expr::type_name_long` returns for diagnostics, not
/// the serde tag.
pub fn parseCheckExprPayload(alloc: Allocator, v: Value) Error!CheckExpr {
    return CheckExpr.parse(alloc, v);
}

pub fn dumpCheckExprPayload(alloc: Allocator, e: CheckExpr) Error!Value {
    return CheckExpr.dump(alloc, e);
}

pub const CheckExpr = struct {
    test_: ?*ExprNode,
    msg: ?*ExprNode,
    if_cond: ?*ExprNode,

    pub fn parse(alloc: Allocator, v: Value) Error!CheckExpr {
        return .{
            .test_ = try base.parseOptionalNodeRef(alloc, base.getField(v, "test") orelse .null, Expr, parseExprPayload),
            .msg = try base.parseOptionalNodeRef(alloc, base.getField(v, "msg") orelse .null, Expr, parseExprPayload),
            .if_cond = try base.parseOptionalNodeRef(alloc, base.getField(v, "if_cond") orelse .null, Expr, parseExprPayload),
        };
    }

    pub fn dump(alloc: Allocator, e: CheckExpr) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "test", try base.dumpOptionalNodeRef(alloc, e.test_, dumpExprPayload));
        try obj.put(alloc, "msg", try base.dumpOptionalNodeRef(alloc, e.msg, dumpExprPayload));
        try obj.put(alloc, "if_cond", try base.dumpOptionalNodeRef(alloc, e.if_cond, dumpExprPayload));
        return .{ .object = obj };
    }
};

// ---------------------------------------------------------------------------
// Polymorphic dispatch
// ---------------------------------------------------------------------------

pub fn parseExprPayload(alloc: Allocator, v: Value) Error!Expr {
    if (v == .null) return error.UnexpectedWireShape;
    const tag = try base.variantTag(v);
    const eql = std.mem.eql;
    if (eql(u8, tag, "Target")) return .{ .target = try dto.Target.parse(alloc, v) };
    if (eql(u8, tag, "Identifier")) return .{ .identifier = try dto.Identifier.parse(alloc, v) };
    if (eql(u8, tag, "Unary")) return .{ .unary = try UnaryExpr.parse(alloc, v) };
    if (eql(u8, tag, "Binary")) return .{ .binary = try BinaryExpr.parse(alloc, v) };
    if (eql(u8, tag, "If")) return .{ .@"if" = try IfExpr.parse(alloc, v) };
    if (eql(u8, tag, "Selector")) return .{ .selector = try SelectorExpr.parse(alloc, v) };
    if (eql(u8, tag, "Call")) return .{ .call = try CallExpr.parse(alloc, v) };
    if (eql(u8, tag, "Paren")) return .{ .paren = try ParenExpr.parse(alloc, v) };
    if (eql(u8, tag, "Quant")) return .{ .quant = try QuantExpr.parse(alloc, v) };
    if (eql(u8, tag, "List")) return .{ .list = try ListExpr.parse(alloc, v) };
    if (eql(u8, tag, "ListIfItem")) return .{ .list_if_item = try ListIfItemExpr.parse(alloc, v) };
    if (eql(u8, tag, "ListComp")) return .{ .list_comp = try ListCompExpr.parse(alloc, v) };
    if (eql(u8, tag, "Starred")) return .{ .starred = try StarredExpr.parse(alloc, v) };
    if (eql(u8, tag, "DictComp")) return .{ .dict_comp = try DictCompExpr.parse(alloc, v) };
    if (eql(u8, tag, "ConfigIfEntry")) return .{ .config_if_entry = try ConfigIfEntryExpr.parse(alloc, v) };
    if (eql(u8, tag, "CompClause")) return .{ .comp_clause = try dto.CompClause.parse(alloc, v) };
    if (eql(u8, tag, "Schema")) return .{ .schema = try SchemaExpr.parse(alloc, v) };
    if (eql(u8, tag, "Config")) return .{ .config = try ConfigExpr.parse(alloc, v) };
    if (eql(u8, tag, "Lambda")) return .{ .lambda = try LambdaExpr.parse(alloc, v) };
    if (eql(u8, tag, "Subscript")) return .{ .subscript = try SubscriptExpr.parse(alloc, v) };
    if (eql(u8, tag, "Compare")) return .{ .compare = try CompareExpr.parse(alloc, v) };
    if (eql(u8, tag, "NumberLit")) return .{ .number_lit = try NumberLitExpr.parse(alloc, v) };
    if (eql(u8, tag, "StringLit")) return .{ .string_lit = try StringLitExpr.parse(alloc, v) };
    if (eql(u8, tag, "NameConstantLit")) return .{ .name_constant_lit = try NameConstantLitExpr.parse(alloc, v) };
    if (eql(u8, tag, "JoinedString")) return .{ .joined_string = try JoinedStringExpr.parse(alloc, v) };
    if (eql(u8, tag, "FormattedValue")) return .{ .formatted_value = try FormattedValueExpr.parse(alloc, v) };
    if (eql(u8, tag, "Missing")) return .{ .missing = try MissingExpr.parse(alloc, v) };
    if (eql(u8, tag, "Check")) return .{ .check_expr = try CheckExpr.parse(alloc, v) };
    if (eql(u8, tag, "Keyword")) return .{ .keyword = try dto.Keyword.parse(alloc, v) };
    if (eql(u8, tag, "Arguments")) return .{ .arguments = try dto.Arguments.parse(alloc, v) };
    return .{
        .unknown = .{
            .tag = try base.dupeString(alloc, tag),
            .value = try base.cloneValue(alloc, v),
        },
    };
}

/// The wire tag for each variant — mirrors Rust's `Expr::type_name_long`.
pub fn exprTag(e: Expr) []const u8 {
    return switch (e) {
        .target => "Target",
        .identifier => "Identifier",
        .unary => "Unary",
        .binary => "Binary",
        .@"if" => "If",
        .selector => "Selector",
        .call => "Call",
        .paren => "Paren",
        .quant => "Quant",
        .list => "List",
        .list_if_item => "ListIfItem",
        .list_comp => "ListComp",
        .starred => "Starred",
        .dict_comp => "DictComp",
        .config_if_entry => "ConfigIfEntry",
        .comp_clause => "CompClause",
        .schema => "Schema",
        .config => "Config",
        .lambda => "Lambda",
        .subscript => "Subscript",
        .compare => "Compare",
        .number_lit => "NumberLit",
        .string_lit => "StringLit",
        .name_constant_lit => "NameConstantLit",
        .joined_string => "JoinedString",
        .formatted_value => "FormattedValue",
        .missing => "Missing",
        .check_expr => "Check",
        .keyword => "Keyword",
        .arguments => "Arguments",
        .unknown => |u| u.tag,
    };
}

pub fn dumpExprPayload(alloc: Allocator, e: Expr) Error!Value {
    const inner: Value = switch (e) {
        .target => |x| try dto.Target.dump(alloc, x),
        .identifier => |x| try dto.Identifier.dump(alloc, x),
        .unary => |x| try UnaryExpr.dump(alloc, x),
        .binary => |x| try BinaryExpr.dump(alloc, x),
        .@"if" => |x| try IfExpr.dump(alloc, x),
        .selector => |x| try SelectorExpr.dump(alloc, x),
        .call => |x| try CallExpr.dump(alloc, x),
        .paren => |x| try ParenExpr.dump(alloc, x),
        .quant => |x| try QuantExpr.dump(alloc, x),
        .list => |x| try ListExpr.dump(alloc, x),
        .list_if_item => |x| try ListIfItemExpr.dump(alloc, x),
        .list_comp => |x| try ListCompExpr.dump(alloc, x),
        .starred => |x| try StarredExpr.dump(alloc, x),
        .dict_comp => |x| try DictCompExpr.dump(alloc, x),
        .config_if_entry => |x| try ConfigIfEntryExpr.dump(alloc, x),
        .comp_clause => |x| try dto.CompClause.dump(alloc, x),
        .schema => |x| try SchemaExpr.dump(alloc, x),
        .config => |x| try ConfigExpr.dump(alloc, x),
        .lambda => |x| try LambdaExpr.dump(alloc, x),
        .subscript => |x| try SubscriptExpr.dump(alloc, x),
        .compare => |x| try CompareExpr.dump(alloc, x),
        .number_lit => |x| try NumberLitExpr.dump(alloc, x),
        .string_lit => |x| try StringLitExpr.dump(alloc, x),
        .name_constant_lit => |x| try NameConstantLitExpr.dump(alloc, x),
        .joined_string => |x| try JoinedStringExpr.dump(alloc, x),
        .formatted_value => |x| try FormattedValueExpr.dump(alloc, x),
        .missing => |x| try MissingExpr.dump(alloc, x),
        .check_expr => |x| try CheckExpr.dump(alloc, x),
        .keyword => |x| try dto.Keyword.dump(alloc, x),
        .arguments => |x| try dto.Arguments.dump(alloc, x),
        .unknown => |x| return x.value,
    };
    // Add the discriminator to the inner payload object.
    const obj = base.expectObject(inner) catch return inner;
    var out: std.json.ObjectMap = .empty;
    var it = obj.iterator();
    while (it.next()) |entry| {
        try out.put(alloc, entry.key_ptr.*, entry.value_ptr.*);
    }
    try out.put(alloc, "type", .{ .string = exprTag(e) });
    return .{ .object = out };
}
