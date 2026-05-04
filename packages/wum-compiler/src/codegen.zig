const std = @import("std");
const Graph = @import("./graph.zig");
const utils = @import("./utils.zig");

const Path = utils.Path;

pub const CodeGenerator = struct {
    allocator: std.mem.Allocator,
    graph: *Graph,

    pub fn init(allocator: std.mem.Allocator, graph: *Graph) CodeGenerator {
        return .{
            .allocator = allocator,
            .graph = graph,
        };
    }

    pub fn generateIndex(self: *CodeGenerator) ![]const u8 {
        _ = self;
        return
            \\import manifest from "./manifest.json";
            \\import commands from "./commands.js";
            \\
            \\export { manifest, commands };
            \\
        ;
    }

    pub fn generateCommands(self: *CodeGenerator) ![]const u8 {
        var out: std.ArrayList(u8) = .empty;
        try out.appendSlice(self.allocator, "export default [\n");

        for (self.graph.commands.items) |command| {
            try out.writer(self.allocator).print("  () => import(\"{s}\"),\n", .{command.symbol.file.path});
        }

        try out.appendSlice(self.allocator, "];\n");
        return out.toOwnedSlice(self.allocator);
    }

    pub fn generateManifest(self: *CodeGenerator) ![]const u8 {
        var out: std.ArrayList(u8) = .empty;
        try out.appendSlice(self.allocator, "{\n");

        try out.appendSlice(self.allocator, "  \"routes\": [\n");
        for (self.graph.routes.items, 0..) |route, index| {
            try out.writer(self.allocator).print(
                "    {{\"endpoint\":\"{s}\",\"method\":\"{s}\",\"handler\":\"{s}\",\"entity\":\"{s}\"}}{s}\n",
                .{
                    route.endpoint,
                    @tagName(route.method),
                    route.symbol.id,
                    if (route.symbol.parent) |parent| parent.id else "",
                    if (index + 1 < self.graph.routes.items.len) "," else "",
                },
            );
        }
        try out.appendSlice(self.allocator, "  ],\n");

        try out.appendSlice(self.allocator, "  \"dependencies\": [\n");
        const dependency_count = self.graph.services.items.len + self.graph.injectables.items.len + self.graph.modules.items.len;
        var dep_index: usize = 0;
        for (self.graph.services.items) |service| {
            try appendDependencyEntry(self.allocator, &out, service.symbol.id, service.dependencies, dep_index + 1 < dependency_count);
            dep_index += 1;
        }
        for (self.graph.injectables.items) |injectable| {
            try appendDependencyEntry(self.allocator, &out, injectable.symbol.id, injectable.dependencies, dep_index + 1 < dependency_count);
            dep_index += 1;
        }
        for (self.graph.modules.items, 0..) |module_item, index| {
            try out.writer(self.allocator).print("    {{\"name\":\"{s}\",\"managers\":[", .{module_item.name});
            for (module_item.managers, 0..) |manager, manager_index| {
                try out.writer(self.allocator).print("\"{s}\"{s}", .{
                    manager.id,
                    if (manager_index + 1 < module_item.managers.len) "," else "",
                });
            }
            const has_more = dep_index + index + 1 < dependency_count;
            try out.writer(self.allocator).print("]}}{s}\n", .{if (has_more) "," else ""});
        }
        try out.appendSlice(self.allocator, "  ],\n");

        try out.appendSlice(self.allocator, "  \"events\": [\n");
        for (self.graph.events.items, 0..) |event, index| {
            try out.writer(self.allocator).print(
                "    {{\"type\":\"{s}\",\"once\":{s},\"handler\":\"{s}\",\"entity\":\"{s}\"}}{s}\n",
                .{
                    event.type,
                    if (event.once) "true" else "false",
                    event.symbol.id,
                    if (event.symbol.parent) |parent| parent.id else "",
                    if (index + 1 < self.graph.events.items.len) "," else "",
                },
            );
        }
        try out.appendSlice(self.allocator, "  ]\n");
        try out.appendSlice(self.allocator, "}\n");

        return out.toOwnedSlice(self.allocator);
    }
};

fn appendDependencyEntry(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    symbol_id: []const u8,
    dependencies: []*Graph.Symbol,
    has_more: bool,
) !void {
    try out.writer(allocator).print("    {{\"service\":\"{s}\",\"dependencies\":[", .{symbol_id});
    for (dependencies, 0..) |dependency, dep_index| {
        try out.writer(allocator).print("\"{s}\"{s}", .{
            dependency.id,
            if (dep_index + 1 < dependencies.len) "," else "",
        });
    }
    try out.appendSlice(allocator, "]}");
    try out.appendSlice(allocator, if (has_more) ",\n" else "\n");
}

test "codegen emits commands and manifest text" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);

    var file = Graph.File{
        .kind = .command,
        .name = "ping.tsx",
        .path = "/tmp/ping.tsx",
        .source = "export default <command />;",
        .transformed_source = null,
        .line_starts = try allocator.dupe(usize, &.{0}),
        .modules = &[_][]const u8{},
        .imports = &[_]*@import("./node.zig"){},
        .exports = &[_]*Graph.Symbol{},
        .declarations = &[_]*Graph.Symbol{},
    };
    const symbol = try allocator.create(Graph.Symbol);
    symbol.* = .{ .id = "default", .file = &file, .node = @import("./node.zig").new(.{ .JsxElement = .{ .range = .{ .start = 0, .end = 18 } } }).withFile(&file) };
    graph.addCommand(.{ .symbol = symbol });

    var codegen = CodeGenerator.init(allocator, &graph);
    const commands = try codegen.generateCommands();
    const index = try codegen.generateIndex();
    try std.testing.expect(std.mem.indexOf(u8, commands, "/tmp/ping.tsx") != null);
    try std.testing.expect(std.mem.indexOf(u8, index, "manifest") != null);
}
