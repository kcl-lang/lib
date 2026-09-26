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

    const os = target.query.os_tag orelse builtin.os.tag;

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

    lib.root_module.link_libc = true;
    lib.root_module.link_libcpp = true;
    lib.root_module.addLibraryPath(kclLibPath(b, &target));
    lib.root_module.linkSystemLibrary(kclLibName(), .{});
    lib.root_module.addImport("spec", spec_module);
    lib.step.dependOn(gen_spec_step);
    if (os == .windows) {
        linkWindowsLibraries(lib);
    } else if (os == .macos) {
        linkMacOSLibraries(lib);
    }

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

    lib_unit_tests.root_module.link_libc = true;
    lib_unit_tests.root_module.link_libcpp = true;
    lib_unit_tests.root_module.addLibraryPath(kclLibPath(b, &target));
    lib_unit_tests.root_module.linkSystemLibrary(kclLibName(), .{});
    lib_unit_tests.root_module.addImport("spec", spec_module);
    lib_unit_tests.step.dependOn(gen_spec_step);
    if (os == .windows) {
        linkWindowsLibraries(lib_unit_tests);
    } else if (os == .macos) {
        linkMacOSLibraries(lib_unit_tests);
    }

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

// Generates the typed protobuf bindings in `src/proto` from
// `../spec/spec.proto` using zig-protobuf's `protoc-gen-zig` plugin and the
// system `protoc`. Regenerated on every build; `zig build gen-proto` runs
// only this step.
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

    const gen_proto = b.step("gen-proto", "generates zig protobuf bindings from ../spec/spec.proto");
    gen_proto.dependOn(&fmt.step);

    return &fmt.step;
}

fn linkWindowsLibraries(lib: *std.Build.Step.Compile) void {
    lib.root_module.linkSystemLibrary("userenv", .{});
    lib.root_module.linkSystemLibrary("ole32", .{});
    lib.root_module.linkSystemLibrary("ntdll", .{});
    lib.root_module.linkSystemLibrary("kernel32", .{});
    lib.root_module.linkSystemLibrary("bcrypt", .{});
    lib.root_module.linkSystemLibrary("ws2_32", .{});
}

fn linkMacOSLibraries(lib: *std.Build.Step.Compile) void {
    lib.root_module.linkFramework("CoreFoundation", .{});
    lib.root_module.linkFramework("Security", .{});
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
