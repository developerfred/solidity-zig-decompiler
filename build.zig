const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main library module
    const mod = b.addModule("solidity_zig_decompiler", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // Main executable
    const exe = b.addExecutable(.{
        .name = "solidity_zig_decompiler",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "solidity_zig_decompiler", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    // Run step
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Run all tests using the test step
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&b.addRunArtifact(exe).step);
}
