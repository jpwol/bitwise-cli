const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");
const HashTable = @import("hash.zig").HashTable(i64, 128);
const allocator = std.heap.page_allocator;

const Node = ast.Node;
const Token = lexer.Token;
const TokenType = lexer.TokenType;

const ParseError = error{
    ExpectedRParen,
    ExpectedFactor,
    UnexpectedToken,
    UnknownOperator,
    OutOfMemory,
    Overflow,
    InvalidCharacter,
};

pub fn evaluate(node: *Node, var_table: *HashTable) !i64 {
    switch (node.node_type) {
        .constant => return node.value.constant,
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
            if (var_table.*.get(name) != null) {
                const ptr = var_table.getPtr(name);
                ptr.?.* = val;
            } else {
                try var_table.*.insert(name, val);
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
                    else => return error.InvalidCharacter,
                };
            }

            const rhs = try evaluate(node.right.?, var_table);

            return switch (op) {
                .add => lhs + rhs,
                .sub => lhs - rhs,
                .mul => lhs * rhs,
                .div => if (rhs == 0) return error.DivideByZero else @divExact(lhs, rhs),
                .greater => if (lhs > rhs) return 1 else return 0,
                .less => if (lhs < rhs) return 1 else return 0,
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
        else => return error.UnsupportedNodeType,
    }
}

// fn precedence(token: Token) u8 {
//     switch (token.type) {
//         .bit_not => return 9,
//         .star, .div => return 8,
//         .plus, .minus => return 7,
//         .shift_right, .shift_left => return 6,
//         .less, .greater => return 5,
//         .bit_and => return 4,
//         .bit_or => return 3,
//         .bit_xor => return 2,
//         .eql => return 1,
//         else => return 0,
//     }
// }

fn expect(tokens: []Token, pos: *usize, expected: TokenType) !void {
    if (pos.* >= tokens.len or tokens[pos.*].type != expected) return error.UnexpectedToken;

    pos.* += 1;
}

// factor -> number | identifier | '(' expression ')'
pub fn parseFactor(tokens: []Token, pos: *usize) ParseError!*Node {
    if (pos.* >= tokens.len) return ParseError.Overflow;

    const tok = tokens[pos.*];
    pos.* += 1;

    return switch (tok.type) {
        .number => try makeConstNode(tok),
        .identifier => try makeIdentifierNode(tok),
        .lparen => {
            const expr = try parseExpression(tokens, pos);
            try expect(tokens, pos, .rparen);
            return expr;
        },
        else => return error.ExpectedFactor,
    };
}

fn parseUnary(tokens: []Token, pos: *usize) ParseError!*Node {
    if (pos.* >= tokens.len) return error.Overflow;

    const tok = tokens[pos.*];

    if (tok.type == .minus or tok.type == .bit_not) {
        pos.* += 1;
        const expr = try parseUnary(tokens, pos);
        return try makeUnaryNode(tok, expr);
    }

    return parseFactor(tokens, pos);
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

pub fn parseExpression(tokens: []Token, pos: *usize) ParseError!*Node {
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

pub fn parseAssignment(tokens: []Token, pos: *usize) ParseError!*Node {
    const lhs = try parseExpression(tokens, pos);

    if (lhs.node_type == .variable and pos.* < tokens.len and tokens[pos.*].type == .eql) {
        pos.* += 1;
        const rhs = try parseAssignment(tokens, pos);
        return try makeAssignmentNode(lhs, rhs);
    }

    return lhs;
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
            else => return error.UnknownOperator,
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
            else => return error.UnexpectedToken,
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

fn makeIdentifierNode(token: Token) !*Node {
    const node = try allocator.create(Node);
    node.* = Node{
        .node_type = .variable,
        .value = .{ .variable = token.value.? },
        .left = null,
        .right = null,
    };
    return node;
}
