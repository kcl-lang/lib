//! Base AST infrastructure shared by every node module: `Pos`, the generic
//! positional `Node(T)` wrapper, JSON wire helpers and the entry points
//! `parseModule` / `parseProgram`.
//!
//! The wire format is whatever the Rust compiler in `kcl-lang/kcl`
//! (`crates/ast/src/ast.rs`) emits through `ParseFileResult.ast_json` /
//! `ParseProgramResult.ast_json`:
//!
//!   - `Node<T>` serializes as `{node: <T>, filename, line, column, end_line,
//!     end_column, id?}`; `NodeRef<T>` has the identical shape.
//!   - `Stmt` / `Expr` / `Type` payloads are internally tagged
//!     (`#[serde(tag = "type")]`), so the discriminator lives at the top of
//!     the `node` object.
//!   - Struct fields are always emitted (absent children surface as explicit
//!     `null`, empty lists as `[]`, absent booleans as `false`) except for
//!     serde `skip_serializing_if` fields such as `ConfigEntry.is_shorthand`
//!     and the optional position / `id` metadata, which are omitted.
//!
//! The typed tree keeps unknown variants as raw JSON so a forward-compatible
//! program still round-trips byte-for-byte at the `std.json.Value` level.
//!
//! Memory: every node is allocated from the caller-provided allocator. Pass
//! an arena and free it once when the tree is no longer needed.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Error = std.mem.Allocator.Error || error{
    UnexpectedWireShape,
    JsonSyntax,
};

/// Source position metadata carried by every `Node(T)`. All fields mirror the
/// optional fields Rust emits alongside `node`; any of them may be absent.
pub const Pos = struct {
    filename: ?[]const u8 = null,
    line: ?i64 = null,
    column: ?i64 = null,
    end_line: ?i64 = null,
    end_column: ?i64 = null,
};

/// `Node<T>` — the positional wrapper around any AST payload, mirroring
/// Rust's `ast::Node<T>`. The optional `id` is the AST index into the symbol
/// table; the runtime omits it when unset.
pub fn Node(comptime T: type) type {
    return struct {
        node: T,
        filename: ?[]const u8 = null,
        line: ?i64 = null,
        column: ?i64 = null,
        end_line: ?i64 = null,
        end_column: ?i64 = null,
        id: ?i64 = null,

        pub const Payload = T;
    };
}

// ---------------------------------------------------------------------------
// std.json.Value helpers
// ---------------------------------------------------------------------------

pub fn expectObject(v: std.json.Value) Error!std.json.ObjectMap {
    return switch (v) {
        .object => |o| o,
        else => error.UnexpectedWireShape,
    };
}

pub fn expectArray(v: std.json.Value) Error!std.json.Array {
    return switch (v) {
        .array => |a| a,
        else => error.UnexpectedWireShape,
    };
}

pub fn expectString(v: std.json.Value) Error![]const u8 {
    return switch (v) {
        .string => |s| s,
        else => error.UnexpectedWireShape,
    };
}

/// Optional object member lookup: missing key or explicit `null` both yield
/// `null` (Rust represents absent children as `null`, never by omission,
/// except for the serde-skip fields handled explicitly by each node).
pub fn getField(v: std.json.Value, key: []const u8) ?std.json.Value {
    return switch (v) {
        .object => |o| o.get(key),
        else => null,
    };
}

pub fn getString(v: std.json.Value, key: []const u8) ?[]const u8 {
    const f = getField(v, key) orelse return null;
    return switch (f) {
        .string => |s| s,
        else => null,
    };
}

pub fn getInteger(v: std.json.Value, key: []const u8) ?i64 {
    const f = getField(v, key) orelse return null;
    return switch (f) {
        .integer => |i| i,
        else => null,
    };
}

pub fn getBool(v: std.json.Value, key: []const u8) ?bool {
    const f = getField(v, key) orelse return null;
    return switch (f) {
        .bool => |b| b,
        else => null,
    };
}

