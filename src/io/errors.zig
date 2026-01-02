pub const AudioError = error{ EngineFailure, PlaybackFailure };
pub fn errorMsg(e: AudioError) []const u8 {
    return switch (e) {
        AudioError.EngineFailure => "failed to setup",
        AudioError.PlaybackFailure => "could not find that file..",
        // else => "unknown error",
    };
}
