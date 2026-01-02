const std = @import("std");
const print = std.debug.print;
const c = @import("miniaudio").lib;
const AudioError = @import("../errors/main.zig").AudioError;
const analysis = @import("../analysis/main.zig");
const types = @import("../types.zig");
const cmd = @import("../commands.zig");
pub const PlayState = cmd.PlayState;

pub fn play(group: [*c]c.ma_sound_group, sounds: []const *types.Sound, state: *PlayState) void {
    _ = c.ma_sound_group_start(group);
    for (sounds) |sound| {
        if (sound.shouldReset(state.position)) {
            state.position = 0;
            return play(group, sounds, state);
        }
        sound.play(state.position);
    }
}

pub fn pause(group: [*c]c.ma_sound_group, sounds: []const *types.Sound) void {
    _ = c.ma_sound_group_stop(group);
    for (sounds) |sound| {
        _ = c.ma_sound_stop(sound.ma_sound);
    }
}

fn openSounds(alloc: std.mem.Allocator, paths: []const [*:0]const u8, engine: [*c]c.ma_engine, group: [*c]c.ma_sound_group) ![]*types.Sound {
    var sound_list = try std.ArrayList(*types.Sound).initCapacity(alloc, paths.len);
    defer sound_list.deinit(alloc);
    for (paths) |path| {
        const s = try alloc.create(types.Sound);
        s.* = try types.Sound.init(alloc, engine, group, std.mem.span(path), 0.0);
        try sound_list.append(alloc, s);
    }
    return try sound_list.toOwnedSlice(alloc);
}

pub fn multiPlayback(paths: []const [*:0]const u8, state: *PlayState, cmd_queue: *cmd.CommandQueue) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();
    defer arena.deinit();

    const engine = try types.setupEngine(alloc);
    defer types.closeEngine(engine);

    const group = try types.setupGroup(alloc, engine);
    defer c.ma_sound_group_uninit(group);

    const sounds = try openSounds(alloc, paths, engine, group);
    defer {
        for (sounds) |item| {
            item.deinit();
        }
    }
    var engine_state = types.EngineState{ .engine = engine, .group = group, .sounds = sounds };
    _ = try std.Thread.spawn(.{}, cmd.handleCommands, .{ cmd_queue, &engine_state, state });

    var was_playing = false; // init to false to setup first playback
    while (true) {
        switch (state.is_playing) {
            true => {
                if (!was_playing) {
                    play(group, sounds, state);
                    was_playing = true;
                }

                var cur_pos: f32 = undefined;
                _ = c.ma_sound_get_cursor_in_seconds(sounds[0].ma_sound, &cur_pos);
                state.position = cur_pos;

                if (types.Sound.shouldReset(sounds[state.deck].*, cur_pos)) {
                    state.is_playing = false;
                    pause(group, sounds);
                    continue;
                }
                std.Thread.sleep(std.time.ns_per_ms * 3);
            },
            false => {
                pause(group, sounds);
                was_playing = false;
            },
        }
    }

    while (c.ma_sound_group_is_playing(group) != 0) {}
    print("finished playing", .{});

    return;
}
