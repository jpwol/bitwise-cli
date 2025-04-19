const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const windows = b.option(bool, "windows", "Target Microsoft Windows") orelse false;

    const exe = b.addExecutable(.{
        .name = "bitline",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(.{
            .os_tag = if (windows) .windows else null,
        }),
        .optimize = optimize,
    });

    b.resolveInstallPrefix(".", .{ .exe_dir = "./bin" });
    b.installArtifact(exe);
}
