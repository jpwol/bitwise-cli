const std = @import("std");
const os = std.os;
const Node = @import("ast.zig").Node;
const Lexer = @import("lexer.zig");
const allocator = std.heap.page_allocator;
const Parser = @import("parser.zig");
const HashTable = @import("hash.zig").HashTable;
const Arena = @import("arena.zig").Arena;
const term = @import("terminal.zig");
const History = @import("history.zig").History;

pub fn main() !u8 {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    const writer = stdout.writer();
    const reader = stdin.reader();
    const err_writer = std.io.getStdErr().writer();

    var arena = try Arena.init(allocator, 1024);
    defer arena.deinit();

    var var_table = try HashTable(f64, 128).init(allocator);
    defer var_table.deinit();

    const pi_key = try allocator.dupe(u8, "PI");
    try var_table.insert(pi_key, 3.14159265359);

    var should_exit = false;
    var exit_code: u8 = 0;

    const original = try term.enableRawMode(stdin.handle);
    defer term.disableRawMode(stdin.handle, original) catch unreachable;

    var history = History.init(allocator, 32);

    while (true) {
        arena.reset();

        const buf = try term.getInput(reader, writer, &history, &should_exit);
        if (should_exit) {
            break;
        }

        try arena.ensureCapacity(buf.len * @sizeOf(Node));

        const tokens = Lexer.lex(buf, allocator) catch |err| {
            try err_writer.print("\nLex Error: {}\n", .{err});
            continue;
        };

        var pos: usize = 0;
        const root = Parser.parseExpression(tokens, &pos, &arena) catch |err| {
            try err_writer.print("\nParse Error: {}\n", .{err});
            continue;
        };
        const result = Parser.evaluate(root, &var_table, &should_exit) catch |err| {
            try err_writer.print("\nEvaluate Error: {}\n", .{err});
            continue;
        };

        if (should_exit) {
            exit_code = @intFromFloat(result);
            break;
        }

        if (@floor(result) == result) {
            try writer.print("\n{d}\n", .{result});
        } else {
            try writer.print("\n{d:.2}\n", .{result});
        }
    }
    try writer.print("\n", .{});

    return exit_code;
}
