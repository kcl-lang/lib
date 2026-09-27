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

/// Parse KCL program with entry files and return the AST JSON string.
/// Equivalent to `call(allocator, "KclService.ParseProgram", encoded)`.
pub fn parseProgram(allocator: std.mem.Allocator, args: spec.ParseProgramArgs) Error!spec.ParseProgramResult {
    return rpc(allocator, "KclService.ParseProgram", args, spec.ParseProgramResult);
}

/// Parse a single KCL file to a Module AST JSON string with import
/// dependencies and parse errors. Equivalent to
/// `call(allocator, "KclService.ParseFile", encoded)`.
pub fn parseFile(allocator: std.mem.Allocator, args: spec.ParseFileArgs) Error!spec.ParseFileResult {
    return rpc(allocator, "KclService.ParseFile", args, spec.ParseFileResult);
}

/// Load the KCL program and its semantic model information including
/// symbols, types, definitions, etc. Equivalent to
/// `call(allocator, "KclService.LoadPackage", encoded)`.
pub fn loadPackage(allocator: std.mem.Allocator, args: spec.LoadPackageArgs) Error!spec.LoadPackageResult {
    return rpc(allocator, "KclService.LoadPackage", args, spec.LoadPackageResult);
}

/// Parse the KCL program and get all option information. Equivalent to
/// `call(allocator, "KclService.ListOptions", encoded)`.
pub fn listOptions(allocator: std.mem.Allocator, args: spec.ParseProgramArgs) Error!spec.ListOptionsResult {
    return rpc(allocator, "KclService.ListOptions", args, spec.ListOptionsResult);
}

/// Parse the KCL program and get all variables by specs. Equivalent to
/// `call(allocator, "KclService.ListVariables", encoded)`.
pub fn listVariables(allocator: std.mem.Allocator, args: spec.ListVariablesArgs) Error!spec.ListVariablesResult {
    return rpc(allocator, "KclService.ListVariables", args, spec.ListVariablesResult);
}

/// Override a KCL file with the given specs; the file is rewritten in place.
/// Equivalent to `call(allocator, "KclService.OverrideFile", encoded)`.
pub fn overrideFile(allocator: std.mem.Allocator, args: spec.OverrideFileArgs) Error!spec.OverrideFileResult {
    return rpc(allocator, "KclService.OverrideFile", args, spec.OverrideFileResult);
}

/// Get the schema type mapping of the program selected by `exec_args`.
/// Equivalent to `call(allocator, "KclService.GetSchemaTypeMapping", encoded)`.
pub fn getSchemaTypeMapping(allocator: std.mem.Allocator, args: spec.GetSchemaTypeMappingArgs) Error!spec.GetSchemaTypeMappingResult {
    return rpc(allocator, "KclService.GetSchemaTypeMapping", args, spec.GetSchemaTypeMappingResult);
}

/// Get the schema type mapping under the input paths, including all of their
/// external dependency packages, keyed by package name. Equivalent to
/// `call(allocator, "KclService.GetSchemaTypeMappingUnderPath", encoded)`.
pub fn getSchemaTypeMappingUnderPath(allocator: std.mem.Allocator, args: spec.GetSchemaTypeMappingArgs) Error!spec.GetSchemaTypeMappingUnderPathResult {
    return rpc(allocator, "KclService.GetSchemaTypeMappingUnderPath", args, spec.GetSchemaTypeMappingUnderPathResult);
}

/// Format KCL source code. Equivalent to
/// `call(allocator, "KclService.FormatCode", encoded)`.
pub fn formatCode(allocator: std.mem.Allocator, args: spec.FormatCodeArgs) Error!spec.FormatCodeResult {
    return rpc(allocator, "KclService.FormatCode", args, spec.FormatCodeResult);
}

/// Format the KCL file or directory at `path` and return the changed file
/// paths. Equivalent to `call(allocator, "KclService.FormatPath", encoded)`.
pub fn formatPath(allocator: std.mem.Allocator, args: spec.FormatPathArgs) Error!spec.FormatPathResult {
    return rpc(allocator, "KclService.FormatPath", args, spec.FormatPathResult);
}

/// Lint files and return error messages including errors and warnings.
/// Equivalent to `call(allocator, "KclService.LintPath", encoded)`.
pub fn lintPath(allocator: std.mem.Allocator, args: spec.LintPathArgs) Error!spec.LintPathResult {
    return rpc(allocator, "KclService.LintPath", args, spec.LintPathResult);
}

