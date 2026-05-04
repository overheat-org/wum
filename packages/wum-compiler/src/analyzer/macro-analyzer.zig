const std = @import("std");
const Analyzer = @import("../analyzer.zig");
const analyzeDependencies = @import("./dependency-analyzer.zig").analyzeDependencies;
const resolver = @import("./decorator-resolver.zig");
const _p = @import("wum-parser");
const Graph = _p.AstGraph;
const Node = _p.Node;

const map = std.StaticStringMap(*const fn (*Analyzer, *Graph.Symbol, []const *Node) anyerror!void).initComptime(.{
    .{ "service", analyzeServiceMacro },
    .{ "injectable", analyzeInjectableMacro },
    .{ "event", analyzeEventMacro },
    .{ "http", analyzeHttpMacro },
});

pub fn analyzeMacro(ctx: *Analyzer, call_expr: *Node, target_symbol: *Graph.Symbol) !void {
    const decorator_name = resolver.resolveDecoratorName(target_symbol.file, call_expr) orelse return;
    const handler = map.get(decorator_name) orelse return;
    const params: []const *Node = if (call_expr.is(.CallExpr)) call_expr.getProps(.CallExpr).params else &[_]*Node{};
    try handler(ctx, target_symbol, params);
}

fn analyzeServiceMacro(ctx: *Analyzer, symbol: *Graph.Symbol, params: []const *Node) !void {
    _ = params;
    const dependencies = try analyzeDependencies(ctx, symbol.node);
    ctx.graph.addService(.{
        .dependencies = dependencies,
        .symbol = symbol,
    });
}

fn analyzeInjectableMacro(ctx: *Analyzer, symbol: *Graph.Symbol, params: []const *Node) !void {
    _ = params;
    const dependencies = try analyzeDependencies(ctx, symbol.node);
    ctx.graph.addInjectable(.{
        .dependencies = dependencies,
        .symbol = symbol,
    });
}

fn analyzeEventMacro(ctx: *Analyzer, symbol: *Graph.Symbol, params: []const *Node) !void {
    _ = params;
    const method_name = symbol.node.getName();
    const once = std.mem.startsWith(u8, method_name, "Once");
    const prefix_len: usize = if (once) 4 else if (std.mem.startsWith(u8, method_name, "On")) 2 else return ctx.failNode(symbol.node, .Semantic, "Event handler method name must start with 'On' or 'Once'");
    if (method_name.len <= prefix_len) {
        return ctx.failNode(symbol.node, .Semantic, "Event handler method name must include the event name after 'On' or 'Once'");
    }

    var event_name = try ctx.allocator.dupe(u8, method_name[prefix_len..]);
    event_name[0] = std.ascii.toLower(event_name[0]);

    ctx.graph.addEvent(.{
        .symbol = symbol,
        .type = event_name,
        .once = once,
    });
}

fn analyzeHttpMacro(ctx: *Analyzer, symbol: *Graph.Symbol, params: []const *Node) !void {
    if (params.len == 0) {
        return ctx.failNode(symbol.node, .Semantic, "Http macro expects a string endpoint argument");
    }
    if (!params[0].is(.String)) {
        return ctx.failNode(params[0], .Semantic, "Http macro endpoint must be a string literal");
    }

    ctx.graph.addRoute(.{
        .endpoint = params[0].getName(),
        .method = resolver.resolveHttpMethod(symbol.file, symbol.node.getDecorators()) orelse .get,
        .symbol = symbol,
        .protocol = "http",
    });
}

test "macro analyzer resolves http member method" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
    };

    const file = try parser.parse("/tmp/http.ts",
        \\import { service, http } from "wum.js/macros";
        \\
        \\@service
        \\export class Api {
        \\  @http.post("/start")
        \\  Start() {}
        \\}
    );

    try @import("./module-analyzer.zig").analyzeModule(&analyzer, .None, file);

    try std.testing.expectEqual(@as(usize, 1), graph.routes.items.len);
    try std.testing.expectEqual(Graph.Route.Method.post, graph.routes.items[0].method);
    try std.testing.expectEqualStrings("/start", graph.routes.items[0].endpoint);
}

test "macro analyzer reports semantic error for invalid event name" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
        .last_error = null,
    };

    const file = try parser.parse("/tmp/event.ts",
        \\import { service, event } from "wum.js/macros";
        \\
        \\@service
        \\export class Init {
        \\  @event
        \\  Ready() {}
        \\}
    );

    try std.testing.expectError(error.CompileFailed, @import("./module-analyzer.zig").analyzeModule(&analyzer, .None, file));
    try std.testing.expect(analyzer.last_error != null);
}

test "macro analyzer reports semantic error for invalid http argument" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
        .last_error = null,
    };

    const file = try parser.parse("/tmp/http-invalid.ts",
        \\import { service, http } from "wum.js/macros";
        \\
        \\@service
        \\export class Api {
        \\  @http.post(value)
        \\  Start() {}
        \\}
    );

    try std.testing.expectError(error.CompileFailed, @import("./module-analyzer.zig").analyzeModule(&analyzer, .None, file));
    try std.testing.expect(analyzer.last_error != null);
}
