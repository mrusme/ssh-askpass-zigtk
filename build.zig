const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gtk_stub = b.option(
        bool,
        "gtk-stub",
        "Link a stub libgtk-4.so.1 instead of the system GTK4, for cross-compiling release binaries.",
    ) orelse false;

    const strip = b.option(bool, "strip", "Strip debug info from the binary.");

    const mod = b.addModule("ssh_askpass_zigtk", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .imports = &.{
            .{ .name = "ssh_askpass_zigtk", .module = mod },
        },
    });
    exe_mod.link_libc = true;

    const exe = b.addExecutable(.{
        .name = "ssh-askpass-zigtk",
        .root_module = exe_mod,
    });
    exe.each_lib_rpath = false;

    if (gtk_stub) {
        const stub = b.addLibrary(.{
            .name = "gtk-4",
            .linkage = .dynamic,
            .version = .{ .major = 1, .minor = 0, .patch = 0 },
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/gtk_stub.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe_mod.addObjectFile(stub.getEmittedBin());
    } else {
        exe_mod.linkSystemLibrary("gtk4", .{});
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
