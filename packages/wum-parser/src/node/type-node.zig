const ExprNode = @import("./expr-node.zig");

pub const Any = struct {};

pub const TypeRef = struct {
    type_name: ExprNode.Identifier,
};

pub const UnionType = struct {
    types: []TypeRef,
};

pub const IntersectionType = struct {
    types: []TypeRef,
};

pub const TypeAnnotation = union(enum) {
    Union: UnionType,
    Intersection: IntersectionType,
    Ref: TypeRef,
};
