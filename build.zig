const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("rfb", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const chatterbox_exe = b.addExecutable(.{
        .name = "chatterbox",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/programs/chatterbox/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "rfb", .module = mod },
            },
        }),
    });

    b.installArtifact(chatterbox_exe);

    const chatterbox_exe_tests = b.addTest(.{
        .root_module = chatterbox_exe.root_module,
    });

    const run_chatterbox_exe_tests = b.addRunArtifact(chatterbox_exe_tests);

    const demoserver_exe = b.addExecutable(.{
        .name = "demoserver",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/programs/demoserver/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "rfb", .module = mod },
            },
        }),
    });

    b.installArtifact(demoserver_exe);

    const demoserver_exe_tests = b.addTest(.{
        .root_module = demoserver_exe.root_module,
    });

    const run_demoserver_exe_tests = b.addRunArtifact(demoserver_exe_tests);

    const snapshot_exe = b.addExecutable(.{
        .name = "snapshot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/programs/snapshot/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "rfb", .module = mod },
            },
        }),
    });

    b.installArtifact(snapshot_exe);

    const snapshot_exe_tests = b.addTest(.{
        .root_module = snapshot_exe.root_module,
    });

    const run_snapshot_exe_tests = b.addRunArtifact(snapshot_exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_chatterbox_exe_tests.step);
    test_step.dependOn(&run_demoserver_exe_tests.step);
    test_step.dependOn(&run_snapshot_exe_tests.step);
}
