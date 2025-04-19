const std = @import("std");

pub const TokenType = enum {
    number,
    identifier,
    plus,
    minus,
    star,
    div,
    less,
    greater,
    shift_left,
    shift_right,
    bit_and,
    bit_or,
    bit_xor,
    bit_not,
    eql,
    lparen,
    rparen,
    eof,
};

pub const Token = struct {
    type: TokenType,
    value: ?[]const u8,
};

pub fn lex(input: []const u8, allocator: std.mem.Allocator) ![]Token {
    var tokens = std.ArrayList(Token).init(allocator);
    var i: usize = 0;

    while (i < input.len) {
        const c = input[i];
        switch (c) {
            ' ', '\t' => {
                i += 1;
            },
            '0'...'9' => {
                const start = i;
                while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
                try tokens.append(Token{ .type = .number, .value = input[start..i] });
            },
            '+' => {
                try tokens.append(Token{ .type = .plus, .value = null });
                i += 1;
            },
            '-' => {
                try tokens.append(Token{ .type = .minus, .value = null });
                i += 1;
            },
            '*' => {
                try tokens.append(Token{ .type = .star, .value = null });
                i += 1;
            },
            '&' => {
                try tokens.append(Token{ .type = .bit_and, .value = null });
                i += 1;
            },
            '|' => {
                try tokens.append(Token{ .type = .bit_or, .value = null });
                i += 1;
            },
            '~' => {
                try tokens.append(Token{ .type = .bit_not, .value = null });
                i += 1;
            },
            '^' => {
                try tokens.append(Token{ .type = .bit_xor, .value = null });
                i += 1;
            },
            '<' => {
                if (input[i + 1] == '<') {
                    try tokens.append(Token{ .type = .shift_left, .value = null });
                    i += 2;
                } else {
                    try tokens.append(Token{ .type = .less, .value = null });
                    i += 1;
                }
            },
            '>' => {
                if (input[i + 1] == '>') {
                    try tokens.append(Token{ .type = .shift_right, .value = null });
                    i += 2;
                } else {
                    try tokens.append(Token{ .type = .greater, .value = null });
                    i += 1;
                }
            },
            '/' => {
                try tokens.append(Token{ .type = .div, .value = null });
                i += 1;
            },
            '(' => {
                try tokens.append(Token{ .type = .lparen, .value = null });
                i += 1;
            },
            ')' => {
                try tokens.append(Token{ .type = .rparen, .value = null });
                i += 1;
            },
            '=' => {
                try tokens.append(Token{ .type = .eql, .value = null });
                i += 1;
            },
            else => {
                if (std.ascii.isAlphabetic(c)) {
                    const start = i;
                    while (i < input.len and std.ascii.isAlphabetic(input[i])) : (i += 1) {}
                    try tokens.append(Token{ .type = .identifier, .value = input[start..i] });
                } else {
                    return error.InvalidCharacter;
                }
            },
        }
    }
    try tokens.append(Token{ .type = .eof, .value = "" });
    return tokens.toOwnedSlice();
}
