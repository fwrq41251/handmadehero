const std = @import("std");

const api = @import("game_api.zig");

pub const GameState = struct {
    tone_hz: f32 = 256.0,
    running_sample_index: u32 = 0,
    player_x: f32 = 75.0,
    player_y: f32 = 75.0,
};

// 0 表示地面，1 表示墙壁
const tile_map = [9][16]u8{
    .{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1 },
    .{ 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1 },
    .{ 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
};

fn getState(memory: *api.Memory) *GameState {
    std.debug.assert(memory.permanent_storage_size >= @sizeOf(GameState));
    const state: *GameState = @ptrCast(@alignCast(memory.permanent_storage));

    if (!memory.is_initialized) {
        state.* = .{};
        memory.is_initialized = true;
    }
    return state;
}

pub export fn updateAndRender(memory: *api.Memory, input: *const api.Input, buffer: *api.OffScreenBuffer) callconv(.c) void {
    clearBackground(buffer);

    const state = getState(memory);

    movePlayer(state, input);
    drawTimeMap(buffer);
    drawPlayer(buffer, state);
}

fn movePlayer(state: *GameState, input: *const api.Input) void {
    const controller: api.ControllerInput = input.controllers[0];
    const speed: f32 = 120.0;

    if (controller.move_left.isDown()) {
        state.player_x -= speed * input.delta_time;
    }
    if (controller.move_right.isDown()) {
        state.player_x += speed * input.delta_time;
    }
    if (controller.move_up.isDown()) {
        state.player_y -= speed * input.delta_time;
    }
    if (controller.move_down.isDown()) {
        state.player_y += speed * input.delta_time;
    }
}

fn drawPlayer(buffer: *api.OffScreenBuffer, state: *GameState) void {
    const player_size: f32 = 20.0;
    const half_size: f32 = player_size / 2.0;

    const min_x = state.player_x - half_size;
    const min_y = state.player_y - half_size;
    const max_x = state.player_x + half_size;
    const max_y = state.player_y + half_size;

    drawRectangle(buffer, min_x, min_y, max_x, max_y, 1.0, 0.0, 0.0);
}

fn drawTimeMap(buffer: *api.OffScreenBuffer) void {
    const tile_size: f32 = 50.0;

    for (0..tile_map.len) |y| {
        for (0..tile_map[y].len) |x| {
            const tile = tile_map[y][x];
            const color: [3]f32 = if (tile == 1) .{ 0.0, 0.0, 0.0 } else .{ 1.0, 1.0, 1.0 };
            const float_x: f32 = @floatFromInt(x);
            const float_y: f32 = @floatFromInt(y);
            const min_x = float_x * tile_size;
            const min_y = float_y * tile_size;
            const max_x = min_x + tile_size;
            const max_y = min_y + tile_size;
            drawRectangle(buffer, min_x, min_y, max_x, max_y, color[0], color[1], color[2]);
        }
    }
}

fn clearBackground(buffer: *api.OffScreenBuffer) void {
    drawRectangle(buffer, 0.0, 0.0, @floatFromInt(buffer.width), @floatFromInt(buffer.height), 0.5, 0.5, 0.5);
}

pub export fn getSoundSamples(memory: *api.Memory, buffer: *api.SoundOutputBuffer) callconv(.c) void {
    const state = getState(memory);
    const volume: i16 = 250;
    const sample_rate: f32 = @floatFromInt(buffer.samples_per_second);
    const phase_step: f32 = 2.0 * std.math.pi * state.tone_hz / sample_rate;

    for (0..buffer.samples_count) |i| {
        const index: f32 = @floatFromInt(state.running_sample_index);
        buffer.samples[i] = @intFromFloat(@sin(index * phase_step) * volume);
        state.running_sample_index +%= 1;
    }
}

fn drawRectangle(
    buffer: *api.OffScreenBuffer,
    min_x: f32,
    min_y: f32,
    max_x: f32,
    max_y: f32,
    r: f32,
    g: f32,
    b: f32,
) void {
    const width: i32 = @intCast(buffer.width);
    const height: i32 = @intCast(buffer.height);

    const left = std.math.clamp(roundToInt(min_x), 0, width);
    const top = std.math.clamp(roundToInt(min_y), 0, height);
    const right = std.math.clamp(roundToInt(max_x), 0, width);
    const bottom = std.math.clamp(roundToInt(max_y), 0, height);

    if (left >= right or top >= bottom) return;

    const redInt: u8 = @intCast(roundToInt(r * 255.0));
    const greenInt: u8 = @intCast(roundToInt(g * 255.0));
    const blueInt: u8 = @intCast(roundToInt(b * 255.0));

    var y = top;
    while (y < bottom) : (y += 1) {
        var x = left;
        while (x < right) : (x += 1) {
            buffer.setPixel(@intCast(x), @intCast(y), redInt, greenInt, blueInt, 255);
        }
    }
}

fn roundToInt(value: f32) i32 {
    return @intFromFloat(@round(value));
}

comptime {
    const update: api.UpdateAndRenderFn = &updateAndRender;
    const sound: api.GetSoundSamplesFn = &getSoundSamples;

    _ = update;
    _ = sound;
}
