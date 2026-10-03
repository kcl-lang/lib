//! KCL plugin support: host functions callable from KCL source.
//!
//! A KCL program reaches a plugin by importing the plugin module and calling
//! the method unqualified:
//!
//! ```kcl
//! import kcl_plugin.strings
//! result = strings.join("KCL", "KCL", 123)
//! ```
//!
//! The runtime resolves that to a `kcl_plugin.strings.join` call into the
//! host, so `register` only ever sees the two halves ("strings", "join").
//!
//! ```zig
//! const kcl = @import("kcl.zig");
//! const plugin = @import("plugin.zig");
//!
//! fn stringsJoin(method: []const u8, args: []const u8, kwargs: []const u8) []const u8 {
//!     _ = method; _ = args; _ = kwargs;
//!     return "\"KCL.KCL.123\"";
//! }
//!
//! var gpa: std.mem.Allocator = ...;
//! try plugin.register(gpa, "strings", "join", stringsJoin);
//! defer plugin.disable(gpa);
//! const result = try kcl.runCode(gpa, "import kcl_plugin.strings\n...");
//! ```
//!
//! Two properties are worth calling out:
//!
//! * **No JSON dependency.** Arguments arrive as raw JSON and the result must
//!   be JSON-encoded, so a method that ignores its arguments needs no parser
//!   at all. A method that inspects them can use `std.json`.
//! * **Errors are data, not crashes.** Invoking a method that was never
//!   registered yields a `{"__kcl_PanicInfo__": "..."}` object, matching what
//!   Go's `plugin.JSONError` and Python's `_call_py_method` return, so an
//!   unknown method surfaces as a KCL-level diagnostic.
//!
//! Under the hood, the first `register` binds a KCL service handle and
//! `root.call` dispatches through it. `dispatch` returns `null` while no
//! plugin is bound, which is the cue for the caller to fall back to the
//! stateless `call_native` entry point.

const std = @import("std");

// ---------------------------------------------------------------------------
// Service-handle FFI (docs/abi.md §6)
// ---------------------------------------------------------------------------

/// Opaque handle returned by `kcl_service_new`. `call_native` is stateless
/// and cannot carry a plugin agent, so the handle is the only way to reach
/// plugins from a pure-FFI binding like this one.
pub const ServiceHandle = ?*anyopaque;

extern "c" fn kcl_service_new(plugin_agent: u64) ServiceHandle;
extern "c" fn kcl_service_delete(svc: ServiceHandle) void;
extern "c" fn kcl_service_call_with_length(
    svc: ServiceHandle,
    method: [*:0]const u8,
    args: ?[*]const u8,
    args_len: usize,
    out_len: *usize,
) ?[*:0]const u8;
extern "c" fn kcl_service_free_string(ptr: [*]const u8) void;

/// A plugin method. The runtime hands over the fully-qualified method name
/// plus the positional and keyword arguments as JSON, and reads a JSON
/// encoded result back. Returning an empty slice yields an empty result.
pub const PluginMethod = *const fn (
    method: []const u8,
    args: []const u8,
    kwargs: []const u8,
) []const u8;

pub const Error = std.mem.Allocator.Error || error{
    /// `plugin` or `method` was empty.
    InvalidName,
    /// The registry is full (`max_methods` entries).
    RegistryFull,
    /// The runtime rejected the service call, e.g. an unknown RPC name.
    ServiceCallFailed,
};

const plugin_prefix = "kcl_plugin.";
const max_methods = 128;

const Entry = struct {
    name: []const u8,
    fn_ptr: PluginMethod,
};

const Registry = struct {
    gpa: std.mem.Allocator,
    entries: std.ArrayList(Entry) = .empty,
    /// Reused for every reply handed back to the runtime. The runtime parses
    /// it on return from the agent, so a single buffer is enough — and a
    /// plugin method must not hold on to the previous result.
    reply: std.ArrayList(u8) = .empty,
    handle: ServiceHandle = null,
};

/// Process-wide state. The KCL runtime is explicitly not thread safe
/// (`root.execProgram` says so too), matching every other binding, and the
/// runtime releases its own dispatch lock before calling a handler so a
/// method may trigger nested KCL evaluation.
var registry: ?Registry = null;

