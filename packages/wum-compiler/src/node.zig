const std = @import("std");
const Parser = @import("./parser.zig");

pub const Kind = enum {
    FnStmt,
};

pub const Range = struct { start: usize, end: usize };

const allocator = std.heap.page_allocator;
const Node = @This();

kind: Kind,
props: Props,

pub fn new(kind: Kind, props: anytype) *Node {
    const node = allocator.create(Node) catch @panic("allocator");

    node.* = .{
        .kind = kind,
        .props = @unionInit(Props, @tagName(kind), props),
    };

    return node;
}

const Props = union(Kind) {
    FnStmt: struct {
        name: []u8,
        ranges: struct {
            params: Range,
            body: Range,
        },
    },
};
