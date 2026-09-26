//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;
const spec = @import("spec");

const call_buffer_size = 4 * 1024 * 1024;

/// Error prefix prepended to every error reply by the Rust dispatcher. Must
/// stay in lockstep with the `format!("ERROR:{}", ...)` literals in
/// `crates/api/src/service/capi.rs`. See `/Users/timi/codes/lib/docs/abi.md`
/// §4 for the full convention.
const ERROR_PREFIX: []const u8 = "ERROR:";

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
    // The C side copies the whole response into `result_ptr` unconditionally
    // and returns its length; the buffer size cannot be queried up front.
    // Use the same 4 MiB scratch buffer as the C and dotnet bindings and
    // return a right-sized copy.
    var buf = try allocator.alloc(u8, call_buffer_size);
    defer allocator.free(buf);
    const empty_args = [0]u8{};
    const written = call_native(
        name.ptr,
        name.len,
        if (args.len == 0) &empty_args else args.ptr,
        args.len,
        buf.ptr,
    );
    return allocator.dupe(u8, buf[0..written]);
}

/// Error set shared by the typed wrappers below. `KclRpc` is returned when
/// the native side answers with an `ERROR:`-prefixed payload (the convention
/// every other binding relies on); `MalformedResponse` when the answer is not
/// a decodable protobuf message of the expected type.
pub const Error = std.mem.Allocator.Error || std.Io.Writer.Error || error{
    KclRpc,
    MalformedResponse,
};

fn rpc(
    allocator: std.mem.Allocator,
    comptime name: []const u8,
    request: anytype,
    comptime Response: type,
) Error!Response {
    var writer: std.Io.Writer.Allocating = .init(allocator);
    defer writer.deinit();
    try request.encode(&writer.writer, allocator);
    const response_bytes = try call(allocator, name, writer.written());
    defer allocator.free(response_bytes);
    if (std.mem.startsWith(u8, response_bytes, ERROR_PREFIX)) {
        return error.KclRpc;
    }
    var reader: std.Io.Reader = .fixed(response_bytes);
    return Response.decode(&reader, allocator) catch return error.MalformedResponse;
}

/// Ping the KCL service; the result echoes back `value`. Equivalent to
/// `call(allocator, "KclService.Ping", encoded)`.
pub fn ping(allocator: std.mem.Allocator, value: []const u8) Error!spec.PingResult {
    return rpc(allocator, "KclService.Ping", spec.PingArgs{ .value = value }, spec.PingResult);
}

/// Return the KCL service version information. Equivalent to
/// `call(allocator, "KclService.GetVersion", "")`.
pub fn getVersion(allocator: std.mem.Allocator) Error!spec.GetVersionResult {
    return rpc(allocator, "KclService.GetVersion", spec.GetVersionArgs{}, spec.GetVersionResult);
}

/// Execute KCL files or inline code and return the JSON/YAML results.
/// Equivalent to `call(allocator, "KclService.ExecProgram", encoded)`.
/// Note that it is not thread safe, mirroring the spec.
pub fn execProgram(allocator: std.mem.Allocator, args: spec.ExecProgramArgs) Error!spec.ExecProgramResult {
    return rpc(allocator, "KclService.ExecProgram", args, spec.ExecProgramResult);
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

test "typed ping round-trips the value" {
    const allocator = testing.allocator;
    var result = try ping(allocator, "hello-kcl");
    defer result.deinit(allocator);
    try testing.expectEqualStrings("hello-kcl", result.value);
}

test "typed getVersion returns a version string" {
    const allocator = testing.allocator;
    var result = try getVersion(allocator);
    defer result.deinit(allocator);
    try testing.expect(result.version.len > 0);
}

test "typed execProgram runs inline kcl code" {
    const allocator = testing.allocator;
    var k_code_list: std.ArrayList([]const u8) = .empty;
    defer k_code_list.deinit(allocator);
    try k_code_list.append(allocator, "alice = {age = 18}");
    var result = try execProgram(allocator, .{ .k_code_list = k_code_list });
    defer result.deinit(allocator);
    try testing.expectEqualStrings("", result.err_message);
    try testing.expect(std.mem.indexOf(u8, result.json_result, "alice") != null);
    try testing.expect(std.mem.indexOf(u8, result.yaml_result, "age: 18") != null);
}
