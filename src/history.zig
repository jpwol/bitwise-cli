const std = @import("std");

pub const History = struct {
    const max_entries = 100;
    buffer: [max_entries][]const u8 = undefined,
    allocator: std.mem.Allocator,
    count: usize = 0,
    start: usize = 0,
    capacity: usize,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) History {
        return History{
            .allocator = allocator,
            .capacity = capacity,
        };
    }

    pub fn add(self: *History, input: []const u8) !void {
        const dupe = try self.allocator.dupe(u8, input);

        const index = (self.start + self.count) % max_entries;
        if (self.count == max_entries) {
            self.allocator.free(self.buffer[self.start]);
            self.start = (self.start + 1) % max_entries;
        } else {
            self.count += 1;
        }
        self.buffer[index] = dupe;
    }

    pub fn get(self: *History, i: usize) ?[]const u8 {
        if (i >= self.count) return null;
        const index = (self.start + i) % max_entries;
        return self.buffer[index];
    }

    pub fn deinit(self: *History) void {
        for (self.buffer[0..self.count]) |entry| {
            self.allocator.free(entry);
        }
    }
};