pub fn dupeString(alloc: Allocator, s: []const u8) Error![]const u8 {
    return alloc.dupe(u8, s) catch return error.OutOfMemory;
}

/// Deep-clone a `std.json.Value` so nodes own their data even when the
/// original parsed document is freed.
pub fn cloneValue(alloc: Allocator, v: std.json.Value) Error!std.json.Value {
    return switch (v) {
        .null => .null,
        .bool => |b| .{ .bool = b },
        .integer => |i| .{ .integer = i },
        .float => |f| .{ .float = f },
        .number_string => |s| .{ .number_string = try dupeString(alloc, s) },
        .string => |s| .{ .string = try dupeString(alloc, s) },
        .array => |a| blk: {
            var out: std.json.Array = std.json.Array.init(alloc);
            for (a.items) |item| {
                try out.append(try cloneValue(alloc, item));
            }
            break :blk .{ .array = out };
        },
        .object => |o| blk: {
            var out: std.json.ObjectMap = .empty;
            var it = o.iterator();
            while (it.next()) |entry| {
                try out.put(alloc, try dupeString(alloc, entry.key_ptr.*), try cloneValue(alloc, entry.value_ptr.*));
            }
            break :blk .{ .object = out };
        },
    };
}

// ---------------------------------------------------------------------------
// Node(T) wire (de)serialization
// ---------------------------------------------------------------------------

/// Parse a `NodeRef<T>`-shaped value (`{node: <T>, filename?, ...}`) into an
/// allocated `*Node(T)`. `parsePayload` resolves the polymorphic / plain
/// payload found under the `node` key.
pub fn parseNodeRef(
    alloc: Allocator,
    v: std.json.Value,
    comptime T: type,
    comptime parsePayload: anytype,
) Error!*Node(T) {
    if (v == .null) return error.UnexpectedWireShape;
    const obj = try expectObject(v);
    const payload = obj.get("node") orelse return error.UnexpectedWireShape;
    const node = try alloc.create(Node(T));
    node.* = .{
        .node = try parsePayload(alloc, payload),
        .filename = if (getString(v, "filename")) |s| try dupeString(alloc, s) else null,
        .line = getInteger(v, "line"),
        .column = getInteger(v, "column"),
        .end_line = getInteger(v, "end_line"),
        .end_column = getInteger(v, "end_column"),
        .id = getInteger(v, "id"),
    };
    return node;
}

/// Optional variant of `parseNodeRef`: `null` payloads stay `null`.
pub fn parseOptionalNodeRef(
    alloc: Allocator,
    v: std.json.Value,
    comptime T: type,
    comptime parsePayload: anytype,
) Error!?*Node(T) {
    if (v == .null) return null;
    return try parseNodeRef(alloc, v, T, parsePayload);
}

/// Serialize a `Node(T)` back to its wire shape. `dumpPayload` renders the
/// inner payload; position metadata and `id` are emitted only when present,
/// matching Rust's `skip_serializing_if` behavior.
pub fn dumpNodeRef(
    alloc: Allocator,
    node: anytype,
    comptime dumpPayload: anytype,
) Error!std.json.Value {
    var obj: std.json.ObjectMap = .empty;
    try obj.put(alloc, "node", try dumpPayload(alloc, node.node));
    if (node.filename) |s| try obj.put(alloc, "filename", .{ .string = s });
    if (node.line) |n| try obj.put(alloc, "line", .{ .integer = n });
    if (node.column) |n| try obj.put(alloc, "column", .{ .integer = n });
    if (node.end_line) |n| try obj.put(alloc, "end_line", .{ .integer = n });
    if (node.end_column) |n| try obj.put(alloc, "end_column", .{ .integer = n });
    if (node.id) |n| try obj.put(alloc, "id", .{ .integer = n });
    return .{ .object = obj };
}

