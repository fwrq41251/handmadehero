const std = @import("std");

const api = @import("game_api.zig");

const pixels_per_meter: f32 = 25.0;
const player_size: f32 = 1.2;
const player_half_size: f32 = player_size / 2.0;

const WorldPosition = struct {
    map_x: i32 = 0,
    map_y: i32 = 0,
    x: f32 = 3.0, // 房间内坐标，单位为米。
    y: f32 = 3.0,
};

pub const GameState = struct {
    tone_hz: f32 = 256.0,
    running_sample_index: u32 = 0,
    player_position: WorldPosition = .{},
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
    // 第一维是房间行，第二维是房间列。
    tile_maps: [1][2]TileMap = .{.{ tile_map, tile_map_2 }},

    fn getTileMap(self: *const World, map_x: i32, map_y: i32) ?*const TileMap {
        if (map_x < 0 or map_y < 0) return null;

        const x: usize = @intCast(map_x);
        const y: usize = @intCast(map_y);
        if (y >= self.tile_maps.len or x >= self.tile_maps[y].len) return null;

        return &self.tile_maps[y][x];
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

    const position = state.player_position;
    const current_map = world.getTileMap(position.map_x, position.map_y) orelse return;
    drawTileMap(buffer, current_map);

    drawPlayer(buffer, state);
}

fn movePlayer(state: *GameState, input: *const api.Input) void {
    const controller: api.ControllerInput = input.controllers[0];
    const speed: f32 = 4.0;

    const position = state.player_position;
    const current_map = world.getTileMap(position.map_x, position.map_y) orelse return;
    var new_position = position;

    if (controller.move_left.isDown()) {
        new_position.x -= speed * input.delta_time;
    }
    if (controller.move_right.isDown()) {
        new_position.x += speed * input.delta_time;
    }
    if (controller.move_up.isDown()) {
        new_position.y -= speed * input.delta_time;
    }
    if (controller.move_down.isDown()) {
        new_position.y += speed * input.delta_time;
    }

    new_position = getNewWorldPosition(current_map, new_position) orelse return;
    const target_map = world.getTileMap(new_position.map_x, new_position.map_y) orelse return;
    if (canPlayerStandAt(target_map, new_position.x, new_position.y)) {
        state.player_position = new_position;
    }
}

fn getNewWorldPosition(map: *const TileMap, position: WorldPosition) ?WorldPosition {
    // 候选位置可能越界，必须在转换为无符号格子索引前检查。
    if (position.x < 0.0 or position.y < 0.0) return null;

    const tile_position = map.getTilePosition(position.x, position.y);
    if (!map.isAtDoor(tile_position)) return position;

    var result = position;
    if (tile_position.x == 0) {
        result.map_x -= 1;
    } else if (tile_position.x == map.getWidth() - 1) {
        result.map_x += 1;
    } else if (tile_position.y == 0) {
        result.map_y -= 1;
    } else if (tile_position.y == map.getHeight() - 1) {
        result.map_y += 1;
    }

    const target_map = world.getTileMap(result.map_x, result.map_y) orelse return null;
    // 仍使用入口跳转：落在目标房间内侧一格的中心。
    if (result.map_x < position.map_x) {
        result.x = (@as(f32, @floatFromInt(target_map.getWidth())) - 1.5) * target_map.tile_size;
    } else if (result.map_x > position.map_x) {
        result.x = 1.5 * target_map.tile_size;
    } else if (result.map_y < position.map_y) {
        result.y = (@as(f32, @floatFromInt(target_map.getHeight())) - 1.5) * target_map.tile_size;
    } else if (result.map_y > position.map_y) {
        result.y = 1.5 * target_map.tile_size;
    }
    return result;
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
    const position = state.player_position;
    const min_x = position.x - player_half_size;
    const min_y = position.y - player_half_size;
    const max_x = position.x + player_half_size;
    const max_y = position.y + player_half_size;

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
