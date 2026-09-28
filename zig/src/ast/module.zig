//! Module — the root AST node — plus the `Program` envelope returned by
//! `ParseProgramResult.ast_json`.

const std = @import("std");
const base = @import("base.zig");
const stmt = @import("stmt.zig");

const Allocator = std.mem.Allocator;
const Error = base.Error;
const Value = std.json.Value;

pub const StringNode = base.Node([]const u8);
pub const CommentNode = base.Node(Comment);
pub const StmtNode = base.Node(stmt.Stmt);

/// A line/block comment captured during parsing.
pub const Comment = struct {
    text: []const u8,

    pub fn parse(alloc: Allocator, v: Value) Error!Comment {
        const inner = base.getField(v, "text") orelse v;
        return .{
            .text = try base.dupeString(alloc, base.getString(inner, "text") orelse (switch (inner) {
                .string => |s| s,
                else => "",
            })),
        };
    }

    pub fn dump(alloc: Allocator, c: Comment) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "text", .{ .string = c.text });
        return .{ .object = obj };
    }
};

/// Top-level AST node for a single KCL file. Mirrors Rust's `ast::Module`
/// (there is deliberately no `pkg` field).
pub const Module = struct {
    filename: []const u8,
    doc: ?*StringNode,
    body: std.ArrayList(*StmtNode),
    comments: std.ArrayList(*CommentNode),

    pub fn parse(alloc: Allocator, v: Value) Error!*Module {
        const module = try alloc.create(Module);
        module.* = .{
            .filename = try base.dupeString(alloc, base.getString(v, "filename") orelse ""),
            .doc = try base.parseOptionalNodeRef(alloc, base.getField(v, "doc") orelse .null, []const u8, parseStringPayload),
            .body = try base.parseNodeRefList(alloc, base.getField(v, "body") orelse .null, stmt.Stmt, stmt.parseStmtPayload),
            .comments = try base.parseNodeRefList(alloc, base.getField(v, "comments") orelse .null, Comment, Comment.parse),
        };
        return module;
    }

    pub fn parseValue(alloc: Allocator, v: Value) Error!Module {
        return (try parse(alloc, v)).*;
    }

    /// Serialize back to the wire shape (`ast_json` compatible).
    pub fn dump(alloc: Allocator, m: *const Module) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "filename", .{ .string = m.filename });
        try obj.put(alloc, "doc", try base.dumpOptionalNodeRef(alloc, m.doc, dumpStringPayload));
        var body: std.json.Array = std.json.Array.init(alloc);
        for (m.body.items) |n| {
            try body.append(try base.dumpNodeRef(alloc, n, stmt.dumpStmtPayload));
        }
        try obj.put(alloc, "body", .{ .array = body });
        var comments: std.json.Array = std.json.Array.init(alloc);
        for (m.comments.items) |n| {
            try comments.append(try base.dumpNodeRef(alloc, n, Comment.dump));
        }
        try obj.put(alloc, "comments", .{ .array = comments });
        return .{ .object = obj };
    }

    /// Return every `SchemaStmt` in the module body — mirrors Rust's
    /// `Module::filter_schema_stmt_from_module`.
    pub fn filterSchemas(m: *const Module, alloc: Allocator) Error!std.ArrayList(*stmt.SchemaStmt) {
        var out: std.ArrayList(*stmt.SchemaStmt) = .empty;
        for (m.body.items) |wrapped| {
            switch (wrapped.node) {
                .schema => |*s| try out.append(alloc, s),
                else => {},
            }
        }
        return out;
    }
};

fn parseStringPayload(alloc: Allocator, v: Value) Error![]const u8 {
    return base.dupeString(alloc, try base.expectString(v));
}

fn dumpStringPayload(alloc: Allocator, s: []const u8) Error!Value {
    _ = alloc;
    return .{ .string = s };
}

/// A program envelope containing one or more `Module`s — the
/// `{"root": str, "pkgs": {"__main__": [Module, ...]}}` document emitted by
/// `ParseProgramResult.ast_json`.
pub const Program = struct {
    root: []const u8,
    modules: std.ArrayList(*Module),

    pub fn dump(alloc: Allocator, p: *const Program) Error!Value {
        var obj: std.json.ObjectMap = .empty;
        try obj.put(alloc, "root", .{ .string = p.root });
        var pkgs: std.json.ObjectMap = .empty;
        var main: std.json.Array = std.json.Array.init(alloc);
        for (p.modules.items) |m| {
            try main.append(try Module.dump(alloc, m));
        }
        try pkgs.put(alloc, "__main__", .{ .array = main });
        try obj.put(alloc, "pkgs", .{ .object = pkgs });
        return .{ .object = obj };
    }
};

pub fn parseModuleValue(alloc: Allocator, v: Value) Error!*Module {
    return Module.parse(alloc, v);
}

/// Handle the program JSON shapes the runtime produces: the
/// `{"root", "pkgs": {"__main__": [...]}}` envelope, a bare module list, or
/// a single module — mirroring the Python `parse_program`.
pub fn parseProgramValue(alloc: Allocator, v: Value) Error!*Program {
    const program = try alloc.create(Program);
    program.* = .{
        .root = "",
        .modules = .empty,
    };
    switch (v) {
        .array => |arr| {
            for (arr.items) |item| {
                try program.modules.append(alloc, try Module.parse(alloc, item));
            }
        },
        .object => |o| {
            if (o.get("pkgs")) |pkgs| {
                program.root = try base.dupeString(alloc, base.getString(v, "root") orelse "");
                if (base.getField(pkgs, "__main__")) |main| {
                    if (main == .null) return program;
                    const arr = try base.expectArray(main);
                    for (arr.items) |item| {
                        try program.modules.append(alloc, try Module.parse(alloc, item));
                    }
                }
                return program;
            }
            if (o.get("body") != null) {
                try program.modules.append(alloc, try Module.parse(alloc, v));
                return program;
            }
            // Legacy shape: a map keyed by filename.
            var it = o.iterator();
            while (it.next()) |entry| {
                try program.modules.append(alloc, try Module.parse(alloc, entry.value_ptr.*));
            }
        },
        else => return error.UnexpectedWireShape,
    }
    return program;
}
