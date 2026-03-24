const std = @import("std");
const Node = @import("./node.zig");
const utils = @import("../utils.zig");

const Path = utils.Path;

const Graph = @This();

pub const File = struct {
    name: []const u8,
    path: []const u8,
    modules: [][]const u8,

    pub inline fn hasImported(self: File, moduleName: []const u8) bool {
        for (self.modules) |m| {
            if (std.mem.eql(u8, m, moduleName)) return true;
        }
        return false;
    }
};

pub const Symbol = struct {
    file: *File,
    node: *Node,
};

pub const Service = struct {
    symbol: *Symbol,
    dependencies: []*Symbol,
};

pub const Event = struct {
    symbol: *Symbol,
    kind: []const u8,
    once: bool,
};

pub const Route = struct {
    pub const Method = enum {
        Get,
        Post,
        Put,
        Patch,
        Delete,
        Options,
        Head,
        Connect,
        Trace,
    };

    endpoint: []const u8,
    method: Method,
    symbol: *Symbol,
    protocol: []const u8,
};

pub const Injectable = struct { symbol: *Symbol, dependencies: []*Symbol };

pub fn symbolFrom(self: *Graph, node: *Node) *Symbol {
    const dir_path = Path.dir(node.file.path);
    const full_path = Path.resolve(
        dir_path,
    );
    self.getFile();

    return Symbol{};
}

pub fn getExportsFrom(self: *Graph, file_path: []const u8) []Graph.Symbol {}

pub fn addInjectable(self: *Graph, injectable: Injectable) void {}

pub fn addService(self: *Graph, service: Service) void {}

pub fn addEvent(self: *Graph, event: Event) void {}

pub fn addRoute(self: *Graph, route: Route) void {}
