//! Rewrites the mutually-recursive submessage fields in the freshly generated
//! `src/proto/com/kcl/api.pb.zig` to their optional-pointer form.
//!
//! protoc-gen-zig (zig-protobuf v5.0.0) emits `?*T` only for fields whose
//! type is the *same* message (direct recursion). `../spec/spec.proto` also
//! contains *mutually* recursive messages — `KclType.function` /
//! `FunctionType.return_ty` and `KclType.index_signature` /
//! `IndexSignature.key|val` — which the generator emits as by-value `?T`
//! optionals. That makes `KclType` an infinitely-sized struct which Zig
//! rejects with a "dependency loop" error as soon as the type is analyzed
//! (e.g. by decoding a `GetSchemaTypeMappingResult`).
//!
//! The zig-protobuf runtime already supports optional pointer submessage
//! fields (see the "self-referential submessage" branches in protobuf.zig and
//! wire.zig, which allocate/destroy through the field allocator), so the
//! declarations are rewritten to `?*T` here. Invoked from build.zig right
//! after the protoc + zig fmt codegen steps; idempotent, and fails loudly if
//! the generator output drifts away from the expected declarations.

const std = @import("std");

const io = std.Io.Threaded.global_single_threaded.io();

/// Path of the generated module, relative to the build root (the working
/// directory build.zig's run steps execute with).
const target_path = "src/proto/com/kcl/api.pb.zig";

const Patch = struct {
    /// Top-level `pub const <message> = struct` container the field is
    /// declared in.
    message: []const u8,
    /// Exact field declaration line emitted by protoc-gen-zig.
    before: []const u8,
    /// Same line with the field type rewritten to `?*T`.
    after: []const u8,
};

const patches = [_]Patch{
    .{
        .message = "KclType",
        .before = "    function: ?FunctionType = null,",
        .after = "    function: ?*FunctionType = null,",
    },
    .{
        .message = "KclType",
        .before = "    index_signature: ?IndexSignature = null,",
        .after = "    index_signature: ?*IndexSignature = null,",
    },
    .{
        .message = "FunctionType",
        .before = "    return_ty: ?KclType = null,",
        .after = "    return_ty: ?*KclType = null,",
    },
    .{
        .message = "IndexSignature",
        .before = "    key: ?KclType = null,",
        .after = "    key: ?*KclType = null,",
    },
    .{
        .message = "IndexSignature",
        .before = "    val: ?KclType = null,",
        .after = "    val: ?*KclType = null,",
    },
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const content = try std.Io.Dir.cwd().readFileAlloc(io, target_path, allocator, .unlimited);
    defer allocator.free(content);

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);

    var current_message: ?[]const u8 = null;
    var applied = [_]bool{false} ** patches.len;

    var start: usize = 0;
    while (true) {
        const end = std.mem.indexOfScalarPos(u8, content, start, '\n') orelse content.len;
        const line = content[start..end];

        if (std.mem.startsWith(u8, line, "pub const ")) {
            // Top-level declarations only: nested entry structs such as
            // `pub const PropertiesEntry = struct {` are indented.
            if (std.mem.indexOf(u8, line, " = struct {")) |idx| {
                current_message = line["pub const ".len..idx];
            } else {
                current_message = null;
            }
        } else if (current_message != null and std.mem.eql(u8, line, "};")) {
            current_message = null;
        }

        var emit: []const u8 = line;
        if (current_message) |message| {
            for (patches, 0..) |patch, i| {
                if (!applied[i] and std.mem.eql(u8, message, patch.message)) {
                    if (std.mem.eql(u8, line, patch.before)) {
                        emit = patch.after;
                        applied[i] = true;
                    } else if (std.mem.eql(u8, line, patch.after)) {
                        // Already patched (e.g. the patcher was run twice
                        // without protoc regenerating in between).
                        applied[i] = true;
                    }
                }
            }
        }
        try out.appendSlice(allocator, emit);

        if (end == content.len) break;
        try out.append(allocator, '\n');
        start = end + 1;
    }

    var missing: usize = 0;
    for (patches, 0..) |patch, i| {
        if (!applied[i]) {
            std.debug.print("error: {s}: expected declaration `{s}` in `{s}` was not found\n", .{ target_path, patch.before, patch.message });
            missing += 1;
        }
    }
    if (missing > 0) return error.PatchTargetNotFound;

    if (std.mem.eql(u8, content, out.items)) return;

    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = target_path, .data = out.items });
}
