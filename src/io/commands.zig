const std = @import("std");
const print = std.debug.print;
const c = @import("miniaudio").lib;
const AudioError = @import("./errors.zig").AudioError;
const types = @import("./types.zig");
const analysis = @import("./analysis.zig");

pub const Command = union(enum) { play: bool, reset, marker: u8, move: types.Direction, deck: usize, panMode: types.PanMode, normalize: bool };

pub const CommandQueue = struct {
    cmd: ?Command,
    mu: std.Thread.Mutex,

    const Self = @This();
    pub fn init() Self {
        return .{
            .cmd = .{ .deck = 0 },
            .mu = std.Thread.Mutex{},
        };
    }

    pub fn set(self: *Self, val: ?Command) void {
        self.mu.lock();
        self.cmd = val;
        self.mu.unlock();
    }

    pub fn take(self: *Self) ?Command {
        self.mu.lock();
        defer self.mu.unlock();
        const val = self.cmd;
        self.cmd = null;
        return val;
    }
};

pub fn handleCommands(cmd: *CommandQueue, engine: *types.EngineState, state: *types.PlayState) !void {
    while (true) {
        if (cmd.take()) |t| {
            switch (t) {
                .normalize => |x| {
                    state.normalize = x;
                    cmd.set(.{ .deck = state.deck }); // retrigger volume
                },
                .panMode => |x| {
                    if (x == state.output) { // reset to center if dup
                        state.output = .stereo;
                        _ = c.ma_sound_group_set_pan(engine.group, 0);
                        continue;
                    }
                    const pan: f32 = switch (x) {
                        .left => -1.0,
                        .right => 1.0,
                        .stereo => 0.0,
                    };
                    state.output = x;
                    _ = c.ma_sound_group_set_pan(engine.group, pan);
                },
                .deck => |x| {
                    const deck_num = @mod(x, engine.sounds.len);
                    state.deck = deck_num;
                    for (engine.sounds, 0..) |sound, idx| {
                        if (idx == deck_num) {
                            const amp: f32 = if (state.normalize) @floatCast(sound.targetVol(f64, state.target_lufs)) else 1.0;
                            c.ma_sound_set_volume(sound.ptr, amp);
                        } else {
                            c.ma_sound_set_volume(sound.ptr, 0);
                        }
                    }
                },
                .play => |x| state.playing = x,
                .reset => {
                    for (engine.sounds) |sound| {
                        sound.play(0.0);
                    }
                    state.position = 0.0;
                },
                .marker => |x| {
                    const active_sound = engine.sounds[state.deck];
                    const pos = analysis.markerPos(x, active_sound);

                    for (engine.sounds) |sound| {
                        _ = c.ma_sound_seek_to_second(sound.ptr, pos);
                    }
                },
                .move => |x| {
                    for (engine.sounds) |sound| {
                        const pos = switch (x) {
                            .fwd => analysis.nextBar(state.position, sound.tempo),
                            .bck => analysis.prevBar(state.position, sound.tempo),
                        };
                        _ = c.ma_sound_seek_to_second(sound.ptr, pos);
                    }
                },
            }
        }
    }
}
