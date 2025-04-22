const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");
const HashTable = @import("hash.zig").HashTable(i64, 128);
const allocator = std.heap.page_allocator;

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

pub fn evaluate(node: *Node, var_table: *HashTable) ParseError!i64 {
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
                        return @intFromFloat(@sqrt(@as(f64, @floatFromInt(x))));
                    }
                },
                .sin => @intFromFloat(@sin(@as(f64, @floatFromInt(x)))),
                .cos => @intFromFloat(@cos(@as(f64, @floatFromInt(x)))),
                .exit => std.process.exit(@intCast(x)),
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
                    .bit_not => ~lhs,
                    else => return ParseError.InvalidCharacter,
                };
            }

            const rhs = try evaluate(node.right.?, var_table);

            return switch (op) {
                .add => lhs + rhs,
                .sub => lhs - rhs,
                .mul => lhs * rhs,
                .div => if (rhs == 0) return ParseError.DivideByZero else @divTrunc(lhs, rhs),
                .greater => @intFromBool(lhs > rhs),
                .less => @intFromBool(lhs < rhs),
                .shift_left => lhs << @intCast(rhs),
                .shift_right => lhs >> @intCast(rhs),
                .bit_and => lhs & rhs,
                .bit_or => lhs | rhs,
                .bit_xor => lhs ^ rhs,
                .bit_not => ~lhs,
                .eql => 0,
                .lparen => 0,
                .rparen => 0,
            };
        },
        // else => return ParseError.UnsupportedNodeType,
    }
}

fn expect(tokens: []Token, pos: *usize, expected: TokenType) !void {
    if (pos.* >= tokens.len or tokens[pos.*].type != expected) return ParseError.UnexpectedToken;

    pos.* += 1;
}

pub fn parseExpression(tokens: []Token, pos: *usize) ParseError!*Node {
    const lhs = try parseBitXor(tokens, pos);

    if (lhs.node_type == .variable and pos.* < tokens.len and tokens[pos.*].type == .eql) {
        pos.* += 1;
        const rhs = try parseExpression(tokens, pos);
        return try makeAssignmentNode(lhs, rhs);
    }

    return lhs;
}

fn parseBitXor(tokens: []Token, pos: *usize) ParseError!*Node {
    var lhs = try parseBitOr(tokens, pos);

    while (pos.* < tokens.len and tokens[pos.*].type == .bit_xor) {
        const tok = tokens[pos.*];
        pos.* += 1;
        const rhs = try parseBitOr(tokens, pos);
        lhs = try makeBinaryNode(tok, lhs, rhs);
    }

    return lhs;
}

fn parseBitOr(tokens: []Token, pos: *usize) ParseError!*Node {
    var lhs = try parseBitAnd(tokens, pos);

    while (pos.* < tokens.len and tokens[pos.*].type == .bit_or) {
        const tok = tokens[pos.*];
        pos.* += 1;
        const rhs = try parseBitAnd(tokens, pos);
        lhs = try makeBinaryNode(tok, lhs, rhs);
    }

    return lhs;
}

fn parseBitAnd(tokens: []Token, pos: *usize) ParseError!*Node {
    var lhs = try parseComparison(tokens, pos);

    while (pos.* < tokens.len and tokens[pos.*].type == .bit_and) {
        const tok = tokens[pos.*];
        pos.* += 1;
        const rhs = try parseComparison(tokens, pos);
        lhs = try makeBinaryNode(tok, lhs, rhs);
    }

    return lhs;
}

fn parseComparison(tokens: []Token, pos: *usize) ParseError!*Node {
    var lhs = try parseBitShift(tokens, pos);

    while (pos.* < tokens.len and tokens[pos.*].type == .less or tokens[pos.*].type == .greater) {
        const tok = tokens[pos.*];
        pos.* += 1;
        const rhs = try parseBitShift(tokens, pos);
        lhs = try makeBinaryNode(tok, lhs, rhs);
    }

    return lhs;
}

fn parseBitShift(tokens: []Token, pos: *usize) ParseError!*Node {
    var lhs = try parseAdditive(tokens, pos);

    while (pos.* < tokens.len and tokens[pos.*].type == .shift_left or tokens[pos.*].type == .shift_right) {
        const tok = tokens[pos.*];
        pos.* += 1;
        const rhs = try parseAdditive(tokens, pos);
        lhs = try makeBinaryNode(tok, lhs, rhs);
    }

    return lhs;
}

