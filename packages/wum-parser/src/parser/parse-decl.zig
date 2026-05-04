const std = @import("std");
const Parser = @import("../parser.zig");
const Scanner = @import("../scanner.zig");
const Node = @import("../node.zig");
const Graph = @import("../graph.zig");

pub fn parseSimpleNamedDecl(parser: *Parser, file: *Graph.File, scanner: *Scanner, keyword: []const u8, kind: Node.Kind) !*Graph.Symbol {
    const start = scanner.offset;
    scanner.offset += keyword.len;
    scanner.skipTrivia();

    const name = scanner.readIdentifier() orelse return parser.failAt(file, scanner.offset, .Syntax, "Expected identifier");
    const id = Node.new(.{ .Id = .{ .name = try parser.allocator.dupe(u8, name) } }).withFile(file);
    const node = switch (kind) {
        .Interface => Node.new(.{ .Interface = .{ .id = id, .range = undefined } }).withFile(file),
        .Type => Node.new(.{ .Type = .{ .id = id, .range = undefined } }).withFile(file),
        .Enum => Node.new(.{ .Enum = .{ .id = id, .range = undefined } }).withFile(file),
        else => unreachable,
    };

    while (!scanner.eof()) {
        const ch = scanner.peek().?;
        scanner.offset += 1;
        if (ch == ';' or ch == '\n') break;
        if (ch == '{') {
            _ = scanner.skipBalanced('{', '}');
            break;
        }
    }

    const range = Node.Range{ .start = start, .end = scanner.offset };
    switch (kind) {
        .Interface => node.getProps(.Interface).range = range,
        .Type => node.getProps(.Type).range = range,
        .Enum => node.getProps(.Enum).range = range,
        else => unreachable,
    }

    return makeSymbol(parser, file, name, node);
}

pub fn parseVariableDecl(parser: *Parser, file: *Graph.File, scanner: *Scanner) ![]*Graph.Symbol {
    if (scanner.startsWithWord("const")) {
        scanner.offset += "const".len;
    } else if (scanner.startsWithWord("let")) {
        scanner.offset += "let".len;
    } else {
        scanner.offset += "var".len;
    }

    scanner.skipTrivia();

    var symbols: std.ArrayList(*Graph.Symbol) = .empty;
    while (!scanner.eof()) {
        scanner.skipTrivia();
        const declarator_start = scanner.offset;
        const name = scanner.readIdentifier() orelse {
            skipVariableTail(scanner);
            break;
        };

        while (!scanner.eof()) {
            const ch = scanner.peek().?;
            switch (ch) {
                ',', ';', '\n' => break,
                '{' => _ = scanner.skipEnclosed('{', '}'),
                '(' => _ = scanner.skipEnclosed('(', ')'),
                '[' => _ = scanner.skipEnclosed('[', ']'),
                '\'', '"', '`' => _ = scanner.readStringToken(),
                else => _ = scanner.advance(),
            }
        }

        const node = Node.new(.{ .VarDecl = .{
            .range = .{ .start = declarator_start, .end = scanner.offset },
        } }).withFile(file);
        try symbols.append(parser.allocator, try makeSymbol(parser, file, name, node));

        scanner.skipTrivia();
        if (scanner.peek() == ',') {
            scanner.offset += 1;
            continue;
        }

        if (scanner.peek() == ';') scanner.offset += 1;
        break;
    }

    return symbols.toOwnedSlice(parser.allocator);
}

fn skipVariableTail(scanner: *Scanner) void {
    while (!scanner.eof()) {
        const ch = scanner.peek().?;
        scanner.offset += 1;
        if (ch == ';' or ch == '\n') break;
    }
}

pub fn findDeclarationByName(declarations: []*Graph.Symbol, name: []const u8) ?*Graph.Symbol {
    for (declarations) |symbol| {
        if (std.mem.eql(u8, symbol.id, name)) return symbol;
    }
    return null;
}

pub fn makeSymbol(parser: *Parser, file: *Graph.File, id: []const u8, node: *Node) !*Graph.Symbol {
    const symbol = try parser.allocator.create(Graph.Symbol);
    symbol.* = .{
        .id = try parser.allocator.dupe(u8, id),
        .file = file,
        .node = node,
    };
    node.file = file;
    return symbol;
}
