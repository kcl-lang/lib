//! High-level `kcl` API mirroring `kcl-lang.io/kcl-go`'s `pkg/kcl` semantics
//! on top of the typed RPC wrappers in `root.zig`.
//!
//! * entry points: `run` (single file), `runFiles` (multiple files),
//!   `runCode` (inline source, via `k_code_list`)
//! * functional options via chainable `with*` builders covering the kcl-go
//!   `With*` set (`Options`)
//! * layered settings: a `kcl.yaml` file is resolved through the
//!   `LoadSettingsFiles` RPC and merged underneath the explicit options with
//!   `kcl-go`'s `Option.Merge` semantics — lists append (settings first),
//!   scalars last-wins (only "set" values propagate)
//! * `Result` with raw `yaml_result` / `json_result` / `log_message` /
//!   `err_message` access plus dotted-key `get` navigation (JSON first,
//!   minimal-YAML fallback)
//! * the kcl-go `_type` hook: with `include_schema_type_path` enabled (and
//!   `full_type_path` not set), `"pkg.Schema"` values in the emitted
//!   documents are rewritten to their short `"Schema"` form
//!
//! Errors: RPC-level failures propagate `root.Error` members; a non-empty
//! `err_message` in the exec result maps to `error.KclError` whose message
//! is available from `lastErrorMessage()` (mirroring kcl-go's
//! `(KCLResultList, error)` return).

const std = @import("std");
const root = @import("root.zig");
const spec = @import("spec");

const Allocator = std.mem.Allocator;

pub const Error = root.Error || error{
    /// The KCL program failed; see `lastErrorMessage()` for the diagnostic.
    KclError,
    /// A result document could not be parsed as JSON.
    JsonSyntax,
    /// A document had an unexpected wire shape while navigating.
    UnexpectedWireShape,
};

const testing = std.testing;

// ---------------------------------------------------------------------------
// Options
// ---------------------------------------------------------------------------

