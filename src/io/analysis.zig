const std = @import("std");
const print = std.debug.print;
const c = @import("miniaudio").lib;
const expect = std.testing.expect;
const AudioError = @import("./errors.zig").AudioError;
const Sound = @import("./types.zig").Sound;

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
    const spm = 4.0 * 60.0 / tempo; // adjust for alt signatures
    if (pos == 0) {
        return spm;
    }

    return (@floor(pos / spm) + 1.0) * spm;
}

test "next bar" {
    try expect(2.0 == nextBar(0.0, 120.0));
    try expect(2.0 == nextBar(1.0, 120.0));
    try expect(4.0 == nextBar(2.0, 120.0));
}

pub fn prevBar(pos: f32, tempo: f32) f32 {
    const spb = 4.0 * 60.0 / tempo;
    const epsilon = 0.2 * spb;

    if (pos <= 0.0) return 0.0;

    const bar_index = @floor(pos / spb);

    const target_bar =
        if (pos - bar_index * spb < epsilon)
            bar_index - 1.0
        else
            bar_index;

    return @max(0.0, target_bar * spb);
}