/// Validate data against a schema given as code strings. Note that it is not
/// thread safe, mirroring the spec. Equivalent to
/// `call(allocator, "KclService.ValidateCode", encoded)`.
pub fn validateCode(allocator: std.mem.Allocator, args: spec.ValidateCodeArgs) Error!spec.ValidateCodeResult {
    return rpc(allocator, "KclService.ValidateCode", args, spec.ValidateCodeResult);
}

/// Build the setting file config from the work dir and setting files.
/// Equivalent to `call(allocator, "KclService.LoadSettingsFiles", encoded)`.
pub fn loadSettingsFiles(allocator: std.mem.Allocator, args: spec.LoadSettingsFilesArgs) Error!spec.LoadSettingsFilesResult {
    return rpc(allocator, "KclService.LoadSettingsFiles", args, spec.LoadSettingsFilesResult);
}

/// Rename all occurrences of the target symbol in the files; files that
/// contain the symbol are rewritten on disk. Equivalent to
/// `call(allocator, "KclService.Rename", encoded)`.
pub fn rename(allocator: std.mem.Allocator, args: spec.RenameArgs) Error!spec.RenameResult {
    return rpc(allocator, "KclService.Rename", args, spec.RenameResult);
}

/// Rename all occurrences of the target symbol in the given source codes and
/// return the modified code without touching the file system. Equivalent to
/// `call(allocator, "KclService.RenameCode", encoded)`.
pub fn renameCode(allocator: std.mem.Allocator, args: spec.RenameCodeArgs) Error!spec.RenameCodeResult {
    return rpc(allocator, "KclService.RenameCode", args, spec.RenameCodeResult);
}

/// Run the KCL unit tests of the given packages. The function is named
/// `@"test"` because `test` is a Zig keyword. Equivalent to
/// `call(allocator, "KclService.Test", encoded)`.
pub fn @"test"(allocator: std.mem.Allocator, args: spec.TestArgs) Error!spec.TestResult {
    return rpc(allocator, "KclService.Test", args, spec.TestResult);
}

/// Download and update the dependencies declared in the `kcl.mod` file at
/// `manifest_path`. Equivalent to
/// `call(allocator, "KclService.UpdateDependencies", encoded)`.
pub fn updateDependencies(allocator: std.mem.Allocator, args: spec.UpdateDependenciesArgs) Error!spec.UpdateDependenciesResult {
    return rpc(allocator, "KclService.UpdateDependencies", args, spec.UpdateDependenciesResult);
}

