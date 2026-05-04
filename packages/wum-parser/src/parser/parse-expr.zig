const std = @import("std");
const Parser = @import("../parser.zig");
const Scanner = @import("../scanner.zig");
const Node = @import("../node.zig");
const Graph = @import("../graph.zig");

pub fn parseTypeRef(parser: *Parser, file: *Graph.File, scanner: *Scanner, limit: usize) !?*Node {
    scanner.skipTrivia();
    if (scanner.offset >= limit) return null;

    const first_name = scanner.readIdentifier() orelse return null;
    var current = Node.new(.{ .Id = .{ .name = first_name } }).withFile(file);
    linkTypeParent(file, current);

    while (true) {
        scanner.skipTrivia();
        if (scanner.peek() != '.') break;

        scanner.offset += 1;
        const part = scanner.readIdentifier() orelse break;
        const property = Node.new(.{ .Id = .{ .name = part } }).withFile(file);
        current = Node.new(.{ .MemberExpr = .{
            .object = current,
            .property = property,
        } }).withFile(file);
    }

    _ = parser;
    return current;
}

pub fn linkTypeParent(file: *Graph.File, id: *Node) void {
    for (file.imports) |import_node| {
        const local = import_node.getProps(.Import).local orelse continue;
        if (std.mem.eql(u8, local.getName(), id.getName())) {
            id.getProps(.Id).parent = import_node;
            return;
        }
    }

    for (file.declarations) |symbol| {
        if (std.mem.eql(u8, symbol.id, id.getName())) {
            id.getProps(.Id).parent = symbol.node;
            return;
        }
    }
}

pub fn parseDecorator(file: *Graph.File, scanner: *Scanner) !*Node {
    return parseDecoratorWithParser(null, file, scanner);
}

pub fn parseDecoratorWithParser(parser: ?*Parser, file: *Graph.File, scanner: *Scanner) !*Node {
    scanner.skipTrivia();
    if (scanner.peek() != '@') {
        if (parser) |p| return p.failAt(file, scanner.offset, .Syntax, "Expected decorator");
        return error.ExpectedDecorator;
    }
    scanner.offset += 1;

    var callee = try parseDecoratorTarget(parser, file, scanner);

    scanner.skipTrivia();
    if (scanner.peek() == '(') {
        const args_range = scanner.skipEnclosed('(', ')') orelse {
            if (parser) |p| return p.failAt(file, scanner.offset, .Syntax, "Expected decorator arguments");
            return error.InvalidDecorator;
        };
        const args = try parseDecoratorArgs(file, scanner.source[args_range.start + 1 .. args_range.end - 1]);
        callee = Node.new(.{ .CallExpr = .{
            .id = callee,
            .params = args,
        } }).withFile(file);
    }

    return callee;
}

fn parseDecoratorTarget(parser: ?*Parser, file: *Graph.File, scanner: *Scanner) !*Node {
    const first = scanner.readIdentifier() orelse {
        if (parser) |p| return p.failAt(file, scanner.offset, .Syntax, "Expected decorator name");
        return error.ExpectedDecoratorName;
    };
    var current = Node.new(.{ .Id = .{ .name = first } }).withFile(file);

    while (true) {
        scanner.skipTrivia();
        if (scanner.peek() != '.') break;

        scanner.offset += 1;
        const prop = scanner.readIdentifier() orelse break;
        const property = Node.new(.{ .Id = .{ .name = prop } }).withFile(file);
        current = Node.new(.{ .MemberExpr = .{
            .object = current,
            .property = property,
        } }).withFile(file);
    }

    return current;
}

fn parseDecoratorArgs(file: *Graph.File, args_source: []const u8) ![]*Node {
    var args: std.ArrayList(*Node) = .empty;
    var scanner = Scanner.init(args_source);

    while (true) {
        scanner.skipTrivia();
        if (scanner.eof()) break;

        if (scanner.peek() == '"' or scanner.peek() == '\'') {
            const token = scanner.readStringToken();
            const raw = token.value.string;
            const value = raw[1 .. raw.len - 1];
            try args.append(std.heap.page_allocator, Node.new(.{ .String = .{ .value = value } }).withFile(file));
        } else {
            _ = scanner.advance();
        }

        scanner.skipTrivia();
        if (scanner.peek() == ',') scanner.offset += 1;
    }

    return args.toOwnedSlice(std.heap.page_allocator);
}
