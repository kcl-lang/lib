//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

extern "c" fn kcl_run(filename_ptr: [*c]const u8, src_ptr: [*c]const u8) [*:0]const u8;
extern "c" fn kcl_fmt(src_ptr: [*c]const u8) [*:0]const u8;

/// Universal KCL RPC dispatcher that mirrors the C ABI in
/// `c/include/kcl_ffi.h`. The first two arguments encode the RPC name (e.g.
/// `"KclService.ExecProgram"`), the middle two encode the protobuf-encoded
/// request, and the final buffer receives the protobuf-encoded response. The
/// returned length is the number of bytes written to `result_ptr`.
extern "c" fn call_native(
    name_ptr: [*c]const u8,
    name_len: usize,
    args_ptr: [*c]const u8,
    args_len: usize,
    result_ptr: [*c]u8,
) usize;

/// Call any KCL service RPC by name. The `name` is the fully-qualified RPC
/// name (e.g. `"KclService.ExecProgram"`, `"BuiltinService.Ping"`,
/// `"BuiltinService.ListMethod"`). The `args` slice must be a protobuf-encoded
/// request message matching the RPC; the response is returned as raw
/// protobuf bytes.
///
/// This mirrors the universal dispatcher exposed by every other KCL
/// language binding (`call` in Python / Go, `callNative` in Swift / dotnet,
/// `call` in C / C++). It lets Zig callers reach the full spec surface even
/// when no typed wrapper has been generated.
pub fn call(allocator: std.mem.Allocator, name: []const u8, args: []const u8) ![]u8 {
    // The C side writes at most `args.len()` worth of bytes for a
    // request/response of comparable size. We start with that as a
    // reasonable upper bound; grow on overflow.
    var buf = try allocator.alloc(u8, args.len);
    errdefer allocator.free(buf);
    while (true) {
        const written = call_native(
            name.ptr,
            name.len,
            args.ptr,
            args.len,
            buf.ptr,
        );
        if (written <= buf.len) {
            return buf[0..written];
        }
        allocator.free(buf);
        buf = try allocator.alloc(u8, written);
    }
}

test "basic kcl run functionality" {
    const filename = "test.k";
    const source = "a = 1";
    const result = kcl_run(filename, source);
    std.debug.print("KCL Run Result: {s}\n", .{result});
}

test "basic kcl fmt functionality" {
    const source = "a = 1";
    const result = kcl_fmt(source);
    std.debug.print("KCL Fmt Result: {s}\n", .{result});
}

test "universal call dispatcher dispatches to KclService.Ping" {
    const allocator = testing.allocator;
    // `BuiltinService.Ping` is registered alongside the dispatcher in the
    // matching kcl PR but kcl-api v0.13.0 only knows about `KclService.Ping`,
    // so route the smoke test through the KclService alias that ships in
    // the released binary.
    const name = "KclService.Ping";
    // protobuf encoded PingArgs{value: "hello-kcl"} is 12 bytes long
    // (1-byte field tag + 1-byte length + 9-byte string "hello-kcl").
    const args = "\x0a\x09hello-kcl";
    const result = try call(allocator, name, args);
    defer allocator.free(result);
    try testing.expect(result.len > 0);
}
