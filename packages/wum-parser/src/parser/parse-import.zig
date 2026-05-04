const std = @import("std");
const Parser = @import("../parser.zig");
const Scanner = @import("../scanner.zig");
const Node = @import("../node.zig");
const Graph = @import("../graph.zig");

pub const Result = struct {
    nodes: []*Node,
    modules: [][]const u8,
};

pub fn parseImport(parser: *Parser, file: *Graph.File, scanner: *Scanner) !Result {
    const statement_start = scanner.offset;
    scanner.offset += "import".len;
    scanner.skipTrivia();

    var nodes: std.ArrayList(*Node) = .empty;
    var modules: std.ArrayList([]const u8) = .empty;

    if (scanner.peek() == '"' or scanner.peek() == '\'') {
        const source_value = try readImportSource(parser, file, scanner);
        try modules.append(parser.allocator, try parser.allocator.dupe(u8, source_value));
        try nodes.append(parser.allocator, try makeImportNode(parser, file, .side_effect, null, null, source_value, undefined));
        const statement_end = consumeImportTerminator(scanner);
        patchImportRanges(nodes.items, .{ .start = statement_start, .end = statement_end });
        return .{
            .nodes = try nodes.toOwnedSlice(parser.allocator),
            .modules = try modules.toOwnedSlice(parser.allocator),
        };
    }

    var source_value: ?[]const u8 = null;

    if (scanner.peek() == '{') {
        const named_source = try parseNamedImports(parser, file, scanner, &nodes);
        source_value = named_source;
    } else if (scanner.peek() == '*') {
        source_value = try parseNamespaceImport(parser, file, scanner, &nodes);
    } else {
        source_value = try parseDefaultOrMixedImport(parser, file, scanner, &nodes);
    }

    if (source_value) |resolved_source| {
        try modules.append(parser.allocator, try parser.allocator.dupe(u8, resolved_source));
    }

    const statement_end = consumeImportTerminator(scanner);
    patchImportRanges(nodes.items, .{ .start = statement_start, .end = statement_end });
    return .{
        .nodes = try nodes.toOwnedSlice(parser.allocator),
        .modules = try modules.toOwnedSlice(parser.allocator),
    };
}

fn parseDefaultOrMixedImport(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    nodes: *std.ArrayList(*Node),
) ![]const u8 {
    const local_name = scanner.readIdentifier() orelse return parser.failAt(file, scanner.offset, .Syntax, "Expected default import name");
    try nodes.append(parser.allocator, try makeImportNode(parser, file, .default, "default", local_name, null, undefined));

    scanner.skipTrivia();
    if (scanner.peek() == ',') {
        scanner.offset += 1;
        scanner.skipTrivia();

        if (scanner.peek() == '{') {
            return parseNamedImports(parser, file, scanner, nodes);
        }

        if (scanner.peek() == '*') {
            return parseNamespaceImport(parser, file, scanner, nodes);
        }
    }

    if (!scanner.startsWithWord("from")) {
        return parser.failAt(file, scanner.offset, .Syntax, "Expected 'from' in import");
    }

    scanner.offset += "from".len;
    scanner.skipTrivia();
    const source_value = try readImportSource(parser, file, scanner);
    patchTrailingImportSource(nodes.items, source_value);
    return source_value;
}

fn parseNamespaceImport(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    nodes: *std.ArrayList(*Node),
) ![]const u8 {
    if (scanner.peek() != '*') return parser.failAt(file, scanner.offset, .Syntax, "Expected namespace import");
    scanner.offset += 1;
    scanner.skipTrivia();

    if (!scanner.startsWithWord("as")) {
        return parser.failAt(file, scanner.offset, .Syntax, "Expected 'as' in namespace import");
    }
    scanner.offset += "as".len;
    scanner.skipTrivia();

    const local_name = scanner.readIdentifier() orelse return parser.failAt(file, scanner.offset, .Syntax, "Expected namespace import alias");
    try nodes.append(parser.allocator, try makeImportNode(parser, file, .namespace, "*", local_name, null, undefined));

    scanner.skipTrivia();
    if (!scanner.startsWithWord("from")) {
        return parser.failAt(file, scanner.offset, .Syntax, "Expected 'from' in import");
    }

    scanner.offset += "from".len;
    scanner.skipTrivia();
    const source_value = try readImportSource(parser, file, scanner);
    patchTrailingImportSource(nodes.items, source_value);
    return source_value;
}

