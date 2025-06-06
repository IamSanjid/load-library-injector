const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const win = b.dependency("zigwin32", .{});

    const injector = b.addExecutable(.{
        .name = "injector",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(.{ .os_tag = .windows }),
        .optimize = optimize,
    });

    injector.root_module.addImport("zigwin32", win.module("win32"));
    b.installArtifact(injector);
}
