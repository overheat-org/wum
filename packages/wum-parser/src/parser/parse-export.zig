const std = @import("std");
const Parser = @import("../parser.zig");
const Scanner = @import("../scanner.zig");
const Node = @import("../node.zig");
const Graph = @import("../graph.zig");
const parse_class = @import("./parse-class.zig");
const parse_decl = @import("./parse-decl.zig");

const export_decl_map = std.StaticStringMap(Node.Kind).initComptime(.{
    .{ "class", .Class },
    .{ "enum", .Enum },
    .{ "function", .Fn },
    .{ "interface", .Interface },
    .{ "type", .Type },
});

pub fn parseExport(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    decorators: []*Node,
    declarations: *std.ArrayList(*Graph.Symbol),
    exports: *std.ArrayList(*Graph.Symbol),
) !void {
    scanner.offset += "export".len;
    scanner.skipTrivia();

    if (scanner.startsWithWord("default")) {
        scanner.offset += "default".len;
        scanner.skipTrivia();

        if (scanner.startsWithWord("class")) {
            const symbol = try parse_class.parseDefaultClassDecl(parser, file, scanner, decorators);
            if (std.mem.eql(u8, symbol.id, "default")) {
                try exports.append(parser.allocator, symbol);
            } else {
                try declarations.append(parser.allocator, symbol);
                try exports.append(parser.allocator, try cloneExportSymbol(parser, symbol, "default"));
            }
            return;
        }

        if (scanner.startsWithWord("function")) {
            const symbol = try parse_class.parseDefaultFunctionDecl(parser, file, scanner, decorators);
            if (std.mem.eql(u8, symbol.id, "default")) {
                try exports.append(parser.allocator, symbol);
            } else {
                try declarations.append(parser.allocator, symbol);
                try exports.append(parser.allocator, try cloneExportSymbol(parser, symbol, "default"));
            }
            return;
        }

        if (scanner.peek() == '<') {
            const range = parseDefaultExpressionRange(scanner);
            const node = Node.new(.{ .JsxElement = .{ .range = range } }).withFile(file);
            const symbol = try parse_decl.makeSymbol(parser, file, "default", node);
            try exports.append(parser.allocator, symbol);
            return;
        }

        if (peekWord(scanner)) |name| {
            if (parse_decl.findDeclarationByName(declarations.items, name)) |symbol| {
                const exported = try parser.allocator.create(Graph.Symbol);
                exported.* = symbol.*;
                exported.id = "default";
                try exports.append(parser.allocator, exported);
                return;
            }
        }

        const node = try parseDefaultExpression(parser, file, scanner);
        const symbol = try parse_decl.makeSymbol(parser, file, "default", node);
        try exports.append(parser.allocator, symbol);
        return;
    }

    if (peekWord(scanner)) |keyword| {
        if (export_decl_map.get(keyword)) |kind| {
            const symbol = switch (kind) {
                .Class => try parse_class.parseClassDecl(parser, file, scanner, decorators),
                .Enum => try parse_decl.parseSimpleNamedDecl(parser, file, scanner, "enum", .Enum),
                .Fn => try parse_class.parseFunctionDecl(parser, file, scanner, decorators),
                .Interface => try parse_decl.parseSimpleNamedDecl(parser, file, scanner, "interface", .Interface),
                .Type => try parse_decl.parseSimpleNamedDecl(parser, file, scanner, "type", .Type),
                else => unreachable,
            };
            try declarations.append(parser.allocator, symbol);
            try exports.append(parser.allocator, symbol);
            return;
        }
    }

    if (scanner.peek() == '*') {
        const start = scanner.offset;
        scanner.offset += 1;
        scanner.skipTrivia();
        if (!scanner.startsWithWord("from")) return parser.failAt(file, scanner.offset, .Syntax, "Expected 'from' in export");
        scanner.offset += "from".len;
        scanner.skipTrivia();

        const source_value = try readExportSource(parser, file, scanner);
        const node = Node.new(.{ .Export = .{
            .kind = .reexport_all,
            .id = Node.new(.{ .Id = .{ .name = "*" } }).withFile(file),
            .source = Node.new(.{ .String = .{ .value = try parser.allocator.dupe(u8, source_value) } }).withFile(file),
            .range = .{ .start = start, .end = scanner.offset },
        } }).withFile(file);
        const symbol = try parse_decl.makeSymbol(parser, file, "*", node);
        try exports.append(parser.allocator, symbol);
        return;
    }

    if (scanner.peek() == '{') {
        const clause_start = scanner.offset;
        const clause = scanner.skipEnclosed('{', '}') orelse return parser.failAt(file, scanner.offset, .Syntax, "Expected export clause");
        var inner = Scanner.init(scanner.source[clause.start + 1 .. clause.end - 1]);
        scanner.skipTrivia();

        var reexport_source: ?[]const u8 = null;
        if (scanner.startsWithWord("from")) {
            scanner.offset += "from".len;
            scanner.skipTrivia();
            reexport_source = try readExportSource(parser, file, scanner);
        }

        while (true) {
            inner.skipTrivia();
            if (inner.eof()) break;

            const local = inner.readIdentifier() orelse break;
            inner.skipTrivia();

            var exported = local;
            if (inner.startsWithWord("as")) {
                inner.offset += 2;
                inner.skipTrivia();
                exported = inner.readIdentifier() orelse return parser.failAt(file, scanner.offset, .Syntax, "Expected exported alias");
            }

            if (reexport_source) |source_value| {
                const node = Node.new(.{ .Export = .{
                    .kind = .reexport_named,
                    .id = Node.new(.{ .Id = .{ .name = try parser.allocator.dupe(u8, exported) } }).withFile(file),
                    .local = Node.new(.{ .Id = .{ .name = try parser.allocator.dupe(u8, local) } }).withFile(file),
                    .source = Node.new(.{ .String = .{ .value = try parser.allocator.dupe(u8, source_value) } }).withFile(file),
                    .range = .{ .start = clause_start, .end = scanner.offset },
                } }).withFile(file);
                try exports.append(parser.allocator, try parse_decl.makeSymbol(parser, file, exported, node));
            } else if (parse_decl.findDeclarationByName(declarations.items, local)) |symbol| {
                const exported_symbol = try parser.allocator.create(Graph.Symbol);
                exported_symbol.* = symbol.*;
                exported_symbol.id = try parser.allocator.dupe(u8, exported);
                try exports.append(parser.allocator, exported_symbol);
            }

            inner.skipTrivia();
            if (inner.peek() == ',') inner.offset += 1;
        }
    }
}