/// Parse a wire list of `NodeRef<T>` (always emitted, possibly empty).
pub fn parseNodeRefList(
    alloc: Allocator,
    v: std.json.Value,
    comptime T: type,
    comptime parsePayload: anytype,
) Error!std.ArrayList(*Node(T)) {
    var out: std.ArrayList(*Node(T)) = .empty;
    if (v == .null) return out;
    const arr = try expectArray(v);
    for (arr.items) |item| {
        try out.append(alloc, try parseNodeRef(alloc, item, T, parsePayload));
    }
    return out;
}

/// Optional-node struct field: `null` → emitted as `.null` (Rust always
/// emits the key), otherwise the serialized node.
pub fn dumpOptionalNodeRef(
    alloc: Allocator,
    node: anytype,
    comptime dumpPayload: anytype,
) Error!std.json.Value {
    const n = node orelse return .null;
    return dumpNodeRef(alloc, n, dumpPayload);
}

/// Parse a repeated string list (`ArrayList([]const u8)`).
pub fn parseStringList(alloc: Allocator, v: std.json.Value) Error!std.ArrayList([]const u8) {
    var out: std.ArrayList([]const u8) = .empty;
    if (v == .null) return out;
    const arr = try expectArray(v);
    for (arr.items) |item| {
        try out.append(alloc, try dupeString(alloc, try expectString(item)));
    }
    return out;
}

/// Parse a list whose items may be explicit `null` (e.g. `Arguments.defaults`).
pub fn parseOptionalNodeRefList(
    alloc: Allocator,
    v: std.json.Value,
    comptime T: type,
    comptime parsePayload: anytype,
) Error!std.ArrayList(?*Node(T)) {
    var out: std.ArrayList(?*Node(T)) = .empty;
    if (v == .null) return out;
    const arr = try expectArray(v);
    for (arr.items) |item| {
        if (item == .null) {
            try out.append(alloc, null);
        } else {
            try out.append(alloc, try parseNodeRef(alloc, item, T, parsePayload));
        }
    }
    return out;
}

// ---------------------------------------------------------------------------
// Tagged-union (de)serialization shared machinery
// ---------------------------------------------------------------------------

/// Fallback for a not-yet-modeled variant: keeps the original tag plus the
/// full raw payload so serialization reproduces the input exactly.
pub fn RawUnknown(comptime T: type) type {
    return struct {
        tag: []const u8,
        value: T,
    };
}

/// Extract the `"type"` discriminator from a tagged payload object.
pub fn variantTag(v: std.json.Value) Error![]const u8 {
    return getString(v, "type") orelse error.UnexpectedWireShape;
}

// ---------------------------------------------------------------------------
// Entry points (declared here to avoid a dedicated module file)
// ---------------------------------------------------------------------------

const module = @import("module.zig");

pub const Module = module.Module;
pub const Program = module.Program;
pub const Comment = module.Comment;
pub const StringNode = Node([]const u8);

/// Parse an `ast_json` string from `ParseFileResult.ast_json` into a typed
/// `Module`.
pub fn parseModule(alloc: Allocator, ast_json: []const u8) Error!*Module {
    var parsed = std.json.parseFromSlice(std.json.Value, alloc, ast_json, .{}) catch return error.JsonSyntax;
    defer parsed.deinit();
    return module.parseModuleValue(alloc, parsed.value);
}

/// Parse the JSON document emitted by `ParseProgramResult.ast_json` /
/// `LoadPackageResult.program` into a `Program` envelope. Handles the
/// `{"root", "pkgs": {"__main__": [Module, ...]}}` envelope, a bare module
/// list, or a single module — mirroring the Python `parse_program`.
pub fn parseProgram(alloc: Allocator, ast_json: []const u8) Error!*Program {
    var parsed = std.json.parseFromSlice(std.json.Value, alloc, ast_json, .{}) catch return error.JsonSyntax;
    defer parsed.deinit();
    return module.parseProgramValue(alloc, parsed.value);
}
