const std = @import("std");
const builtin = @import("builtin");
const Compiler = @import("./compiler.zig").Compiler;
const Graph = @import("./graph.zig");
const compiler_mod = @import("./compiler.zig");

const allocator = if (builtin.cpu.arch == .wasm32) std.heap.wasm_allocator else std.heap.page_allocator;

const InputFile = struct {
    path: []const u8,
    source: []const u8,
    kind: []const u8,
};

const Input = struct {
    files: []InputFile,
};

const SnapshotEntry = struct {
    id: []const u8,
    content: []const u8,
};

const Output = struct {
    virtual_modules: []SnapshotEntry,
    files: []SnapshotEntry,
};

var last_result: []u8 = &.{};
var last_error: []u8 = &.{};

pub export fn wum_alloc(len: u32) u32 {
    const buf = allocator.alloc(u8, len) catch return 0;
    return @intCast(@intFromPtr(buf.ptr));
}

pub export fn wum_free(ptr: u32, len: u32) void {
    if (ptr == 0 or len == 0) return;
    const slice = @as([*]u8, @ptrFromInt(ptr))[0..len];
    allocator.free(slice);
}

pub export fn wum_prepare(ptr: u32, len: u32) u32 {
    clearLastBuffers();

    const input_json = @as([*]u8, @ptrFromInt(ptr))[0..len];
    const result = prepareInternal(input_json) catch |err| {
        setLastError(err) catch {};
        return 0;
    };

    last_result = result;
    return 1;
}

pub export fn wum_result_ptr() u32 {
    return if (last_result.len == 0) 0 else @intCast(@intFromPtr(last_result.ptr));
}

pub export fn wum_result_len() u32 {
    return @intCast(last_result.len);
}

pub export fn wum_error_ptr() u32 {
    return if (last_error.len == 0) 0 else @intCast(@intFromPtr(last_error.ptr));
}

pub export fn wum_error_len() u32 {
    return @intCast(last_error.len);
}

fn prepareInternal(input_json: []const u8) ![]u8 {
    var parsed = try std.json.parseFromSlice(Input, allocator, input_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var compiler = Compiler.init(allocator);
    var file_inputs: std.ArrayList(compiler_mod.FileInput) = .empty;

    for (parsed.value.files) |file| {
        try file_inputs.append(allocator, .{
            .path = try allocator.dupe(u8, file.path),
            .source = try allocator.dupe(u8, file.source),
            .kind = parseKind(file.kind),
        });
    }

    const prepared = try compiler.prepare(.{ .files = try file_inputs.toOwnedSlice(allocator) });
    const output = try buildOutput(prepared.graph, &compiler);

    var out: std.io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try std.json.Stringify.value(output, .{}, &out.writer);
    return try allocator.dupe(u8, out.written());
}

fn buildOutput(graph: *Graph, compiler: *Compiler) !Output {
    var virtual_modules: std.ArrayList(SnapshotEntry) = .empty;
    inline for ([_]compiler_mod.VirtualModule{ .index, .commands, .manifest }) |module_id| {
        const content = (try compiler.load(module_id.id())) orelse "";
        try virtual_modules.append(allocator, .{
            .id = try allocator.dupe(u8, module_id.id()),
            .content = try allocator.dupe(u8, content),
        });
    }

    var files: std.ArrayList(SnapshotEntry) = .empty;
    var file_it = graph.files.iterator();
    while (file_it.next()) |entry| {
        const content = graph.getFileContent(entry.key_ptr.*) orelse continue;
        try files.append(allocator, .{
            .id = try allocator.dupe(u8, entry.key_ptr.*),
            .content = try allocator.dupe(u8, content),
        });
    }

    return .{
        .virtual_modules = try virtual_modules.toOwnedSlice(allocator),
        .files = try files.toOwnedSlice(allocator),
    };
}

fn parseKind(kind: []const u8) Graph.FileKind {
    if (std.mem.eql(u8, kind, "command")) return .command;
    if (std.mem.eql(u8, kind, "service")) return .service;
    return .unknown;
}

fn clearLastBuffers() void {
    if (last_result.len > 0) allocator.free(last_result);
    if (last_error.len > 0) allocator.free(last_error);
    last_result = &.{};
    last_error = &.{};
}

fn setLastError(err: anyerror) !void {
    last_error = try std.fmt.allocPrint(allocator, "{s}", .{@errorName(err)});
}

test "wasm wrapper compiles snapshot json" {
    const input =
        \\{"files":[
        \\{"path":"/tmp/commands/ping.tsx","source":"export default <command name=\"ping\"></command>;","kind":"command"},
        \\{"path":"/tmp/services/repo.ts","source":"export class Repo {}","kind":"service"},
        \\{"path":"/tmp/services/app.ts","source":"import { service } from \"wum.js/macros\";\nimport { Repo } from \"./repo\";\n\n@service\nexport class App {\n  constructor(repo: Repo) {}\n}","kind":"service"}
        \\]}
    ;

    const output = try prepareInternal(input);
    try std.testing.expect(std.mem.indexOf(u8, output, "virtual:index") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "/tmp/services/app.ts") != null);
}
