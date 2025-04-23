const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");
const HashTable = @import("hash.zig").HashTable(f64, 128);
const allocator = std.heap.page_allocator;
const Arena = @import("arena.zig").Arena;

const Node = ast.Node;
const Function = ast.Function;
const Token = lexer.Token;
const TokenType = lexer.TokenType;

pub const ParseError = error{
    ExpectedRParen,
    ExpectedFactor,
    UnexpectedToken,
    UnknownOperator,
    UnknownFunction,
    OutOfMemory,
    Overflow,
    InvalidCharacter,
    InvalidArgsNumber,
    SqrtOfNegative,
    DivideByZero,
    ReservedName,
};

pub fn evaluate(node: *Node, var_table: *HashTable) ParseError!f64 {
    switch (node.node_type) {
        .constant => return node.value.constant,
        .function => {
            const function_type = node.value.function.name;
            const args = node.value.function.args;
            if (args.len != 1) return ParseError.InvalidArgsNumber;

            const x = try evaluate(args[0], var_table);

            return switch (function_type) {
                .sqrt => {
                    if (x < 0) {
                        return ParseError.SqrtOfNegative;
                    } else {
                        return @sqrt(x);
                    }
                },
                .sin => @sin(x),
                .cos => @cos(x),
                .exit => std.process.exit(0),
            };
        },
        .variable => {
            const name = node.value.variable;
            if (var_table.*.get(name)) |val| {
                return val;
            } else {
                return 0;
            }
        },
        .assignment => {
            const identifier_node = node.left.?;
            const name = identifier_node.value.variable;
            const val = try evaluate(node.right.?, var_table);
            if (var_table.*.getPtr(name)) |p| {
                p.* = val;
            } else {
                const ident_copy = try allocator.dupe(u8, name);
                try var_table.*.insert(ident_copy, val);
            }

            return val;
        },
        .operator => {
            const op = node.value.operator;
            const lhs = try evaluate(node.left.?, var_table);

            if (node.right == null) {
                return switch (op) {
                    .sub => -lhs,
                    // .bit_not => ~(@as(i64, @intFromFloat(lhs))),
                    else => return ParseError.InvalidCharacter,
                };
            }

            const rhs = try evaluate(node.right.?, var_table);

            return switch (op) {
                .add => lhs + rhs,
                .sub => lhs - rhs,
                .mul => lhs * rhs,
                .div => if (rhs == 0) {
                    return ParseError.DivideByZero;
                } else {
                    return lhs / rhs;
                },
                .greater => @floatFromInt(@intFromBool(lhs > rhs)),
                .less => @floatFromInt(@intFromBool(lhs < rhs)),
                .shift_left => @floatFromInt((@as(i64, @intFromFloat(lhs))) << @intCast(@as(i64, @intFromFloat(rhs)))),
                .shift_right => @floatFromInt((@as(i64, @intFromFloat(lhs))) >> @intCast(@as(i64, @intFromFloat(rhs)))),
                .bit_and => @floatFromInt(@as(i64, @intFromFloat(lhs)) & @as(i64, @intFromFloat(rhs))),
                .bit_or => @floatFromInt(@as(i64, @intFromFloat(lhs)) | @as(i64, @intFromFloat(rhs))),
                .bit_xor => @floatFromInt(@as(i64, @intFromFloat(lhs)) ^ @as(i64, @intFromFloat(rhs))),
                .bit_not => @as(f64, (@floatFromInt(~@as(i64, @intFromFloat(lhs))))),
                .eql => 0,
                .lparen => 0,
                .rparen => 0,
            };
        },
    }
}

fn expect(tokens: []Token, pos: *usize, expected: TokenType) !void {
    if (pos.* >= tokens.len or tokens[pos.*].type != expected) return ParseError.UnexpectedToken;

    pos.* += 1;
}

pub fn parseExpression(tokens: []Token, pos: *usize, arena: *Arena) ParseError!*Node {
    const lhs = try parseBitXor(tokens, pos, arena);

    if (lhs.node_type == .variable and pos.* < tokens.len and tokens[pos.*].type == .eql) {
        pos.* += 1;
        const rhs = try parseExpression(tokens, pos, arena);
        return try makeAssignmentNode(lhs, rhs, arena);
    }

    return lhs;
}

