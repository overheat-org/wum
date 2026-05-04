const TypeNode = @import("./type-node.zig");
const FunctionNode = @import("./function-node.zig");

pub const ClassMethod = struct {
    id: TypeNode.Identifier,
    decorators: []Decorator,
    params: []FunctionNode.FunctionParam,
    index: usize,

    pub fn parseBody() void {}
    pub fn parseParams() void {}
    pub fn parse() void {}
};

pub const ClassProperty = struct {
    pub const Accessibility = enum {
        Public,
        Private,
        Protected,
    };

    accessibility: Accessibility,
    static: bool,
    computed: bool,
    key: TypeNode.Identifier,
    value: TypeNode.Any,
    index: usize,
};

pub const BodyClass = struct {
    methods: []ClassMethod,
    props: []ClassProperty,

    pub fn getConstructor(self: @This()) ClassMethod {
        _ = self;
        @panic("not implemented");
    }
};

pub const ClassExpr = struct {
    id: ?TypeNode.Identifier,
    decorators: []Decorator,
    body: ?BodyClass,

    pub fn parse(self: @This()) void {
        _ = self;
    }
};

pub const ObjectExpr = struct {};

pub const Expression = union(enum) {
    /// Elements ignored by parser
    Ignored: ?*anyopaque,
    Fn: FunctionNode.FunctionExpr,
    Class: ClassExpr,
    Object: ObjectExpr,
};

pub const Decorator = struct {
    expression: Expression,
};

pub const ClassDecl = struct {
    id: TypeNode.Identifier,
    decorators: []Decorator,
    body: ?BodyClass,

    pub fn parse(self: @This()) void {
        _ = self;
    }
};
