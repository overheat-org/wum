const std = @import("std");
const Graph = @import("./graph.zig");

const Analyzer = @This();

graph: Graph,
allocator: std.mem.Allocator,