fn parseAdditive(tokens: []Token, pos: *usize) ParseError!*Node {
    var lhs = try parseTerm(tokens, pos);

    while (pos.* < tokens.len) {
        const tok = tokens[pos.*];
        if (tok.type != .plus and tok.type != .minus) break;
        pos.* += 1;

        const rhs = try parseTerm(tokens, pos);
        lhs = try makeBinaryNode(tok, lhs, rhs);
    }

    return lhs;
}

fn parseTerm(tokens: []Token, pos: *usize) ParseError!*Node {
    var lhs = try parseUnary(tokens, pos);

    while (pos.* < tokens.len) {
        const tok = tokens[pos.*];
        if (tok.type != .star and tok.type != .div) break;
        pos.* += 1;

        const rhs = try parseUnary(tokens, pos);
        lhs = try makeBinaryNode(tok, lhs, rhs);
    }

    return lhs;
}

fn parseUnary(tokens: []Token, pos: *usize) ParseError!*Node {
    if (pos.* >= tokens.len) return ParseError.Overflow;

    const tok = tokens[pos.*];

    if (tok.type == .minus or tok.type == .bit_not) {
        pos.* += 1;
        const expr = try parseUnary(tokens, pos);
        return try makeUnaryNode(tok, expr);
    }

    return parseFactor(tokens, pos);
}

// factor -> number | identifier | '(' expression ')'
fn parseFactor(tokens: []Token, pos: *usize) ParseError!*Node {
    if (pos.* >= tokens.len) return ParseError.Overflow;

    const tok = tokens[pos.*];
    pos.* += 1;

    return switch (tok.type) {
        .number => try makeConstNode(tok),
        .identifier => {
            if (pos.* < tokens.len and tokens[pos.*].type == .lparen) {
                pos.* += 1;
                var args = std.ArrayList(*Node).init(allocator);

                if (tokens[pos.*].type != .rparen) {
                    while (true) {
                        const arg = try parseExpression(tokens, pos);
                        try args.append(arg);

                        if (tokens[pos.*].type == .comma) {
                            pos.* += 1;
                        } else break;
                    }
                }
                try expect(tokens, pos, .rparen);

                const arg_array = try args.toOwnedSlice();
                return try makeFunctionNode(tok, arg_array);
            } else {
                if (std.mem.eql(u8, tok.value.?, "sqrt") or
                    std.mem.eql(u8, tok.value.?, "sin") or
                    std.mem.eql(u8, tok.value.?, "cos") or
                    std.mem.eql(u8, tok.value.?, "exit")) return ParseError.ReservedName;

                return try makeVariableNode(tok);
            }
        },
        .lparen => {
            const expr = try parseExpression(tokens, pos);
            try expect(tokens, pos, .rparen);
            return expr;
        },
        else => return ParseError.ExpectedFactor,
    };
}

pub fn makeBinaryNode(op: Token, lhs: *Node, rhs: *Node) ParseError!*Node {
    const node = try allocator.create(Node);
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

pub fn makeConstNode(token: Token) ParseError!*Node {
    const value_int = try std.fmt.parseInt(i64, token.value.?, 10);

    const node = try allocator.create(Node);
    node.* = Node{
        .node_type = .constant,
        .value = .{ .constant = value_int },
        .left = null,
        .right = null,
    };

    return node;
}

fn makeUnaryNode(operator: Token, operand: *Node) !*Node {
    const node = try allocator.create(Node);

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

fn makeAssignmentNode(identifier: *Node, value: *Node) !*Node {
    const node = try allocator.create(Node);

    node.* = Node{
        .node_type = .assignment,
        .value = .{ .assignment = '=' },
        .left = identifier,
        .right = value,
    };

    return node;
}

fn makeVariableNode(token: Token) !*Node {
    const node = try allocator.create(Node);
    node.* = Node{
        .node_type = .variable,
        .value = .{ .variable = token.value.? },
        .left = null,
        .right = null,
    };
    return node;
}

fn makeFunctionNode(token: Token, args: []*Node) ParseError!*Node {
    const node = try allocator.create(Node);

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
