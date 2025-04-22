const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Arena = struct {
    buffer: []u8,
    allocator: Allocator,
    offset: usize = 0,

    pub fn init(allocator: Allocator, initial_size: usize) !Arena {
        return Arena{
            .buffer = try allocator.alloc(u8, initial_size),
            .allocator = allocator,
        };
    }

    pub fn alloc(self: *Arena, T: type) !*T {
        const size = @sizeOf(T);
        const alignment = @alignOf(T);
        const aligned_offset = std.mem.alignForward(usize, self.offset, alignment);

        if (aligned_offset + size > self.buffer.len)
            return error.OutOfMemory;

        const ptr = self.buffer.ptr + aligned_offset;
        self.offset = aligned_offset + size;
        return @ptrCast(@alignCast(ptr));
    }

    pub fn reset(self: *Arena) void {
        self.offset = 0;
    }

    pub fn ensureCapacity(self: *Arena, new_size: usize) !void {
        if (new_size > self.buffer.len) {
            self.allocator.free(self.buffer);
            self.buffer = try self.allocator.alloc(u8, new_size);
        }

        self.reset();
    }

    pub fn deinit(self: *Arena) void {
        self.allocator.free(self.buffer);
    }
};
