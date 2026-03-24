const Scanner = @import("./scanner.zig");
const Token = @import("./token.zig");
const stmt = @import("./parser/parse-stmt.zig");

const Parser = @This();

scanner: Scanner,

pub fn init() Parser {}

pub fn parse(self: Parser) !void {
    stmt.parse(self.scanner);
}

pub fn parseRange(self: Parser) !void {
    _ = self;
}
