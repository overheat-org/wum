const Scanner = @import("./scanner.zig");
const Token = @import("./token.zig");
const stmt = @import("./parser/parse-stmt.zig");

const Parser = @This();

scanner: Scanner,

pub fn parse(self: Parser) !void {
    stmt.parse(self.scanner);
}
