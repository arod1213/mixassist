const std = @import("std");
const posix = std.posix;
const print = std.debug.print;

const audio = @import("audio");
const playback = audio.playback;
const PlayState = playback.PlayState;
const CommandQueue = audio.CommandQueue;

fn worker(paths: []const [*:0]const u8, state: *PlayState, cmd: *CommandQueue) void {
    playback.multiPlayback(paths, state, cmd) catch return;
}

fn setupTermios(handle: posix.fd_t) !void {
    var settings = try posix.tcgetattr(handle);
    settings.lflag.ICANON = false;
    settings.lflag.ECHO = false;
    _ = try posix.tcsetattr(handle, posix.TCSA.NOW, settings);
}

fn pollTimestamp(w: *std.Io.Writer, state: *const PlayState) void {
    while (true) {
        const int_sec: u32 = @intFromFloat(state.position);
        const min: u32 = int_sec / 60;
        const sec: u32 = @mod(int_sec, 60);
        w.print("time of {d:0>2}:{d:0>2}\r", .{ min, sec }) catch return;

        std.Thread.sleep(std.time.ns_per_ms * 30);
    }
}

fn handleInput(r: *std.Io.Reader, queue: *CommandQueue, state: *PlayState) !void {
    const b = try r.takeByte();

    switch (b) {
        'q' => return,

        // playback
        'p' => queue.set(.{ .play = !state.is_playing }),
        's' => queue.set(.{ .deck = state.deck + 1 }),
        'n' => queue.set(.{ .normalize = !state.normalize }),

        // pan
        'l' => queue.set(.{ .panMode = .left }),
        'r' => queue.set(.{ .panMode = .right }),
        'c' => queue.set(.{ .panMode = .stereo }),

        // position
        'w' => queue.set(.{ .move = .fwd }),
        'b' => queue.set(.{ .move = .bck }),
        '0' => queue.set(.{ .reset = {} }),
        '1'...'9' => |m| queue.set(.{ .marker = try std.fmt.charToDigit(m, 10) }),
        else => {},
    }
}

pub fn main() !void {
    var stdin = std.fs.File.stdin();
    try setupTermios(stdin.handle);

    var buf: [20]u8 = undefined;
    var stdin_reader = stdin.reader(&buf);
    var reader = &stdin_reader.interface;

    var out_buf: [20]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&out_buf);
    var writer = &stdout_writer.interface;
    _ = &writer;

    const args = std.os.argv;
    if (args.len < 2) {
        try writer.print("not enough arguments\nplease provide paths to audio files\n", .{});
        return;
    }

    const paths = args[1..];

    var state = PlayState.init(-13.0);
    var cmd = CommandQueue.init();
    const handle = try std.Thread.spawn(.{}, worker, .{ paths, &state, &cmd });
    defer handle.join();

    _ = try std.Thread.spawn(.{}, pollTimestamp, .{ writer, &state }); // print timestamp

    while (true) {
        handleInput(&reader, &cmd, &state) catch |e| {
            try writer.print("failed because {any}\n", .{e});
            break;
        };
    }
}