/// Mutable bag of run options; mirrors the union of fields kcl-go's `Option`
/// struct can populate. Build it with `init`, chain `with*` builders, then
/// pass it to `run` / `runFiles` / `runCode`. `deinit` frees the stored
/// copies; the strings passed to the builders are copied.
pub const Options = struct {
    alloc: Allocator,
    work_dir: ?[]const u8 = null,
    k_filename_list: std.ArrayList([]const u8) = .empty,
    k_code_list: std.ArrayList([]const u8) = .empty,
    args: std.ArrayList(spec.Argument) = .empty,
    overrides: std.ArrayList([]const u8) = .empty,
    selectors: std.ArrayList([]const u8) = .empty,
    external_pkgs: std.ArrayList(spec.ExternalPkg) = .empty,
    settings: ?[]const u8 = null,
    output_format: ?[]const u8 = null,
    error_format: ?[]const u8 = null,
    disable_none: ?bool = null,
    sort_keys: ?bool = null,
    show_hidden: ?bool = null,
    include_schema_type_path: ?bool = null,
    full_type_path: ?bool = null,
    strict_range_check: ?bool = null,
    compile_only: ?bool = null,
    fast_eval: ?bool = null,
    print_override_ast: ?bool = null,
    disable_yaml_result: ?bool = null,
    verbose: ?i32 = null,
    debug: ?bool = null,

    pub fn init(alloc: Allocator) Options {
        return .{ .alloc = alloc };
    }

    pub fn deinit(self: *Options) void {
        const a = self.alloc;
        for (self.k_filename_list.items) |s| a.free(s);
        self.k_filename_list.deinit(a);
        for (self.k_code_list.items) |s| a.free(s);
        self.k_code_list.deinit(a);
        for (self.args.items) |arg| {
            a.free(arg.name);
            a.free(arg.value);
        }
        self.args.deinit(a);
        for (self.overrides.items) |s| a.free(s);
        self.overrides.deinit(a);
        for (self.selectors.items) |s| a.free(s);
        self.selectors.deinit(a);
        for (self.external_pkgs.items) |pkg| {
            a.free(pkg.pkg_name);
            a.free(pkg.pkg_path);
        }
        self.external_pkgs.deinit(a);
        if (self.work_dir) |s| a.free(s);
        if (self.settings) |s| a.free(s);
        if (self.output_format) |s| a.free(s);
        if (self.error_format) |s| a.free(s);
    }

    fn dupe(self: *Options, s: []const u8) Error![]const u8 {
        return self.alloc.dupe(u8, s) catch return error.OutOfMemory;
    }

    /// Append an in-memory KCL source to the program (kcl-go `WithCode`).
    pub fn withCode(self: *Options, code: []const u8) *Options {
        self.k_code_list.append(self.alloc, self.dupe(code) catch return self) catch return self;
        return self;
    }

    /// Append file paths to `k_filename_list` (kcl-go `WithKFilenames`).
    pub fn withKFilenames(self: *Options, paths: []const []const u8) *Options {
        for (paths) |p| {
            self.k_filename_list.append(self.alloc, self.dupe(p) catch return self) catch return self;
        }
        return self;
    }

    /// kcl `-D key=value` options (kcl-go `WithOptions`). Entries without an
    /// `=` separator (or with an empty key) are skipped, matching kcl-go's
    /// `strings.Index(kv, "=") > 0` guard.
    pub fn withOptions(self: *Options, key_value_list: []const []const u8) *Options {
        for (key_value_list) |kv| {
            const idx = std.mem.indexOfScalar(u8, kv, '=') orelse continue;
            if (idx == 0) continue;
            self.args.append(self.alloc, .{
                .name = self.dupe(kv[0..idx]) catch return self,
                .value = self.dupe(kv[idx + 1 ..]) catch return self,
            }) catch return self;
        }
        return self;
    }

    /// kcl `-O` override specs (kcl-go `WithOverrides`).
    pub fn withOverrides(self: *Options, specs: []const []const u8) *Options {
        for (specs) |s| {
            self.overrides.append(self.alloc, self.dupe(s) catch return self) catch return self;
        }
        return self;
    }

    /// kcl `-S` path selectors (kcl-go `WithSelectors`).
    pub fn withSelectors(self: *Options, selectors: []const []const u8) *Options {
        for (selectors) |s| {
            self.selectors.append(self.alloc, self.dupe(s) catch return self) catch return self;
        }
        return self;
    }

    /// kcl `-Y` settings file (kcl-go `WithSettings`). Resolved through the
    /// `LoadSettingsFiles` RPC at exec time and merged underneath the
    /// explicit options.
    pub fn withSettings(self: *Options, filename: []const u8) *Options {
        self.settings = self.dupe(filename) catch return self;
        return self;
    }

    pub fn withWorkDir(self: *Options, dir: []const u8) *Options {
        self.work_dir = self.dupe(dir) catch return self;
        return self;
    }

    /// kcl `-E name=path` external packages (kcl-go `WithExternalPkgs`).
    pub fn withExternalPkgs(self: *Options, key_value_list: []const []const u8) *Options {
        for (key_value_list) |kv| {
            const idx = std.mem.indexOfScalar(u8, kv, '=') orelse continue;
            if (idx == 0) continue;
            self.external_pkgs.append(self.alloc, .{
                .pkg_name = self.dupe(kv[0..idx]) catch return self,
                .pkg_path = self.dupe(kv[idx + 1 ..]) catch return self,
            }) catch return self;
        }
        return self;
    }

    /// kcl-go `WithExternalPkgNameAndPath`.
    pub fn withExternalPkgNameAndPath(self: *Options, name: []const u8, path: []const u8) *Options {
        self.external_pkgs.append(self.alloc, .{
            .pkg_name = self.dupe(name) catch return self,
            .pkg_path = self.dupe(path) catch return self,
        }) catch return self;
        return self;
    }

    /// Output format selector (`"json"` / `"yaml"`) forwarded to the proto
    /// `format` field (mirrors the Python facade).
    pub fn withOutputFormat(self: *Options, format: []const u8) *Options {
        self.output_format = self.dupe(format) catch return self;
        return self;
    }

    /// Diagnostic output format (`--error_format`): one of `"pretty"`
    /// (default), `"short"`, `"arcanist"` or `"sarif"`.
    pub fn withErrorFormat(self: *Options, format: []const u8) *Options {
        self.error_format = self.dupe(format) catch return self;
        return self;
    }

    pub fn withDisableNone(self: *Options, b: bool) *Options {
        self.disable_none = b;
        return self;
    }

    pub fn withSortKeys(self: *Options, b: bool) *Options {
        self.sort_keys = b;
        return self;
    }

    pub fn withShowHidden(self: *Options, b: bool) *Options {
        self.show_hidden = b;
        return self;
    }

    pub fn withIncludeSchemaTypePath(self: *Options, b: bool) *Options {
        self.include_schema_type_path = b;
        return self;
    }

    /// kcl-go `WithFullTypePath`: requests full schema type paths —
    /// disables the `_type` short-name hook and implies
    /// `include_schema_type_path`.
    pub fn withFullTypePath(self: *Options, b: bool) *Options {
        self.full_type_path = b;
        if (b) self.include_schema_type_path = true;
        return self;
    }

    pub fn withStrictRangeCheck(self: *Options, b: bool) *Options {
        self.strict_range_check = b;
        return self;
    }

    pub fn withCompileOnly(self: *Options, b: bool) *Options {
        self.compile_only = b;
        return self;
    }

    pub fn withFastEval(self: *Options, b: bool) *Options {
        self.fast_eval = b;
        return self;
    }

    pub fn withPrintOverrideAst(self: *Options, b: bool) *Options {
        self.print_override_ast = b;
        return self;
    }

    pub fn withDisableYamlResult(self: *Options, b: bool) *Options {
        self.disable_yaml_result = b;
        return self;
    }

    pub fn withVerbose(self: *Options, level: i32) *Options {
        self.verbose = level;
        return self;
    }

    pub fn withDebug(self: *Options, b: bool) *Options {
        self.debug = b;
        return self;
    }
};

// ---------------------------------------------------------------------------
// Result
// ---------------------------------------------------------------------------

