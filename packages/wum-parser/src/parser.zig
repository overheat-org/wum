const std = @import("std");
const Scanner = @import("./scanner.zig");
const Node = @import("./node.zig");
const Graph = @import("./graph.zig");
const errors = @import("./errors.zig");
const Path = @import("./utils.zig").Path;
const parse_body = @import("./parser/parse-body.zig");
const parse_stmt = @import("./parser/parse-stmt.zig");
const parse_class = @import("./parser/parse-class.zig");
const parse_param = @import("./parser/parse-param.zig");

const Parser = @This();

allocator: std.mem.Allocator,
graph: *Graph,
last_error: ?errors.CompileError = null,
last_error_source: ?[]const u8 = null,
last_error_line_starts: ?[]const usize = null,

pub fn init(allocator: std.mem.Allocator, graph: *Graph) Parser {
    return .{
        .allocator = allocator,
        .graph = graph,
        .last_error = null,
        .last_error_source = null,
        .last_error_line_starts = null,
    };
}

pub fn parse(self: *Parser, path: []const u8, source: []const u8) !*Graph.File {
    return self.parseWithKind(.unknown, path, source);
}

pub fn parseWithKind(self: *Parser, kind: Graph.FileKind, path: []const u8, source: []const u8) !*Graph.File {
    var scanner = Scanner.init(source);
    var imports: std.ArrayList(*Node) = .empty;
    var modules: std.ArrayList([]const u8) = .empty;
    var declarations: std.ArrayList(*Graph.Symbol) = .empty;
    var exports: std.ArrayList(*Graph.Symbol) = .empty;

    const file = try self.allocator.create(Graph.File);
    file.* = .{
        .kind = kind,
        .name = Path.basename(path),
        .path = try self.allocator.dupe(u8, path),
        .source = try self.allocator.dupe(u8, source),
        .line_starts = try errors.buildLineStarts(self.allocator, source),
        .modules = &[_][]const u8{},
        .imports = &[_]*Node{},
        .exports = &[_]*Graph.Symbol{},
        .declarations = &[_]*Graph.Symbol{},
    };

    try parse_stmt.parseProgram(self, file, &scanner, &imports, &modules, &declarations, &exports);

    file.imports = try imports.toOwnedSlice(self.allocator);
    file.modules = try modules.toOwnedSlice(self.allocator);
    file.declarations = try declarations.toOwnedSlice(self.allocator);
    file.exports = try exports.toOwnedSlice(self.allocator);

    try self.graph.addParsedFile(file);
    return file;
}

pub fn getLastError(self: *Parser) ?errors.CompileError {
    return self.last_error;
}

pub fn formatLastError(self: *Parser) !?[]const u8 {
    const compile_error = self.last_error orelse return null;
    if (self.graph.getFile(compile_error.file_path)) |file| {
        return try errors.format(self.allocator, compile_error, file.source, file.line_starts);
    }

    const source = self.last_error_source orelse return null;
    const line_starts = self.last_error_line_starts orelse return null;
    return try errors.format(self.allocator, compile_error, source, line_starts);
}

pub fn failAt(self: *Parser, file: *Graph.File, offset: usize, kind: errors.Kind, message: []const u8) error{CompileFailed} {
    return self.failRange(file, .{ .start = offset, .end = offset }, kind, message);
}

pub fn failRange(self: *Parser, file: *Graph.File, range: Node.Range, kind: errors.Kind, message: []const u8) error{CompileFailed} {
    self.last_error = errors.make(
        self.allocator,
        file.path,
        file.source,
        file.line_starts,
        .{ .start = range.start, .end = range.end },
        kind,
        message,
    ) catch unreachable;
    self.last_error_source = file.source;
    self.last_error_line_starts = file.line_starts;
    return error.CompileFailed;
}

pub fn parseClassOrFnBody(self: *Parser, file: *Graph.File, range: Node.Range) !*Node {
    return parse_body.parseClassOrFnBody(self, file, range);
}

pub fn parseClassBody(self: *Parser, file: *Graph.File, range: Node.Range) !*Node {
    return parse_class.parseClassBody(self, file, range);
}

pub fn parseMethod(self: *Parser, file: *Graph.File, range: Node.Range, decorators: []*Node) !*Node {
    return parse_class.parseMethod(self, file, range, decorators);
}

pub fn parseParams(self: *Parser, file: *Graph.File, range: Node.Range) ![]*Node {
    return parse_param.parseParams(self, file, range);
}

test "parser indexes imports declarations and exports" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = Parser.init(allocator, &graph);

    const file = try parser.parse(
        "/tmp/service.ts",
        \\import { service as svc, event } from "wum.js/macros";
        \\
        \\class LocalDep {}
        \\
        \\@svc
        \\export class Init {
        \\  constructor(private dep: LocalDep, repo: Repo) {}
        \\
        \\  @event
        \\  OnceReady() {}
        \\}
    );

    try std.testing.expect(file.hasImported("wum.js/macros"));
    try std.testing.expectEqual(@as(usize, 2), file.imports.len);
    try std.testing.expectEqual(@as(usize, 1), file.exports.len);
    try std.testing.expectEqualStrings("Init", file.exports[0].id);

    const class_body = file.exports[0].node.getBody(&parser);
    const ctor = class_body.getConstructor(&parser).?;
    const params = ctor.getParams(&parser);
    try std.testing.expectEqual(@as(usize, 2), params.len);
    try std.testing.expectEqualStrings("LocalDep", params[0].getType(&parser).?.getResolvedName());
}

