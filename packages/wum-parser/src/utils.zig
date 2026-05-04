const std = @import("std");

pub const Path = struct {
    pub fn basename(path: []const u8) []const u8 {
        return std.fs.path.basename(path);
    }

    pub fn dir(path: []const u8) []const u8 {
        return std.fs.path.dirname(path) orelse ".";
    }

    pub fn resolve(allocator: std.mem.Allocator, base: []const u8, part: []const u8) ![]const u8 {
        return std.fs.path.resolve(allocator, &.{ base, part });
    }

    pub fn join(allocator: std.mem.Allocator, parts: []const []const u8) ![]const u8 {
        return std.fs.path.join(allocator, parts);
    }

    pub fn extname(path: []const u8) []const u8 {
        return std.fs.path.extension(path);
    }

    pub fn stem(path: []const u8) []const u8 {
        const base = basename(path);
        const ext = extname(base);
        if (ext.len == 0) return base;
        return base[0 .. base.len - ext.len];
    }
};
