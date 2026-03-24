const std = @import("std");
const Parser = @import("../parser.zig");
const Node = @import("../node.zig");
const Graph = @import("../graph.zig");
const Analyzer = @import("../analyzer.zig");

pub fn analyzeDependencies(ctx: *Analyzer, node: Node) []Graph.Symbol {
    if (!node.is(.Class)) @panic("Expected Class");

    const p = ctx.parser;
    const body = node.getBody(p);
    const constructor = body.getConstructor(p);

    const params = constructor.getParams(p);

    const slice = ctx.allocator.alloc(Graph.Symbol, params.len) catch @panic("Cannot alloc dependencies");

    for (params, 0..params.len) |param, i| {
        const type_ = param.getType(p);

        if (type_ != null) @panic("Cannot find type");

        const target = type_.?.getParent() orelse type_;
        slice[i] = ctx.graph.symbolFrom(target);
    }

    return slice;
}

test {
    const allocator = std.heap.page_allocator;
    std.heap.testAllocator(allocator);

    const analyzer = Analyzer{ .allocator = allocator };
    const parser = Parser.init();

    const content =
        \\class Dependency {}
        \\
        \\class MyClass {
        \\    constructor(private dependency: Dependency) {}
        \\}
    ;

    const program = parser.parse(content);
    const node = program.getChildren()[1];

    const symbols = analyzeDependencies(&analyzer, node);
    std.testing.expect(symbols.len == 1);

    const symbol = symbols[0];
    Node.eql(symbol.node, Node.new(
        .Class,
        .{ .id = "Dependency" },
    ));
}
