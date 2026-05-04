const std = @import("std");
const Analyzer = @import("../analyzer.zig");
const Graph = @import("../graph.zig");
const errors = @import("../errors.zig");

pub fn analyzeCommandModule(ctx: *Analyzer, file: *Graph.File) !void {
    for (file.declarations) |symbol| {
        switch (symbol.node.kind) {
            .Enum => return ctx.failNode(symbol.node, .Semantic, "Cannot use enum in command"),
            .Class => return ctx.failNode(symbol.node, .Semantic, "Cannot use class in command"),
            else => {},
        }
    }

    var default_export: ?*Graph.Symbol = null;
    for (file.exports) |symbol| {
        if (!std.mem.eql(u8, symbol.id, "default")) {
            return ctx.failNode(symbol.node, .Semantic, "Cannot export in command");
        }
        default_export = symbol;
    }

    if (default_export) |symbol| {
        switch (symbol.node.kind) {
            .ObjectExpr, .JsxElement, .Export, .Interface, .Type, .VarDecl => {},
            else => return ctx.failNode(symbol.node, .Semantic, "Cannot export by default a non-command element"),
        }

        ctx.graph.addCommand(.{ .symbol = symbol });
    }
}

test "command analyzer accepts jsx default export" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
    };

    const file = try parser.parse(
        "/tmp/command.tsx",
        \\import { x } from "./dep";
        \\export default <command name="ping"></command>;
    );

    try analyzeCommandModule(&analyzer, file);
    try std.testing.expectEqual(@as(usize, 1), graph.commands.items.len);
}

test "command analyzer accepts object default export" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
    };

    const file = try parser.parse(
        "/tmp/object-command.ts",
        \\export default { run() {} };
    );

    try analyzeCommandModule(&analyzer, file);
    try std.testing.expectEqual(@as(usize, 1), graph.commands.items.len);
}

test "command analyzer rejects enum usage" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
        .last_error = null,
    };

    const file = try parser.parse(
        "/tmp/command-enum.ts",
        \\enum State { Ready }
        \\export default { ok: true };
    );

    try std.testing.expectError(error.CompileFailed, analyzeCommandModule(&analyzer, file));
    try std.testing.expectEqual(errors.Kind.Semantic, analyzer.last_error.?.kind);
}

test "command analyzer rejects class usage" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
        .last_error = null,
    };

    const file = try parser.parse(
        "/tmp/command-class.ts",
        \\class Service {}
        \\export default { ok: true };
    );

    try std.testing.expectError(error.CompileFailed, analyzeCommandModule(&analyzer, file));
}

test "command analyzer rejects named exports" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
        .last_error = null,
    };

    const file = try parser.parse(
        "/tmp/command-export.ts",
        \\const value = 1;
        \\export { value };
    );

    try std.testing.expectError(error.CompileFailed, analyzeCommandModule(&analyzer, file));
}

test "command analyzer rejects non command default export" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("../parser.zig").init(allocator, &graph);
    var analyzer = Analyzer{
        .allocator = allocator,
        .graph = &graph,
        .parser = &parser,
        .last_error = null,
    };

    const file = try parser.parse(
        "/tmp/command-default-fn.ts",
        \\export default function Boot() {}
    );

    try std.testing.expectError(error.CompileFailed, analyzeCommandModule(&analyzer, file));
    try std.testing.expect(analyzer.last_error != null);
}
