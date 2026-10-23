const std = @import("std");

const api = @import("game_api.zig");

const pixels_per_meter: f32 = 25.0;
const player_size: f32 = 1.2;
const player_half_size: f32 = player_size / 2.0;
const tile_size: f32 = 2.0;
const tile_map_width = 16;
const tile_map_height = 9;
const chunk_size = 16;

const WorldPosition = struct {
    tile_x: i32 = 0,
    tile_y: i32 = 0,
    offset_x: f32 = 0.0,
    offset_y: f32 = 0.0,

    fn move(self: *WorldPosition, delta_x: f32, delta_y: f32) void {
        self.offset_x += delta_x;
        self.offset_y += delta_y;
        self.recanonicalize();
    }

    fn recanonicalize(self: *WorldPosition) void {
        const delta_x: i32 = @intFromFloat(@floor(self.offset_x / tile_size));
        const delta_y: i32 = @intFromFloat(@floor(self.offset_y / tile_size));

        self.tile_x += delta_x;
        self.tile_y += delta_y;

        self.offset_x -= @as(f32, @floatFromInt(delta_x)) * tile_size;
        self.offset_y -= @as(f32, @floatFromInt(delta_y)) * tile_size;
    }
};

fn offsetPosition(
    position: WorldPosition,
    dx: f32,
    dy: f32,
) WorldPosition {
    var result = position;
    result.move(dx, dy);
    return result;
}

const PositionDelta = struct {
    x: f32,
    y: f32,
};

/// 返回 position 相对于 origin 的位移，单位为米，正 Y 向上。
fn getPositionDifference(position: WorldPosition, origin: WorldPosition) PositionDelta {
    // 先求整数差再转换为浮点数，保留大坐标附近的小距离精度。
    const tile_delta_x = @as(i64, position.tile_x) - @as(i64, origin.tile_x);
    const tile_delta_y = @as(i64, position.tile_y) - @as(i64, origin.tile_y);

    return .{
        .x = @as(f32, @floatFromInt(tile_delta_x)) * tile_size +
            (position.offset_x - origin.offset_x),
        .y = @as(f32, @floatFromInt(tile_delta_y)) * tile_size +
            (position.offset_y - origin.offset_y),
    };
}

const ChunkPosition = struct {
    chunk_x: i32,
    chunk_y: i32,
    local_x: usize,
    local_y: usize,
};

fn getChunkPosition(tile_x: i32, tile_y: i32) ChunkPosition {
    return .{
        .chunk_x = @divFloor(tile_x, chunk_size),
        .chunk_y = @divFloor(tile_y, chunk_size),
        .local_x = @intCast(@mod(tile_x, chunk_size)),
        .local_y = @intCast(@mod(tile_y, chunk_size)),
    };
}

const TileChunk = struct {
    tiles: [chunk_size][chunk_size]u8 = .{.{1} ** chunk_size} ** chunk_size,
};

pub const GameState = struct {
    tone_hz: f32 = 256.0,
    running_sample_index: u32 = 0,
    player_position: WorldPosition = .{
        .tile_x = 1,
        .tile_y = 7,
        .offset_x = 1.0,
        .offset_y = 1.0,
    },
};

const TileMap = struct {
    tiles: [tile_map_height][tile_map_width]u8,
};

