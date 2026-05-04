const std = @import("std");
const Parser = @import("../parser.zig");
const Scanner = @import("../scanner.zig");
const Node = @import("../node.zig");
const Graph = @import("../graph.zig");
const parse_expr = @import("./parse-expr.zig");
const parse_decl = @import("./parse-decl.zig");

pub fn parseClassBody(parser: *Parser, file: *Graph.File, range: Node.Range) !*Node {
    var scanner = Scanner.init(file.source);
    scanner.offset = range.start + 1;

    var methods: std.ArrayList(*Node) = .empty;
    var pending_decorators: std.ArrayList(*Node) = .empty;
    var constructor_range: ?Node.Range = null;

    while (!scanner.eof() and scanner.offset < range.end - 1) {
        scanner.skipTrivia();
        if (scanner.offset >= range.end - 1) break;

        if (scanner.peek() == '@') {
            const decorator = try parse_expr.parseDecoratorWithParser(parser, file, &scanner);
            try pending_decorators.append(parser.allocator, decorator);
            continue;
        }

        const checkpoint = scanner.offset;
        const maybe_name = scanner.readIdentifier();
        if (maybe_name) |name| {
            scanner.skipTrivia();
            if (scanner.peek() == '(') {
                const method = try parseMethodAt(parser, file, &scanner, checkpoint, name, pending_decorators.items);

                if (std.mem.eql(u8, name, "constructor")) {
                    const fn_props = method.getProps(.Fn);
                    constructor_range = .{
                        .start = checkpoint,
                        .end = fn_props.ranges.body.end,
                    };
                } else if (pending_decorators.items.len > 0) {
                    try methods.append(parser.allocator, method);
                }

                pending_decorators.clearRetainingCapacity();
                continue;
            }
        }

        pending_decorators.clearRetainingCapacity();
        scanner.offset = checkpoint + 1;
    }

    return Node.new(.{ .ClassBody = .{
        .constructor_range = constructor_range,
        .methods = try methods.toOwnedSlice(parser.allocator),
    } }).withFile(file);
}

pub fn parseMethod(parser: *Parser, file: *Graph.File, range: Node.Range, decorators: []*Node) !*Node {
    var scanner = Scanner.init(file.source);
    scanner.offset = range.start;

    const name = scanner.readIdentifier() orelse return parser.failAt(file, scanner.offset, .Syntax, "Expected method name");
    return parseMethodAt(parser, file, &scanner, range.start, name, decorators);
}

pub fn parseClassDecl(parser: *Parser, file: *Graph.File, scanner: *Scanner, decorators: []*Node) !*Graph.Symbol {
    return parseClassDeclWithOptions(parser, file, scanner, decorators, false, null);
}

pub fn parseDefaultClassDecl(parser: *Parser, file: *Graph.File, scanner: *Scanner, decorators: []*Node) !*Graph.Symbol {
    return parseClassDeclWithOptions(parser, file, scanner, decorators, true, "default");
}

pub fn parseFunctionDecl(parser: *Parser, file: *Graph.File, scanner: *Scanner, decorators: []*Node) !*Graph.Symbol {
    return parseFunctionDeclWithOptions(parser, file, scanner, decorators, false, null);
}

pub fn parseDefaultFunctionDecl(parser: *Parser, file: *Graph.File, scanner: *Scanner, decorators: []*Node) !*Graph.Symbol {
    return parseFunctionDeclWithOptions(parser, file, scanner, decorators, true, "default");
}

fn parseClassDeclWithOptions(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    decorators: []*Node,
    allow_anonymous: bool,
    fallback_name: ?[]const u8,
) !*Graph.Symbol {
    const start = scanner.offset;
    scanner.offset += "class".len;
    scanner.skipTrivia();

    const name = if (scanner.readIdentifier()) |resolved| resolved else if (allow_anonymous) fallback_name.? else return parser.failAt(file, scanner.offset, .Syntax, "Expected class name");

    while (!scanner.eof()) {
        scanner.skipTrivia();
        if (scanner.peek() == '{') break;
        scanner.offset += 1;
    }

    const body = scanner.skipEnclosed('{', '}') orelse return parser.failAt(file, scanner.offset, .Syntax, "Expected class body");
    const id = Node.new(.{ .Id = .{ .name = try parser.allocator.dupe(u8, name) } }).withFile(file);
    const node = Node.new(.{ .Class = .{
        .id = id,
        .decorators = try parser.allocator.dupe(*Node, decorators),
        .ranges = .{
            .decl = .{ .start = start, .end = body.end },
            .body = .{ .start = body.start, .end = body.end },
        },
    } }).withFile(file);

    return parse_decl.makeSymbol(parser, file, name, node);
}

fn parseFunctionDeclWithOptions(
    parser: *Parser,
    file: *Graph.File,
    scanner: *Scanner,
    decorators: []*Node,
    allow_anonymous: bool,
    fallback_name: ?[]const u8,
) !*Graph.Symbol {
    const start = scanner.offset;
    scanner.offset += "function".len;
    scanner.skipTrivia();

    const name = if (scanner.readIdentifier()) |resolved| resolved else if (allow_anonymous) fallback_name.? else return parser.failAt(file, scanner.offset, .Syntax, "Expected function name");
    const params = scanner.skipEnclosed('(', ')') orelse return parser.failAt(file, scanner.offset, .Syntax, "Expected function params");
    scanner.skipTrivia();
    const body = scanner.skipEnclosed('{', '}') orelse return parser.failAt(file, scanner.offset, .Syntax, "Expected function body");

    const id = Node.new(.{ .Id = .{ .name = try parser.allocator.dupe(u8, name) } }).withFile(file);
    const node = Node.new(.{ .Fn = .{
        .id = id,
        .decorators = try parser.allocator.dupe(*Node, decorators),
        .ranges = .{
            .decl = .{ .start = start, .end = body.end },
            .params = .{ .start = params.start, .end = params.end },
            .body = .{ .start = body.start, .end = body.end },
        },
    } }).withFile(file);

    return parse_decl.makeSymbol(parser, file, name, node);
}

fn parseMethodAt(parser: *Parser, file: *Graph.File, scanner: *Scanner, start: usize, name: []const u8, decorators: []*Node) !*Node {
    const params_range = scanner.skipEnclosed('(', ')') orelse return parser.failAt(file, scanner.offset, .Syntax, "Expected method params");
    scanner.skipTrivia();
    const body_range = scanner.skipEnclosed('{', '}') orelse return parser.failAt(file, scanner.offset, .Syntax, "Expected method body");

    const id = Node.new(.{ .Id = .{ .name = name } }).withFile(file);
    return Node.new(.{ .Fn = .{
        .id = id,
        .decorators = try parser.allocator.dupe(*Node, decorators),
        .ranges = .{
            .decl = .{ .start = start, .end = body_range.end },
            .params = .{ .start = params_range.start, .end = params_range.end },
            .body = .{ .start = body_range.start, .end = body_range.end },
        },
    } }).withFile(file);
}
