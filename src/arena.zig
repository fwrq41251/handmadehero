const std = @import("std");
const assert = std.debug.assert;

pub const Arena = struct {
    buffer: []u8,
    used: usize = 0,

    pub fn init(buffer: []u8) Arena {
        return Arena{
            .buffer = buffer,
            .used = 0,
        };
    }

    pub fn pushSize(self: *Arena, size: usize, alignment: usize) []u8 {
        assert(std.math.isPowerOfTwo(alignment));

        const current_addr = @intFromPtr(self.buffer.ptr) + self.used;
        const aligned_addr = std.mem.alignForward(usize, current_addr, alignment);
        const align_offset = aligned_addr - current_addr;

        assert(self.used <= self.buffer.len);
        assert(align_offset <= self.buffer.len - self.used);

        const start = self.used + align_offset;
        assert(size <= self.buffer.len - start);
        self.used = start + size;

        return self.buffer[start..self.used];
    }

    pub fn pushStruct(self: *Arena, comptime T: type) *T {
        const ptr = self.pushSize(@sizeOf(T), @alignOf(T));
        const typed_ptr: *T = @ptrCast(@alignCast(ptr));
        return typed_ptr;
    }

    pub fn pushArray(self: *Arena, comptime T: type, count: usize) []T {
        const size = std.math.mul(usize, @sizeOf(T), count) catch @panic("size overflow");
        const ptr = self.pushSize(size, @alignOf(T));
        const typed_ptr: []T = @ptrCast(@alignCast(ptr));
        return typed_ptr[0..count];
    }
};