/// Wrapper around `spec.ExecProgramResult` with ergonomic access. All
/// strings are owned by the result; call `deinit` when done.
pub const Result = struct {
    alloc: Allocator,
    json_result: []const u8,
    yaml_result: []const u8,
    log_message: []const u8,
    err_message: []const u8,
    /// Effective output format selector (`"yaml"` unless overridden).
    output_format: []const u8,

    pub fn deinit(self: *Result) void {
        const a = self.alloc;
        a.free(self.json_result);
        a.free(self.yaml_result);
        a.free(self.log_message);
        a.free(self.err_message);
        a.free(self.output_format);
    }

    /// Look up `dotted` (`"a.b.c"`) in the parsed result document. JSON is
    /// preferred; when `json_result` is empty a minimal YAML reader handles
    /// the subset of YAML the KCL runtime emits. Object segments select
    /// fields; integer segments select array items. Returns `null` when the
    /// path does not resolve.
    ///
    /// `allocator` should be an arena: the returned `std.json.Value` tree is
    /// allocated from it and is not individually deinit-able.
    pub fn get(self: *const Result, allocator: Allocator, dotted: []const u8) Error!?std.json.Value {
        var doc: ?std.json.Value = null;
        if (self.json_result.len > 0) {
            doc = std.json.parseFromSliceLeaky(std.json.Value, allocator, self.json_result, .{}) catch null;
        }
        if (doc == null and self.yaml_result.len > 0) {
            doc = try yaml.parseYaml(allocator, self.yaml_result);
        }
        var current = doc orelse return null;
        var it = std.mem.splitScalar(u8, dotted, '.');
        while (it.next()) |segment| {
            switch (current) {
                .object => |o| {
                    current = o.get(segment) orelse return null;
                },
                .array => |arr| {
                    const idx = std.fmt.parseInt(usize, segment, 10) catch return null;
                    if (idx >= arr.items.len) return null;
                    current = arr.items[idx];
                },
                else => return null,
            }
        }
        return current;
    }
};

// ---------------------------------------------------------------------------
// Errors carried out of band (error unions cannot hold payloads)
// ---------------------------------------------------------------------------

threadlocal var last_error_buf: [8192]u8 = undefined;
threadlocal var last_error_len: usize = 0;

fn setLastErrorMessage(msg: []const u8) void {
    const n = @min(msg.len, last_error_buf.len);
    @memcpy(last_error_buf[0..n], msg[0..n]);
    last_error_len = n;
}

/// Message carried by the most recent `error.KclError` on this thread.
pub fn lastErrorMessage() ?[]const u8 {
    if (last_error_len == 0) return null;
    return last_error_buf[0..last_error_len];
}

// ---------------------------------------------------------------------------
// Entry points
// ---------------------------------------------------------------------------

/// Evaluate the KCL file at `path` (kcl-go `kcl.Run`).
pub fn run(allocator: Allocator, path: []const u8, options: *Options) Error!Result {
    var paths = [_][]const u8{path};
    return runFiles(allocator, &paths, options);
}

/// Evaluate multiple KCL files (kcl-go `kcl.RunFiles`).
pub fn runFiles(allocator: Allocator, paths: []const []const u8, options: *Options) Error!Result {
    var args = spec.ExecProgramArgs{};
    defer args.deinit(allocator);

    try applySettings(allocator, options, &args);
    try overlayOptions(allocator, options, &args);

    for (paths) |p| {
        try args.k_filename_list.append(allocator, try allocator.dupe(u8, p));
    }

    return exec(allocator, &args, options);
}

/// Evaluate an in-memory KCL source string (via `k_code_list`).
pub fn runCode(allocator: Allocator, code: []const u8, options: *Options) Error!Result {
    var args = spec.ExecProgramArgs{};
    defer args.deinit(allocator);

    try applySettings(allocator, options, &args);
    try overlayOptions(allocator, options, &args);

    try args.k_code_list.append(allocator, try allocator.dupe(u8, code));

    return exec(allocator, &args, options);
}

fn exec(allocator: Allocator, args: *spec.ExecProgramArgs, options: *Options) Error!Result {
    var resp = try root.execProgram(allocator, args.*);
    defer resp.deinit(allocator);

    if (resp.err_message.len > 0) {
        setLastErrorMessage(resp.err_message);
        return error.KclError;
    }

    // kcl-go typeAttributeHook: with include_schema_type_path set (and
    // full_type_path unset), rewrite "_type" values to their short form.
    const include_type = args.include_schema_type_path;
    const full_path = options.full_type_path orelse false;

    var json_result: []const u8 = undefined;
    var yaml_result: []const u8 = undefined;
    if (include_type and !full_path) {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        if (rewriteTypeAttributes(arena.allocator(), resp.json_result)) |rewritten| {
            json_result = try allocator.dupe(u8, rewritten.json);
            yaml_result = try allocator.dupe(u8, rewritten.yaml);
        } else |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            // Unparseable documents are passed through untouched, matching
            // kcl-go's hook which ignores unmarshal failures.
            else => {
                json_result = try allocator.dupe(u8, resp.json_result);
                yaml_result = try allocator.dupe(u8, resp.yaml_result);
            },
        }
    } else {
        json_result = try allocator.dupe(u8, resp.json_result);
        yaml_result = try allocator.dupe(u8, resp.yaml_result);
    }

    return .{
        .alloc = allocator,
        .json_result = json_result,
        .yaml_result = yaml_result,
        .log_message = try allocator.dupe(u8, resp.log_message),
        .err_message = try allocator.dupe(u8, resp.err_message),
        .output_format = try allocator.dupe(u8, options.output_format orelse "yaml"),
    };
}