const World = struct {
    chunks: [1][2]TileChunk = createChunks(),

    fn getTileChunk(
        self: *const World,
        chunk_x: i32,
        chunk_y: i32,
    ) ?*const TileChunk {
        if (chunk_x < 0 or chunk_y < 0) return null;

        const x: usize = @intCast(chunk_x);
        const y: usize = @intCast(chunk_y);

        if (y >= self.chunks.len or x >= self.chunks[y].len) {
            return null;
        }

        return &self.chunks[y][x];
    }

    fn getTile(self: *const World, tile_x: i32, tile_y: i32) u8 {
        const p = getChunkPosition(tile_x, tile_y);
        const chunk = self.getTileChunk(p.chunk_x, p.chunk_y) orelse return 1;
        return chunk.tiles[p.local_y][p.local_x];
    }

    fn isWalkable(self: *const World, position: WorldPosition) bool {
        const tile = self.getTile(position.tile_x, position.tile_y);
        return tile == 0;
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

fn createChunks() [1][2]TileChunk {
    var chunks: [1][2]TileChunk = .{.{ .{}, .{} }};
    const maps = [_]TileMap{ tile_map, tile_map_2 };

    for (maps, 0..) |map, map_x| {
        for (map.tiles, 0..) |row, row_index| {
            // 手写地图从上往下排列，chunk 内的 Y 则从下往上增加。
            const tile_y = tile_map_height - 1 - row_index;
            for (row, 0..) |tile, local_x| {
                const tile_x = map_x * tile_map_width + local_x;
                chunks[tile_y / chunk_size][tile_x / chunk_size]
                    .tiles[tile_y % chunk_size][tile_x % chunk_size] = tile;
            }
        }
    }

    return chunks;
}

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

    const camera_position = state.player_position;
    drawTileMap(buffer, camera_position);

    drawPlayer(buffer, state, camera_position);
}

fn movePlayer(state: *GameState, input: *const api.Input) void {
    const controller: api.ControllerInput = input.controllers[0];
    const speed: f32 = 4.0;

    const position = state.player_position;
    var new_position = position;

    var dx: f32 = 0.0;
    var dy: f32 = 0.0;
    if (controller.move_left.isDown()) {
        dx -= speed * input.delta_time;
    }
    if (controller.move_right.isDown()) {
        dx += speed * input.delta_time;
    }
    if (controller.move_up.isDown()) {
        dy += speed * input.delta_time;
    }
    if (controller.move_down.isDown()) {
        dy -= speed * input.delta_time;
    }
    new_position.move(dx, dy);

    if (canPlayerStandAt(new_position)) {
        state.player_position = new_position;
    }
}

fn canPlayerStandAt(position: WorldPosition) bool {
    const min_min = offsetPosition(position, -player_half_size, -player_half_size);
    var max_min = offsetPosition(position, player_half_size, -player_half_size);
    var min_max = offsetPosition(position, -player_half_size, player_half_size);
    var max_max = offsetPosition(position, player_half_size, player_half_size);

    // 碰撞范围不包含最大 X/Y 边界；这里只调整查询格子，不再规范化。
    if (max_min.offset_x == 0.0) max_min.tile_x -= 1;
    if (min_max.offset_y == 0.0) min_max.tile_y -= 1;
    if (max_max.offset_x == 0.0) max_max.tile_x -= 1;
    if (max_max.offset_y == 0.0) max_max.tile_y -= 1;

    return world.isWalkable(min_min) and world.isWalkable(max_min) and world.isWalkable(min_max) and world.isWalkable(max_max);
}

fn drawPlayer(
    buffer: *api.OffScreenBuffer,
    state: *const GameState,
    camera_position: WorldPosition,
) void {
    const delta = getPositionDifference(state.player_position, camera_position);
    const min_x = delta.x - player_half_size;
    const min_y = delta.y - player_half_size;
    const max_x = delta.x + player_half_size;
    const max_y = delta.y + player_half_size;

    drawRectangleInMeters(buffer, min_x, min_y, max_x, max_y, 1.0, 0.0, 0.0);
}

fn drawTileMap(buffer: *api.OffScreenBuffer, camera_position: WorldPosition) void {
    const half_width = @as(f32, @floatFromInt(buffer.width)) * 0.5 / pixels_per_meter;
    const half_height = @as(f32, @floatFromInt(buffer.height)) * 0.5 / pixels_per_meter;
    const min_position = offsetPosition(camera_position, -half_width, -half_height);
    const max_position = offsetPosition(camera_position, half_width, half_height);

    // 包含窗口边缘的部分格子；最终由像素绘制函数裁剪。
    var tile_y = min_position.tile_y;
    while (tile_y <= max_position.tile_y) : (tile_y += 1) {
        var tile_x = min_position.tile_x;
        while (tile_x <= max_position.tile_x) : (tile_x += 1) {
            const tile = world.getTile(tile_x, tile_y);
            const delta = getPositionDifference(.{
                .tile_x = tile_x,
                .tile_y = tile_y,
            }, camera_position);

            const shade: f32 = if (tile == 1) 0.0 else 1.0;

            drawRectangleInMeters(
                buffer,
                delta.x,
                delta.y,
                delta.x + tile_size,
                delta.y + tile_size,
                shade,
                shade,
                shade,
            );
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

/// 绘制相对于摄像机的米制矩形，屏幕中心为原点，正 Y 向上。
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
    const center_x = @as(f32, @floatFromInt(buffer.width)) * 0.5;
    const center_y = @as(f32, @floatFromInt(buffer.height)) * 0.5;

    const pixel_min_x = center_x + min_x * pixels_per_meter;
    const pixel_max_x = center_x + max_x * pixels_per_meter;
    const pixel_min_y = center_y - max_y * pixels_per_meter;
    const pixel_max_y = center_y - min_y * pixels_per_meter;

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
    if (!(player_size > 0.0 and player_size <= tile_size)) {
        @compileError("Four-corner collision requires 0 < player_size <= tile_size.");
    }

    const update: api.UpdateAndRenderFn = &updateAndRender;
    const sound: api.GetSoundSamplesFn = &getSoundSamples;

    _ = update;
    _ = sound;
}
