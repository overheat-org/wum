const std = @import("std");
const Scanner = @import("../scanner.zig");
const Token = @import("../token.zig");
const Node = @import("../node.zig");
const expr = @import("./parse-expr.zig");

pub fn parse(ctx: *Scanner) !void {
    ctx.advance();
    ctx.current;
}

fn parseKeyword(ctx: *Scanner) !void {
    const current = ctx.current.value.string;

    ctx.advance();

    const handlers = .{
        .function = parseFunction,
    };

    const handler = @field(handlers, current);

    return handler.*();
}

fn parseFunction(ctx: *Scanner) !Node {
    try ctx.expect(.Identifier);

    const id = ctx.current.value.string;

    try ctx.expectAndAdvance(.LParen);

    const params_offset = ctx.offset;
    try ctx.advanceUntil(.RParen);

    const params_offset_range = Node.Range{ params_offset, ctx.offset };

    ctx.advance();
    try ctx.expectAndAdvance(.LBrace);

    const body_offset = ctx.offset;
    try ctx.advanceUntil(.RBrace);

    const body_offset_range = Node.Range{ body_offset, ctx.offset };

    return Node.new(
        .FnStmt,
        .{
            .name = id,
            .ranges = .{
                .params = params_offset_range,
                .body = body_offset_range,
            },
        },
    );
}
