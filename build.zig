const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mini = b.addModule("mini", .{
        .root_source_file = b.path("src/miniaudio.zig"),
        .target = target,
        .link_libc = true,
    });
    mini.addIncludePath(b.path("./include"));
    mini.addCSourceFile(.{
        .file = b.path("include/miniaudio.c"),
        .flags = &.{},
    });

    const aubio = b.addModule("aubio", .{
        .root_source_file = b.path("src/aubio.zig"),
        .target = target,
        .link_libc = true,
    });

    if (builtin.target.os.tag == .macos) {
        aubio.linkFramework("CoreFoundation", .{ .needed = true });
        aubio.linkFramework("CoreAudio", .{ .needed = true });
        aubio.linkFramework("AudioToolbox", .{ .needed = true });
        aubio.linkFramework("Accelerate", .{ .needed = true });
    }

    aubio.linkSystemLibrary("sndfile", .{ .preferred_link_mode = .dynamic });
    aubio.linkSystemLibrary("aubio", .{ .preferred_link_mode = .static });

    const ebur = b.addModule("ebur", .{
        .root_source_file = b.path("src/ebur128.zig"),
        .target = target,
        .link_libc = true,
    });
    ebur.linkSystemLibrary("ebur128", .{ .preferred_link_mode = .static });

    const mod = b.addModule("audio", .{
        .root_source_file = b.path("src/io/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "miniaudio", .module = mini },
            .{ .name = "ebur128", .module = ebur },
            .{ .name = "aubio", .module = aubio },
        },
    });

    const exe = b.addExecutable(.{
        .name = "audio",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "audio", .module = mod },
            },
        }),
    });
    exe.linkLibC();
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
