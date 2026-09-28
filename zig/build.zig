const std = @import("std");
const builtin = @import("builtin");
const protobuf = @import("protobuf");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const protobuf_dep = b.dependency("protobuf", .{
        .target = target,
        .optimize = optimize,
    });

    const gen_spec_step = addSpecProtoCodegen(b, protobuf_dep);

    const spec_module = b.createModule(.{
        .root_source_file = b.path("src/proto/com/kcl/api.pb.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    spec_module.addImport("protobuf", protobuf_dep.module("protobuf"));

    const lib = b.addLibrary(.{
        .name = "kcl_lib_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });

    linkNativeKcl(b, lib.root_module, &target);
    lib.root_module.addImport("spec", spec_module);
    lib.step.dependOn(gen_spec_step);

    // Options shared by the test steps below (fixture paths etc.).
    const test_options = b.addOptions();
    test_options.addOption(
        []const u8,
        "ast_alignment_fixture",
        b.pathResolve(&.{ b.build_root.path orelse ".", "test_data", "ast_alignment", "main.k" }),
    );

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    linkNativeKcl(b, lib_unit_tests.root_module, &target);
    lib_unit_tests.root_module.addImport("spec", spec_module);
    lib_unit_tests.step.dependOn(gen_spec_step);

    // High-level kcl API tests (src/kcl.zig).
    const kcl_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/kcl.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    linkNativeKcl(b, kcl_unit_tests.root_module, &target);
    kcl_unit_tests.root_module.addImport("spec", spec_module);
    kcl_unit_tests.step.dependOn(gen_spec_step);

    // Typed AST package tests (src/ast.zig) + the alignment test against
    // the runtime-emitted ast_json (tests/ast_alignment.zig).
    const ast_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ast.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });

    const ast_alignment_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ast_alignment_test.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    linkNativeKcl(b, ast_alignment_tests.root_module, &target);
    ast_alignment_tests.root_module.addImport("spec", spec_module);
    ast_alignment_tests.root_module.addOptions("test_options", test_options);
    ast_alignment_tests.step.dependOn(gen_spec_step);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const run_kcl_unit_tests = b.addRunArtifact(kcl_unit_tests);
    const run_ast_unit_tests = b.addRunArtifact(ast_unit_tests);
    const run_ast_alignment_tests = b.addRunArtifact(ast_alignment_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_kcl_unit_tests.step);
    test_step.dependOn(&run_ast_unit_tests.step);
    test_step.dependOn(&run_ast_alignment_tests.step);
}

/// Wires a module so it can link the prebuilt native `libkcl` and call the
/// C FFI dispatcher: libc/libc++, the platform library path, the system
/// library itself and the platform-specific system libraries.
fn linkNativeKcl(b: *std.Build, module: *std.Build.Module, target: *const std.Build.ResolvedTarget) void {
    const os = target.query.os_tag orelse builtin.os.tag;
    module.link_libc = true;
    module.link_libcpp = true;
    module.addLibraryPath(kclLibPath(b, target));
    module.linkSystemLibrary(kclLibName(), .{});
    if (os == .windows) {
        linkWindowsLibraries(module);
    } else if (os == .macos) {
        linkMacOSLibraries(module);
    }
}

// Generates the typed protobuf bindings in `src/proto` from
// `../spec/spec.proto` using zig-protobuf's `protoc-gen-zig` plugin and the
// system `protoc`, then patches the mutually-recursive `KclType` fields that
// protoc-gen-zig cannot represent (see `tools/fix_pb_mutual_recursion.zig`).
// Regenerated on every build; `zig build gen-proto` runs only these steps.
fn addSpecProtoCodegen(b: *std.Build, protobuf_dep: *std.Build.Dependency) *std.Build.Step {
    const protoc_gen_zig = b.addExecutable(.{
        .name = "protoc-gen-zig",
        .root_module = b.createModule(.{
            .root_source_file = protobuf_dep.path("bootstrapped-generator/main.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });
    protoc_gen_zig.root_module.addImport("protobuf", protobuf_dep.module("protobuf"));

    const destination_directory = b.pathResolve(&.{ b.build_root.path orelse ".", "src", "proto" });
    // protoc does not create a missing --zig_out directory itself.
    std.Io.Dir.cwd().createDirPath(b.graph.io, destination_directory) catch {};

    const protoc = b.addSystemCommand(&.{"protoc"});
    protoc.addPrefixedFileArg("--plugin=protoc-gen-zig=", protoc_gen_zig.getEmittedBin());
    protoc.addArg("--zig_out");
    protoc.addArg(destination_directory);
    protoc.addArg("-I");
    protoc.addDirectoryArg(b.path("../spec"));
    protoc.addFileArg(b.path("../spec/spec.proto"));

    const fmt = b.addSystemCommand(&.{ b.graph.zig_exe, "fmt", destination_directory });
    fmt.step.dependOn(&protoc.step);

    const fix_pb_mutual_recursion = b.addExecutable(.{
        .name = "fix_pb_mutual_recursion",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/fix_pb_mutual_recursion.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });
    const run_fix = b.addRunArtifact(fix_pb_mutual_recursion);
    run_fix.setCwd(.{ .cwd_relative = b.build_root.path orelse "." });
    run_fix.step.dependOn(&fmt.step);

    const gen_proto = b.step("gen-proto", "generates zig protobuf bindings from ../spec/spec.proto");
    gen_proto.dependOn(&run_fix.step);

    return &run_fix.step;
}

fn linkWindowsLibraries(module: *std.Build.Module) void {
    module.linkSystemLibrary("userenv", .{});
    module.linkSystemLibrary("ole32", .{});
    module.linkSystemLibrary("ntdll", .{});
    module.linkSystemLibrary("kernel32", .{});
    module.linkSystemLibrary("bcrypt", .{});
    module.linkSystemLibrary("ws2_32", .{});
}

fn linkMacOSLibraries(module: *std.Build.Module) void {
    module.linkFramework("CoreFoundation", .{});
    module.linkFramework("Security", .{});
}

fn kclLibName() []const u8 {
    return "kcl";
}

fn kclLibPath(b: *std.Build, target: *const std.Build.ResolvedTarget) std.Build.LazyPath {
    const os = target.query.os_tag orelse builtin.os.tag;
    const arch = target.query.cpu_arch orelse builtin.cpu.arch;
    switch (os) {
        .windows => {
            switch (arch) {
                .x86_64 => {
                    return b.path("../go/lib/windows-amd64/");
                },
                .x86 => {
                    return b.path("../go/lib/windows-amd64/");
                },
                .aarch64 => {
                    return b.path("../go/lib/windows-arm64/");
                },
                else => @panic("Unsupported Windows architecture"),
            }
        },
        .linux => {
            switch (arch) {
                .x86_64 => {
                    return b.path("../go/lib/linux-amd64/");
                },
                .x86 => {
                    return b.path("../go/lib/linux-amd64/");
                },
                .aarch64 => {
                    return b.path("../go/lib/linux-arm64/");
                },
                else => @panic("Unsupported Linux architecture"),
            }
        },
        .macos => {
            switch (arch) {
                .x86_64 => {
                    return b.path("../go/lib/darwin-amd64/");
                },
                .aarch64 => {
                    return b.path("../go/lib/darwin-arm64/");
                },
                else => @panic("Unsupported macOS architecture"),
            }
        },
        else => @panic("Unsupported operating system"),
    }
}
