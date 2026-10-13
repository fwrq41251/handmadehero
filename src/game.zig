const std = @import("std");

const api = @import("game_api.zig");

const player_size: f32 = 20.0;
const player_half_size: f32 = player_size / 2.0;

pub const GameState = struct {
    tone_hz: f32 = 256.0,
    running_sample_index: u32 = 0,
    player_x: f32 = 75.0,
    player_y: f32 = 75.0,
};

const TileMap = struct {
    tiles: [9][16]u8,
    tile_size: f32 = 50.0,

    fn getTile(self: *const TileMap, x: usize, y: usize) u8 {
        if (y >= self.tiles.len or x >= self.tiles[y].len) {
            return 1; // 超出地图范围视为墙壁
        }
        return self.tiles[y][x];
    }

    fn isWalkable(self: *const TileMap, x: usize, y: usize) bool {
        return self.getTile(x, y) == 0;
    }
};

// 0 表示地面，1 表示墙壁
const tile_map = TileMap{ .tiles = .{
    .{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1 },
    .{ 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1 },
    .{ 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
} };

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
    drawTimeMap(buffer, &tile_map);
    drawPlayer(buffer, state);
}

fn movePlayer(state: *GameState, input: *const api.Input) void {
    const controller: api.ControllerInput = input.controllers[0];
    const speed: f32 = 120.0;

    var new_x = state.player_x;
    var new_y = state.player_y;

    if (controller.move_left.isDown()) {
        new_x -= speed * input.delta_time;
    }
    if (controller.move_right.isDown()) {
        new_x += speed * input.delta_time;
    }
    if (controller.move_up.isDown()) {
        new_y -= speed * input.delta_time;
    }
    if (controller.move_down.isDown()) {
        new_y += speed * input.delta_time;
    }

    if (canPlayerStandAt(&tile_map, new_x, new_y)) {
        state.player_x = new_x;
        state.player_y = new_y;
    }
}

fn canPlayerStandAt(map: *const TileMap, x: f32, y: f32) bool {
    const min_x = x - player_half_size;
    const min_y = y - player_half_size;
    const max_x = x + player_half_size;
    const max_y = y + player_half_size;
    const tile_size = map.tile_size;
    const tiles = map.tiles;
    const map_width = tile_size * @as(f32, @floatFromInt(tiles[0].len));
    const map_height = tile_size * @as(f32, @floatFromInt(tiles.len));

    // 在转换为无符号索引前，确认整个玩家矩形位于地图内。
    if (!(min_x >= 0.0 and min_y >= 0.0 and max_x <= map_width and max_y <= map_height)) {
        return false;
    }

    const first_x: usize = @intFromFloat(@floor(min_x / tile_size));
    const first_y: usize = @intFromFloat(@floor(min_y / tile_size));
    // max 不包含在矩形内，恰好贴墙时取墙前的格子。
    const last_x: usize = @as(usize, @intFromFloat(@ceil(max_x / tile_size))) - 1;
    const last_y: usize = @as(usize, @intFromFloat(@ceil(max_y / tile_size))) - 1;

    return map.isWalkable(first_x, first_y) and
        map.isWalkable(last_x, first_y) and
        map.isWalkable(first_x, last_y) and
        map.isWalkable(last_x, last_y);
}

fn drawPlayer(buffer: *api.OffScreenBuffer, state: *GameState) void {
    const min_x = state.player_x - player_half_size;
    const min_y = state.player_y - player_half_size;
    const max_x = state.player_x + player_half_size;
    const max_y = state.player_y + player_half_size;

    drawRectangle(buffer, min_x, min_y, max_x, max_y, 1.0, 0.0, 0.0);
}

fn drawTimeMap(buffer: *api.OffScreenBuffer, map: *const TileMap) void {
    const tile_size = map.tile_size;
    const tiles = map.tiles;
    for (0..tiles.len) |y| {
        for (0..tiles[y].len) |x| {
            const tile = tiles[y][x];
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
