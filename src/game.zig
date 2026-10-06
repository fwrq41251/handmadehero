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

pub fn updateAndRender(memory: *api.Memory, input: *const api.Input, buffer: *api.OffScreenBuffer) void {
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
}

pub fn getSoundSamples(memory: *api.Memory, buffer: *api.SoundOutputBuffer) void {
    const state = getState(memory);
    const volume: i16 = 2500;
    const sample_rate: f32 = @floatFromInt(buffer.samples_per_second);
    const phase_step: f32 = 2.0 * std.math.pi * state.tone_hz / sample_rate;

    for (0..buffer.samples.len) |i| {
        const index: f32 = @floatFromInt(state.running_sample_index);
        buffer.samples[i] = @intFromFloat(@sin(index * phase_step) * volume);
        state.running_sample_index +%= 1;
    }
}
