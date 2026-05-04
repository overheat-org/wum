const std = @import("std");
const Graph = @import("./graph.zig");
const errors = @import("./errors.zig");
const _parser = @import("wum-parser");
const Parser = _parser.Parser;
const AstGraph = _parser.AstGraph;
const Node = _parser.Node;

const Analyzer = @This();

graph: *AstGraph,
parser: *Parser,
allocator: std.mem.Allocator,
last_error: ?errors.CompileError = null,

test {
    _ = @import("./analyzer/command-analyzer.zig");
    _ = @import("./analyzer/decorator-resolver.zig");
    _ = @import("./analyzer/dependency-analyzer.zig");
    _ = @import("./analyzer/macro-analyzer.zig");
    _ = @import("./analyzer/module-analyzer.zig");
}

pub fn failNode(self: *Analyzer, node: *Node, kind: errors.Kind, message: []const u8) error{CompileFailed} {
    const file = node.file orelse unreachable;
    const range = node.getRange() orelse @import("./node.zig").Range{ .start = 0, .end = 0 };
    self.last_error = errors.make(
        self.allocator,
        file.path,
        file.source,
        file.line_starts,
        .{ .start = range.start, .end = range.end },
        kind,
        message,
    ) catch unreachable;
    return error.CompileFailed;
}

pub fn formatLastError(self: *Analyzer) !?[]const u8 {
    const compile_error = self.last_error orelse return null;
    const file = self.graph.getFile(compile_error.file_path) orelse return null;
    return try errors.format(self.allocator, compile_error, file.source, file.line_starts);
}