// ---------------------------------------------------------------------------
// Settings (LoadSettingsFiles RPC) + Option.Merge overlay
// ---------------------------------------------------------------------------

/// Populate `args` from the `kcl.yaml` settings file recorded via
/// `withSettings`, resolved by the native runtime through the
/// `LoadSettingsFiles` RPC (mirrors kcl-go `settings.LoadFile` +
/// `To_ExecProgramArgs`).
fn applySettings(allocator: Allocator, options: *Options, args: *spec.ExecProgramArgs) Error!void {
    const settings_path = options.settings orelse return;
    const work_dir = options.work_dir orelse ".";

    var files: std.ArrayList([]const u8) = .empty;
    defer files.deinit(allocator);
    try files.append(allocator, settings_path);

    var result = try root.loadSettingsFiles(allocator, .{
        .work_dir = work_dir,
        .files = files,
    });
    defer result.deinit(allocator);

    const cfg = result.kcl_cli_configs orelse return;

    // Every string stored into `args` is duplicated with the exec allocator:
    // `ExecProgramArgs.deinit` frees them, and the settings result keeps its
    // own copies.
    for (cfg.files.items) |f| {
        try args.k_filename_list.append(allocator, try allocator.dupe(u8, f));
    }
    if (cfg.output.len > 0) {
        args.format = try allocator.dupe(u8, cfg.output);
    }
    for (cfg.overrides.items) |o| {
        try args.overrides.append(allocator, try allocator.dupe(u8, o));
    }
    for (cfg.path_selector.items) |s| {
        try args.path_selector.append(allocator, try allocator.dupe(u8, s));
    }
    // Boolean flags follow kcl-go's Merge: only set values propagate.
    if (cfg.strict_range_check) args.strict_range_check = true;
    if (cfg.disable_none) args.disable_none = true;
    if (cfg.sort_keys) args.sort_keys = true;
    if (cfg.show_hidden) args.show_hidden = true;
    if (cfg.include_schema_type_path) args.include_schema_type_path = true;
    if (cfg.fast_eval) args.fast_eval = true;
    if (cfg.verbose > 0) args.verbose = @intCast(cfg.verbose);
    if (cfg.debug) args.debug = 1;

    for (result.kcl_options.items) |opt| {
        try args.args.append(allocator, .{
            .name = try allocator.dupe(u8, opt.key),
            .value = try allocator.dupe(u8, opt.value),
        });
    }
}

/// Overlay the explicit `Options` on top of the settings-derived base with
/// kcl-go `Option.Merge` semantics: lists append, scalars propagate only
/// when set (booleans only when true, matching Merge's zero-value skips).
fn overlayOptions(allocator: Allocator, options: *Options, args: *spec.ExecProgramArgs) Error!void {
    if (options.work_dir) |wd| {
        if (wd.len > 0) args.work_dir = try allocator.dupe(u8, wd);
    }
    for (options.k_filename_list.items) |p| {
        try args.k_filename_list.append(allocator, try allocator.dupe(u8, p));
    }
    for (options.k_code_list.items) |c| {
        try args.k_code_list.append(allocator, try allocator.dupe(u8, c));
    }
    for (options.args.items) |arg| {
        try args.args.append(allocator, .{
            .name = try allocator.dupe(u8, arg.name),
            .value = try allocator.dupe(u8, arg.value),
        });
    }
    for (options.overrides.items) |o| {
        try args.overrides.append(allocator, try allocator.dupe(u8, o));
    }
    for (options.selectors.items) |s| {
        try args.path_selector.append(allocator, try allocator.dupe(u8, s));
    }
    for (options.external_pkgs.items) |pkg| {
        try args.external_pkgs.append(allocator, .{
            .pkg_name = try allocator.dupe(u8, pkg.pkg_name),
            .pkg_path = try allocator.dupe(u8, pkg.pkg_path),
        });
    }
    if (options.output_format) |f| {
        if (f.len > 0) args.format = try allocator.dupe(u8, f);
    }
    if (options.error_format) |f| {
        if (f.len > 0) args.error_format = try allocator.dupe(u8, f);
    }
    if (options.disable_none) |b| {
        if (b) args.disable_none = true;
    }
    if (options.sort_keys) |b| {
        if (b) args.sort_keys = true;
    }
    if (options.show_hidden) |b| {
        if (b) args.show_hidden = true;
    }
    if (options.include_schema_type_path) |b| {
        if (b) args.include_schema_type_path = true;
    }
    if (options.strict_range_check) |b| {
        if (b) args.strict_range_check = true;
    }
    if (options.compile_only) |b| {
        if (b) args.compile_only = true;
    }
    if (options.fast_eval) |b| {
        if (b) args.fast_eval = true;
    }
    if (options.print_override_ast) |b| {
        if (b) args.print_override_ast = true;
    }
    if (options.disable_yaml_result) |b| {
        if (b) args.disable_yaml_result = true;
    }
    if (options.verbose) |v| {
        if (v > 0) args.verbose = v;
    }
    if (options.debug) |b| {
        if (b) args.debug = 1;
    }
}

