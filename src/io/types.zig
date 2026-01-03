const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const AudioError = @import("./errors.zig").AudioError;
const c = @import("miniaudio").lib;
const aubio = @import("aubio");
const loudness = @import("./loudness.zig");

pub const Direction = enum { fwd, bck };
pub const PanMode = enum { left, right, stereo };

pub const PlayState = struct {
    // settings
    normalize: bool = true,
    target_lufs: f32,

    // state
    playing: bool = true,
    position: f32 = 0.0,
    deck: usize = 0,

    // seek
    direction: ?Direction = null,
    marker: ?usize = null,

    output: PanMode = .stereo,

    pub fn init(target_lufs: f32) @This() {
        return .{ .target_lufs = target_lufs };
    }
};

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
    ptr: *c.struct_ma_sound,
    tempo: f32,
    downbeat: f32,
    lufs: ?f64,
    offset_seconds: f32,

    const Self = @This();

    pub fn init(alloc: Allocator, engine: [*c]c.ma_engine, group: [*c]c.ma_sound_group, filepath: []const u8) !Self {
        const ptr = try alloc.create(c.ma_sound);
        if (c.ma_sound_init_from_file(engine, @ptrCast(filepath), 0, group, null, ptr) != c.MA_SUCCESS) {
            return error.FailedToInit;
        }

        // MAYBE CHANGE for more precision
        const tempo: f32 = @round(aubio.getBpm(filepath, engine.*.sampleRate) catch 0);
        const lufs: ?f64 = loudness.getLufs(ptr, engine.*) catch null;
        const downbeat: f32 = 0.0;

        return .{
            .ptr = ptr,
            .tempo = tempo,
            .downbeat = downbeat,
            .lufs = lufs,
            .offset_seconds = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        c.ma_sound_uninit(self.ptr);
    }

    pub fn play(self: Self, pos: f32) void {
        const x = pos + self.offset_seconds;
        _ = c.ma_sound_seek_to_second(self.ptr, x);
        _ = c.ma_sound_start(self.ptr);
    }

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
        _ = c.ma_sound_get_length_in_seconds(self.ptr, &length);
        return pos >= length and pos > 0.0;
    }
};
