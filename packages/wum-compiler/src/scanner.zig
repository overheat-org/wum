const std = @import("std");
const Token = @import("./token.zig");
const Scanner = @This();
const Keywords = std.StaticStringMap(Type).initComptime(.{
    .{ "break", .Keyword },
    .{ "case", .Keyword },
    .{ "catch", .Keyword },
    .{ "class", .Keyword },
    .{ "const", .Keyword },
    .{ "continue", .Keyword },
    .{ "debugger", .Keyword },
    .{ "default", .Keyword },
    .{ "delete", .Keyword },
    .{ "do", .Keyword },
    .{ "else", .Keyword },
    .{ "export", .Keyword },
    .{ "extends", .Keyword },
    .{ "finally", .Keyword },
    .{ "for", .Keyword },
    .{ "function", .Keyword },
    .{ "if", .Keyword },
    .{ "import", .Keyword },
    .{ "in", .Keyword },
    .{ "instanceof", .Keyword },
    .{ "new", .Keyword },
    .{ "return", .Keyword },
    .{ "super", .Keyword },
    .{ "switch", .Keyword },
    .{ "this", .Keyword },
    .{ "throw", .Keyword },
    .{ "try", .Keyword },
    .{ "typeof", .Keyword },
    .{ "var", .Keyword },
    .{ "void", .Keyword },
    .{ "while", .Keyword },
    .{ "with", .Keyword },
    .{ "yield", .Keyword },
    .{ "enum", .Keyword },
    .{ "await", .Keyword },
    .{ "implements", .Keyword },
    .{ "interface", .Keyword },
    .{ "let", .Keyword },
    .{ "package", .Keyword },
    .{ "private", .Keyword },
    .{ "protected", .Keyword },
    .{ "public", .Keyword },
    .{ "static", .Keyword },
});

source: []const u8,
current: Token = Token.OutOfRange,
offset: usize = 0,

fn scan(self: Scanner) []Token {
	switch (self.source[self.offset]) {
		' ', '\r', '\t' => self.advance(),
		'a'...'z', 'A'...'Z' => {
			makeWord();
			
			// Token{
			// 	.type = 
			// }
		},
		'_' => {
			const w = makeWord();

			self.advance();

			return Token{
				.type = .Identifier,
				.value = w,
			}
		},
		'1'...'9' => {},
		'[' => {}
	}
}

pub fn advance(self: *Scanner) void {
    self.offset += 1;
	self.scan();
}

pub fn expect(self: *Scanner, comptime tokenType: Token.Type) !void {
	if(self.current != tokenType) {
		return error.SyntaxError;
	}
}

pub fn expectAndAdvance(self: *Scanner, comptime tokenType: Token.Type) !void {
	try self.expect(tokenType);

	self.offset += 1;
}

pub fn advanceUntil(self: *Scanner, comptime tokenType: Token.Type) !void {
	while(
		self.current.type != tokenType and
		self.current.type != Token.Type.OutOfRange
	) {
		self.advance();
	}

	if(self.current.type != Token.Type.OutOfRange) return error.SyntaxError;
	return self.current;
}