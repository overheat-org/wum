const Parser = @import("../parser.zig");
const Scanner = @import("../scanner.zig");
const Node = @import("../node.zig");
const Graph = @import("../graph.zig");

pub fn parseClassOrFnBody(_: *Parser, file: *Graph.File, range: Node.Range) !*Node {
    var scanner = Scanner.init(file.source);
    scanner.offset = range.start + 1;

    while (!scanner.eof() and scanner.offset < range.end - 1) {
        scanner.skipTrivia();
        if (scanner.offset >= range.end - 1) break;

        const ch = scanner.peek() orelse break;
        switch (ch) {
            '{' => _ = scanner.skipEnclosed('{', '}'),
            '(' => _ = scanner.skipEnclosed('(', ')'),
            '[' => _ = scanner.skipEnclosed('[', ']'),
            '\'', '"', '`' => _ = scanner.readStringToken(),
            else => _ = scanner.advance(),
        }
    }

    return Node.new(.{ .Block = .{ .range = range } }).withFile(file);
}
