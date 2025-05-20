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
    modulo,
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

pub const Function = enum {
    sqrt,
    sin,
    cos,
    pow,
    exit,
};

pub const Node = struct {
    node_type: NodeType,
    value: Value,
    left: ?*Node,
    right: ?*Node,

    const Value = union(NodeType) {
        constant: f64,
        operator: OperatorType,
        variable: []const u8,
        function: struct {
            name: Function,
            args: []*Node,
        },
        assignment: u8,
    };
};