fn parseBitXor(tokens: []Token, pos: *usize, arena: *Arena) ParseError!*Node {
    var lhs = try parseBitOr(tokens, pos, arena);

    while (pos.* < tokens.len and tokens[pos.*].type == .bit_xor) {
        const tok = tokens[pos.*];
        pos.* += 1;
        const rhs = try parseBitOr(tokens, pos, arena);
        lhs = try makeBinaryNode(tok, lhs, rhs, arena);
    }

    return lhs;
}

fn parseBitOr(tokens: []Token, pos: *usize, arena: *Arena) ParseError!*Node {
    var lhs = try parseBitAnd(tokens, pos, arena);

    while (pos.* < tokens.len and tokens[pos.*].type == .bit_or) {
        const tok = tokens[pos.*];
        pos.* += 1;
        const rhs = try parseBitAnd(tokens, pos, arena);
        lhs = try makeBinaryNode(tok, lhs, rhs, arena);
    }

    return lhs;
}

fn parseBitAnd(tokens: []Token, pos: *usize, arena: *Arena) ParseError!*Node {
    var lhs = try parseComparison(tokens, pos, arena);

    while (pos.* < tokens.len and tokens[pos.*].type == .bit_and) {
        const tok = tokens[pos.*];
        pos.* += 1;
        const rhs = try parseComparison(tokens, pos, arena);
        lhs = try makeBinaryNode(tok, lhs, rhs, arena);
    }

    return lhs;
}

fn parseComparison(tokens: []Token, pos: *usize, arena: *Arena) ParseError!*Node {
    var lhs = try parseBitShift(tokens, pos, arena);

    while (pos.* < tokens.len and tokens[pos.*].type == .less or tokens[pos.*].type == .greater) {
        const tok = tokens[pos.*];
        pos.* += 1;
        const rhs = try parseBitShift(tokens, pos, arena);
        lhs = try makeBinaryNode(tok, lhs, rhs, arena);
    }

    return lhs;
}

fn parseBitShift(tokens: []Token, pos: *usize, arena: *Arena) ParseError!*Node {
    var lhs = try parseAdditive(tokens, pos, arena);

    while (pos.* < tokens.len and tokens[pos.*].type == .shift_left or tokens[pos.*].type == .shift_right) {
        const tok = tokens[pos.*];
        pos.* += 1;
        const rhs = try parseAdditive(tokens, pos, arena);
        lhs = try makeBinaryNode(tok, lhs, rhs, arena);
    }

    return lhs;
}

fn parseAdditive(tokens: []Token, pos: *usize, arena: *Arena) ParseError!*Node {
    var lhs = try parseTerm(tokens, pos, arena);

    while (pos.* < tokens.len) {
        const tok = tokens[pos.*];
        if (tok.type != .plus and tok.type != .minus) break;
        pos.* += 1;

        const rhs = try parseTerm(tokens, pos, arena);
        lhs = try makeBinaryNode(tok, lhs, rhs, arena);
    }

    return lhs;
}

fn parseTerm(tokens: []Token, pos: *usize, arena: *Arena) ParseError!*Node {
    var lhs = try parseUnary(tokens, pos, arena);

    while (pos.* < tokens.len) {
        const tok = tokens[pos.*];
        if (tok.type != .star and tok.type != .div) break;
        pos.* += 1;

        const rhs = try parseUnary(tokens, pos, arena);
        lhs = try makeBinaryNode(tok, lhs, rhs, arena);
    }

    return lhs;
}

fn parseUnary(tokens: []Token, pos: *usize, arena: *Arena) ParseError!*Node {
    if (pos.* >= tokens.len) return ParseError.Overflow;

    const tok = tokens[pos.*];

    if (tok.type == .minus or tok.type == .bit_not) {
        pos.* += 1;
        const expr = try parseUnary(tokens, pos, arena);
        return try makeUnaryNode(tok, expr, arena);
    }

    return parseFactor(tokens, pos, arena);
}

