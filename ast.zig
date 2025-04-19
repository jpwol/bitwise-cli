const std = @import("std");

pub const NodeType = enum {
    constant,
    operator,
    variable,
    function,
    assignment,
};

pub const OperatorType = enum {
    add,
    sub,
    mul,
    div,
    greater,
    less,
    shift_right,
    shift_left,
    bit_and,
    bit_or,
    bit_xor,
    bit_not,
    eql,
    lparen,
    rparen,
};

pub const Node = struct {
    const Self = @This();

    node_type: NodeType,
    value: Value,
    left: ?*Node,
    right: ?*Node,

    const Value = union(NodeType) {
        constant: i64,
        operator: OperatorType,
        variable: []const u8,
        function: []const u8,
        assignment: u8,
    };
};
