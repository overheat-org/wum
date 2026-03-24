const std = @import("std");
const Parser = @import("./parser.zig");
const Graph = @import("./graph.zig");

const File = Graph.File;

pub const Kind = enum {
    Id,
    Fn,
    Class,
    ClassBody,
    Import,
    Export,
    JsxElement,
    CallExpr,
};

pub const Range = struct { start: usize, end: usize };

const allocator = std.heap.page_allocator;
const Node = @This();

kind: Kind,
props: Props,
file: File,

pub fn new(kind: Kind, props: anytype) *Node {
    const node = allocator.create(Node) catch @panic("allocator");

    node.* = .{
        .kind = kind,
        .props = @unionInit(Props, @tagName(kind), props),
    };

    return node;
}

pub fn is(self: *Node, kind: Kind) bool {
    return self.kind == kind;
}

pub fn hasType(self: *Node) bool {
    return switch (self.props) {
        .Id => self.props.Id.infer != null,
        _ => unreachable,
    };
}

pub fn getType(self: *Node, parser: *Parser) ?*Node {}

pub fn getNode(self: *Node, comptime propName: []const u8) *Node {}

pub fn getProps(self: *Node, comptime k: Kind) *const @FieldType(Props, @tagName(k)) {
    return switch (self.props) {
        k => |*v| v,
        else => unreachable,
    };
}

pub fn getBody(self: *Node, parser: *Parser) *Node {
    return switch (self.props) {
        .Fn => |symbol| parser.parseRange(symbol.ranges.body),
        .Class => |symbol| parser.parseRange(symbol.ranges.body),
        _ => unreachable,
    };
}

pub fn getParams(self: *Node, parser: *Parser) []*Node {
    return switch (self.props) {
        .Fn => |fnStmt| parser.parseRange(fnStmt.ranges.params),
        _ => unreachable,
    };
}

pub fn getConstructor(self: *Node, parser: *Parser) *Node {
    return switch (self.props) {
        .ClassBody => |symbol| parser.parseRange(symbol.ranges.constructor),
        _ => unreachable,
    };
}

pub fn getParent(self: *Node) ?*Node {
    return switch (self.props) {
        .Id => |symbol| symbol.parent,
    };
}

pub fn getDecorators(self: *Node) []*Node {}

pub const Id = struct {
    name: []const u8,
    infer: ?*Node,
    parent: ?*Node,
};

pub const CallExpr = struct {
    id: *Node,
    params: []*Node,
};

pub const Props = union(Kind) {
    Id: Id,
    CallExpr: CallExpr,
    Fn: struct {
        id: *Node,
        ranges: struct {
            params: Range,
            body: Range,
        },
    },
    Class: struct {
        id: *Node,
        ranges: struct {
            body: Range,
        },
    },
    ClassBody: struct {
        ranges: struct {
            constructor: Range,
        },
    },
    Import: struct {
        id: *Node,
        source: *Node,
    },
    Export: struct { id: *Node },
};