/// The live registry, or `null` when nothing is registered. `&registry.?`
/// would read as "address of the optional" to the `orelse` protocol, so go
/// through an explicit payload capture.
fn active() ?*Registry {
    if (registry) |*r| return r;
    return null;
}

/// The bound service handle, or `null` when no plugin is registered.
pub fn serviceHandle() ServiceHandle {
    const r = active() orelse return null;
    return r.handle;
}

/// Whether `plugin`.`method` is currently in the registry.
pub fn registered(plugin: []const u8, method: []const u8) bool {
    const r = active() orelse return false;
    return find(r, plugin, method) != null;
}

/// Add or replace `plugin`.`method`. Binds the KCL service handle on the
/// first call; register methods before evaluating any KCL, since nothing
/// evaluated before the first registration can reach the plugin.
pub fn register(gpa: std.mem.Allocator, plugin: []const u8, method: []const u8, fn_ptr: PluginMethod) Error!void {
    if (plugin.len == 0 or method.len == 0) return error.InvalidName;
    if (registry == null) registry = .{ .gpa = gpa };
    const r = &registry.?;

    if (find(r, plugin, method)) |entry| {
        entry.fn_ptr = fn_ptr;
    } else {
        if (r.entries.items.len >= max_methods) return error.RegistryFull;
        try r.entries.append(r.gpa, .{
            .name = try std.fmt.allocPrint(r.gpa, plugin_prefix ++ "{s}.{s}", .{ plugin, method }),
            .fn_ptr = fn_ptr,
        });
    }

    if (r.handle == null) {
        r.handle = kcl_service_new(@intFromPtr(&methodAgent));
    }
}

/// Unbind the service handle, empty the registry and release everything it
/// owns. Afterwards `dispatch` returns `null` again and `root.call` goes
/// back to the stateless `call_native` path.
pub fn disable(gpa: std.mem.Allocator) void {
    const r = active() orelse return;
    if (r.handle) |h| kcl_service_delete(h);
    for (r.entries.items) |entry| gpa.free(entry.name);
    r.entries.deinit(gpa);
    r.reply.deinit(gpa);
    registry = null;
}

/// Call `name` through the bound service handle, or return `null` when no
/// plugin is registered. The returned slice is owned by the caller.
pub fn dispatch(gpa: std.mem.Allocator, name: []const u8, args: []const u8) Error!?[]u8 {
    const r = active() orelse return null;
    const svc = r.handle orelse return null;

    // The runtime decodes the RPC name as a C string, so it has to be
    // NUL-terminated; Zig slices carry no terminator of their own.
    const c_name = try gpa.dupeZ(u8, name);
    defer gpa.free(c_name);

    var out_len: usize = 0;
    const reply = kcl_service_call_with_length(svc, c_name.ptr, args.ptr, args.len, &out_len) orelse
        return error.ServiceCallFailed;
    defer kcl_service_free_string(reply);

    // The reply is always NUL-terminated, but the runtime only writes
    // `out_len` on the success path — its panic branch returns an
    // "ERROR:..." string without setting it. Recover the length with
    // `strlen` in that case so the error still reaches the caller.
    const bytes = std.mem.span(reply);
    const n = if (out_len == 0) bytes.len else @min(out_len, bytes.len);
    return try gpa.dupe(u8, bytes[0..n]);
}

fn find(r: *Registry, plugin: []const u8, method: []const u8) ?*Entry {
    for (r.entries.items) |*entry| {
        if (matchesPluginMethod(entry.name, plugin, method)) return entry;
    }
    return null;
}

/// Whether `absolute` is `kcl_plugin.<plugin>.<method>`. Comparing the two
/// halves against the stored name in place keeps the agent's hot path
/// allocation-free — `++` needs a comptime-known left operand, so joining
/// the caller's two runtime slices is not an option.
fn matchesPluginMethod(absolute: []const u8, plugin: []const u8, method: []const u8) bool {
    const split = plugin_prefix.len + plugin.len;
    if (absolute.len != split + 1 + method.len) return false;
    if (!std.mem.eql(u8, absolute[0..plugin_prefix.len], plugin_prefix)) return false;
    if (absolute[split] != '.') return false;
    if (!std.mem.eql(u8, absolute[plugin_prefix.len..split], plugin)) return false;
    return std.mem.eql(u8, absolute[split + 1 ..], method);
}

