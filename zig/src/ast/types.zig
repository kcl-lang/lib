//! Type hierarchy — mirrors `ast::Type` in
//! `kcl-lang/kcl/crates/ast/src/ast.rs` with the same internally-tagged
//! representation as `Expr`.
//!
//! Wire shapes verified against the v0.13.1 runtime:
//!
//!   - `Any`      → `{"type":"Any"}`
//!   - `Basic`    → `{"type":"Basic","value":"Int"}`
//!   - `List`     → `{"type":"List","value":{"inner_type":<Type>?}}`
//!   - `Dict`     → `{"type":"Dict","value":{"key_type":<Type>?,"value_type":<Type>?}}`
//!   - `Function` → `{"type":"Function","value":{"params_ty":[<Type>]|null,"ret_ty":<Type>?}}`
//!   - `Union`    → `{"type":"Union","value":{"type_elements":[<Type>]}}`
//!   - `Named`    → `{"type":"Named","value":<flat Identifier>}`
//!   - `Literal`  → `{"type":"Literal","value":{"type":"Str"|"Int"|"Float"|"Bool","value":...}}`
//!
//! Literal string/int/float/bool types (from older/other bindings) surface
//! through `Literal` in this runtime version and are kept verbatim.

const std = @import("std");
const base = @import("base.zig");
const dto = @import("dto.zig");

const Allocator = std.mem.Allocator;
const Error = base.Error;
const Value = std.json.Value;

pub const StringNode = base.Node([]const u8);
pub const TypeNode = base.Node(Type);

pub const Type = union(enum) {
    any: AnyType,
    basic: BasicType,
    list: ListType,
    dict: DictType,
    function: FunctionType,
    union_: UnionType,
    named: NamedType,
    literal: LiteralType,
    schema_ref: SchemaRefType,
    /// Forward-compatible fallback (see `expr.Expr.unknown`).
    unknown: base.RawUnknown(Value),
};

pub const AnyType = struct {
    fn parse(alloc: Allocator, v: Value) Error!AnyType {
        _ = alloc;
        _ = v;
        return .{};
    }

    fn dump(alloc: Allocator, t: AnyType) Error!Value {
        _ = alloc;
        _ = t;
        return .{ .object = .empty };
    }
};

pub const BasicType = struct {
    value: []const u8,

    fn parse(alloc: Allocator, v: Value) Error!BasicType {
        return .{
            .value = try base.dupeString(alloc, base.getString(v, "value") orelse ""),
        };
    }

    fn dump(alloc: Allocator, t: BasicType) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "value", .{ .string = t.value });
        return .{ .object = obj };
    }
};

pub const ListType = struct {
    inner_type: ?*TypeNode,

    fn parse(alloc: Allocator, v: Value) Error!ListType {
        const inner = base.getField(v, "value") orelse Value.null;
        return .{
            .inner_type = try base.parseOptionalNodeRef(alloc, base.getField(inner, "inner_type") orelse .null, Type, parseTypePayload),
        };
    }

    fn dump(alloc: Allocator, t: ListType) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        var inner: std.json.ObjectMap = .empty;
        try inner.put(alloc, "inner_type", try base.dumpOptionalNodeRef(alloc, t.inner_type, dumpTypePayload));
        try obj.put(alloc, "value", .{ .object = inner });
        return .{ .object = obj };
    }
};

pub const DictType = struct {
    key_type: ?*TypeNode,
    value_type: ?*TypeNode,

    fn parse(alloc: Allocator, v: Value) Error!DictType {
        const inner = base.getField(v, "value") orelse Value.null;
        return .{
            .key_type = try base.parseOptionalNodeRef(alloc, base.getField(inner, "key_type") orelse .null, Type, parseTypePayload),
            .value_type = try base.parseOptionalNodeRef(alloc, base.getField(inner, "value_type") orelse .null, Type, parseTypePayload),
        };
    }

    fn dump(alloc: Allocator, t: DictType) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        var inner: std.json.ObjectMap = .empty;
        try inner.put(alloc, "key_type", try base.dumpOptionalNodeRef(alloc, t.key_type, dumpTypePayload));
        try inner.put(alloc, "value_type", try base.dumpOptionalNodeRef(alloc, t.value_type, dumpTypePayload));
        try obj.put(alloc, "value", .{ .object = inner });
        return .{ .object = obj };
    }
};

pub const FunctionType = struct {
    params_ty: std.ArrayList(*TypeNode) = .empty,
    ret_ty: ?*TypeNode,

    fn parse(alloc: Allocator, v: Value) Error!FunctionType {
        const inner = base.getField(v, "value") orelse Value.null;
        var params: std.ArrayList(*TypeNode) = .empty;
        if (base.getField(inner, "params_ty")) |f| {
            if (f != .null) {
                const arr = try base.expectArray(f);
                for (arr.items) |item| {
                    try params.append(alloc, try base.parseNodeRef(alloc, item, Type, parseTypePayload));
                }
            }
        }
        return .{
            .params_ty = params,
            .ret_ty = try base.parseOptionalNodeRef(alloc, base.getField(inner, "ret_ty") orelse .null, Type, parseTypePayload),
        };
    }

    fn dump(alloc: Allocator, t: FunctionType) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        var inner: std.json.ObjectMap = .empty;
        if (t.params_ty.items.len == 0) {
            // The runtime emits an explicit `null` when there are no params.
            try inner.put(alloc, "params_ty", .null);
        } else {
            var params: std.json.Array = std.json.Array.init(alloc);
            for (t.params_ty.items) |n| {
                try params.append(try base.dumpNodeRef(alloc, n, dumpTypePayload));
            }
            try inner.put(alloc, "params_ty", .{ .array = params });
        }
        try inner.put(alloc, "ret_ty", try base.dumpOptionalNodeRef(alloc, t.ret_ty, dumpTypePayload));
        try obj.put(alloc, "value", .{ .object = inner });
        return .{ .object = obj };
    }
};

