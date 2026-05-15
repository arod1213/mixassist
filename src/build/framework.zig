const std = @import("std");
const builtin = @import("builtin");
const XCFrameworkStep = @import("xcframework.zig").XCFrameworkStep;

pub fn create(b: *std.Build, target: *std.Target) void {
    const xcframework = XCFrameworkStep.create(b, .{
        .name = "GhosttyKit",
        .out_path = "macos/GhosttyKit.xcframework",
        .libraries = switch (target) {
            .universal => &.{
                .{
                    .library = macos_universal.output,
                    .headers = b.path("include"),
                    .dsym = macos_universal.dsym,
                },
                .{
                    .library = ios.output,
                    .headers = b.path("include"),
                    .dsym = ios.dsym,
                },
                .{
                    .library = ios_sim.output,
                    .headers = b.path("include"),
                    .dsym = ios_sim.dsym,
                },
            },

            .native => &.{.{
                .library = macos_native.output,
                .headers = b.path("include"),
                .dsym = macos_native.dsym,
            }},
        },
    });
}
