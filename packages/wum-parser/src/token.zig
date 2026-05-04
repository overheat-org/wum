pub const Type = enum {
    eof,
    identifier,
    keyword,
    string,
    number,
    at,
    comma,
    dot,
    colon,
    semicolon,
    l_paren,
    r_paren,
    l_brace,
    r_brace,
    l_bracket,
    r_bracket,
    equal,
};

pub const Value = union(enum) {
    none,
    string: []const u8,
};

const Token = @This();

type: Type,
value: Value = .none,
start: usize,
end: usize,

pub fn init(token_type: Type, start: usize, end: usize) Token {
    return .{
        .type = token_type,
        .start = start,
        .end = end,
    };
}

pub fn initString(token_type: Type, value: []const u8, start: usize, end: usize) Token {
    return .{
        .type = token_type,
        .value = .{ .string = value },
        .start = start,
        .end = end,
    };
}
