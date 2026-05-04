const std = @import("std");
const Graph = @import("./graph.zig");
const Node = @import("./node.zig");
const Scanner = @import("./scanner.zig");
const utils = @import("./utils.zig");

const Path = utils.Path;

pub const Transformer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Transformer {
        return .{ .allocator = allocator };
    }

    pub fn transformFile(self: *Transformer, file: *Graph.File) ![]const u8 {
        return switch (file.kind) {
            .service => self.transformService(file.source),
            .command => self.transformCommand(file),
            .unknown => try self.allocator.dupe(u8, file.source),
        };
    }

    fn transformService(self: *Transformer, source: []const u8) ![]const u8 {
        var ranges: std.ArrayList(Node.Range) = .empty;
        var scanner = Scanner.init(source);

        while (!scanner.eof()) {
            const ch = scanner.peek() orelse break;
            switch (ch) {
                '\'', '"', '`' => _ = scanner.readStringToken(),
                '/' => {
                    const before = scanner.offset;
                    scanner.skipTrivia();
                    if (scanner.offset == before) _ = scanner.advance();
                },
                '@' => {
                    const start = scanner.offset;
                    _ = scanner.advance();
                    _ = scanner.readIdentifier();

                    while (!scanner.eof() and scanner.peek() == '.') {
                        _ = scanner.advance();
                        _ = scanner.readIdentifier();
                    }

                    scanner.skipTrivia();
                    if (scanner.peek() == '(') _ = scanner.skipEnclosed('(', ')');

                    while (!scanner.eof()) {
                        const tail = scanner.peek().?;
                        if (tail == ' ' or tail == '\t' or tail == '\r') {
                            _ = scanner.advance();
                            continue;
                        }
                        if (tail == '\n') {
                            _ = scanner.advance();
                        }
                        break;
                    }

                    try ranges.append(self.allocator, .{ .start = start, .end = scanner.offset });
                },
                else => _ = scanner.advance(),
            }
        }

        return removeRanges(self.allocator, source, ranges.items);
    }

    fn transformCommand(self: *Transformer, file: *Graph.File) ![]const u8 {
        var out: std.ArrayList(u8) = .empty;
        var cursor: usize = 0;

        const imports = file.imports;
        var import_index: usize = 0;
        while (import_index < imports.len) {
            const range = imports[import_index].getProps(.Import).range;
            if (range.start > cursor) {
                try out.appendSlice(self.allocator, file.source[cursor..range.start]);
            }

            var group_end = import_index + 1;
            while (group_end < imports.len and sameRange(imports[group_end].getProps(.Import).range, range)) : (group_end += 1) {}

            try self.appendCommandImportGroup(&out, file, imports[import_index..group_end]);
            cursor = range.end;
            import_index = group_end;
        }

        if (cursor < file.source.len) {
            try out.appendSlice(self.allocator, file.source[cursor..]);
        }

        const body = out.items;
        const export_default = std.mem.indexOf(u8, body, "export default") orelse {
            if (findNamedDefaultExport(body)) |named_default| {
                var wrapped_named: std.ArrayList(u8) = .empty;
                try wrapped_named.appendSlice(self.allocator, "export default async function() {\n");
                try wrapped_named.appendSlice(self.allocator, body[0..named_default.range.start]);
                if (named_default.range.end < body.len) {
                    try wrapped_named.appendSlice(self.allocator, body[named_default.range.end..]);
                }
                try wrapped_named.writer(self.allocator).print("return {s};\n", .{named_default.local_name});
                try wrapped_named.appendSlice(self.allocator, "}\n");
                return wrapped_named.toOwnedSlice(self.allocator);
            }

            return try self.allocator.dupe(u8, file.source);
        };

        var wrapped: std.ArrayList(u8) = .empty;
        try wrapped.appendSlice(self.allocator, "export default async function() {\n");
        try wrapped.appendSlice(self.allocator, body[0..export_default]);
        try wrapped.appendSlice(self.allocator, "return");
        try wrapped.appendSlice(self.allocator, body[export_default + "export default".len ..]);
        try wrapped.appendSlice(self.allocator, "\n}\n");
        return wrapped.toOwnedSlice(self.allocator);
    }

    fn appendCommandImportGroup(self: *Transformer, out: *std.ArrayList(u8), file: *Graph.File, imports: []*Node) !void {
        for (imports) |import_node| {
            const props = import_node.getProps(.Import);
            const source = try self.resolveCommandImportSource(file, props.source.getName());

            switch (props.kind) {
                .side_effect => try out.writer(self.allocator).print("await import(\"{s}\");\n", .{source}),
                .namespace => try out.writer(self.allocator).print("const {s} = await import(\"{s}\");\n", .{
                    props.local.?.getName(),
                    source,
                }),
                .default => try out.writer(self.allocator).print("const {s} = (await import(\"{s}\")).default;\n", .{
                    props.local.?.getName(),
                    source,
                }),
                .named => try out.writer(self.allocator).print("const {s} = (await import(\"{s}\")).{s};\n", .{
                    props.local.?.getName(),
                    source,
                    props.id.?.getName(),
                }),
            }
        }
    }

    fn resolveCommandImportSource(self: *Transformer, file: *Graph.File, source: []const u8) ![]const u8 {
        var resolved = source;
        if (std.mem.indexOf(u8, resolved, "/managers/")) |_| {
            resolved = try std.mem.replaceOwned(u8, self.allocator, resolved, "/managers/", "/services/");
        }

        if (std.mem.startsWith(u8, resolved, "./") or std.mem.startsWith(u8, resolved, "../")) {
            return Path.resolve(self.allocator, Path.dir(file.path), resolved);
        }

        return try self.allocator.dupe(u8, resolved);
    }
};

