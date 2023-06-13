const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const win = b.dependency("zigwin32", .{});

    const injector = b.addExecutable(.{
        .name = "injector",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = .{ .os_tag = .windows },
        .optimize = optimize,
    });

    injector.addModule("zigwin32", win.module("zigwin32"));
    b.installArtifact(injector);
}
