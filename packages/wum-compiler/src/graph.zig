const std = @import("std");
const Node = @import("./node.zig");
const utils = @import("./utils.zig");
const errors = @import("./errors.zig");

const Path = utils.Path;
const Graph = @This();

pub const File = struct {
    kind: FileKind,
    name: []const u8,
    path: []const u8,
    source: []const u8,
    transformed_source: ?[]const u8 = null,
    line_starts: []usize,
    modules: [][]const u8,
    imports: []*Node,
    exports: []*Symbol,
    declarations: []*Symbol,

    pub fn hasImported(self: File, module_name: []const u8) bool {
        for (self.modules) |mod| {
            if (std.mem.eql(u8, mod, module_name)) return true;
        }
        return false;
    }
};

pub const FileKind = enum {
    service,
    command,
    unknown,
};

pub const Symbol = struct {
    id: []const u8,
    file: *File,
    node: *Node,
    parent: ?*Symbol = null,
};

pub const Service = struct {
    symbol: *Symbol,
    dependencies: []*Symbol,
};

pub const Event = struct {
    symbol: *Symbol,
    type: []const u8,
    once: bool,
};

pub const Route = struct {
    pub const Method = enum {
        get,
        post,
        put,
        patch,
        delete,
        options,
        head,
        connect,
        trace,
    };

    endpoint: []const u8,
    method: Method,
    symbol: *Symbol,
    protocol: []const u8,
};

pub const Injectable = struct {
    symbol: *Symbol,
    dependencies: []*Symbol,
};

pub const Command = struct {
    symbol: *Symbol,
};

pub const Module = struct {
    name: []const u8,
    managers: []*Symbol,
};

pub const EmittedFile = struct {
    path: []const u8,
    content: []const u8,
};

allocator: std.mem.Allocator,
files: std.StringHashMap(*File),
symbols_by_key: std.StringHashMap(*Symbol),
services: std.ArrayList(*const Service),
injectables: std.ArrayList(*const Injectable),
events: std.ArrayList(*const Event),
routes: std.ArrayList(*const Route),
commands: std.ArrayList(*const Command),
modules: std.ArrayList(*const Module),
emitted_files: std.StringHashMap(*const EmittedFile),

pub fn init(allocator: std.mem.Allocator) Graph {
    return .{
        .allocator = allocator,
        .files = std.StringHashMap(*File).init(allocator),
        .symbols_by_key = std.StringHashMap(*Symbol).init(allocator),
        .services = .empty,
        .injectables = .empty,
        .events = .empty,
        .routes = .empty,
        .commands = .empty,
        .modules = .empty,
        .emitted_files = std.StringHashMap(*const EmittedFile).init(allocator),
    };
}

pub fn addParsedFile(self: *Graph, file: *File) !void {
    try self.files.put(file.path, file);

    for (file.declarations) |symbol| {
        try self.symbols_by_key.put(try self.makeSymbolKey(symbol.file.path, symbol.id), symbol);
    }

    for (file.exports) |symbol| {
        try self.symbols_by_key.put(try self.makeSymbolKey(symbol.file.path, symbol.id), symbol);
    }
}

fn makeSymbolKey(self: *Graph, file_path: []const u8, id: []const u8) ![]const u8 {
    return std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ file_path, id });
}

pub fn getFile(self: *Graph, file_path: []const u8) ?*File {
    return self.files.get(file_path);
}

pub fn getFileContent(self: *Graph, file_path: []const u8) ?[]const u8 {
    const file = self.files.get(file_path) orelse return null;
    return file.transformed_source orelse file.source;
}

pub fn getExportsFrom(self: *Graph, file_path: []const u8) []*Symbol {
    const file = self.files.get(file_path) orelse return &[_]*Symbol{};
    return file.exports;
}

pub fn getSymbolsByFile(self: *Graph, file_path: []const u8) []*Symbol {
    const file = self.files.get(file_path) orelse return &[_]*Symbol{};
    const total = file.declarations.len + file.exports.len;
    const symbols = self.allocator.alloc(*Symbol, total) catch @panic("alloc symbols by file");

    var index: usize = 0;
    for (file.declarations) |symbol| {
        symbols[index] = symbol;
        index += 1;
    }
    for (file.exports) |symbol| {
        symbols[index] = symbol;
        index += 1;
    }
    return symbols;
}

