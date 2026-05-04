const std = @import("std");
const Token = @import("./token.zig");

const Scanner = @This();

// zig fmt: off
pub const keywords = std.StaticStringMap(u0).initComptime(.{
    .{ "as",        0 },
    .{ "class",     0 },
    .{ "const",     0 },
    .{ "default",   0 },
    .{ "enum",      0 },
    .{ "export",    0 },
    .{ "extends",   0 },
    .{ "function",  0 },
    .{ "from",      0 },
    .{ "if",        0 },
    .{ "implements",0 },
    .{ "import",    0 },
    .{ "interface", 0 },
    .{ "let",       0 },
    .{ "private",   0 },
    .{ "protected", 0 },
    .{ "public",    0 },
    .{ "readonly",  0 },
    .{ "return",    0 },
    .{ "static",    0 },
    .{ "type",      0 },
    .{ "var",       0 },
    .{ "while",     0 },
});
// zig fmt: on

source: []const u8,
offset: usize = 0,

pub fn init(source: []const u8) Scanner {
    return .{
        .source = source,
    };
}

pub fn eof(self: Scanner) bool {
    return self.offset >= self.source.len;
}

pub fn peek(self: Scanner) ?u8 {
    if (self.eof()) return null;
    return self.source[self.offset];
}

pub fn peekAt(self: Scanner, index: usize) ?u8 {
    if (index >= self.source.len) return null;
    return self.source[index];
}

pub fn advance(self: *Scanner) ?u8 {
    const ch = self.peek() orelse return null;
    self.offset += 1;
    return ch;
}

pub fn skipTrivia(self: *Scanner) void {
    while (!self.eof()) {
        const ch = self.peek().?;
        switch (ch) {
            ' ', '\n', '\r', '\t' => {
                self.offset += 1;
            },
            '/' => {
                const next = self.peekAt(self.offset + 1);
                if (next == '/') {
                    self.offset += 2;
                    while (!self.eof() and self.peek().? != '\n') self.offset += 1;
                    continue;
                }

                if (next == '*') {
                    self.offset += 2;
                    while (self.offset + 1 < self.source.len) {
                        if (self.source[self.offset] == '*' and self.source[self.offset + 1] == '/') {
                            self.offset += 2;
                            break;
                        }
                        self.offset += 1;
                    }
                    continue;
                }

                return;
            },
            else => return,
        }
    }
}

pub fn nextToken(self: *Scanner) Token {
    self.skipTrivia();

    const start = self.offset;
    const ch = self.peek() orelse return Token.init(.eof, start, start);

    switch (ch) {
        '@' => {
            self.offset += 1;
            return Token.init(.at, start, self.offset);
        },
        ',' => {
            self.offset += 1;
            return Token.init(.comma, start, self.offset);
        },
        '.' => {
            self.offset += 1;
            return Token.init(.dot, start, self.offset);
        },
        ':' => {
            self.offset += 1;
            return Token.init(.colon, start, self.offset);
        },
        ';' => {
            self.offset += 1;
            return Token.init(.semicolon, start, self.offset);
        },
        '(' => {
            self.offset += 1;
            return Token.init(.l_paren, start, self.offset);
        },
        ')' => {
            self.offset += 1;
            return Token.init(.r_paren, start, self.offset);
        },
        '{' => {
            self.offset += 1;
            return Token.init(.l_brace, start, self.offset);
        },
        '}' => {
            self.offset += 1;
            return Token.init(.r_brace, start, self.offset);
        },
        '[' => {
            self.offset += 1;
            return Token.init(.l_bracket, start, self.offset);
        },
        ']' => {
            self.offset += 1;
            return Token.init(.r_bracket, start, self.offset);
        },
        '=' => {
            self.offset += 1;
            return Token.init(.equal, start, self.offset);
        },
        '\'', '"', '`' => return self.readStringToken(),
        else => {
            if (isIdentStart(ch)) return self.readWordToken();
            if (std.ascii.isDigit(ch)) return self.readNumberToken();

            self.offset += 1;
            return Token.init(.identifier, start, self.offset);
        },
    }
}