test "parser handles default named and anonymous exports" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = Parser.init(allocator, &graph);

    const named_fn_file = try parser.parse(
        "/tmp/default-fn.ts",
        \\export default function Boot() {}
    );
    try std.testing.expectEqual(@as(usize, 1), named_fn_file.exports.len);
    try std.testing.expectEqualStrings("default", named_fn_file.exports[0].id);
    try std.testing.expectEqual(@as(usize, 1), named_fn_file.declarations.len);
    try std.testing.expectEqualStrings("Boot", named_fn_file.declarations[0].id);

    const anon_fn_file = try parser.parse(
        "/tmp/default-anon-fn.ts",
        \\export default function() {}
    );
    try std.testing.expectEqual(@as(usize, 1), anon_fn_file.exports.len);
    try std.testing.expectEqualStrings("default", anon_fn_file.exports[0].id);

    const anon_class_file = try parser.parse(
        "/tmp/default-anon-class.ts",
        \\export default class {}
    );
    try std.testing.expectEqual(@as(usize, 1), anon_class_file.exports.len);
    try std.testing.expectEqualStrings("default", anon_class_file.exports[0].id);

    const expr_file = try parser.parse(
        "/tmp/default-expr.ts",
        \\export default call(factory({ ready: true }));
    );
    try std.testing.expectEqual(@as(usize, 1), expr_file.exports.len);
    try std.testing.expectEqualStrings("default", expr_file.exports[0].id);
    try std.testing.expect(expr_file.exports[0].node.is(.Expr));
    try std.testing.expectEqualStrings("call(factory({ ready: true }))", expr_file.exports[0].node.getSourceSlice());

    const jsx_file = try parser.parse(
        "/tmp/default-jsx.tsx",
        \\export default <command name="ping"></command>;
    );
    try std.testing.expectEqual(@as(usize, 1), jsx_file.exports.len);
    try std.testing.expect(jsx_file.exports[0].node.is(.JsxElement));
    try std.testing.expectEqualStrings("<command name=\"ping\"></command>", jsx_file.exports[0].node.getSourceSlice());
}

test "parser handles import variants and reexports" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = Parser.init(allocator, &graph);

    const file = try parser.parse(
        "/tmp/import-export.ts",
        \\import Boot from "./boot";
        \\import * as lib from "./lib";
        \\import Boot2, { service as svc } from "./mixed";
        \\import "./side-effect";
        \\export { svc as service } from "./mixed";
        \\export * from "./lib";
    );

    try std.testing.expectEqual(@as(usize, 5), file.imports.len);
    try std.testing.expectEqual(Node.ImportKind.default, file.imports[0].getProps(.Import).kind);
    try std.testing.expectEqual(Node.ImportKind.namespace, file.imports[1].getProps(.Import).kind);
    try std.testing.expectEqual(Node.ImportKind.default, file.imports[2].getProps(.Import).kind);
    try std.testing.expectEqual(Node.ImportKind.named, file.imports[3].getProps(.Import).kind);
    try std.testing.expectEqual(Node.ImportKind.side_effect, file.imports[4].getProps(.Import).kind);
    try std.testing.expectEqual(@as(usize, 2), file.exports.len);
    try std.testing.expect(file.exports[0].node.is(.Export));
    try std.testing.expectEqual(Node.ExportKind.reexport_named, file.exports[0].node.getProps(.Export).kind);
    try std.testing.expectEqual(Node.ExportKind.reexport_all, file.exports[1].node.getProps(.Export).kind);
}

test "parser indexes multiple variable declarators" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = Parser.init(allocator, &graph);

    const file = try parser.parse(
        "/tmp/vars.ts",
        \\const first = create(), second = { ready: true }, third = arr[0];
    );

    try std.testing.expectEqual(@as(usize, 3), file.declarations.len);
    try std.testing.expect(file.declarations[0].node.is(.VarDecl));
    try std.testing.expect(file.declarations[1].node.is(.VarDecl));
    try std.testing.expect(file.declarations[2].node.is(.VarDecl));
}

test "parser handles export named as default" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = Parser.init(allocator, &graph);

    const file = try parser.parse(
        "/tmp/export-default-alias.ts",
        \\class Boot {}
        \\export { Boot as default };
    );

    try std.testing.expectEqual(@as(usize, 1), file.exports.len);
    try std.testing.expectEqualStrings("default", file.exports[0].id);
    try std.testing.expectEqualStrings("Boot", file.exports[0].node.getName());
}

test "parser stores explicit line and column for syntax error" {
    const allocator = std.heap.page_allocator;
    var graph = Graph.init(allocator);
    var parser = Parser.init(allocator, &graph);

    try std.testing.expectError(
        error.CompileFailed,
        parser.parse(
            "/tmp/invalid.ts",
            \\import { foo as } from "pkg";
        ),
    );

    const compile_error = parser.getLastError().?;
    try std.testing.expectEqual(errors.Kind.Syntax, compile_error.kind);
    try std.testing.expectEqual(@as(usize, 1), compile_error.position.line);
    try std.testing.expect(compile_error.position.column > 1);

    const rendered = (try parser.formatLastError()).?;
    try std.testing.expect(std.mem.indexOf(u8, rendered, "/tmp/invalid.ts:1:") != null);
}