pub fn symbolFrom(self: *Graph, node: *Node) *Symbol {
    if (node.is(.Id)) {
        if (node.getParent()) |parent| return self.symbolFrom(parent);
    }

    if (node.is(.MemberExpr)) {
        const member = node.getProps(.MemberExpr);
        if (member.object.is(.Id)) {
            if (member.object.getParent()) |parent| {
                if (parent.is(.Import) and parent.getProps(.Import).kind == .namespace) {
                    if (self.resolveImportedSymbol(parent, member.property.getName())) |symbol| return symbol;
                }
            }
        }
    }

    const file = node.file orelse @panic("node without file");
    var id = node.getName();

    if (node.is(.Import)) {
        if (self.resolveImportedSymbol(node, null)) |symbol| return symbol;
        id = if (node.getProps(.Import).id) |import_id| import_id.getName() else node.getName();
    }

    const key = self.makeSymbolKey(file.path, id) catch @panic("alloc key");
    if (self.symbols_by_key.get(key)) |symbol| return symbol;

    const symbol = self.allocator.create(Symbol) catch @panic("alloc symbol");
    symbol.* = .{
        .id = id,
        .file = file,
        .node = node,
    };
    self.symbols_by_key.put(key, symbol) catch @panic("put symbol");
    return symbol;
}

pub fn addInjectable(self: *Graph, injectable: Injectable) void {
    const item = self.allocator.create(Injectable) catch @panic("alloc injectable");
    item.* = injectable;
    self.injectables.append(self.allocator, item) catch @panic("append injectable");
}

pub fn addService(self: *Graph, service: Service) void {
    const item = self.allocator.create(Service) catch @panic("alloc service");
    item.* = service;
    self.services.append(self.allocator, item) catch @panic("append service");
}

pub fn addEvent(self: *Graph, event: Event) void {
    const item = self.allocator.create(Event) catch @panic("alloc event");
    item.* = event;
    self.events.append(self.allocator, item) catch @panic("append event");
}

pub fn addRoute(self: *Graph, route: Route) void {
    const item = self.allocator.create(Route) catch @panic("alloc route");
    item.* = route;
    self.routes.append(self.allocator, item) catch @panic("append route");
}

pub fn addCommand(self: *Graph, command: Command) void {
    const item = self.allocator.create(Command) catch @panic("alloc command");
    item.* = command;
    self.commands.append(self.allocator, item) catch @panic("append command");
}

pub fn addModule(self: *Graph, module_data: Module) void {
    const item = self.allocator.create(Module) catch @panic("alloc module");
    item.* = module_data;
    self.modules.append(self.allocator, item) catch @panic("append module");
}

pub fn addEmittedFile(self: *Graph, path: []const u8, content: []const u8) void {
    const item = self.allocator.create(EmittedFile) catch @panic("alloc emitted file");
    item.* = .{
        .path = path,
        .content = content,
    };
    self.emitted_files.put(path, item) catch @panic("put emitted file");
}

pub fn getEmittedFile(self: *Graph, path: []const u8) ?*const EmittedFile {
    return self.emitted_files.get(path);
}

fn resolveImportedSymbol(self: *Graph, import_node: *Node, namespace_property: ?[]const u8) ?*Symbol {
    const import_props = import_node.getProps(.Import);
    const imported_name = if (namespace_property) |property| property else if (import_props.id) |id| id.getName() else return null;
    const source_path = self.resolveImportPath(import_node.file.?, import_props.source.getName()) orelse return null;
    const symbols = self.getExportsFrom(source_path);

    for (symbols) |symbol| {
        if (std.mem.eql(u8, symbol.id, imported_name)) return symbol;
    }

    return null;
}

fn resolveImportPath(self: *Graph, file: *File, raw_source: []const u8) ?[]const u8 {
    if (raw_source.len == 0) return null;
    if (raw_source[0] != '.') return raw_source;

    const base_dir = Path.dir(file.path);
    const resolved = Path.resolve(std.heap.page_allocator, base_dir, raw_source) catch return null;

    if (std.mem.endsWith(u8, resolved, ".ts") or
        std.mem.endsWith(u8, resolved, ".tsx") or
        std.mem.endsWith(u8, resolved, ".js") or
        std.mem.endsWith(u8, resolved, ".jsx"))
    {
        if (self.files.get(resolved) != null) return resolved;
    }

    const candidates = [_][]const u8{ ".ts", ".tsx", ".js", ".jsx", "/index.ts", "/index.tsx", "/index.js", "/index.jsx" };
    for (candidates) |suffix| {
        const candidate = std.fmt.allocPrint(std.heap.page_allocator, "{s}{s}", .{ resolved, suffix }) catch continue;
        if (self.files.get(candidate) != null) return candidate;
    }

    return null;
}
