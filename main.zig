const std = @import("std");
const Node = @import("ast.zig").Node;
const Lexer = @import("lexer.zig");
const allocator = std.heap.page_allocator;
const Parser = @import("parser.zig");

const writer = std.io.getStdOut().writer();
const reader = std.io.getStdIn().reader();

pub fn main() !void {
    while (true) {
        try writer.print("\x1b[34m>>>\x1b[0m ", .{});

        const buf = try allocator.alloc(u8, 1024);

        const input = try reader.readUntilDelimiterOrEof(buf, '\n');

        if (input) |i| {
            const tokens = try Lexer.lex(i, std.heap.page_allocator);
            var pos: usize = 0;
            const root = try Parser.parseExpression(tokens, &pos, 0);
            const result = try Parser.evaluate(root);
            std.debug.print("Result: {}\n", .{result});
        } else {
            break;
        }
    }
}