pub const UnionType = struct {
    type_elements: std.ArrayList(*TypeNode) = .empty,

    fn parse(alloc: Allocator, v: Value) Error!UnionType {
        const inner = base.getField(v, "value") orelse Value.null;
        return .{
            .type_elements = try base.parseNodeRefList(alloc, base.getField(inner, "type_elements") orelse .null, Type, parseTypePayload),
        };
    }

    fn dump(alloc: Allocator, t: UnionType) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        var inner: std.json.ObjectMap = .empty;
        var elems: std.json.Array = std.json.Array.init(alloc);
        for (t.type_elements.items) |n| {
            try elems.append(try base.dumpNodeRef(alloc, n, dumpTypePayload));
        }
        try inner.put(alloc, "type_elements", .{ .array = elems });
        try obj.put(alloc, "value", .{ .object = inner });
        return .{ .object = obj };
    }
};

pub const NamedType = struct {
    value: dto.Identifier,

    fn parse(alloc: Allocator, v: Value) Error!NamedType {
        const inner = base.getField(v, "value") orelse Value.null;
        return .{
            .value = try dto.Identifier.parse(alloc, inner),
        };
    }

    fn dump(alloc: Allocator, t: NamedType) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "value", try dto.Identifier.dump(alloc, t.value));
        return .{ .object = obj };
    }
};

pub const LiteralType = struct {
    /// The literal value object (`{"type":"Str","value":...}`) kept verbatim.
    value: Value,

    fn parse(alloc: Allocator, v: Value) Error!LiteralType {
        const raw = base.getField(v, "value") orelse Value.null;
        return .{
            .value = try base.cloneValue(alloc, raw),
        };
    }

    fn dump(alloc: Allocator, t: LiteralType) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "value", t.value);
        return .{ .object = obj };
    }
};

/// A named schema reference (`SchemaRefType`). The v0.13.1 runtime resolves
/// schema paths to `Named` instead, so this variant is provided for
/// forward compatibility and mirrors the Python shape.
pub const SchemaRefType = struct {
    schema_name: []const u8,
    pkgpath: []const u8,

    fn parse(alloc: Allocator, v: Value) Error!SchemaRefType {
        return .{
            .schema_name = try base.dupeString(alloc, base.getString(v, "schema_name") orelse ""),
            .pkgpath = try base.dupeString(alloc, base.getString(v, "pkgpath") orelse ""),
        };
    }

    fn dump(alloc: Allocator, t: SchemaRefType) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "schema_name", .{ .string = t.schema_name });
        try obj.put(alloc, "pkgpath", .{ .string = t.pkgpath });
        return .{ .object = obj };
    }
};

pub fn parseTypePayload(alloc: Allocator, v: Value) Error!Type {
    if (v == .null) return error.UnexpectedWireShape;
    const tag = try base.variantTag(v);
    const eql = std.mem.eql;
    if (eql(u8, tag, "Any")) return .{ .any = try AnyType.parse(alloc, v) };
    if (eql(u8, tag, "Basic")) return .{ .basic = try BasicType.parse(alloc, v) };
    if (eql(u8, tag, "List")) return .{ .list = try ListType.parse(alloc, v) };
    if (eql(u8, tag, "Dict")) return .{ .dict = try DictType.parse(alloc, v) };
    if (eql(u8, tag, "Function")) return .{ .function = try FunctionType.parse(alloc, v) };
    if (eql(u8, tag, "Union")) return .{ .union_ = try UnionType.parse(alloc, v) };
    if (eql(u8, tag, "Named")) return .{ .named = try NamedType.parse(alloc, v) };
    if (eql(u8, tag, "Literal")) return .{ .literal = try LiteralType.parse(alloc, v) };
    if (eql(u8, tag, "SchemaRef")) return .{ .schema_ref = try SchemaRefType.parse(alloc, v) };
    return .{
        .unknown = .{
            .tag = try base.dupeString(alloc, tag),
            .value = try base.cloneValue(alloc, v),
        },
    };
}

pub fn typeTag(t: Type) []const u8 {
    return switch (t) {
        .any => "Any",
        .basic => "Basic",
        .list => "List",
        .dict => "Dict",
        .function => "Function",
        .union_ => "Union",
        .named => "Named",
        .literal => "Literal",
        .schema_ref => "SchemaRef",
        .unknown => |u| u.tag,
    };
}

pub fn dumpTypePayload(alloc: Allocator, t: Type) Error!Value {
    const inner: Value = switch (t) {
        .any => |x| try AnyType.dump(alloc, x),
        .basic => |x| try BasicType.dump(alloc, x),
        .list => |x| try ListType.dump(alloc, x),
        .dict => |x| try DictType.dump(alloc, x),
        .function => |x| try FunctionType.dump(alloc, x),
        .union_ => |x| try UnionType.dump(alloc, x),
        .named => |x| try NamedType.dump(alloc, x),
        .literal => |x| try LiteralType.dump(alloc, x),
        .schema_ref => |x| try SchemaRefType.dump(alloc, x),
        .unknown => |x| return x.value,
    };
    const obj = base.expectObject(inner) catch return inner;
    var out: std.json.ObjectMap = .empty;
    var it = obj.iterator();
    while (it.next()) |entry| {
        try out.put(alloc, entry.key_ptr.*, entry.value_ptr.*);
    }
    try out.put(alloc, "type", .{ .string = typeTag(t) });
    return .{ .object = out };
}
