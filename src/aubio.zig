pub const lib = @cImport({
    @cInclude("aubio/aubio.h");
});

pub fn getBpm(path: []const u8, sr: c_uint) !f32 {
    var n_frames: c_uint = 0;
    const hop_size: c_uint = 512;
    const win_size: c_uint = 1024;

    var source = lib.new_aubio_source(path.ptr, sr, hop_size);
    if (source == null) {
        return error.MissingSource;
    }
    _ = &source;
    defer lib.del_aubio_source(source);

    var in_vec = lib.new_fvec(hop_size);
    _ = &in_vec;
    var out_vec = lib.new_fvec(1);
    _ = &out_vec;
    defer lib.del_fvec(in_vec);
    defer lib.del_fvec(out_vec);

    var tempo = lib.new_aubio_tempo("default", win_size, hop_size, sr);
    if (tempo == null) {
        lib.del_aubio_source(source);
        return error.BadObject;
    }
    defer lib.del_aubio_tempo(tempo);
    _ = &tempo;

    var read: c_uint = 0;
    var bpm: f32 = 0;

    while (true) {
        read = 0;
        lib.aubio_source_do(source, in_vec, &read);
        if (read == 0) break;

        lib.aubio_tempo_do(tempo, in_vec, out_vec);

        if (out_vec.*.data[0] != 0) {
            bpm = lib.aubio_tempo_get_bpm(tempo);
        }

        n_frames += read;
        if (read < hop_size) break;
    }

    return bpm;
}
