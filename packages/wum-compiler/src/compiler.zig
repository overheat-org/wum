const std = @import("std");
const Graph = @import("./graph.zig");
const Parser = @import("./parser.zig");
const Analyzer = @import("./analyzer.zig");
const Transformer = @import("./transformer.zig").Transformer;
const CodeGenerator = @import("./codegen.zig").CodeGenerator;
const module_analyzer = @import("./analyzer/module-analyzer.zig");

pub const VirtualModule = enum {
    index,
    commands,
    manifest,

    pub fn id(self: VirtualModule) []const u8 {
        return switch (self) {
            .index => "virtual:index",
            .commands => "virtual:commands.tsx",
            .manifest => "virtual:manifest",
        };
    }
};

pub const FileInput = struct {
    path: []const u8,
    source: []const u8,
    kind: Graph.FileKind,
};

pub const PrepareInput = struct {
    files: []const FileInput,
};

pub const PrepareResult = struct {
    graph: *Graph,
};

pub const Compiler = struct {
    allocator: std.mem.Allocator,
    graph: *Graph,
    parser: *Parser,
    analyzer: *Analyzer,
    transformer: *Transformer,
    codegen: *CodeGenerator,

    pub fn init(allocator: std.mem.Allocator) Compiler {
        const graph = allocator.create(Graph) catch @panic("alloc graph");
        graph.* = Graph.init(allocator);

        const parser = allocator.create(Parser) catch @panic("alloc parser");
        parser.* = Parser.init(allocator, graph);

        const analyzer = allocator.create(Analyzer) catch @panic("alloc analyzer");
        analyzer.* = .{
            .allocator = allocator,
            .graph = graph,
            .parser = parser,
        };

        const transformer = allocator.create(Transformer) catch @panic("alloc transformer");
        transformer.* = Transformer.init(allocator);

        const codegen = allocator.create(CodeGenerator) catch @panic("alloc codegen");
        codegen.* = CodeGenerator.init(allocator, graph);

        return .{
            .allocator = allocator,
            .graph = graph,
            .parser = parser,
            .analyzer = analyzer,
            .transformer = transformer,
            .codegen = codegen,
        };
    }

    pub fn prepare(self: *Compiler, input: PrepareInput) !PrepareResult {
        for (input.files) |file_input| {
            _ = try self.parser.parseWithKind(file_input.kind, file_input.path, file_input.source);
        }

        var files_it = self.graph.files.valueIterator();
        while (files_it.next()) |file_ptr| {
            const file = file_ptr.*;
            switch (file.kind) {
                .command => try module_analyzer.analyzeModule(self.analyzer, .Command, file),
                .service => try module_analyzer.analyzeModule(self.analyzer, .Common, file),
                .unknown => {},
            }

            file.transformed_source = try self.transformer.transformFile(file);
        }

        try self.refreshVirtualModules();
        return .{ .graph = self.graph };
    }

    pub fn resolveId(self: *Compiler, id: []const u8) ?[]const u8 {
        _ = self;
        if (isVirtualId(id)) return id;
        return id;
    }

    pub fn load(self: *Compiler, id: []const u8) !?[]const u8 {
        if (self.graph.getEmittedFile(id)) |emitted| return emitted.content;
        if (self.graph.getFileContent(id)) |content| return content;
        return null;
    }

    fn refreshVirtualModules(self: *Compiler) !void {
        self.graph.addEmittedFile(VirtualModule.index.id(), try self.codegen.generateIndex());
        self.graph.addEmittedFile(VirtualModule.commands.id(), try self.codegen.generateCommands());
        self.graph.addEmittedFile(VirtualModule.manifest.id(), try self.codegen.generateManifest());
    }
};

fn isVirtualId(id: []const u8) bool {
    return std.mem.eql(u8, id, VirtualModule.index.id()) or
        std.mem.eql(u8, id, VirtualModule.commands.id()) or
        std.mem.eql(u8, id, VirtualModule.manifest.id());
}

test "compiler prepares virtual modules and file loads from explicit inputs" {
    const allocator = std.heap.page_allocator;
    var compiler = Compiler.init(allocator);

    const inputs = [_]FileInput{
        .{ .path = "/tmp/commands/ping.tsx", .source = "export default <command name=\"ping\"></command>;", .kind = .command },
        .{ .path = "/tmp/services/repo.ts", .source = "export class Repo {}", .kind = .service },
        .{ .path = "/tmp/services/app.ts", .source =
            \\import { service } from "wum.js/macros";
            \\import { Repo } from "./repo";
            \\
            \\@service
            \\export class App {
            \\  constructor(repo: Repo) {}
            \\}
        , .kind = .service },
    };

    _ = try compiler.prepare(.{ .files = &inputs });

    try std.testing.expectEqualStrings("virtual:index", compiler.resolveId("virtual:index").?);
    try std.testing.expect((try compiler.load("virtual:index")) != null);
    try std.testing.expect((try compiler.load("virtual:commands.tsx")) != null);
    try std.testing.expect((try compiler.load("virtual:manifest")) != null);

    const service_content = (try compiler.load("/tmp/services/app.ts")).?;
    try std.testing.expect(std.mem.indexOf(u8, service_content, "@service") == null);
}