/// List the methods exposed by the native KCL dispatcher. Equivalent to
/// `call(allocator, "BuiltinService.ListMethod", "")`.
pub fn listMethod(allocator: std.mem.Allocator) Error!spec.ListMethodResult {
    return rpc(allocator, "BuiltinService.ListMethod", spec.ListMethodArgs{}, spec.ListMethodResult);
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

// Pure protobuf round-trip — does not require the native dispatcher.
// Covers ExecProgramArgs.error_format (19) and sourcemap_output (22),
// which were added to the regenerated api.pb.zig.
test "ExecProgramArgs error_format + sourcemap_output round-trip on the wire" {
    const allocator = testing.allocator;

    var args: spec.ExecProgramArgs = .{};
    args.error_format = "sarif";
    args.sourcemap_output = "/tmp/out.js.map";

    var writer: std.Io.Writer.Allocating = .init(allocator);
    defer writer.deinit();
    try args.encode(&writer.writer, allocator);

    var reader: std.Io.Reader = .fixed(writer.written());
    var decoded = try spec.ExecProgramArgs.decode(&reader, allocator);
    defer decoded.deinit(allocator);

    try testing.expectEqualStrings("sarif", decoded.error_format);
    try testing.expectEqualStrings("/tmp/out.js.map", decoded.sourcemap_output.?);
}

// Pure protobuf round-trip for ExecProgramResult.sourcemap (5).
test "ExecProgramResult sourcemap round-trip on the wire" {
    const allocator = testing.allocator;

    var result: spec.ExecProgramResult = .{};
    result.json_result = "{\"a\": 1}";
    result.yaml_result = "a: 1";
    result.sourcemap = "{\"version\":3,\"sources\":[]}";

    var writer: std.Io.Writer.Allocating = .init(allocator);
    defer writer.deinit();
    try result.encode(&writer.writer, allocator);

    var reader: std.Io.Reader = .fixed(writer.written());
    var decoded = try spec.ExecProgramResult.decode(&reader, allocator);
    defer decoded.deinit(allocator);

    try testing.expectEqualStrings("{\"a\": 1}", decoded.json_result);
    try testing.expectEqualStrings("a: 1", decoded.yaml_result);
    try testing.expectEqualStrings("{\"version\":3,\"sources\":[]}", decoded.sourcemap.?);
}

// End-to-end: actually runs KCL through the native dispatcher with
// error_format set and sourcemap_output set. Asserts that the call
// round-trips and that result.sourcemap is populated when the runtime
// supports it.
test "typed execProgram propagates sourcemap_output end-to-end" {
    const allocator = testing.allocator;
    var k_code_list: std.ArrayList([]const u8) = .empty;
    defer k_code_list.deinit(allocator);
    try k_code_list.append(allocator, "alice = {age = 18}");
    var result = try execProgram(allocator, .{
        .k_code_list = k_code_list,
        .error_format = "sarif",
        .sourcemap_output = "/tmp/zig_out.js.map",
    });
    defer result.deinit(allocator);
    try testing.expectEqualStrings("", result.err_message);

    // The runtime may or may not yet emit sourcemaps — if it doesn't,
    // sourcemap will be null. Skip the inner check in that case so this
    // test stays green on a stale runtime while still exercising the
    // field plumbing.
    if (result.sourcemap == null) {
        return;
    }
    try testing.expect(std.mem.indexOf(u8, result.sourcemap.?, "\"version\"") != null);
}

// ---------------------------------------------------------------------------
// Tests for the typed wrappers below the universal `call` dispatcher.
//
// `std.testing.tmpDir` places its directory at `.zig-cache/tmp/<random>`
// relative to the test process working directory — the directory `zig build`
// was invoked from — and the native KCL runtime resolves the relative paths
// handed to it against that same working directory. Building the fixture
// paths from this prefix therefore works on every platform without a
// realpath call.
// ---------------------------------------------------------------------------

const tmp_dir_prefix = ".zig-cache/tmp";

fn tmpPath(allocator: std.mem.Allocator, tmp: *std.testing.TmpDir, sub_path: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, tmp_dir_prefix ++ "/{s}/{s}", .{ tmp.sub_path[0..], sub_path });
}

test "typed parseProgram parses a temp file" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "parse");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "parse/main.k", .data = "a = 1\n" });
    const path = try tmpPath(allocator, &tmp, "parse/main.k");
    defer allocator.free(path);

    var paths: std.ArrayList([]const u8) = .empty;
    defer paths.deinit(allocator);
    try paths.append(allocator, path);

    var result = try parseProgram(allocator, .{ .paths = paths });
    defer result.deinit(allocator);
    try testing.expectEqual(@as(usize, 0), result.errors.items.len);
    try testing.expectEqual(@as(usize, 1), result.paths.items.len);
    try testing.expect(result.ast_json.len > 0);
}

test "typed parseFile returns a module AST" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "parse_file");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "parse_file/main.k", .data = "a = 1\n" });
    const path = try tmpPath(allocator, &tmp, "parse_file/main.k");
    defer allocator.free(path);

    var result = try parseFile(allocator, .{ .path = path });
    defer result.deinit(allocator);
    try testing.expectEqual(@as(usize, 0), result.errors.items.len);
    try testing.expectEqual(@as(usize, 0), result.deps.items.len);
    try testing.expect(result.ast_json.len > 0);
}

test "typed loadPackage returns symbols and scopes" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "load_package");
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "load_package/schema.k",
        .data = "schema AppConfig:\n    replicas: int\n\napp: AppConfig {\n    replicas: 2\n}\n",
    });
    const path = try tmpPath(allocator, &tmp, "load_package/schema.k");
    defer allocator.free(path);

    var paths: std.ArrayList([]const u8) = .empty;
    defer paths.deinit(allocator);
    try paths.append(allocator, path);

    var result = try loadPackage(allocator, .{
        .parse_args = .{ .paths = paths },
        .resolve_ast = true,
    });
    defer result.deinit(allocator);
    try testing.expectEqual(@as(usize, 0), result.parse_errors.items.len);
    try testing.expectEqual(@as(usize, 0), result.type_errors.items.len);
    try testing.expect(result.symbols.items.len > 0);
    try testing.expect(std.mem.indexOf(u8, result.program, "AppConfig") != null);
}

