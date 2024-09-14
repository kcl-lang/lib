const std = @import("std");
const builtin = @import("builtin");

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

    const lib = b.addStaticLibrary(.{
        .name = "kcl_lib_zig",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();
    lib.linkLibCpp();
    lib.addLibraryPath(kclLibPath(b, &target));
    lib.linkSystemLibrary(kclLibName());
    if (os == .windows) {
        linkWindowsLibraries(lib);
    }

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_unit_tests.linkLibC();
    lib_unit_tests.linkLibCpp();
    lib_unit_tests.addLibraryPath(kclLibPath(b, &target));
    lib_unit_tests.linkSystemLibrary(kclLibName());
    if (os == .windows) {
        linkWindowsLibraries(lib_unit_tests);
    }

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn linkWindowsLibraries(lib: *std.Build.Step.Compile) void {
    lib.linkSystemLibrary("userenv");
    lib.linkSystemLibrary("ole32");
    lib.linkSystemLibrary("ntdll");
    lib.linkSystemLibrary("kernel32");
    lib.linkSystemLibrary("bcrypt");
    lib.linkSystemLibrary("ws2_32");
}

fn kclLibName() []const u8 {
    return "kclvm_cli_cdylib";
}

fn kclLibPath(b: *std.Build, target: *const std.Build.ResolvedTarget) std.Build.LazyPath {
    const os = target.query.os_tag orelse builtin.os.tag;
    const arch = target.query.cpu_arch orelse builtin.cpu.arch;
    switch (os) {
        .windows => {
            switch (arch) {
                .x86_64 => {
                    return b.path("../go/lib/windows-amd64/static");
                },
                .x86 => {
                    return b.path("../go/lib/windows-amd64/static");
                },
                .aarch64 => {
                    return b.path("../go/lib/windows-arm64/static");
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
