//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

extern "c" fn kcl_run(filename_ptr: [*c]const u8, src_ptr: [*c]const u8) [*:0]const u8;
extern "c" fn kcl_fmt(src_ptr: [*c]const u8) [*:0]const u8;

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
