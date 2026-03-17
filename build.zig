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

    // Test executable for the library module
    const lib_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    lib_tests.addModule("solidity_zig_decompiler", mod);

    // Test executable for evm.signatures
    const signatures_test = b.addTest(.{
        .root_source_file = b.path("src/evm/signatures_test.zig"),
        .target = target,
    });

    // Test executable for evm.parser
    const parser_test = b.addTest(.{
        .root_source_file = b.path("src/evm/parser_test.zig"),
        .target = target,
    });

    // Run all tests
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&b.addRunArtifact(lib_tests).step);
    test_step.dependOn(&b.addRunArtifact(signatures_test).step);
    test_step.dependOn(&b.addRunArtifact(parser_test).step);

    // Exe tests
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);
}
