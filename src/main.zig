const std = @import("std");
const Node = @import("ast.zig").Node;
const Lexer = @import("lexer.zig");
const allocator = std.heap.page_allocator;
const Parser = @import("parser.zig");
const HashTable = @import("hash.zig").HashTable;

const writer = std.io.getStdOut().writer();
const reader = std.io.getStdIn().reader();

pub fn main() !void {
    var var_table = try HashTable(i64, 128).init(allocator);

    while (true) {
        try writer.print("\x1b[34m>>>\x1b[0m ", .{});

        const buf = try allocator.alloc(u8, 1024);

        const input = try reader.readUntilDelimiterOrEof(buf, '\n');

        if (input) |i| {
            const tokens = Lexer.lex(i, std.heap.page_allocator) catch |err| {
                std.debug.print("Error: {}\n", .{err});
                continue;
            };
            var pos: usize = 0;

            const root = Parser.parseExpression(tokens, &pos) catch |err| {
                std.debug.print("Error: {}\n", .{err});
                continue;
            };
            const result = Parser.evaluate(root, &var_table) catch |err| {
                std.debug.print("Error: {}\n", .{err});
                continue;
            };

            try writer.print("{}\n", .{result});
        } else {
            try writer.print("\n", .{});
            break;
        }
    }
}
