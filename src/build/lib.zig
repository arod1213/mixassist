const AudioLib = @This();

const std = @import("std");
const builtin = @import("builtin");
const RunStep = std.Build.Step.Run;
const LibtoolStep = @import("libstep.zig").LibtoolStep;

/// The step that generates the file.
step: *std.Build.Step,

/// The final static library file
output: std.Build.LazyPath,
dsym: ?std.Build.LazyPath,

pub fn initStatic(
    b: *std.Build,
    target: *std.Target,
) !AudioLib {
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
    const lib = b.addLibrary(.{
        .name = "ghostty",
        .root_module = mod,
        // .root_module = b.createModule(.{
        //     .root_source_file = b.path("src/main_c.zig"),
        //     .target = deps.config.target,
        //     .optimize = deps.config.optimize,
        //     .strip = deps.config.strip,
        //     .omit_frame_pointer = deps.config.strip,
        //     .unwind_tables = if (deps.config.strip) .none else .sync,
        // }),

        // Fails on self-hosted x86_64 on macOS
        .use_llvm = true,
    });
    lib.linkLibC();

    // These must be bundled since we're compiling into a static lib.
    // Otherwise, you get undefined symbol errors.
    lib.bundle_compiler_rt = true;
    lib.bundle_ubsan_rt = true;

    // Add our dependencies. Get the list of all static deps so we can
    // build a combined archive if necessary.
    // var lib_list = try deps.add(lib);
    const lib_list: []std.Build.LazyPath = .{
        lib.getEmittedBin(),
    };
    // try lib_list.append(b.allocator, lib.getEmittedBin());

    if (!builtin.config.target.result.os.tag.isDarwin()) return .{
        .step = &lib.step,
        .output = lib.getEmittedBin(),
        .dsym = null,
    };

    // Create a static lib that contains all our dependencies.
    const libtool = LibtoolStep.create(b, .{
        .name = "ghostty",
        .out_name = "libghostty-fat.a",
        .sources = lib_list.items,
    });
    libtool.step.dependOn(&lib.step);

    return .{
        .step = libtool.step,
        .output = libtool.output,

        // Static libraries cannot have dSYMs because they aren't linked.
        .dsym = null,
    };
}
