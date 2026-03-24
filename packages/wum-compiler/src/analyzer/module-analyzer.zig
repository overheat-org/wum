const std = @import("std");
const Node = @import("../node.zig");
const Analyzer = @import("../analyzer.zig");
const Graph = @import("../graph.zig");
const analyzeMacro = @import("./macro-analyzer.zig").analyzeMacro;

const WUM_MACROS = "wum.js/macros";

const ModuleKind = enum {
    Command,
    Common,
};

pub fn analyzeModule(ctx: *Analyzer, kind: ModuleKind, file: *Graph.File) void {
    const symbols = ctx.graph.getExportsFrom(file.path);

    // TODO: check and resolve interfaces and types?
    for (symbols) |symbol|
        if (kind == .Command) switch (symbol.node.kind) {
            .Interface, .Type, .Object, .JsxElement => continue,
            _ => @panic("Unexpected element"),
        } else if (file.hasImported(WUM_MACROS)) switch (symbol.node.kind) {
            .Class => analyzeClass(symbol),
            _ => continue,
        };
}

fn analyzeClass(ctx: *Analyzer, symbol: *Graph.Symbol) void {
    const decorators = symbol.node.getDecorators();

    for (decorators) |callExpr| {
        const decoratorDecl = callExpr.getNode("id").getParent();

        // zig fmt: off
        if (
            decoratorDecl == null or
                if (decoratorDecl.is(.Import)) std.mem.eql(u8, decoratorDecl.getSource(), WUM_MACROS)
                else false
        ) continue;
        // zig fmt: on

        analyzeMacro(ctx, callExpr, symbol);
    }
}
