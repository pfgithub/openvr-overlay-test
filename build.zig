const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("openvr-overlay", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addIncludePath("lib");
    exe.linkLibC();
    exe.disable_sanitize_c = true; // rawdraw depends on undefined behaviour
    exe.addCSourceFile("lib/rawdraw_sf.c", &.{});
    if(target.isLinux()) {
        exe.linkSystemLibrary("m");
        exe.linkSystemLibrary("X11");
        exe.linkSystemLibrary("GL");
        exe.addObjectFile("lib/openvr/lib/linux64/libopenvr_api.so");
    }else if(target.isWindows()) {
        exe.linkSystemLibrary("opengl32");
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("opengl32");
        exe.addObjectFile("lib/openvr/lib/win64/openvr_api.lib");
    }
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