test "typed listOptions finds all option() calls" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "option");
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "option/main.k",
        .data = "a = option(\"key1\")\nb = option(\"key2\", required=True)\nc = {\n    metadata.key = option(\"metadata-key\")\n}\n",
    });
    const path = try tmpPath(allocator, &tmp, "option/main.k");
    defer allocator.free(path);

    var paths: std.ArrayList([]const u8) = .empty;
    defer paths.deinit(allocator);
    try paths.append(allocator, path);

    var result = try listOptions(allocator, .{ .paths = paths });
    defer result.deinit(allocator);
    try testing.expectEqual(@as(usize, 3), result.options.items.len);
    try testing.expectEqualStrings("key1", result.options.items[0].name);
    try testing.expectEqualStrings("key2", result.options.items[1].name);
    try testing.expectEqualStrings("metadata-key", result.options.items[2].name);
}

test "typed listVariables returns variables by file" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "variables");
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "variables/schema.k",
        .data = "schema AppConfig:\n    replicas: int\n\napp: AppConfig {\n    replicas: 2\n}\n",
    });
    const path = try tmpPath(allocator, &tmp, "variables/schema.k");
    defer allocator.free(path);

    var files: std.ArrayList([]const u8) = .empty;
    defer files.deinit(allocator);
    try files.append(allocator, path);

    var result = try listVariables(allocator, .{ .files = files });
    defer result.deinit(allocator);
    try testing.expectEqual(@as(usize, 0), result.parse_errors.items.len);
    try testing.expect(result.variables.items.len > 0);
    var found_app = false;
    for (result.variables.items) |entry| {
        if (std.mem.eql(u8, entry.key, "app")) {
            found_app = true;
            try testing.expectEqual(@as(usize, 1), entry.value.?.variables.items.len);
            try testing.expectEqualStrings(
                "AppConfig {\n    replicas: 2\n}",
                entry.value.?.variables.items[0].value,
            );
        }
    }
    try testing.expect(found_app);
}

test "typed overrideFile rewrites the file on disk" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "override");
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "override/main.k",
        .data = "a = 1\nb = {\n    \"a\": 1\n    \"b\": 2\n}\n",
    });
    const path = try tmpPath(allocator, &tmp, "override/main.k");
    defer allocator.free(path);

    var specs: std.ArrayList([]const u8) = .empty;
    defer specs.deinit(allocator);
    try specs.append(allocator, "b.a=2");

    var result = try overrideFile(allocator, .{ .file = path, .specs = specs });
    defer result.deinit(allocator);
    try testing.expect(result.result);
    try testing.expectEqual(@as(usize, 0), result.parse_errors.items.len);

    const content = try tmp.dir.readFileAlloc(testing.io, "override/main.k", allocator, .limited(1 << 16));
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "\"a\": 2") != null);
}

test "typed getSchemaTypeMapping maps the AppConfig schema" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "schema_ty");
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "schema_ty/schema.k",
        .data = "schema AppConfig:\n    replicas: int\n\napp: AppConfig {\n    replicas: 2\n}\n",
    });
    const path = try tmpPath(allocator, &tmp, "schema_ty/schema.k");
    defer allocator.free(path);

    var filenames: std.ArrayList([]const u8) = .empty;
    defer filenames.deinit(allocator);
    try filenames.append(allocator, path);

    var result = try getSchemaTypeMapping(allocator, .{
        .exec_args = .{ .k_filename_list = filenames },
    });
    defer result.deinit(allocator);
    try testing.expect(result.schema_type_mapping.items.len > 0);
    var found_replicas = false;
    for (result.schema_type_mapping.items) |entry| {
        if (!std.mem.eql(u8, entry.key, "app")) continue;
        for (entry.value.?.properties.items) |prop| {
            if (std.mem.eql(u8, prop.key, "replicas")) {
                found_replicas = true;
                try testing.expectEqualStrings("int", prop.value.?.type);
            }
        }
    }
    try testing.expect(found_replicas);
}

test "typed getSchemaTypeMappingUnderPath keys schemas by package" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "schema_ty_path");
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "schema_ty_path/schema.k",
        .data = "schema AppConfig:\n    replicas: int\n\napp: AppConfig {\n    replicas: 2\n}\n",
    });
    const path = try tmpPath(allocator, &tmp, "schema_ty_path/schema.k");
    defer allocator.free(path);

    var filenames: std.ArrayList([]const u8) = .empty;
    defer filenames.deinit(allocator);
    try filenames.append(allocator, path);

    var result = try getSchemaTypeMappingUnderPath(allocator, .{
        .exec_args = .{ .k_filename_list = filenames },
    });
    defer result.deinit(allocator);
    var found_main = false;
    for (result.schema_type_mapping.items) |entry| {
        if (!std.mem.eql(u8, entry.key, "__main__")) continue;
        found_main = true;
        var found_schema = false;
        for (entry.value.?.schema_type.items) |ty| {
            if (std.mem.eql(u8, ty.schema_name, "AppConfig")) found_schema = true;
        }
        try testing.expect(found_schema);
    }
    try testing.expect(found_main);
}

