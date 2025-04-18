const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");
const allocator = std.heap.page_allocator;

const Node = ast.Node;
const Token = lexer.Token;

const ParseError = error{
    ExpectedRParen,
    ExpectedFactor,
    UnexpectedToken,
    UnknownOperator,
    OutOfMemory,
    Overflow,
    InvalidCharacter,
};

pub fn evaluate(node: *Node) !i64 {
    switch (node.node_type) {
        .constant => return node.value.constant,
        .operator => {
            const op = node.value.operator;
            const lhs = try evaluate(node.left.?);
            const rhs = try evaluate(node.right.?);

            return switch (op) {
                .add => lhs + rhs,
                .sub => lhs - rhs,
                .mul => lhs * rhs,
                .div => if (rhs == 0) return error.DivideByZero else @divExact(lhs, rhs),
                .greater => if (lhs > rhs) 1 else 0,
                .less => if (lhs < rhs) 1 else 0,
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

fn precedence(token: Token) u8 {
    switch (token.type) {
        .bit_not => return 9,
        .star, .div => return 8,
        .plus, .minus => return 7,
        .shift_right, .shift_left => return 6,
        .less, .greater => return 5,
        .bit_and => return 4,
        .bit_or => return 3,
        .bit_xor => return 2,
        .eql => return 1,
        else => return 0,
    }
}

pub fn parseFactor(tokens: []Token, pos: *usize, min_prec: u8) ParseError!*Node {
    if (pos.* >= tokens.len) return ParseError.Overflow;

    const tok = tokens[pos.*];
    pos.* += 1;

    return switch (tok.type) {
        .number => try makeConstNode(tok),
        .lparen => {
            const node = try parseExpression(tokens, pos, min_prec);
            if (tokens[pos.*].type != .rparen) return error.ExpectedRParen;
            pos.* += 1;
            return node;
        },
        else => return error.ExpectedFactor,
    };
}

// pub fn parseTerm(tokens: []Token, pos: *usize) !*Node {
//     // var node = try parseFactor(tokens, pos, min_prec);
//
//     while (pos.* < tokens.len) {
//         const tok = tokens[pos.*];
//         if (tok.type != .star and tok.type != .div) break;
//
//         pos.* += 1;
//         const rhs = try parseFactor(tokens, pos);
//         node = try makeBinaryNode(tok, node, rhs);
//     }
//
//     return node;
// }

pub fn parseExpression(tokens: []Token, pos: *usize, min_prec: u8) ParseError!*Node {
    var lhs = try parseFactor(tokens, pos, min_prec);

    while (pos.* < tokens.len) {
        const op = tokens[pos.*];
        if (op.type == .eof) break;

        const prec = precedence(op);

        if (prec < min_prec) break;
        pos.* += 1;
        const rhs = try parseExpression(tokens, pos, prec + 1);
        lhs = try makeBinaryNode(op, lhs, rhs);
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