// ---------------------------------------------------------------------------
// `_type` attribute hook (kcl-go hook.go)
// ---------------------------------------------------------------------------

const RewriteResult = struct {
    json: []const u8,
    yaml: []const u8,
};

fn rewriteTypeAttributes(a: Allocator, json_result: []const u8) Error!RewriteResult {
    const parsed = std.json.parseFromSlice(std.json.Value, a, json_result, .{}) catch return error.JsonSyntax;
    modifyType(parsed.value);
    var json_out: std.Io.Writer.Allocating = .init(a);
    try std.json.Stringify.value(parsed.value, .{}, &json_out.writer);

    // Regenerate the YAML mirror from the modified document, mirroring
    // kcl-go's yaml.Marshal over the generic map (keys sorted).
    var yaml_out: std.Io.Writer.Allocating = .init(a);
    try yaml.writeYamlDocument(parsed.value, &yaml_out.writer);

    return .{
        .json = try json_out.toOwnedSlice(),
        .yaml = try yaml_out.toOwnedSlice(),
    };
}

/// Recursively rewrite every `"_type"` string to its last `.`-separated
/// segment, mirroring `modifyType` in kcl-go's hook.go.
fn modifyType(v: std.json.Value) void {
    switch (v) {
        .object => |o| {
            var it = o.iterator();
            while (it.next()) |entry| {
                if (std.mem.eql(u8, entry.key_ptr.*, "_type")) {
                    if (entry.value_ptr.* == .string) {
                        const s = entry.value_ptr.*.string;
                        if (std.mem.lastIndexOfScalar(u8, s, '.')) |idx| {
                            entry.value_ptr.* = .{ .string = s[idx + 1 ..] };
                        }
                    }
                } else {
                    modifyType(entry.value_ptr.*);
                }
            }
        },
        .array => |arr| {
            for (arr.items) |item| modifyType(item);
        },
        else => {},
    }
}

// ---------------------------------------------------------------------------
// Minimal YAML support (documents the KCL runtime emits)
// ---------------------------------------------------------------------------

