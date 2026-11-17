const arena = @import("arena.zig");

pub const chunk_size = 16;
pub const chunk_columns = 2;
pub const chunk_rows = 1;

pub const TileChunk = struct {
    tiles: [chunk_size][chunk_size]u8 = .{.{1} ** chunk_size} ** chunk_size,
};

pub const World = struct {
    arena: arena.Arena,
    chunks: []TileChunk,
    chunk_width: usize,
    chunk_height: usize,

    pub fn init(memory: []u8) World {
        var arena_obj = arena.Arena.init(memory);

        const chunks = arena_obj.pushArray(TileChunk, chunk_columns * chunk_rows);
        for (chunks) |*chunk| {
            chunk.* = .{};
        }

        var world = World{
            .arena = arena_obj,
            .chunks = chunks,
            .chunk_width = chunk_columns,
            .chunk_height = chunk_rows,
        };
        world.loadMaps();
        return world;
    }

    fn loadMaps(self: *World) void {
        self.generateRoom(0, 0);
        self.generateRoom(16, 0);
        self.setTile(15, 3, 0);
        self.setTile(16, 3, 0);
    }

    fn generateRoom(self: *World, origin_x: i32, origin_y: i32) void {
        for (0..tile_map_height) |local_y| {
            for (0..tile_map_width) |local_x| {
                const is_wall =
                    local_x == 0 or local_x == tile_map_width - 1 or
                    local_y == 0 or local_y == tile_map_height - 1;

                const tile_x = origin_x + @as(i32, @intCast(local_x));
                const tile_y = origin_y + @as(i32, @intCast(local_y));

                self.setTile(tile_x, tile_y, if (is_wall) 1 else 0);
            }
        }
    }

    fn getTileChunk(
        self: *const World,
        x: i32,
        y: i32,
    ) ?*TileChunk {
        if (x < 0 or y < 0) return null;
        const usize_x: usize = @intCast(x);
        const usize_y: usize = @intCast(y);
        if (usize_x >= self.chunk_width or usize_y >= self.chunk_height) return null;
        return &self.chunks[usize_y * self.chunk_width + usize_x];
    }

    pub fn getTile(self: *const World, tile_x: i32, tile_y: i32) u8 {
        const p = getChunkPosition(tile_x, tile_y);
        const chunk = self.getTileChunk(p.chunk_x, p.chunk_y) orelse return 1;
        return chunk.tiles[p.local_y][p.local_x];
    }

    pub fn setTile(self: *World, tile_x: i32, tile_y: i32, value: u8) void {
        const p = getChunkPosition(tile_x, tile_y);
        const chunk = self.getTileChunk(p.chunk_x, p.chunk_y) orelse return;
        chunk.tiles[p.local_y][p.local_x] = value;
    }
};

const tile_map_width = 16;
const tile_map_height = 9;

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