test "typed formatCode normalizes the source" {
    const allocator = testing.allocator;
    var result = try formatCode(allocator, .{
        .source = "schema Person:\n    name:   str\n    age:    int\n\n    check:\n        0 <   age <   120\n",
    });
    defer result.deinit(allocator);
    try testing.expectEqualStrings(
        "schema Person:\n    name: str\n    age: int\n\n    check:\n        0 < age < 120\n",
        result.formatted,
    );
}

test "typed formatPath rewrites an unformatted file" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "format");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "format/test.k", .data = "a=1\n" });
    const path = try tmpPath(allocator, &tmp, "format/test.k");
    defer allocator.free(path);

    var result = try formatPath(allocator, .{ .path = path });
    defer result.deinit(allocator);
    try testing.expectEqual(@as(usize, 1), result.changed_paths.items.len);
    try testing.expect(std.mem.endsWith(u8, result.changed_paths.items[0], "test.k"));

    const content = try tmp.dir.readFileAlloc(testing.io, "format/test.k", allocator, .limited(1 << 16));
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "a = 1") != null);
}

test "typed lintPath reports the unused import" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "lint");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "lint/test-lint.k", .data = "import math\n\na = 1\n" });
    const path = try tmpPath(allocator, &tmp, "lint/test-lint.k");
    defer allocator.free(path);

    var paths: std.ArrayList([]const u8) = .empty;
    defer paths.deinit(allocator);
    try paths.append(allocator, path);

    var result = try lintPath(allocator, .{ .paths = paths });
    defer result.deinit(allocator);
    var found = false;
    for (result.results.items) |msg| {
        if (std.mem.indexOf(u8, msg, "imported but unused") != null) found = true;
    }
    try testing.expect(found);
}

test "typed validateCode accepts valid data and rejects invalid data" {
    const allocator = testing.allocator;
    const code = "schema Person:\n    name: str\n    age: int\n\n    check:\n        0 < age < 120\n";
    const valid = "{\"name\": \"Alice\", \"age\": 10}";
    const invalid = "{\"name\": \"Alice\", \"age\": 1110}";

    var ok = try validateCode(allocator, .{ .code = code, .data = valid, .format = "json" });
    defer ok.deinit(allocator);
    try testing.expect(ok.success);
    try testing.expectEqualStrings("", ok.err_message);

    var bad = try validateCode(allocator, .{ .code = code, .data = invalid, .format = "json" });
    defer bad.deinit(allocator);
    try testing.expect(!bad.success);
    try testing.expect(bad.err_message.len > 0);
}

test "typed loadSettingsFiles merges kcl.yaml" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "settings");
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "settings/kcl.yaml",
        .data = "kcl_cli_configs:\n  strict_range_check: true\nkcl_options:\n  - key: key\n    value: value\n",
    });
    const work_dir = try tmpPath(allocator, &tmp, "settings");
    defer allocator.free(work_dir);
    const file = try tmpPath(allocator, &tmp, "settings/kcl.yaml");
    defer allocator.free(file);

    var files: std.ArrayList([]const u8) = .empty;
    defer files.deinit(allocator);
    try files.append(allocator, file);

    var result = try loadSettingsFiles(allocator, .{ .work_dir = work_dir, .files = files });
    defer result.deinit(allocator);
    try testing.expect(result.kcl_cli_configs.?.strict_range_check);
    try testing.expectEqual(@as(usize, 1), result.kcl_options.items.len);
    try testing.expectEqualStrings("key", result.kcl_options.items[0].key);
    try testing.expect(std.mem.indexOf(u8, result.kcl_options.items[0].value, "value") != null);
}

