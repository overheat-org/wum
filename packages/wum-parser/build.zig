const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("wum-parser", .{
        .root_source_file = b.path("src/main.zig"),
    });
}
