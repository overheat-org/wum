const std = @import("std");

pub const Type = enum {
    OutOfRange,
    Identifier,
    Keyword,
    Number,
    String,
    Comma,
    Dot,
    Colon,
    Semicolon,
    LParen,
    RParen,
    LBrace,
    RBrace,
    LBracket,
    RBracket,
    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    Equal,
    Bang,
    Less,
    Greater,
    Ampersand,
    Pipe,
    Caret,
    Tilde,
    Question,
    Arrow,
    Ellipsis,
    EOF,
};

const Number = union {
    i8: i8,
};

const Value = union {
    number: Number,
    string: []const u8,
    null: bool,
};

const Token = @This();

type: Type,
value: Value,

pub const OutOfRange = Token{ .type = .OutOfRange, .value = .null };
