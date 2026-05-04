const std = @import("std");

pub const Kind = enum {
    Syntax,
    Semantic,
    Internal,
};

pub const Position = struct {
    line: usize,
    column: usize,
};

pub const CompileError = struct {
    kind: Kind,
    message: []const u8,
    file_path: []const u8,
    range: Range,
    position: Position,
};

pub const Range = struct {
    start: usize,
    end: usize,
};

pub fn make(
    allocator: std.mem.Allocator,
    file_path: []const u8,
    source: []const u8,
    line_starts: []const usize,
    range: Range,
    kind: Kind,
    message: []const u8,
) !CompileError {
    _ = source;
    return .{
        .kind = kind,
        .message = try allocator.dupe(u8, message),
        .file_path = try allocator.dupe(u8, file_path),
        .range = range,
        .position = positionFromOffset(line_starts, range.start),
    };
}

pub fn buildLineStarts(allocator: std.mem.Allocator, source: []const u8) ![]usize {
    var starts: std.ArrayList(usize) = .empty;
    try starts.append(allocator, 0);

    for (source, 0..) |ch, index| {
        if (ch == '\n' and index + 1 < source.len) {
            try starts.append(allocator, index + 1);
        }
    }

    return starts.toOwnedSlice(allocator);
}

pub fn positionFromOffset(line_starts: []const usize, offset: usize) Position {
    var line_index: usize = 0;

    for (line_starts, 0..) |start, index| {
        if (start > offset) break;
        line_index = index;
    }

    return .{
        .line = line_index + 1,
        .column = offset - line_starts[line_index] + 1,
    };
}

pub fn format(
    allocator: std.mem.Allocator,
    compile_error: CompileError,
    source: []const u8,
    line_starts: []const usize,
) ![]const u8 {
    const line_slice = getLineSlice(source, line_starts, compile_error.position.line);
    const kind_name = switch (compile_error.kind) {
        .Syntax => "syntax error",
        .Semantic => "semantic error",
        .Internal => "internal error",
    };

    const caret_padding = if (compile_error.position.column > 0) compile_error.position.column - 1 else 0;
    const caret_line = try std.fmt.allocPrint(allocator, "{s}^", .{try allocator.alloc(u8, caret_padding)});
    @memset(@constCast(caret_line[0..caret_padding]), ' ');

    return std.fmt.allocPrint(
        allocator,
        "{s}: {s}\n  at {s}:{d}:{d}\n\n{s}\n{s}",
        .{
            kind_name,
            compile_error.message,
            compile_error.file_path,
            compile_error.position.line,
            compile_error.position.column,
            line_slice,
            caret_line,
        },
    );
}

fn getLineSlice(source: []const u8, line_starts: []const usize, line: usize) []const u8 {
    const line_index = if (line == 0) 0 else line - 1;
    const start = line_starts[line_index];
    const end = if (line_index + 1 < line_starts.len) line_starts[line_index + 1] - 1 else source.len;
    return source[start..end];
}

test "errors formats message with position and caret" {
    const allocator = std.heap.page_allocator;
    const source =
        \\alpha
        \\beta
    ;
    const starts = try buildLineStarts(allocator, source);
    const compile_error = try make(
        allocator,
        "/tmp/test.ts",
        source,
        starts,
        .{ .start = 6, .end = 6 },
        .Syntax,
        "Unexpected token",
    );

    const text = try format(allocator, compile_error, source, starts);
    try std.testing.expect(std.mem.indexOf(u8, text, "syntax error: Unexpected token") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "/tmp/test.ts:2:1") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\nbeta\n^") != null);
}
