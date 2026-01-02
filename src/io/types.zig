const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const AudioError = @import("./errors/main.zig").AudioError;
const c = @import("miniaudio").lib;
const loudness = @import("./loudness.zig");

pub const EngineState = struct {
    engine: *c.ma_engine,
    group: *c.ma_sound_group,
    sounds: []*Sound,
};

pub fn setupEngine(alloc: Allocator) !*c.struct_ma_engine {
    const ptr = try alloc.create(c.ma_engine);

    var config = c.ma_engine_config_init();
    config.channels = 2;

    if (c.ma_engine_init(&config, ptr) != c.MA_SUCCESS) {
        return AudioError.EngineFailure;
    }

    return ptr;
}

pub fn closeEngine(engine: [*c]c.ma_engine) void {
    _ = c.ma_engine_stop(engine);
    c.ma_engine_uninit(engine);
}

pub fn setupGroup(alloc: Allocator, engine: [*c]c.ma_engine) !*c.ma_sound_group {
    const ptr = try alloc.create(c.ma_sound_group);
    {
        const result = c.ma_sound_group_init(engine, 0, null, ptr);
        if (result != c.MA_SUCCESS) {
            return AudioError.EngineFailure;
        }
    }
    return ptr;
}

pub const Sound = struct {
    ma_sound: *c.struct_ma_sound,
    offset: f32 = 0,
    tempo: f32,
    lufs: ?f64,

    const Self = @This();

    pub fn targetVol(self: Self, comptime T: type, target: T) T {
        return loudness.ampToTarget(T, self.lufs orelse target, target);
    }

    // maybe fix this so has to be at end for all
    pub fn atEnd(sounds: []const *const Self, pos: f32) bool {
        for (sounds) |sound| {
            if (shouldReset(sound.*, pos)) {
                return true;
            }
        }
        return false;
    }

    pub fn shouldReset(self: Self, pos: f32) bool {
        var length: f32 = 0;
        _ = c.ma_sound_get_length_in_seconds(self.ma_sound, &length);
        return pos >= length and pos > 0.0;
    }

    pub fn play(self: Self, pos: f32) void {
        _ = c.ma_sound_seek_to_second(self.ma_sound, pos);
        _ = c.ma_sound_start(self.ma_sound);
    }

    pub fn init(alloc: Allocator, engine: [*c]c.ma_engine, group: [*c]c.ma_sound_group, filepath: []const u8, offset: f32) !Self {
        const ptr = try alloc.create(c.ma_sound);
        if (c.ma_sound_init_from_file(engine, @ptrCast(filepath), 0, group, null, ptr) != c.MA_SUCCESS) {
            return error.FailedToInit;
        }

        const lufs: ?f64 = loudness.getLufs(ptr, engine.*) catch null;
        return .{
            .lufs = lufs,
            .ma_sound = ptr,
            .offset = offset,
            .tempo = 102,
        };
    }

    pub fn deinit(self: *Self) void {
        c.ma_sound_uninit(self.ma_sound);
    }
};