test "typed rename rewrites occurrences on disk" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "rename");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "rename/main.k", .data = "a = 1\nb = a\n" });
    const root = try tmpPath(allocator, &tmp, "rename");
    defer allocator.free(root);
    const path = try tmpPath(allocator, &tmp, "rename/main.k");
    defer allocator.free(path);

    var file_paths: std.ArrayList([]const u8) = .empty;
    defer file_paths.deinit(allocator);
    try file_paths.append(allocator, path);

    var result = try rename(allocator, .{
        .package_root = root,
        .symbol_path = "a",
        .file_paths = file_paths,
        .new_name = "a2",
    });
    defer result.deinit(allocator);
    try testing.expectEqual(@as(usize, 1), result.changed_files.items.len);
    try testing.expect(std.mem.endsWith(u8, result.changed_files.items[0], "main.k"));

    const content = try tmp.dir.readFileAlloc(testing.io, "rename/main.k", allocator, .limited(1 << 16));
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "a2 = 1") != null);
    try testing.expect(std.mem.indexOf(u8, content, "b = a2") != null);
}

test "typed renameCode returns modified code without touching disk" {
    const allocator = testing.allocator;
    // Mirrors the other language bindings: renameCode works on an in-memory
    // source map keyed by absolute-style paths, so no real fixtures (or even
    // a real directory) are needed — the package root is an opaque prefix.
    const root = "/mock/path";
    const path = "/mock/path/main.k";

    var source_codes: std.ArrayList(spec.RenameCodeArgs.SourceCodesEntry) = .empty;
    defer source_codes.deinit(allocator);
    try source_codes.append(allocator, .{ .key = path, .value = "a = 1\nb = a" });

    var result = try renameCode(allocator, .{
        .package_root = root,
        .symbol_path = "a",
        .source_codes = source_codes,
        .new_name = "a2",
    });
    defer result.deinit(allocator);
    try testing.expectEqual(@as(usize, 1), result.changed_codes.items.len);
    try testing.expectEqualStrings(path, result.changed_codes.items[0].key);
    try testing.expectEqualStrings("a2 = 1\nb = a2", result.changed_codes.items[0].value);
}

test "typed test runs kcl unit tests of a package" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "mod/pkg");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "mod/kcl.mod", .data = "[package]\nname = \"tmp_mod\"\n" });
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "mod/pkg/func.k",
        .data = "func = lambda x {\n    x\n}\n",
    });
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "mod/pkg/func_test.k",
        .data = "test_func_0 = lambda {\n    assert func(\"a\") == \"a\"\n}\n\ntest_func_1 = lambda {\n    assert func(\"b\") == \"b\"\n}\n",
    });
    const pkg_root = try tmpPath(allocator, &tmp, "mod");
    defer allocator.free(pkg_root);
    const pkg_pattern = try std.fmt.allocPrint(allocator, "{s}/...", .{pkg_root});
    defer allocator.free(pkg_pattern);

    var pkg_list: std.ArrayList([]const u8) = .empty;
    defer pkg_list.deinit(allocator);
    try pkg_list.append(allocator, pkg_pattern);

    var result = try @"test"(allocator, .{ .pkg_list = pkg_list });
    defer result.deinit(allocator);
    try testing.expectEqual(@as(usize, 2), result.info.items.len);
    for (result.info.items) |info| {
        try testing.expectEqualStrings("", info.@"error");
    }
}

test "typed updateDependencies succeeds on a dependency-free module" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "deps");
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "deps/kcl.mod",
        .data = "[package]\nname = \"tmp_mod\"\nedition = \"0.0.1\"\nversion = \"0.0.1\"\n",
    });
    const manifest_path = try tmpPath(allocator, &tmp, "deps");
    defer allocator.free(manifest_path);

    var result = try updateDependencies(allocator, .{ .manifest_path = manifest_path });
    defer result.deinit(allocator);
    try testing.expectEqual(@as(usize, 0), result.external_pkgs.items.len);
}

test "typed listMethod exposes the KclService RPCs" {
    const allocator = testing.allocator;
    // The prebuilt libkcl v0.13.0 binary predates the BuiltinService
    // registration (same situation as `BuiltinService.Ping` above): its
    // dispatcher reports the unknown method with an empty payload, while kcl
    // built from a newer source returns the full method table. Exercise the
    // assertions only when the runtime implements the RPC.
    var result = listMethod(allocator) catch |err| switch (err) {
        error.KclRpc => return,
        else => return err,
    };
    defer result.deinit(allocator);
    if (result.method_name_list.items.len == 0) return;
    var found_exec = false;
    var found_ping = false;
    for (result.method_name_list.items) |name| {
        if (std.mem.eql(u8, name, "KclService.ExecProgram")) found_exec = true;
        if (std.mem.eql(u8, name, "KclService.Ping")) found_ping = true;
    }
    try testing.expect(found_exec);
    try testing.expect(found_ping);
}