fn parseDefaultExpression(_: *Parser, file: *Graph.File, scanner: *Scanner) !*Node {
    const range = parseDefaultExpressionRange(scanner);
    const source = file.source[range.start..range.end];
    if (source.len > 0 and source[0] == '{') {
        return Node.new(.{ .ObjectExpr = .{ .range = range } }).withFile(file);
    }
    return Node.new(.{ .Expr = .{ .range = range } }).withFile(file);
}

fn parseDefaultExpressionRange(scanner: *Scanner) Node.Range {
    scanner.skipTrivia();
    const start = scanner.offset;

    while (!scanner.eof()) {
        const ch = scanner.peek().?;
        switch (ch) {
            ';', '\n' => break,
            '{' => _ = scanner.skipEnclosed('{', '}'),
            '(' => _ = scanner.skipEnclosed('(', ')'),
            '[' => _ = scanner.skipEnclosed('[', ']'),
            '\'', '"', '`' => _ = scanner.readStringToken(),
            else => _ = scanner.advance(),
        }
    }

    return .{ .start = start, .end = scanner.offset };
}

fn peekWord(scanner: *Scanner) ?[]const u8 {
    const checkpoint = scanner.offset;
    const word = scanner.readIdentifier() orelse return null;
    scanner.offset = checkpoint;
    return word;
}

fn readExportSource(parser: *Parser, file: *Graph.File, scanner: *Scanner) ![]const u8 {
    const source_token = scanner.readStringToken();
    const raw_source = switch (source_token.value) {
        .string => |value| value,
        else => return parser.failAt(file, scanner.offset, .Syntax, "Expected export source"),
    };
    if (raw_source.len < 2) return parser.failAt(file, scanner.offset, .Syntax, "Expected export source");
    return raw_source[1 .. raw_source.len - 1];
}

fn cloneExportSymbol(parser: *Parser, symbol: *Graph.Symbol, exported_name: []const u8) !*Graph.Symbol {
    const exported_symbol = try parser.allocator.create(Graph.Symbol);
    exported_symbol.* = symbol.*;
    exported_symbol.id = try parser.allocator.dupe(u8, exported_name);
    return exported_symbol;
}