/// The C entry point the runtime calls: `method` is the fully-qualified
/// plugin name, `args_json` / `kwargs_json` the JSON arguments. The reply is
/// copied into a reusable buffer because the runtime parses it as soon as
/// this function returns.
fn methodAgent(
    method: ?[*:0]const u8,
    args_json: ?[*:0]const u8,
    kwargs_json: ?[*:0]const u8,
) callconv(.c) ?[*:0]const u8 {
    const r = active() orelse return emptyZ();
    const name = if (method) |m| std.mem.span(m) else "";

    // Copy the function pointer out before calling: a method may re-enter
    // the registry (nested KCL evaluation), and holding a slice reference
    // across that call would alias a possibly reallocated list.
    var target: ?PluginMethod = null;
    for (r.entries.items) |entry| {
        if (std.mem.eql(u8, entry.name, name)) {
            target = entry.fn_ptr;
            break;
        }
    }
    const fn_ptr = target orelse return panicInfo(r, "invalid method: not found");

    const args = if (args_json) |a| std.mem.span(a) else "";
    const kwargs = if (kwargs_json) |k| std.mem.span(k) else "";
    const result = fn_ptr(name, args, kwargs);

    r.reply.clearRetainingCapacity();
    r.reply.appendSlice(r.gpa, result) catch return panicInfo(r, "out of memory building the plugin reply");
    r.reply.append(r.gpa, 0) catch return panicInfo(r, "out of memory building the plugin reply");
    // The trailing NUL above is what makes the sentinel cast sound; the
    // pointer itself stays valid until the next invocation, by which point
    // the runtime has already parsed the JSON.
    return asZ(r);
}

/// Build `{"__kcl_PanicInfo__":"<message>"}` in the shared reply buffer, the
/// same shape Go's `plugin.JSONError` and Python's `_call_py_method` produce.
fn panicInfo(r: *Registry, message: []const u8) [*:0]const u8 {
    r.reply.clearRetainingCapacity();
    r.reply.appendSlice(r.gpa, "{\"__kcl_PanicInfo__\":\"") catch return emptyZ();
    for (message) |ch| {
        switch (ch) {
            '"', '\\' => {
                r.reply.append(r.gpa, '\\') catch return emptyZ();
                r.reply.append(r.gpa, ch) catch return emptyZ();
            },
            '\n' => r.reply.appendSlice(r.gpa, "\\n") catch return emptyZ(),
            '\r' => r.reply.appendSlice(r.gpa, "\\r") catch return emptyZ(),
            '\t' => r.reply.appendSlice(r.gpa, "\\t") catch return emptyZ(),
            else => {
                if (ch < 0x20) {
                    var buf: [6]u8 = undefined;
                    _ = std.fmt.bufPrint(&buf, "\\u{x:0>4}", .{ch}) catch return emptyZ();
                    r.reply.appendSlice(r.gpa, &buf) catch return emptyZ();
                } else {
                    r.reply.append(r.gpa, ch) catch return emptyZ();
                }
            },
        }
    }
    r.reply.appendSlice(r.gpa, "\"}") catch return emptyZ();
    r.reply.append(r.gpa, 0) catch return emptyZ();
    return asZ(r);
}

/// The reply buffer as a C string. Both callers append a NUL first, so the
/// cast is sound even though `ArrayList` items carry no sentinel of their own.
fn asZ(r: *Registry) [*:0]const u8 {
    return @ptrCast(r.reply.items.ptr);
}