fn parseNamedImports(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    nodes: *std.ArrayList(*Node),
) ![]const u8 {
    const clause = scanner.skipEnclosed('{', '}') orelse return parser.failAt(file, scanner.offset, .Syntax, "Expected import clause");
    const clause_source = scanner.source[clause.start + 1 .. clause.end - 1];
    var inner = Scanner.init(clause_source);

    while (true) {
        inner.skipTrivia();
        if (inner.eof()) break;

        const imported = inner.readIdentifier() orelse return parser.failAt(file, clause.start + 1 + inner.offset, .Syntax, "Expected imported name");
        inner.skipTrivia();

        var local = imported;
        if (inner.startsWithWord("as")) {
            inner.offset += 2;
            inner.skipTrivia();
            local = inner.readIdentifier() orelse return parser.failAt(file, clause.start + 1 + inner.offset, .Syntax, "Expected local import alias");
        }

        try nodes.append(parser.allocator, try makeImportNode(parser, file, .named, imported, local, null, undefined));

        inner.skipTrivia();
        if (inner.peek() == ',') {
            inner.offset += 1;
            continue;
        }
    }

    scanner.skipTrivia();
    if (!scanner.startsWithWord("from")) {
        return parser.failAt(file, scanner.offset, .Syntax, "Expected 'from' in import");
    }

    scanner.offset += "from".len;
    scanner.skipTrivia();
    const source_value = try readImportSource(parser, file, scanner);
    patchTrailingImportSource(nodes.items, source_value);
    return source_value;
}

fn readImportSource(parser: *Parser, file: *Graph.File, scanner: *Scanner) ![]const u8 {
    const source_token = scanner.readStringToken();
    const raw_source = switch (source_token.value) {
        .string => |value| value,
        else => return parser.failAt(file, scanner.offset, .Syntax, "Expected import source"),
    };

    if (raw_source.len < 2) return parser.failAt(file, scanner.offset, .Syntax, "Expected import source");
    return raw_source[1 .. raw_source.len - 1];
}

fn makeImportNode(
    parser: *Parser,
    file: *Graph.File,
    kind: Node.ImportKind,
    imported_name: ?[]const u8,
    local_name: ?[]const u8,
    source_value: ?[]const u8,
    range: Node.Range,
) !*Node {
    const imported_id = if (imported_name) |name|
        Node.new(.{ .Id = .{ .name = try parser.allocator.dupe(u8, name) } }).withFile(file)
    else
        null;
    const local_id = if (local_name) |name|
        Node.new(.{ .Id = .{ .name = try parser.allocator.dupe(u8, name) } }).withFile(file)
    else
        null;
    const source_id = Node.new(.{ .String = .{ .value = try parser.allocator.dupe(u8, source_value orelse "") } }).withFile(file);

    const import_node = Node.new(.{ .Import = .{
        .kind = kind,
        .id = imported_id,
        .local = local_id,
        .source = source_id,
        .range = range,
    } }).withFile(file);

    if (local_id) |local| {
        local.getProps(.Id).parent = import_node;
    }

    return import_node;
}

fn patchTrailingImportSource(nodes: []*Node, source_value: []const u8) void {
    var index = nodes.len;
    while (index > 0) {
        index -= 1;
        const import_props = nodes[index].getProps(.Import);
        if (import_props.source.getName().len != 0) break;
        import_props.source.getProps(.String).value = source_value;
    }
}

fn patchImportRanges(nodes: []*Node, range: Node.Range) void {
    for (nodes) |node| {
        node.getProps(.Import).range = range;
    }
}

fn consumeImportTerminator(scanner: *Scanner) usize {
    while (!scanner.eof()) {
        const ch = scanner.peek().?;
        scanner.offset += 1;
        if (ch == ';' or ch == '\n') break;
    }
    return scanner.offset;
}
