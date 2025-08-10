const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const cham = b.dependency("chameleon", .{});
    exe_mod.addImport("chameleon", cham.module("chameleon"));

    const exe = b.addExecutable(.{
        .name = "wordle_term",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);
}
