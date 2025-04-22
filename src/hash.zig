const std = @import("std");
const Allocator = std.mem.Allocator;
// const allocator = std.heap.page_allocator;

// pub fn HashTable(comptime T: type, size: u64) type {
//     return ChainedHashTable(T, size);
// }
pub fn HashTable(comptime T: type, size: u64) type {
    return struct {
        const Self = @This();

        const Entry = struct {
            key: []const u8,
            value: T,
            next: ?*Entry,

            inline fn hash(key: []const u8, table_size: u64) u64 {
                var h: u64 = 0;
                for (key) |c| {
                    h = h * 31 + c;
                }

                return h % table_size;
            }
        };

        buckets: []?*Entry,
        size: u64,
        allocator: Allocator,

        pub fn init(allocator: Allocator) !Self {
            const buckets = try allocator.alloc(?*Entry, size);

            for (buckets) |*bucket| {
                bucket.* = null;
            }

            return Self{
                .buckets = buckets,
                .size = size,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.buckets) |*bucket| {
                var entry = bucket.*;
                while (entry) |e| {
                    const next = e.next;
                    self.allocator.free(e.key);
                    self.allocator.destroy(e);
                    entry = next;
                }
            }

            self.allocator.free(self.buckets);
        }

        pub fn insert(self: *Self, key: []const u8, value: T) !void {
            const index = Entry.hash(key, self.size);

            const entry = try self.allocator.create(Entry);
            entry.* = Entry{
                .key = key,
                .value = value,
                .next = self.buckets[index],
            };

            self.buckets[index] = entry;
        }

        pub fn get(self: *Self, key: []const u8) ?T {
            const index = Entry.hash(key, self.size);

            var entry = self.buckets[index];
            while (entry) |e| {
                if (std.mem.eql(u8, e.key, key)) {
                    return e.value;
                }
                entry = e.next;
            }

            return null;
        }

        pub fn getPtr(self: *Self, key: []const u8) ?*T {
            const index = Entry.hash(key, self.size);

            var entry = self.buckets[index];
            while (entry) |e| {
                if (std.mem.eql(u8, e.key, key)) {
                    return &e.value;
                }
                entry = e.next;
            }

            return null;
        }

        pub fn remove(self: *Self, key: []const u8) ?T {
            const index = Entry.hash(key, self.size);
            var current = self.buckets[index];
            var prev: ?*Entry = null;

            if (current == null) {
                return null;
            }

            while (current) |entry| {
                if (std.mem.eql(u8, entry.key, key)) {
                    const value = entry.value;
                    if (prev) |p| {
                        p.next = entry.next;
                    } else {
                        self.buckets[index] = entry.next;
                    }
                    self.allocator.destroy(entry);
                    return value;
                }

                prev = current;
                current = entry.next;
            }

            return null;
        }
    };
}