pub const yaml = struct {
    /// Parse the subset of YAML the KCL runtime emits: block mappings and
    /// sequences with two-space indentation, `---` document separators and
    /// plain/quoted scalars. Returns the first document.
    pub fn parseYaml(a: Allocator, text: []const u8) Error!std.json.Value {
        var lines: std.ArrayList([]const u8) = .empty;
        defer lines.deinit(a);
        var doc_lines: std.ArrayList([]const u8) = .empty;
        defer doc_lines.deinit(a);

        var it = std.mem.splitScalar(u8, text, '\n');
        while (it.next()) |line| {
            try lines.append(a, line);
        }
        // Take lines up to the first `---` separator (single-document view).
        for (lines.items) |line| {
            if (std.mem.eql(u8, std.mem.trim(u8, line, " \t\r"), "---")) break;
            try doc_lines.append(a, line);
        }
        var pos: usize = 0;
        return parseBlock(a, doc_lines.items, &pos, 0);
    }

    fn parseBlock(a: Allocator, lines: []const []const u8, pos: *usize, indent: usize) Error!std.json.Value {
        // Skip blank lines.
        while (pos.* < lines.len and std.mem.trim(u8, lines[pos.*], " \t\r").len == 0) {
            pos.* += 1;
        }
        if (pos.* >= lines.len) return .null;

        const first = lines[pos.*];
        const first_indent = countIndent(first);
        if (first_indent < indent) return .null;
        const trimmed = std.mem.trim(u8, first[first_indent..], " \t\r");
        if (std.mem.startsWith(u8, trimmed, "- ")) {
            return parseSeq(a, lines, pos, first_indent);
        }
        if (std.mem.indexOfScalar(u8, trimmed, ':') != null) {
            return parseMap(a, lines, pos, first_indent);
        }
        pos.* += 1;
        return scalarValue(a, trimmed);
    }

    fn parseSeq(a: Allocator, lines: []const []const u8, pos: *usize, indent: usize) Error!std.json.Value {
        var arr: std.json.Array = std.json.Array.init(a);
        while (pos.* < lines.len) {
            const line = lines[pos.*];
            if (std.mem.trim(u8, line, " \t\r").len == 0) {
                pos.* += 1;
                continue;
            }
            const line_indent = countIndent(line);
            if (line_indent != indent) break;
            const trimmed = std.mem.trim(u8, line[line_indent..], " \t\r");
            if (!std.mem.startsWith(u8, trimmed, "-")) break;
            const rest = std.mem.trim(u8, trimmed[1..], " \t\r");
            if (rest.len == 0) {
                pos.* += 1;
                const child = try parseBlock(a, lines, pos, indent + 1);
                try arr.append(child);
            } else if (std.mem.indexOfScalar(u8, rest, ':') != null) {
                // Inline map start: rewrite the line as a map line and parse.
                pos.* += 1;
                var sub: std.json.ObjectMap = .empty;
                const consumed = try parseInlineMapEntry(a, lines, pos, indent, rest, &sub);
                _ = consumed;
                try arr.append(.{ .object = sub });
            } else {
                pos.* += 1;
                try arr.append(scalarValue(a, rest));
            }
        }
        return .{ .array = arr };
    }

    fn parseMap(a: Allocator, lines: []const []const u8, pos: *usize, indent: usize) Error!std.json.Value {
        var obj: std.json.ObjectMap = .empty;
        while (pos.* < lines.len) {
            const line = lines[pos.*];
            if (std.mem.trim(u8, line, " \t\r").len == 0) {
                pos.* += 1;
                continue;
            }
            const line_indent = countIndent(line);
            if (line_indent != indent) break;
            const trimmed = std.mem.trim(u8, line[line_indent..], " \t\r");
            const colon = std.mem.indexOfScalar(u8, trimmed, ':') orelse break;
            const key = std.mem.trim(u8, trimmed[0..colon], " \t\r\"'");
            pos.* += 1;
            const value_text = std.mem.trim(u8, trimmed[colon + 1 ..], " \t\r");
            if (value_text.len > 0) {
                try obj.put(a, try a.dupe(u8, key), scalarValue(a, value_text));
            } else {
                const child = try parseBlock(a, lines, pos, indent + 1);
                try obj.put(a, try a.dupe(u8, key), child);
            }
        }
        return .{ .object = obj };
    }

    fn parseInlineMapEntry(a: Allocator, lines: []const []const u8, pos: *usize, indent: usize, first: []const u8, obj: *std.json.ObjectMap) Error!void {
        const colon = std.mem.indexOfScalar(u8, first, ':').?;
        const key = std.mem.trim(u8, first[0..colon], " \t\r\"'");
        const value_text = std.mem.trim(u8, first[colon + 1 ..], " \t\r");
        if (value_text.len > 0) {
            try obj.put(a, try a.dupe(u8, key), scalarValue(a, value_text));
        } else {
            const child = try parseBlock(a, lines, pos, indent + 2);
            try obj.put(a, try a.dupe(u8, key), child);
        }
        // Consume any additional entries of the same inline map.
        while (pos.* < lines.len) {
            const line = lines[pos.*];
            if (std.mem.trim(u8, line, " \t\r").len == 0) {
                pos.* += 1;
                continue;
            }
            const line_indent = countIndent(line);
            if (line_indent <= indent) break;
            const trimmed = std.mem.trim(u8, line[line_indent..], " \t\r");
            const colon2 = std.mem.indexOfScalar(u8, trimmed, ':') orelse break;
            const key2 = std.mem.trim(u8, trimmed[0..colon2], " \t\r\"'");
            pos.* += 1;
            const value_text2 = std.mem.trim(u8, trimmed[colon2 + 1 ..], " \t\r");
            if (value_text2.len > 0) {
                try obj.put(a, try a.dupe(u8, key2), scalarValue(a, value_text2));
            } else {
                const child2 = try parseBlock(a, lines, pos, line_indent + 1);
                try obj.put(a, try a.dupe(u8, key2), child2);
            }
        }
    }

    fn writeIndent(writer: *std.Io.Writer, indent: usize) Error!void {
        var i: usize = 0;
        while (i < indent) : (i += 1) {
            try writer.writeByte(' ');
        }
    }

    fn countIndent(line: []const u8) usize {
        var n: usize = 0;
        while (n < line.len and line[n] == ' ') n += 1;
        return n;
    }

    fn scalarValue(a: Allocator, raw: []const u8) std.json.Value {
        _ = a;
        if (raw.len == 0) return .null;
        if (std.mem.eql(u8, raw, "null") or std.mem.eql(u8, raw, "~")) return .null;
        if (std.mem.eql(u8, raw, "true")) return .{ .bool = true };
        if (std.mem.eql(u8, raw, "false")) return .{ .bool = false };
        if (raw[0] == '"' and raw[raw.len - 1] == '"' and raw.len >= 2) {
            return .{ .string = raw[1 .. raw.len - 1] };
        }
        if (raw[0] == '\'' and raw[raw.len - 1] == '\'' and raw.len >= 2) {
            return .{ .string = raw[1 .. raw.len - 1] };
        }
        if (std.fmt.parseInt(i64, raw, 10)) |i| {
            return .{ .integer = i };
        } else |_| {}
        if (std.fmt.parseFloat(f64, raw)) |f| {
            return .{ .float = f };
        } else |_| {}
        return .{ .string = raw };
    }

    /// Serialize a `std.json.Value` back to the block-style YAML subset,
    /// with mapping keys sorted (matching kcl-go's yaml.v3 regeneration in
    /// the `_type` hook).
    pub fn writeYamlDocument(v: std.json.Value, writer: *std.Io.Writer) Error!void {
        try writeYamlValue(v, writer, 0);
        try writer.writeAll("\n");
    }

    fn writeYamlValue(v: std.json.Value, writer: *std.Io.Writer, indent: usize) Error!void {
        switch (v) {
            .object => |o| {
                if (o.count() == 0) {
                    try writer.writeAll("{}\n");
                    return;
                }
                var keys: std.ArrayList([]const u8) = .empty;
                defer keys.deinit(std.heap.page_allocator);
                var it = o.iterator();
                while (it.next()) |entry| {
                    try keys.append(std.heap.page_allocator, entry.key_ptr.*);
                }
                std.mem.sort([]const u8, keys.items, {}, struct {
                    fn lt(_: void, x: []const u8, y: []const u8) bool {
                        return std.mem.order(u8, x, y) == .lt;
                    }
                }.lt);
                for (keys.items) |k| {
                    try writeIndent(writer, indent);
                    try writer.print("{s}:", .{k});
                    const child = o.get(k).?;
                    if (isScalar(child)) {
                        try writer.writeAll(" ");
                        try writeYamlScalar(child, writer);
                        try writer.writeAll("\n");
                    } else {
                        try writer.writeAll("\n");
                        try writeYamlValue(child, writer, indent + 2);
                    }
                }
            },
            .array => |arr| {
                if (arr.items.len == 0) {
                    try writer.writeAll("[]\n");
                    return;
                }
                for (arr.items) |item| {
                    try writeIndent(writer, indent);
                    try writer.writeAll("-");
                    if (isScalar(item)) {
                        try writer.writeAll(" ");
                        try writeYamlScalar(item, writer);
                        try writer.writeAll("\n");
                    } else {
                        try writer.writeAll("\n");
                        try writeYamlValue(item, writer, indent + 2);
                    }
                }
            },
            else => {
                try writeYamlScalar(v, writer);
                try writer.writeAll("\n");
            },
        }
    }

    fn isScalar(v: std.json.Value) bool {
        return switch (v) {
            .object, .array => false,
            else => true,
        };
    }

    fn writeYamlScalar(v: std.json.Value, writer: *std.Io.Writer) Error!void {
        switch (v) {
            .null => try writer.writeAll("null"),
            .bool => |b| try writer.writeAll(if (b) "true" else "false"),
            .integer => |i| try writer.print("{d}", .{i}),
            .float => |f| try writer.print("{d}", .{f}),
            .number_string => |s| try writer.print("{s}", .{s}),
            .string => |s| try writeYamlString(s, writer),
            else => {},
        }
    }

    fn writeYamlString(s: []const u8, writer: *std.Io.Writer) Error!void {
        if (needsYamlQuotes(s)) {
            try writer.writeAll("\"");
            for (s) |c| {
                switch (c) {
                    '"' => try writer.writeAll("\\\""),
                    '\\' => try writer.writeAll("\\\\"),
                    '\n' => try writer.writeAll("\\n"),
                    else => try writer.writeByte(c),
                }
            }
            try writer.writeAll("\"");
        } else {
            try writer.writeAll(s);
        }
    }

    fn needsYamlQuotes(s: []const u8) bool {
        if (s.len == 0) return true;
        const special = "{}[]#&*!|>'\"%@`?:, ";
        if (std.mem.indexOfScalar(u8, special, s[0]) != null) return true;
        if (std.mem.eql(u8, s, "null") or std.mem.eql(u8, s, "true") or std.mem.eql(u8, s, "false") or std.mem.eql(u8, s, "~")) return true;
        if (std.fmt.parseInt(i64, s, 10)) |_| {
            return true;
        } else |_| {}
        if (std.fmt.parseFloat(f64, s)) |_| {
            return true;
        } else |_| {}
        return false;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "run executes a single file and navigates the result" {
    const allocator = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const nav_alloc = arena.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "kcl_run");
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "kcl_run/main.k",
        .data = "alice = {age = 18, address = {city = \"Springfield\"}}\n",
    });
    const path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/kcl_run/main.k", .{tmp.sub_path[0..]});
    defer allocator.free(path);

    var options = Options.init(allocator);
    defer options.deinit();
    var result = try run(allocator, path, &options);
    defer result.deinit();

    try testing.expectEqualStrings("", result.err_message);
    const age = (try result.get(nav_alloc, "alice.age")).?;
    try testing.expectEqual(@as(i64, 18), age.integer);
    const city = (try result.get(nav_alloc, "alice.address.city")).?;
    try testing.expectEqualStrings("Springfield", city.string);
    try testing.expect((try result.get(nav_alloc, "alice.missing")) == null);
}

