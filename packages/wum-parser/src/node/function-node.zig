const TypeNode = @import("./type-node.zig");

pub const Identifier = struct {
    name: []const u8,
};

pub const FunctionParam = struct {
    id: Identifier,
    type_annotation: TypeNode.TypeAnnotation,
    init: TypeNode.Any,
};

pub const FunctionExpr = struct {
    id: ?Identifier,
    params: []FunctionParam,

    pub fn parseBody() void {}
    pub fn parseParams() void {}
    pub fn parse() void {}
};

pub const ArrowFunctionExpr = struct {
    id: ?Identifier,
    params: []FunctionParam,

    pub fn parseBody() void {}
    pub fn parseParams() void {}
    pub fn parse() void {}
};
