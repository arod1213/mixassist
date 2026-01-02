const std = @import("std");
const c = @import("miniaudio").lib;
const eb = @import("ebur128").lib;
const print = std.debug.print;

pub fn ampToTarget(comptime T: type, lufs: T, target: T) T {
    const diff = target - lufs;
    return dbToAmp(T, diff);
}

pub fn ampToDb(comptime T: type, amp: T) T {
    return 20.0 * @log10(amp);
}

pub fn dbToAmp(comptime T: type, db: T) T {
    return std.math.pow(T, 10.0, (db / 20.0));
}

pub fn getLufs(sound: [*c]c.ma_sound, engine: c.ma_engine) !f64 {
    const channels: usize = 2;
    const sample_rate: usize = @intCast(engine.sampleRate);

    const state = eb.ebur128_init(channels, sample_rate, eb.EBUR128_MODE_I);
    defer eb.ebur128_destroy(@constCast(&state));

    const data_source = c.ma_sound_get_data_source(sound);

    const frame_count: usize = 4096;
    var buffer: [frame_count * channels]f32 = undefined;

    while (true) {
        var frames_read: u64 = 0;

        const result = c.ma_data_source_read_pcm_frames(
            data_source,
            &buffer,
            frame_count,
            &frames_read,
        );
        if (result != c.MA_SUCCESS or frames_read == 0) break;

        _ = eb.ebur128_add_frames_float(
            state,
            &buffer,
            @intCast(frames_read),
        );
    }

    var loudness_lufs: f64 = 0;
    if (eb.ebur128_loudness_global(state, &loudness_lufs) != eb.EBUR128_SUCCESS) {
        return error.LUFSNotFound;
    }
    _ = c.ma_data_source_seek_to_pcm_frame(data_source, 0);
    return loudness_lufs;
}
