const std = @import("std");

const api = @import("game_api.zig");

const pixels_per_meter: f32 = 25.0;
const player_size: f32 = 1.2;
const player_half_size: f32 = player_size / 2.0;

pub const GameState = struct {
    tone_hz: f32 = 256.0,
    running_sample_index: u32 = 0,
    player_x: f32 = 3.0,
    player_y: f32 = 3.0,
    map_index: usize = 0,
};

const TileMap = struct {
    tiles: [9][16]u8,
    tile_size: f32 = 2.0,

    fn getWidth(self: *const TileMap) usize {
        return self.tiles[0].len;
    }

    fn getHeight(self: *const TileMap) usize {
        return self.tiles.len;
    }

    fn getTile(self: *const TileMap, tile_position: TilePosition) u8 {
        const x = tile_position.x;
        const y = tile_position.y;
        if (y >= self.tiles.len or x >= self.tiles[y].len) {
            return 1; // 超出地图范围视为墙壁
        }
        return self.tiles[y][x];
    }

    fn isWalkable(self: *const TileMap, tile_position: TilePosition) bool {
        return self.getTile(tile_position) == 0;
    }

    fn getTilePosition(self: *const TileMap, x: f32, y: f32) TilePosition {
        const tile_x: usize = @intFromFloat(@floor(x / self.tile_size));
        const tile_y: usize = @intFromFloat(@floor(y / self.tile_size));
        return TilePosition{ .x = tile_x, .y = tile_y };
    }

    // 查询矩形不包含的最大边界；x、y 必须大于零。
    fn getMaxTilePosition(self: *const TileMap, x: f32, y: f32) TilePosition {
        const tile_x: usize = @intFromFloat(@ceil(x / self.tile_size) - 1.0);
        const tile_y: usize = @intFromFloat(@ceil(y / self.tile_size) - 1.0);
        return TilePosition{ .x = tile_x, .y = tile_y };
    }

    fn isAtDoor(self: *const TileMap, tile_position: TilePosition) bool {
        const is_at_side = tile_position.x == 0 or tile_position.x == self.getWidth() - 1 or
            tile_position.y == 0 or tile_position.y == self.getHeight() - 1;
        const tile = self.getTile(tile_position);
        return is_at_side and tile == 0;
    }
};

const TilePosition = struct {
    x: usize,
    y: usize,
};

const World = struct {
    tile_maps: [2]TileMap = .{ tile_map, tile_map_2 },

    fn getTileMap(self: *const World, index: usize) *const TileMap {
        return &self.tile_maps[index];
    }
};

const world = World{};

// 0 表示地面，1 表示墙壁
const tile_map = TileMap{ .tiles = .{
    .{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1 },
    .{ 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1 },
    .{ 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
} };

const tile_map_2 = TileMap{ .tiles = .{
    .{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1 },
    .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1 },
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

    const current_map = world.getTileMap(state.map_index);
    drawTileMap(buffer, current_map);

    drawPlayer(buffer, state);
}

fn movePlayer(state: *GameState, input: *const api.Input) void {
    const controller: api.ControllerInput = input.controllers[0];
    const speed: f32 = 4.0;

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

    const current_map = world.getTileMap(state.map_index);
    const new_map_index = getNewTileMapIndex(state.map_index, current_map, new_x, new_y);
    if (new_map_index != state.map_index) {
        state.map_index = new_map_index;
        // Reset player position when changing maps
        if (new_map_index == 0) {
            state.player_x = 29.0;
        } else if (new_map_index == 1) {
            state.player_x = 3.0;
        }
        return;
    }
    if (canPlayerStandAt(current_map, new_x, new_y)) {
        state.player_x = new_x;
        state.player_y = new_y;
    }
}

fn getNewTileMapIndex(current_map_index: usize, map: *const TileMap, x: f32, y: f32) usize {
    const tile_position = map.getTilePosition(x, y);
    if (map.isAtDoor(tile_position)) {
        return if (current_map_index == 0) 1 else 0;
    } else {
        return current_map_index;
    }
}

fn canPlayerStandAt(map: *const TileMap, x: f32, y: f32) bool {
    const min_x = x - player_half_size;
    const min_y = y - player_half_size;
    const max_x = x + player_half_size;
    const max_y = y + player_half_size;

    if (min_x < 0.0 or min_y < 0.0) {
        return false;
    }

    const pos1 = map.getTilePosition(min_x, min_y);
    const pos4 = map.getMaxTilePosition(max_x, max_y);
    const pos2 = TilePosition{ .x = pos4.x, .y = pos1.y };
    const pos3 = TilePosition{ .x = pos1.x, .y = pos4.y };

    return map.isWalkable(pos1) and map.isWalkable(pos2) and map.isWalkable(pos3) and map.isWalkable(pos4);
}

fn drawPlayer(buffer: *api.OffScreenBuffer, state: *GameState) void {
    const min_x = state.player_x - player_half_size;
    const min_y = state.player_y - player_half_size;
    const max_x = state.player_x + player_half_size;
    const max_y = state.player_y + player_half_size;

    drawRectangleInMeters(buffer, min_x, min_y, max_x, max_y, 1.0, 0.0, 0.0);
}

fn drawTileMap(buffer: *api.OffScreenBuffer, map: *const TileMap) void {
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
            drawRectangleInMeters(buffer, min_x, min_y, max_x, max_y, color[0], color[1], color[2]);
        }
    }
}

fn clearBackground(buffer: *api.OffScreenBuffer) void {
    drawRectangleInPixels(buffer, 0.0, 0.0, @floatFromInt(buffer.width), @floatFromInt(buffer.height), 0.5, 0.5, 0.5);
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

fn drawRectangleInMeters(
    buffer: *api.OffScreenBuffer,
    min_x: f32,
    min_y: f32,
    max_x: f32,
    max_y: f32,
    r: f32,
    g: f32,
    b: f32,
) void {
    const pixel_min_x = min_x * pixels_per_meter;
    const pixel_min_y = min_y * pixels_per_meter;
    const pixel_max_x = max_x * pixels_per_meter;
    const pixel_max_y = max_y * pixels_per_meter;

    drawRectangleInPixels(buffer, pixel_min_x, pixel_min_y, pixel_max_x, pixel_max_y, r, g, b);
}

fn drawRectangleInPixels(
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

    const red_int: u8 = @intCast(roundToInt(r * 255.0));
    const green_int: u8 = @intCast(roundToInt(g * 255.0));
    const blue_int: u8 = @intCast(roundToInt(b * 255.0));

    var y = top;
    while (y < bottom) : (y += 1) {
        var x = left;
        while (x < right) : (x += 1) {
            buffer.setPixel(@intCast(x), @intCast(y), red_int, green_int, blue_int, 255);
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
