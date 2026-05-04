const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    const root_module = b.createModule(.{
        .root_source_file = b.path("src/wasm.zig"),
        .target = target,
        .optimize = optimize,
    });

    const dep = b.dependency("wum-parser", .{});

    const wasm = b.addExecutable(.{
        .name = "compiler",
        .root_module = root_module,
    });
    wasm.entry = .disabled;
    wasm.rdynamic = true;
    wasm.export_table = true;
    wasm.import_memory = false;
    wasm.root_module.addImport("wum-parser", dep.module("wum-parser"));

    const install = b.addInstallArtifact(wasm, .{
        .dest_dir = .{ .override = .{ .custom = "lib" } },
    });

    const wasm_step = b.step("wasm", "Build the compiler WebAssembly binary");
    wasm_step.dependOn(&install.step);
}
