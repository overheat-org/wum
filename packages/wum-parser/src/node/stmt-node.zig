const TypeNode = @import("./type-node.zig");

pub const EnumMember = struct {
    id: TypeNode.Identifier,
    init: TypeNode.Any,
};

pub const Enum = struct {
    id: TypeNode.Identifier,
    members: ?[]EnumMember,

    pub fn parse() void {}
};

pub const Type = struct {};

pub const Interface = struct {};

pub const JsxElement = struct {};

pub const Import = struct {};

pub const Export = struct {};
