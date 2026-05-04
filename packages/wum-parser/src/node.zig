const Node = @This();

const TypeNode = @import("./node/type-node.zig");
const FunctionNode = @import("./node/function-node.zig");
const ClassNode = @import("./node/class-node.zig");
const ExprNode = @import("./node/expr-node.zig");
const StmtNode = @import("./node/stmt-node.zig");

pub const Any = TypeNode.Any;
pub const Identifier = ExprNode.Identifier;
pub const TypeRef = TypeNode.TypeRef;
pub const UnionType = TypeNode.UnionType;
pub const IntersectionType = TypeNode.IntersectionType;
pub const TypeAnnotation = TypeNode.TypeAnnotation;

pub const MethodParam = FunctionNode.FunctionParam;
pub const FunctionExpr = FunctionNode.FunctionExpr;

pub const ClassMethod = ClassNode.ClassMethod;
pub const ClassProperty = ClassNode.ClassProperty;
pub const BodyClass = ClassNode.BodyClass;
pub const ClassExpr = ClassNode.ClassExpr;
pub const ClassDecl = ClassNode.ClassDecl;

pub const Expression = ExprNode.Expression;
pub const Decorator = ExprNode.Decorator;
pub const ObjectExpr = ExprNode.ObjectExpr;

pub const ArrowFunctionExpr = FunctionNode.ArrowFunctionExpr;

pub const EnumMember = StmtNode.EnumMember;
pub const Enum = StmtNode.Enum;
pub const Type = StmtNode.Type;
pub const Interface = StmtNode.Interface;
pub const JsxElement = ExprNode.JsxElement;
pub const Import = StmtNode.Import;
pub const Export = StmtNode.Export;

comptime {
    _ = Node;
}
