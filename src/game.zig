const std = @import("std");

const api = @import("game_api.zig");

pub const GameState = struct {
    tone_hz: f32 = 256.0,
    running_sample_index: u32 = 0,
    green_offset: u8 = 0,
    blue_offset: u8 = 0,
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
    const state = getState(memory);

    const controller = input.controllers[0];
    if (controller.move_up.isDown()) {
        state.green_offset -%= 2;
    }
    if (controller.move_down.isDown()) {
        state.green_offset +%= 2;
    }
    if (controller.move_left.isDown()) {
        state.blue_offset -%= 2;
    }
    if (controller.move_right.isDown()) {
        state.blue_offset +%= 2;
    }

    // 默认自增滚动
    state.green_offset +%= 1;
    state.blue_offset +%= 1;

    for (0..buffer.height) |y| {
        for (0..buffer.width) |x| {
            const blue: u8 = @truncate(x);
            const green: u8 = @truncate(y);
            const red: u8 = 0;
            buffer.setPixel(@intCast(x), @intCast(y), red, green +% state.green_offset, blue +% state.blue_offset, 255);
        }
    }

    drawRectangle(buffer, 50.0, 50.0, 200.0, 200.0, 255, 150, 0);
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
    r: u8,
    g: u8,
    b: u8,
) void {
    const width: i32 = @intCast(buffer.width);
    const height: i32 = @intCast(buffer.height);

    const left = std.math.clamp(roundToInt(min_x), 0, width);
    const top = std.math.clamp(roundToInt(min_y), 0, height);
    const right = std.math.clamp(roundToInt(max_x), 0, width);
    const bottom = std.math.clamp(roundToInt(max_y), 0, height);

    if (left >= right or top >= bottom) return;

    var y = top;
    while (y < bottom) : (y += 1) {
        var x = left;
        while (x < right) : (x += 1) {
            buffer.setPixel(@intCast(x), @intCast(y), r, g, b, 255);
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
