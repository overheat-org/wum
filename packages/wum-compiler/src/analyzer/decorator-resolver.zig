const std = @import("std");
const Node = @import("../node.zig");
const Graph = @import("../graph.zig");

const decorator_name_map = std.StaticStringMap([]const u8).initComptime(.{
    .{ "service", "service" },
    .{ "injectable", "injectable" },
    .{ "event", "event" },
    .{ "http", "http" },
});

const http_method_map = std.StaticStringMap(Graph.Route.Method).initComptime(.{
    .{ "get", .get },
    .{ "post", .post },
    .{ "put", .put },
    .{ "patch", .patch },
    .{ "delete", .delete },
    .{ "options", .options },
    .{ "head", .head },
    .{ "connect", .connect },
    .{ "trace", .trace },
});

pub fn resolveDecoratorImport(file: *Graph.File, decorator: *Node) ?*Node {
    const local_name = getDecoratorLocalName(decorator) orelse return null;

    for (file.imports) |import_node| {
        const local = import_node.getProps(.Import).local orelse continue;
        if (std.mem.eql(u8, local.getName(), local_name)) {
            return import_node;
        }
    }

    return null;
}

pub fn resolveDecoratorName(file: *Graph.File, decorator: *Node) ?[]const u8 {
    const import_node = resolveDecoratorImport(file, decorator) orelse return null;
    return lowercaseImportName(import_node.getNode("id").getName());
}

pub fn resolveHttpMethod(file: *Graph.File, decorators: []*Node) ?Graph.Route.Method {
    for (decorators) |decorator| {
        const import_name = resolveDecoratorName(file, decorator) orelse continue;
        if (!std.mem.eql(u8, import_name, "http")) continue;

        const target = if (decorator.is(.CallExpr)) decorator.getNode("id") else decorator;
        if (!target.is(.MemberExpr)) continue;

        const method_name = target.getProps(.MemberExpr).property.getName();
        return resolveMethodName(method_name);
    }

    return null;
}

fn getDecoratorLocalName(decorator: *Node) ?[]const u8 {
    return switch (decorator.kind) {
        .CallExpr => getDecoratorLocalName(decorator.getNode("id")),
        .Id => decorator.getName(),
        .MemberExpr => getDecoratorLocalName(decorator.getNode("object")),
        else => null,
    };
}

fn lowercaseImportName(name: []const u8) ?[]const u8 {
    var buf: [32]u8 = undefined;
    if (name.len > buf.len) return null;

    for (name, 0..) |ch, index| {
        buf[index] = std.ascii.toLower(ch);
    }

    return decorator_name_map.get(buf[0..name.len]);
}

fn resolveMethodName(method_name: []const u8) ?Graph.Route.Method {
    var buf: [32]u8 = undefined;
    if (method_name.len > buf.len) return null;

    for (method_name, 0..) |ch, index| {
        buf[index] = std.ascii.toLower(ch);
    }

    return http_method_map.get(buf[0..method_name.len]);
}