test "runCode evaluates inline source" {
    const allocator = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var options = Options.init(allocator);
    defer options.deinit();

    var result = try runCode(allocator, "bob = 42", &options);
    defer result.deinit();
    const v = (try result.get(arena.allocator(), "bob")).?;
    try testing.expectEqual(@as(i64, 42), v.integer);
}

test "run returns error.KclError with the err_message" {
    const allocator = testing.allocator;
    var options = Options.init(allocator);
    defer options.deinit();

    try testing.expectError(error.KclError, runCode(allocator, "assert False, \"boom\"", &options));
    const msg = lastErrorMessage().?;
    try testing.expect(std.mem.indexOf(u8, msg, "boom") != null);

    // Compile errors surface through the RPC-layer error convention.
    try testing.expectError(error.KclRpc, runCode(allocator, "a = b +", &options));
}

test "withOptions parses -D key=value pairs" {
    const allocator = testing.allocator;
    var options = Options.init(allocator);
    defer options.deinit();
    _ = options.withOptions(&.{ "env=prod", "replicas=3", "bad", "=x" });

    try testing.expectEqual(@as(usize, 2), options.args.items.len);
    try testing.expectEqualStrings("env", options.args.items[0].name);
    try testing.expectEqualStrings("prod", options.args.items[0].value);
    try testing.expectEqualStrings("replicas", options.args.items[1].name);
}

