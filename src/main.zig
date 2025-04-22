const std = @import("std");
const Node = @import("ast.zig").Node;
const Lexer = @import("lexer.zig");
const allocator = std.heap.page_allocator;
const Parser = @import("parser.zig");
const HashTable = @import("hash.zig").HashTable;
const Arena = @import("arena.zig").Arena;

pub fn main() !void {
    const writer = std.io.getStdOut().writer();
    const reader = std.io.getStdIn().reader();
    const err_writer = std.io.getStdErr().writer();

    var arena = try Arena.init(allocator, 1024);
    defer arena.deinit();

    var var_table = try HashTable(i64, 128).init(allocator);
    defer var_table.deinit();

    var buf: [1024]u8 = undefined;

    while (true) {
        arena.reset();

        try writer.print("\x1b[34m>>>\x1b[0m ", .{});

        const input = try reader.readUntilDelimiterOrEof(&buf, '\n');

        if (input) |i| {
            try arena.ensureCapacity(i.len * @sizeOf(Node));

            const tokens = Lexer.lex(i, allocator) catch |err| {
                try err_writer.print("Error: {}\n", .{err});
                continue;
            };

            var pos: usize = 0;
            const root = Parser.parseExpression(tokens, &pos, &arena) catch |err| {
                try err_writer.print("Error: {}\n", .{err});
                continue;
            };
            const result = Parser.evaluate(root, &var_table) catch |err| {
                try err_writer.print("Error: {}\n", .{err});
                continue;
            };

            try writer.print("{}\n", .{result});
        } else {
            try writer.print("\n", .{});
            break;
        }
    }
}
