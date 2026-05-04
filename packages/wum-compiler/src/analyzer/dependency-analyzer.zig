const Node = @import("../node.zig");
const Graph = @import("../graph.zig");
const Analyzer = @import("../analyzer.zig");
const std = @import("std");

pub fn analyzeDependencies(ctx: *Analyzer, node: *Node) ![]*Graph.Symbol {
    if (!node.is(.Class)) return ctx.failNode(node, .Internal, "Expected class node for dependency analysis");

    const body = node.getBody(ctx.parser);
    const constructor = body.getConstructor(ctx.parser) orelse return &[_]*Graph.Symbol{};
    const params = constructor.getParams(ctx.parser);

    const slice = try ctx.allocator.alloc(*Graph.Symbol, params.len);

    for (params, 0..) |param, index| {
        const type_ref = param.getType(ctx.parser) orelse return ctx.failNode(param, .Semantic, "Expected a type annotation for injectable parameter");
        slice[index] = ctx.graph.symbolFrom(type_ref);
    }

    return slice;
}

test "dependency analyzer resolves imported symbols across parsed files" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
    };

    _ = try parser.parse(
        "/tmp/repo.ts",
        \\export class Repo {}
    );

    const file = try parser.parse(
        "/tmp/service.ts",
        \\import { Repo as AppRepo } from "./repo";
        \\export class Service {
        \\  constructor(repo: AppRepo) {}
        \\}
    );

    const dependencies = try analyzeDependencies(&analyzer, file.exports[0].node);
    try std.testing.expectEqual(@as(usize, 1), dependencies.len);
    try std.testing.expectEqualStrings("Repo", dependencies[0].id);
    try std.testing.expectEqualStrings("/tmp/repo.ts", dependencies[0].file.path);
}

test "dependency analyzer resolves namespace imported types" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
    };

    _ = try parser.parse(
        "/tmp/types.ts",
        \\export class Repo {}
    );

    const file = try parser.parse(
        "/tmp/service-ns.ts",
        \\import * as types from "./types";
        \\export class Service {
        \\  constructor(repo: types.Repo) {}
        \\}
    );

    const dependencies = try analyzeDependencies(&analyzer, file.exports[0].node);
    try std.testing.expectEqual(@as(usize, 1), dependencies.len);
    try std.testing.expectEqualStrings("Repo", dependencies[0].id);
    try std.testing.expectEqualStrings("/tmp/types.ts", dependencies[0].file.path);
}
