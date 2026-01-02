const std = @import("std");
const print = std.debug.print;
const c = @import("miniaudio").lib;
const expect = std.testing.expect;
const AudioError = @import("../errors/main.zig").AudioError;
const Sound = @import("../types.zig").Sound;

pub fn markerPos(num: usize, sound: *const Sound) f32 {
    var length: f32 = undefined;
    if (c.ma_sound_get_length_in_seconds(sound.ma_sound, &length) != 0) {
        length = 0.0;
    }
    if (num == 0) {
        return 0;
    }
    const f_pos: f32 = @floatFromInt(num);

    // const x = sound.tempo / 60.0 * 4 * f_pos;

    const x = length / 10.0 * f_pos;
    return x;
}

pub fn nextBar(pos: f32, tempo: f32) f32 {
    const spm = 4.0 * tempo / 60.0; // adjust for alt signatures
    if (pos == 0) {
        return spm;
    }

    return @ceil(pos / spm) * spm;
}

test "next bar" {
    try expect(2.0 == nextBar(0.0, 120.0));
    try expect(2.0 == nextBar(1.0, 120.0));
    try expect(4.0 == nextBar(2.0, 120.0));
}

pub fn prevBar(pos: f32, tempo: f32) f32 {
    const spm: f32 = 4.0 * tempo / 60.0; // adjust for alt signatures
    if (pos == 0) {
        return 0;
    }

    const div: f32 = @floor(pos / spm); // bars ahead

    const div_int: i32 = @intFromFloat(div);
    const div_float: f32 = @floatFromInt(div_int);

    const rem: f32 = div - div_float;

    const prev: f32 = @as(f32, @floatFromInt(div_int - 1)) * spm;
    if (prev < 0.0) {
        return 0.0;
    }

    if (rem < 0.1) {
        const x: f32 = prev - spm;
        if (x < 0.0) {
            return 0.0;
        }
        return x;
    }

    return prev;
}
