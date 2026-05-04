const std = @import("std");
const Parser = @import("../parser.zig");
const Scanner = @import("../scanner.zig");
const Node = @import("../node.zig");
const Graph = @import("../graph.zig");
const parse_expr = @import("./parse-expr.zig");

pub fn parseParams(parser: *Parser, file: *Graph.File, range: Node.Range) ![]*Node {
    var scanner = Scanner.init(file.source);
    scanner.offset = range.start + 1;
    var params: std.ArrayList(*Node) = .empty;

    while (!scanner.eof() and scanner.offset < range.end - 1) {
        scanner.skipTrivia();
        if (scanner.offset >= range.end - 1) break;

        if (isParamModifier(&scanner)) {
            _ = scanner.readIdentifier();
            continue;
        }

        const name = scanner.readIdentifier() orelse {
            scanner.offset += 1;
            continue;
        };

        scanner.skipTrivia();
        var type_ref: ?*Node = null;
        if (scanner.peek() == ':') {
            scanner.offset += 1;
            type_ref = try parse_expr.parseTypeRef(parser, file, &scanner, range.end);
        }

        const id = Node.new(.{ .Id = .{ .name = name } }).withFile(file);
        const param = Node.new(.{ .Param = .{ .id = id, .type_ref = type_ref } }).withFile(file);
        try params.append(parser.allocator, param);

        skipToNextParam(&scanner, range.end);
    }

    return params.toOwnedSlice(parser.allocator);
}

fn isParamModifier(scanner: *Scanner) bool {
    return scanner.startsWithWord("public") or
        scanner.startsWithWord("private") or
        scanner.startsWithWord("protected") or
        scanner.startsWithWord("readonly");
}

fn skipToNextParam(scanner: *Scanner, limit: usize) void {
    while (!scanner.eof() and scanner.offset < limit - 1) {
        scanner.skipTrivia();
        const ch = scanner.peek() orelse break;

        if (ch == ',') {
            scanner.offset += 1;
            break;
        }
        if (ch == ')') break;
        if (ch == '(') {
            _ = scanner.skipEnclosed('(', ')');
            continue;
        }
        if (ch == '{') {
            _ = scanner.skipEnclosed('{', '}');
            continue;
        }
        if (ch == '[') {
            _ = scanner.skipEnclosed('[', ']');
            continue;
        }
        if (ch == '<') {
            scanner.offset += 1;
            _ = scanner.skipBalanced('<', '>');
            continue;
        }

        scanner.offset += 1;
    }
}
