// Cross-language AST dump for the Zig binding.
//
//   hack/dump/zig.sh <golden.json> <out.json>
//
// Runs the binding's real decoder (`ast.parseModule`) and its real serializer
// (`Module.dump`) over the shared capture and writes the tree in the shape
// `hack/ast_diff/canonical.rb` compares.
//
// Zig is the one binding on this list that has a *wire* serializer rather than
// only a decoder, so this is a round-trip: decode the golden, serialize it
// back, and hand that to the comparator. That is a stronger check than the
// reflective walk the other bindings get — a bug in either direction shows up,
// and a bug that only lived in the decoder cannot hide behind a lossy dumper.
// The binding's own `src/ast_alignment_test.zig` already does exactly this, and
// this dumper calls the same two functions rather than restating them.
//
// Nothing is added to the tree: `Module.dump` emits wire keys and wire tags,
// so there is no `@cls` and no `@tag` to cross-check, and the report says the
// class check was unavailable for this binding.

const std = @import("std");
// `@import("ast")`, not `@import("ast.zig")`: the build script names the
// module (`--dep ast -Mast=zig/src/ast.zig`), and a module's import name is
// the one given to `-M`, not its file name.
const ast = @import("ast");

// Zig 0.16 hands `main` its argv and an `Io` through `std.process.Init`
// rather than through `std.process.argsAlloc`, which no longer exists. The
// arena is the one `start.zig` would have set up for a `main` that takes an
// allocator, so this is the same shape the runtime uses.
pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    const io = init.io;

    // `Args` is an iterator in 0.16, not a slice: `skip()` drops argv[0] and
    // the two `next()`s are the golden and the output path.
    var it = init.minimal.args.iterate();
    defer it.deinit();
    _ = it.skip();
    const golden_arg = it.next() orelse {
        std.debug.print("usage: hack/dump/zig.sh <golden.json> <out.json>\n", .{});
        std.process.exit(2);
    };
    const out_arg = it.next() orelse {
        std.debug.print("usage: hack/dump/zig.sh <golden.json> <out.json>\n", .{});
        std.process.exit(2);
    };
    if (it.next() != null) {
        std.debug.print("usage: hack/dump/zig.sh <golden.json> <out.json>\n", .{});
        std.process.exit(2);
    }

    const golden_src = try std.Io.Dir.cwd().readFileAlloc(io, golden_arg, a, .limited(1 << 30));

    // The binding's real decoder…
    const m = try ast.parseModule(a, golden_src);
    // …and its real serializer. `parseModule` already returns a `*Module`, so
    // `dump` is called on the pointer rather than through method syntax —
    // Zig will not implicitly dereference past one level. Between them this is
    // a round-trip, not a reflection, so the bytes the comparator sees were
    // produced by the binding and not by this file.
    const root = try ast.Module.dump(a, m);

    // The same envelope every other dumper writes, so the comparator's
    // vacuity guards (`body` and `comments` counts) apply unchanged.
    var doc: std.json.ObjectMap = .empty;
    try doc.put(a, "schema", .{ .string = "kcl-ast-canonical/1" });
    try doc.put(a, "binding", .{ .string = "zig" });
    try doc.put(a, "mode", .{ .string = "wire" });
    try doc.put(a, "root", root);

    // `std.json.Stringify` cannot print this tree. Zig 0.16 requires a
    // sentinel-terminated slice to write a JSON string, and the binding's
    // strings are plain `[]const u8` (`ast/base.zig:119` `dupeString`), so
    // every `.string` in the tree is a `[*]u8` and `Stringify.value` is a
    // compile error: "unable to stringify type '[*]u8' without sentinel".
    //
    // That is a std incompatibility, not a decode bug, and it is not the
    // binding's to be judged on here: the binding's own
    // `src/ast_alignment_test.zig` compares `Value` trees structurally with
    // `jsonEqual` and never stringifies, so nothing in its own test suite
    // reaches this. Printing is this file's job, so the writer is here — it
    // walks the binding's `Value` tree and decides nothing about what any
    // node means.
    var aw: std.Io.Writer.Allocating = .init(a);
    defer aw.deinit();
    try writeValue(&aw.writer, .{ .object = doc }, 0);
    try aw.writer.writeByte('\n');

    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = out_arg, .data = aw.written() });
}

/// Print one `std.json.Value`. Indented two spaces per level so the dump
/// reads the way the other dumpers' do; the comparator does not care, but a
/// human reading a diff does.
fn writeValue(w: *std.Io.Writer, v: std.json.Value, indent: usize) !void {
    // A fixed stack buffer, not an allocation: the AST is a few levels deep
    // and this is the whole of the indentation that is ever needed.
    var pad_buf: [64]u8 = undefined;
    var inner_buf: [64]u8 = undefined;
    const pad = pad_buf[0..2 * indent];
    const inner = inner_buf[0..2 * (indent + 1)];
    @memset(pad, ' ');
    @memset(inner, ' ');

    switch (v) {
        .null => try w.writeAll("null"),
        .bool => |b| try w.writeAll(if (b) "true" else "false"),
        .integer => |i| try w.print("{d}", .{i}),
        .float => |f| try w.print("{d}", .{f}),
        .number_string, .string => |s| try writeString(w, s),
        .array => |arr| {
            if (arr.items.len == 0) return w.writeAll("[]");
            try w.writeAll("[\n");
            for (arr.items, 0..) |item, i| {
                try w.writeAll(inner);
                try writeValue(w, item, indent + 1);
                try w.writeAll(if (i == arr.items.len - 1) "\n" else ",\n");
            }
            try w.writeAll(pad);
            try w.writeAll("]");
        },
        .object => |obj| {
            if (obj.count() == 0) return w.writeAll("{}");
            try w.writeAll("{\n");
            var it = obj.iterator();
            var i: usize = 0;
            const n = obj.count();
            while (it.next()) |entry| : (i += 1) {
                try w.writeAll(inner);
                try writeString(w, entry.key_ptr.*);
                try w.writeAll(": ");
                try writeValue(w, entry.value_ptr.*, indent + 1);
                try w.writeAll(if (i == n - 1) "\n" else ",\n");
            }
            try w.writeAll(pad);
            try w.writeAll("}");
        },
    }
}

fn writeString(w: *std.Io.Writer, s: []const u8) !void {
    try w.writeByte('"');
    for (s) |c| {
        switch (c) {
            '"' => try w.writeAll("\\\""),
            '\\' => try w.writeAll("\\\\"),
            '\n' => try w.writeAll("\\n"),
            '\r' => try w.writeAll("\\r"),
            '\t' => try w.writeAll("\\t"),
            0x08 => try w.writeAll("\\b"),
            0x0C => try w.writeAll("\\f"),
            else => {
                if (c < 0x20) {
                    try w.print("\\u{x:0>4}", .{c});
                } else {
                    try w.writeByte(c);
                }
            },
        }
    }
    try w.writeByte('"');
}
