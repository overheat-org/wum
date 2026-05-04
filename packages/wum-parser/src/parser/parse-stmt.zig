const std = @import("std");
const Parser = @import("../parser.zig");
const Scanner = @import("../scanner.zig");
const Node = @import("../node.zig");
const Graph = @import("../graph.zig");
const parse_expr = @import("./parse-expr.zig");
const parse_class = @import("./parse-class.zig");
const parse_decl = @import("./parse-decl.zig");
const parse_import = @import("./parse-import.zig");
const parse_export = @import("./parse-export.zig");

const StmtHandler = *const fn (
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    pending_decorators: *std.ArrayList(*Node),
    declarations: *std.ArrayList(*Graph.Symbol),
    exports: *std.ArrayList(*Graph.Symbol),
) anyerror!void;

const stmt_map = std.StaticStringMap(StmtHandler).initComptime(.{
    .{ "export", parseExportStmt },
    .{ "class", parseClassStmt },
    .{ "enum", parseEnumStmt },
    .{ "function", parseFunctionStmt },
    .{ "interface", parseInterfaceStmt },
    .{ "type", parseTypeStmt },
    // .{ "const", parseVariableStmt },
    // .{ "let", parseVariableStmt }, // Código desnecessário, não precisamos ler variaveis
    // .{ "var", parseVariableStmt },
});

pub fn parseProgram(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    imports: *std.ArrayList(*Node),
    modules: *std.ArrayList([]const u8),
    declarations: *std.ArrayList(*Graph.Symbol),
    exports: *std.ArrayList(*Graph.Symbol),
) !void {
    var pending_decorators: std.ArrayList(*Node) = .empty;

    while (true) {
        scanner.skipTrivia();
        if (scanner.eof()) break;

        if (scanner.peek() == '@') {
            const decorator = try parse_expr.parseDecorator(file, scanner);
            try pending_decorators.append(parser.allocator, decorator);
            continue;
        }

        if (scanner.startsWithWord("import")) {
            pending_decorators.clearRetainingCapacity();
            const result = try parse_import.parseImport(parser, file, scanner);
            for (result.nodes) |node| try imports.append(parser.allocator, node);
            for (result.modules) |module_name| try modules.append(parser.allocator, module_name);
            continue;
        }

        const keyword = peekWord(scanner) orelse {
            _ = scanner.advance();
            continue;
        };

        if (stmt_map.get(keyword)) |handler| {
            try handler(parser, file, scanner, &pending_decorators, declarations, exports);
            continue;
        }

        _ = scanner.advance();
    }
}

fn peekWord(scanner: *Scanner) ?[]const u8 {
    const checkpoint = scanner.offset;
    const word = scanner.readIdentifier() orelse return null;
    scanner.offset = checkpoint;
    return word;
}

fn parseExportStmt(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    pending_decorators: *std.ArrayList(*Node),
    declarations: *std.ArrayList(*Graph.Symbol),
    exports: *std.ArrayList(*Graph.Symbol),
) !void {
    try parse_export.parseExport(parser, file, scanner, pending_decorators.items, declarations, exports);
    pending_decorators.clearRetainingCapacity();
}

fn parseClassStmt(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    pending_decorators: *std.ArrayList(*Node),
    declarations: *std.ArrayList(*Graph.Symbol),
    exports: *std.ArrayList(*Graph.Symbol),
) !void {
    const symbol = try parse_class.parseClassDecl(parser, file, scanner, pending_decorators.items);
    try declarations.append(parser.allocator, symbol);
    pending_decorators.clearRetainingCapacity();
    _ = exports;
}

fn parseFunctionStmt(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    pending_decorators: *std.ArrayList(*Node),
    declarations: *std.ArrayList(*Graph.Symbol),
    exports: *std.ArrayList(*Graph.Symbol),
) !void {
    const symbol = try parse_class.parseFunctionDecl(parser, file, scanner, pending_decorators.items);
    try declarations.append(parser.allocator, symbol);
    pending_decorators.clearRetainingCapacity();
    _ = exports;
}

fn parseEnumStmt(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    pending_decorators: *std.ArrayList(*Node),
    declarations: *std.ArrayList(*Graph.Symbol),
    exports: *std.ArrayList(*Graph.Symbol),
) !void {
    const symbol = try parse_decl.parseSimpleNamedDecl(parser, file, scanner, "enum", .Enum);
    try declarations.append(parser.allocator, symbol);
    pending_decorators.clearRetainingCapacity();
    _ = exports;
}

fn parseInterfaceStmt(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    pending_decorators: *std.ArrayList(*Node),
    declarations: *std.ArrayList(*Graph.Symbol),
    exports: *std.ArrayList(*Graph.Symbol),
) !void {
    const symbol = try parse_decl.parseSimpleNamedDecl(parser, file, scanner, "interface", .Interface);
    try declarations.append(parser.allocator, symbol);
    pending_decorators.clearRetainingCapacity();
    _ = exports;
}

fn parseTypeStmt(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    pending_decorators: *std.ArrayList(*Node),
    declarations: *std.ArrayList(*Graph.Symbol),
    exports: *std.ArrayList(*Graph.Symbol),
) !void {
    const symbol = try parse_decl.parseSimpleNamedDecl(parser, file, scanner, "type", .Type);
    try declarations.append(parser.allocator, symbol);
    pending_decorators.clearRetainingCapacity();
    _ = exports;
}

fn parseVariableStmt(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    pending_decorators: *std.ArrayList(*Node),
    declarations: *std.ArrayList(*Graph.Symbol),
    exports: *std.ArrayList(*Graph.Symbol),
) !void {
    const symbols = try parse_decl.parseVariableDecl(parser, file, scanner);
    for (symbols) |resolved| try declarations.append(parser.allocator, resolved);
    pending_decorators.clearRetainingCapacity();
    _ = exports;
}
