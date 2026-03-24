const std = @import("std");
const Analyzer = @import("../analyzer.zig");
const Node = @import("../node.zig");
const Graph = @import("../graph.zig");
const analyzeDependencies = @import("./dependency-analyzer.zig").analyzeDependencies;

const map = std.StaticStringMap(*fn (*Analyzer, *Graph.Symbol, []*Node) void).initComptime(.{
    .{ "Service", analyzeServiceMacro },
    .{ "Injectable", analyzeInjectableMacro },
    .{ "Event", analyzeEventMacro },
    .{ "Http", analyzeHttpMacro },
});

pub inline fn analyzeMacro(ctx: *Analyzer, callExpr: *Node, targetSymbol: *Graph.Symbol) void {
    const callExprProps: *Node.CallExpr = callExpr.getProps(.CallExpr);
    const handlerOrNull = map.get(callExprProps.id.getNode("name"));

    if (handlerOrNull) |handler| handler(ctx, targetSymbol, callExprProps.params);
}

fn analyzeServiceMacro(ctx: *Analyzer, symbol: *Graph.Symbol, params: []*Node) void {
    _ = params;

    const dependencies = analyzeDependencies(ctx, symbol.node);

    ctx.graph.addService(.{
        .dependencies = dependencies,
        .symbol = symbol,
    });
}

fn analyzeInjectableMacro(ctx: *Analyzer, symbol: *Graph.Symbol, params: []*Node) void {
    _ = params;

    const dependencies = analyzeDependencies(ctx, symbol.node);

    ctx.graph.addInjectable(.{
        .dependencies = dependencies,
        .symbol = symbol,
    });
}

fn analyzeEventMacro(ctx: *Analyzer, symbol: *Graph.Symbol, params: []*Node) void {
    _ = params;

    // TODO: resolve name of function

    if (!symbol.node.is(.Fn)) @panic("Expected function");

    ctx.graph.addEvent(.{
        .symbol = symbol,
        .type = "",
        .once = false,
    });
}

fn analyzeHttpMacro(ctx: *Analyzer, symbol: *Graph.Symbol, params: []*Node) void {
    _ = params;

    // TODO: resolve member expr to pass method

    ctx.graph.addRoute(.{
        .endpoint = "",
        .method = .GET,
        .symbol = symbol,
        .protocol = "http",
    });
}