test "run applies -D options and -O overrides" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "kcl_opts");
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "kcl_opts/main.k",
        .data = "env = option(\"env\")\nreplicas = option(\"replicas\", default=1)\nname = \"app\"\n",
    });
    const path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/kcl_opts/main.k", .{tmp.sub_path[0..]});
    defer allocator.free(path);

    var options = Options.init(allocator);
    defer options.deinit();
    _ = options.withOptions(&.{ "env=prod", "replicas=3" });
    _ = options.withOverrides(&.{"name=\"bob\""});

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const nav_alloc = arena.allocator();

    var result = try run(allocator, path, &options);
    defer result.deinit();
    try testing.expectEqualStrings("prod", (try result.get(nav_alloc, "env")).?.string);
    try testing.expectEqual(@as(i64, 3), (try result.get(nav_alloc, "replicas")).?.integer);
    try testing.expectEqualStrings("bob", (try result.get(nav_alloc, "name")).?.string);
}

test "settings file merges under explicit options (kcl-go Option.Merge)" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "kcl_settings");
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "kcl_settings/kcl.yaml",
        .data = "kcl_cli_configs:\n  files:\n    - main.k\n  overrides:\n    - name=from-settings\n  sort_keys: true\nkcl_options:\n  - key: env\n    value: from-settings\n",
    });
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "kcl_settings/main.k",
        .data = "env = option(\"env\", default=\"unset\")\nname = \"app\"\nz = 1\na = 2\n",
    });
    const work_dir = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/kcl_settings", .{tmp.sub_path[0..]});
    defer allocator.free(work_dir);
    const settings_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/kcl_settings/kcl.yaml", .{tmp.sub_path[0..]});
    defer allocator.free(settings_path);

    var options = Options.init(allocator);
    defer options.deinit();
    _ = options.withSettings(settings_path);
    _ = options.withWorkDir(work_dir);
    // Explicit option overrides the settings value.
    _ = options.withOptions(&.{"env=explicit"});
    // Explicit override appends after the settings override (last wins in
    // the runtime).
    _ = options.withOverrides(&.{"name=from-explicit"});

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const nav_alloc = arena.allocator();

    var result = try runFiles(allocator, &.{}, &options);
    defer result.deinit();
    try testing.expectEqualStrings("explicit", (try result.get(nav_alloc, "env")).?.string);
    try testing.expectEqualStrings("from-explicit", (try result.get(nav_alloc, "name")).?.string);
}

test "include_schema_type_path rewrites _type to the short form" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "kcl_type");
    // A relative import gives the schema a package path, so the runtime
    // emits the full `"person.Person"` type path.
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "kcl_type/person.k",
        .data = "schema Person:\n    name: str\n",
    });
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = "kcl_type/main.k",
        .data = "import .person\n\np = person.Person {name = \"Alice\"}\n",
    });
    const path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/kcl_type/main.k", .{tmp.sub_path[0..]});
    defer allocator.free(path);

    var options = Options.init(allocator);
    defer options.deinit();
    _ = options.withIncludeSchemaTypePath(true);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const nav_alloc = arena.allocator();

    var result = try run(allocator, path, &options);
    defer result.deinit();
    const ty = (try result.get(nav_alloc, "p._type")).?;
    try testing.expectEqualStrings("Person", ty.string);
    try testing.expect(std.mem.indexOf(u8, result.yaml_result, "_type: Person") != null);

    // With full_type_path the rewrite is disabled.
    var full = Options.init(allocator);
    defer full.deinit();
    _ = full.withFullTypePath(true);

    var full_result = try run(allocator, path, &full);
    defer full_result.deinit();
    const full_ty = (try full_result.get(nav_alloc, "p._type")).?;
    try testing.expectEqualStrings("person.Person", full_ty.string);
}

test "get falls back to minimal YAML when json_result is empty" {
    const allocator = testing.allocator;
    var options = Options.init(allocator);
    defer options.deinit();
    _ = options.withDisableYamlResult(true);
    _ = options.withOutputFormat("json");

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var result = try runCode(allocator, "a = {b = {c = 7}}\n", &options);
    defer result.deinit();
    const v = (try result.get(arena.allocator(), "a.b.c")).?;
    try testing.expectEqual(@as(i64, 7), v.integer);
}

test "yaml round-trip handles nested structures" {
    const allocator = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\top:
        \\  list:
        \\    - 1
        \\    - two
        \\  flag: true
        \\  nothing: null
        \\
    ;
    const v = try yaml.parseYaml(a, text);
    const list = v.object.get("top").?.object.get("list").?.array;
    try testing.expectEqual(@as(usize, 2), list.items.len);
    try testing.expectEqual(@as(i64, 1), list.items[0].integer);
    try testing.expectEqualStrings("two", list.items[1].string);
    try testing.expectEqual(true, v.object.get("top").?.object.get("flag").?.bool);
    try testing.expect(v.object.get("top").?.object.get("nothing").? == .null);
}