// factor -> number | identifier | '(' expression ')'
fn parseFactor(tokens: []Token, pos: *usize, arena: *Arena) ParseError!*Node {
    if (pos.* >= tokens.len) return ParseError.Overflow;

    const tok = tokens[pos.*];
    pos.* += 1;

    return switch (tok.type) {
        .number => try makeConstNode(tok, arena),
        .identifier => {
            if (pos.* < tokens.len and tokens[pos.*].type == .lparen) {
                pos.* += 1;
                var args = std.ArrayList(*Node).init(allocator);

                if (tokens[pos.*].type != .rparen) {
                    while (true) {
                        const arg = try parseExpression(tokens, pos, arena);
                        try args.append(arg);

                        if (tokens[pos.*].type == .comma) {
                            pos.* += 1;
                        } else break;
                    }
                }
                try expect(tokens, pos, .rparen);

                const arg_array = try args.toOwnedSlice();
                return try makeFunctionNode(tok, arg_array, arena);
            } else {
                if (std.mem.eql(u8, tok.value.?, "sqrt") or
                    std.mem.eql(u8, tok.value.?, "sin") or
                    std.mem.eql(u8, tok.value.?, "cos") or
                    std.mem.eql(u8, tok.value.?, "exit")) return ParseError.ReservedName;

                return try makeVariableNode(tok, arena);
            }
        },
        .lparen => {
            const expr = try parseExpression(tokens, pos, arena);
            try expect(tokens, pos, .rparen);
            return expr;
        },
        else => return ParseError.ExpectedFactor,
    };
}

pub fn makeBinaryNode(op: Token, lhs: *Node, rhs: *Node, arena: *Arena) ParseError!*Node {
    const node = try arena.alloc(Node);
    node.* = Node{
        .node_type = .operator,
        .value = .{ .operator = switch (op.type) {
            .plus => .add,
            .minus => .sub,
            .star => .mul,
            .div => .div,
            .greater => .greater,
            .less => .less,
            .shift_right => .shift_right,
            .shift_left => .shift_left,
            .bit_and => .bit_and,
            .bit_or => .bit_or,
            .bit_xor => .bit_xor,
            .bit_not => .bit_not,
            .eql => .eql,
            else => return ParseError.UnknownOperator,
        } },
        .left = lhs,
        .right = rhs,
    };

    return node;
}

pub fn makeConstNode(token: Token, arena: *Arena) ParseError!*Node {
    const value = try std.fmt.parseFloat(f64, token.value.?);

    const node = try arena.alloc(Node);
    node.* = Node{
        .node_type = .constant,
        .value = .{ .constant = value },
        .left = null,
        .right = null,
    };

    return node;
}

fn makeUnaryNode(operator: Token, operand: *Node, arena: *Arena) !*Node {
    const node = try arena.alloc(Node);

    node.* = Node{
        .node_type = .operator,
        .value = .{ .operator = switch (operator.type) {
            .minus => .sub,
            .bit_not => .bit_not,
            else => return ParseError.UnexpectedToken,
        } },
        .left = operand,
        .right = null,
    };

    return node;
}

fn makeAssignmentNode(identifier: *Node, value: *Node, arena: *Arena) !*Node {
    const node = try arena.alloc(Node);

    node.* = Node{
        .node_type = .assignment,
        .value = .{ .assignment = '=' },
        .left = identifier,
        .right = value,
    };

    return node;
}

fn makeVariableNode(token: Token, arena: *Arena) !*Node {
    const node = try arena.alloc(Node);
    node.* = Node{
        .node_type = .variable,
        .value = .{ .variable = token.value.? },
        .left = null,
        .right = null,
    };
    return node;
}

fn makeFunctionNode(token: Token, args: []*Node, arena: *Arena) ParseError!*Node {
    const node = try arena.alloc(Node);

    var function_type: Function = undefined;

    if (std.mem.eql(u8, token.value.?, "sqrt")) {
        function_type = .sqrt;
    } else if (std.mem.eql(u8, token.value.?, "sin")) {
        function_type = .sin;
    } else if (std.mem.eql(u8, token.value.?, "cos")) {
        function_type = .cos;
    } else if (std.mem.eql(u8, token.value.?, "exit")) {
        function_type = .exit;
    } else {
        return ParseError.UnknownFunction;
    }
    node.* = Node{
        .node_type = .function,
        .value = .{ .function = .{ .name = function_type, .args = args } },
        .left = null,
        .right = null,
    };

    return node;
}
