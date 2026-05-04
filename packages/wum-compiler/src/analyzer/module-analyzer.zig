const std = @import("std");
const Analyzer = @import("../analyzer.zig");
const analyzeMacro = @import("./macro-analyzer.zig").analyzeMacro;
const analyzeCommandModule = @import("./command-analyzer.zig").analyzeCommandModule;
const resolveDecoratorImport = @import("./decorator-resolver.zig").resolveDecoratorImport;
const Graph = @import("wum-parser").AstGraph;

const WUM_MACROS = "wum.js/macros";

pub const ModuleKind = enum {
    None,
    Command,
};

pub fn analyzeModule(ctx: *Analyzer, kind: ModuleKind, file: *Graph.File) !void {
    if (kind == .Command) {
        return analyzeCommandModule(ctx, file);
    }

    const symbols = ctx.graph.getExportsFrom(file.path);
    for (symbols) |symbol| {
        if (file.hasImported(WUM_MACROS)) {
            switch (symbol.node.kind) {
                .Class => try analyzeClass(ctx, symbol),
                else => continue,
            }
        }
    }
}

fn analyzeClass(ctx: *Analyzer, symbol: *Graph.Symbol) !void {
    for (symbol.node.getDecorators()) |decorator| {
        const decorator_decl = resolveDecoratorImport(symbol.file, decorator) orelse continue;
        if (!std.mem.eql(u8, decorator_decl.getSource(), WUM_MACROS)) continue;
        try analyzeMacro(ctx, decorator, symbol);
    }

    const body = symbol.node.getBody(ctx.parser);
    const class_body = body.getProps(.ClassBody);
    for (class_body.methods) |method_node| {
        const method_symbol = ctx.graph.symbolFrom(method_node);
        method_symbol.parent = symbol;
        for (method_node.getDecorators()) |decorator| {
            const decorator_decl = resolveDecoratorImport(symbol.file, decorator) orelse continue;
            if (!std.mem.eql(u8, decorator_decl.getSource(), WUM_MACROS)) continue;
            try analyzeMacro(ctx, decorator, method_symbol);
        }
    }
}

test "module analyzer resolves decorator aliases and method decorators" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
    };

    const file = try parser.parse("/tmp/service.ts",
        \\import { Service as svc, Event as evt } from "wum.js/macros";
        \\
        \\class Repo {}
        \\
        \\@svc
        \\export class Init {
        \\  constructor(repo: Repo) {}
        \\
        \\  @evt
        \\  OnceReady() {}
        \\}
    );

    try analyzeModule(&analyzer, .None, file);

    try std.testing.expectEqual(@as(usize, 1), graph.services.items.len);
    try std.testing.expectEqual(@as(usize, 1), graph.events.items.len);
    try std.testing.expectEqualStrings("ready", graph.events.items[0].type);
    try std.testing.expect(graph.events.items[0].once);
    try std.testing.expectEqual(@as(usize, 1), graph.services.items[0].dependencies.len);
    try std.testing.expectEqualStrings("Repo", graph.services.items[0].dependencies[0].id);
}

test "module analyzer delegates command analysis" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
        .last_error = null,
    };

    const file = try parser.parse("/tmp/command.tsx",
        \\export default <command name="ping"></command>
    );

    try analyzeModule(&analyzer, .Command, file);
    try std.testing.expectEqual(@as(usize, 1), graph.commands.items.len);
}