pub fn readStringToken(self: *Scanner) Token {
    const quote = self.peek().?;
    const start = self.offset;
    self.offset += 1;

    while (!self.eof()) {
        const ch = self.peek().?;

        if (ch == '\\') {
            self.offset += 2;
            continue;
        }

        if (quote == '`' and ch == '$' and self.peekAt(self.offset + 1) == '{') {
            self.offset += 2;
            _ = self.skipBalanced('{', '}');
            continue;
        }

        self.offset += 1;
        if (ch == quote) break;
    }

    return Token.initString(.string, self.source[start..self.offset], start, self.offset);
}

pub fn readWordToken(self: *Scanner) Token {
    const start = self.offset;
    self.offset += 1;

    while (!self.eof()) {
        const ch = self.peek().?;
        if (!isIdentContinue(ch)) break;
        self.offset += 1;
    }

    const value = self.source[start..self.offset];
    if (keywords.has(value)) {
        return Token.initString(.keyword, value, start, self.offset);
    }

    return Token.initString(.identifier, value, start, self.offset);
}

pub fn readNumberToken(self: *Scanner) Token {
    const start = self.offset;
    self.offset += 1;
    while (!self.eof() and std.ascii.isDigit(self.peek().?)) self.offset += 1;
    return Token.init(.number, start, self.offset);
}

pub fn skipBalanced(self: *Scanner, open: u8, close: u8) usize {
    var depth: usize = 1;

    while (!self.eof()) {
        const ch = self.peek().?;

        if (ch == '\'' or ch == '"' or ch == '`') {
            _ = self.readStringToken();
            continue;
        }

        if (ch == '/') {
            const next = self.peekAt(self.offset + 1);
            if (next == '/' or next == '*') {
                self.skipTrivia();
                continue;
            }
        }

        self.offset += 1;

        if (ch == open) {
            depth += 1;
        } else if (ch == close) {
            depth -= 1;
            if (depth == 0) return self.offset - 1;
        }
    }

    return self.offset;
}

pub fn skipEnclosed(self: *Scanner, open: u8, close: u8) ?struct { start: usize, end: usize } {
    self.skipTrivia();
    if (self.peek() != open) return null;
    const start = self.offset;
    self.offset += 1;
    const end = self.skipBalanced(open, close);
    return .{ .start = start, .end = end + 1 };
}

pub fn readIdentifier(self: *Scanner) ?[]const u8 {
    self.skipTrivia();
    const ch = self.peek() orelse return null;
    if (!isIdentStart(ch)) return null;
    const token = self.readWordToken();
    return switch (token.value) {
        .string => |value| value,
        else => null,
    };
}

pub fn startsWithWord(self: Scanner, word: []const u8) bool {
    if (self.offset + word.len > self.source.len) return false;
    if (!std.mem.eql(u8, self.source[self.offset .. self.offset + word.len], word)) return false;

    const prev_ok = self.offset == 0 or !isIdentContinue(self.source[self.offset - 1]);
    const next_index = self.offset + word.len;
    const next_ok = next_index >= self.source.len or !isIdentContinue(self.source[next_index]);
    return prev_ok and next_ok;
}

pub fn isIdentStart(ch: u8) bool {
    return std.ascii.isAlphabetic(ch) or ch == '_' or ch == '$';
}

pub fn isIdentContinue(ch: u8) bool {
    return isIdentStart(ch) or std.ascii.isDigit(ch);
}

test "scanner reads identifiers and strings" {
    var scanner = Scanner.init("import { foo as bar } from \"x\";");

    const t1 = scanner.nextToken();
    try std.testing.expectEqual(Token.Type.keyword, t1.type);

    _ = scanner.nextToken();
    const t3 = scanner.nextToken();
    try std.testing.expectEqual(Token.Type.identifier, t3.type);

    while (true) {
        const token = scanner.nextToken();
        if (token.type == .string) {
            try std.testing.expectEqualStrings("\"x\"", token.value.string);
            break;
        }
    }
}