const NamedDefaultExport = struct {
    range: Node.Range,
    local_name: []const u8,
};

fn sameRange(left: Node.Range, right: Node.Range) bool {
    return left.start == right.start and left.end == right.end;
}

fn removeRanges(allocator: std.mem.Allocator, source: []const u8, ranges: []const Node.Range) ![]const u8 {
    if (ranges.len == 0) return try allocator.dupe(u8, source);

    var out: std.ArrayList(u8) = .empty;
    var cursor: usize = 0;
    for (ranges) |range| {
        if (range.start > cursor) try out.appendSlice(allocator, source[cursor..range.start]);
        cursor = @max(cursor, range.end);
    }
    if (cursor < source.len) try out.appendSlice(allocator, source[cursor..]);
    return out.toOwnedSlice(allocator);
}

fn findNamedDefaultExport(source: []const u8) ?NamedDefaultExport {
    const export_index = std.mem.indexOf(u8, source, "export {") orelse return null;
    const clause_open = std.mem.indexOfPos(u8, source, export_index, "{") orelse return null;

    var scanner = Scanner.init(source);
    scanner.offset = clause_open;
    const clause = scanner.skipEnclosed('{', '}') orelse return null;
    const clause_source = source[clause.start + 1 .. clause.end - 1];

    var inner = Scanner.init(clause_source);
    while (!inner.eof()) {
        inner.skipTrivia();
        const local_name = inner.readIdentifier() orelse break;
        inner.skipTrivia();

        var exported_name = local_name;
        if (inner.startsWithWord("as")) {
            inner.offset += 2;
            inner.skipTrivia();
            exported_name = inner.readIdentifier() orelse return null;
        }

        if (std.mem.eql(u8, exported_name, "default")) {
            var statement_end = clause.end;
            while (statement_end < source.len and (source[statement_end] == ' ' or source[statement_end] == '\t' or source[statement_end] == '\r')) : (statement_end += 1) {}
            if (statement_end < source.len and source[statement_end] == ';') statement_end += 1;
            if (statement_end < source.len and source[statement_end] == '\n') statement_end += 1;
            return .{
                .range = .{ .start = export_index, .end = statement_end },
                .local_name = local_name,
            };
        }

        inner.skipTrivia();
        if (inner.peek() == ',') inner.offset += 1;
    }

    return null;
}

test "transformer removes decorator lines from services" {
    const allocator = std.heap.page_allocator;
    var transformer = Transformer.init(allocator);
    var file = Graph.File{
        .kind = .service,
        .name = "svc.ts",
        .path = "/tmp/svc.ts",
        .source =
            \\@service
            \\export class App {}
        ,
        .line_starts = try allocator.dupe(usize, &.{0}),
        .modules = &[_][]const u8{},
        .imports = &[_]*@import("./node.zig"){},
        .exports = &[_]*Graph.Symbol{},
        .declarations = &[_]*Graph.Symbol{},
    };

    const transformed = try transformer.transformFile(&file);
    try std.testing.expect(std.mem.indexOf(u8, transformed, "@service") == null);
    try std.testing.expect(std.mem.indexOf(u8, transformed, "export class App") != null);
}

test "transformer rewrites command imports and wraps default export" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("./parser.zig").init(allocator, &graph);
    var transformer = Transformer.init(allocator);

    const file = try parser.parseWithKind(
        .command,
        "/tmp/commands/ping.tsx",
        \\import Boot, { run as exec } from "./boot";
        \\import * as api from "../managers/api";
        \\import "./setup";
        \\export default <command name="ping"></command>;
    );

    const transformed = try transformer.transformFile(file);
    try std.testing.expect(std.mem.indexOf(u8, transformed, "const Boot = (await import(\"/tmp/commands/boot\")).default;") != null);
    try std.testing.expect(std.mem.indexOf(u8, transformed, "const exec = (await import(\"/tmp/commands/boot\")).run;") != null);
    try std.testing.expect(std.mem.indexOf(u8, transformed, "const api = await import(\"/tmp/services/api\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, transformed, "await import(\"/tmp/commands/setup\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, transformed, "export default async function()") != null);
    try std.testing.expect(std.mem.indexOf(u8, transformed, "return <command name=\"ping\"></command>;") != null);
}

test "transformer wraps named default export in command" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = @import("./parser.zig").init(allocator, &graph);
    var transformer = Transformer.init(allocator);

    const file = try parser.parseWithKind(
        .command,
        "/tmp/commands/ping.tsx",
        \\const command = <command name="ping"></command>;
        \\export { command as default };
    );

    const transformed = try transformer.transformFile(file);
    try std.testing.expect(std.mem.indexOf(u8, transformed, "export default async function()") != null);
    try std.testing.expect(std.mem.indexOf(u8, transformed, "return command;") != null);
    try std.testing.expect(std.mem.indexOf(u8, transformed, "export { command as default }") == null);
}