/// A static empty C string, so the "no registry" and allocation-failure
/// paths have something valid to return.
fn emptyZ() [*:0]const u8 {
    return "";
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;
const kcl = @import("kcl.zig");

fn stringsJoin(method: []const u8, args: []const u8, kwargs: []const u8) []const u8 {
    _ = method;
    _ = args;
    _ = kwargs;
    return "\"KCL.KCL.123\"";
}

/// Echoes its arguments back, so the test can see exactly what the runtime
/// hands a plugin method.
fn stringsArgs(method: []const u8, args: []const u8, kwargs: []const u8) []const u8 {
    _ = method;
    // A method that inspects its arguments is free to use `std.json`; here
    // string concatenation is enough to show the shape the runtime sends.
    return std.fmt.allocPrint(std.heap.page_allocator,
        \\{{"args":{s},"kwargs":{s}}}
    , .{ args, kwargs }) catch "{}";
}

test "registry is empty before the first register" {
    try testing.expect(!registered("strings", "join"));
    try testing.expect(serviceHandle() == null);
    try testing.expectEqual(@as(?[]u8, null), try dispatch(testing.allocator, "KclService.Ping", ""));
}

test "register / registered / disable" {
    const gpa = testing.allocator;
    defer disable(gpa);

    try register(gpa, "strings", "join", stringsJoin);
    try register(gpa, "strings", "args", stringsArgs);
    try testing.expect(registered("strings", "join"));
    try testing.expect(registered("strings", "args"));
    try testing.expect(!registered("strings", "missing"));
    try testing.expect(serviceHandle() != null);

    // Re-registering the same name replaces rather than duplicates.
    try register(gpa, "strings", "join", stringsJoin);
    try testing.expectEqual(@as(usize, 2), registry.?.entries.items.len);

    disable(gpa);
    try testing.expect(!registered("strings", "join"));
    try testing.expect(serviceHandle() == null);
}

test "plugin result reaches the KCL program" {
    const gpa = testing.allocator;
    defer disable(gpa);
    try register(gpa, "strings", "join", stringsJoin);

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const a = arena.allocator();

    var options = kcl.Options.init(a);
    const result = try kcl.runCode(a,
        \\import kcl_plugin.strings
        \\result = strings.join("KCL", "KCL", 123)
    , &options);
    try testing.expectEqualStrings("", result.err_message);
    try testing.expect(std.mem.indexOf(u8, result.yaml_result, "KCL.KCL.123") != null);
}

test "positional and keyword arguments arrive as JSON" {
    const gpa = testing.allocator;
    defer disable(gpa);
    try register(gpa, "strings", "args", stringsArgs);

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const a = arena.allocator();

    var options = kcl.Options.init(a);
    const result = try kcl.runCode(a,
        \\import kcl_plugin.strings
        \\result = strings.args("a", b = 2)
    , &options);
    try testing.expectEqualStrings("", result.err_message);
    // The runtime parses the plugin's JSON reply, so the JSON array and
    // object show up in the YAML output as a list item and a mapping entry.
    try testing.expect(std.mem.indexOf(u8, result.yaml_result, "- a") != null);
    try testing.expect(std.mem.indexOf(u8, result.yaml_result, "b: 2") != null);
}

test "unknown plugin method is a KCL diagnostic, not a crash" {
    const gpa = testing.allocator;
    defer disable(gpa);
    try register(gpa, "strings", "join", stringsJoin);

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const a = arena.allocator();

    var options = kcl.Options.init(a);
    const result = kcl.runCode(a,
        \\import kcl_plugin.strings
        \\result = strings.nope()
    , &options) catch |err| switch (err) {
        error.KclError => return, // expected: the PanicInfo surfaces here
        else => return err,
    };
    // Reaching this point means the runtime evaluated the call without
    // reporting an error, which would mean the unknown method silently
    // succeeded — surface the result so the failure is visible.
    try testing.expect(result.err_message.len > 0);
}

test "evaluation still works after disabling" {
    const gpa = testing.allocator;
    try register(gpa, "strings", "join", stringsJoin);
    disable(gpa);

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const a = arena.allocator();

    var options = kcl.Options.init(a);
    const result = try kcl.runCode(a, "a = 1\n", &options);
    try testing.expect(std.mem.indexOf(u8, result.yaml_result, "a: 1") != null);
}
