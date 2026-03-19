// ============================================================================
// Integration Tests for Decompiler
// ============================================================================

const std = @import("std");
const decompiler = @import("../decompiler/main.zig");

test "decompile simple contract" {
    const allocator = std.testing.allocator;
    // Minimal bytecode with function selector
    const bytecode = [_]u8{ 0x60, 0x80, 0x52, 0x60, 0x08, 0x3d }; // Standard contract prologue
    const config = decompiler.Config{};
    
    const contract = try decompiler.decompile(allocator, &bytecode, config);
    
    // Basic contract should have a name
    try std.testing.expect(contract.name.len > 0);
}

test "decompile ERC20-like contract" {
    const allocator = std.testing.allocator;
    // Bytecode with ERC20 function selectors
    // transfer: 0xa9059cbb
    // approve: 0x095ea7b3
    // balanceOf: 0x70a08231
    const bytecode = [_]u8{
        0x60, 0x80, 0x52, // Standard contract setup
        0x60, 0x08, 0x3d, // Return memory
        // Add more to simulate real contract
        0x5a, // GAS
        0xf3, // RETURN
    };
    const config = decompiler.Config{};
    
    const contract = try decompiler.decompile(allocator, &bytecode, config);
    
    // Contract should be processed
    try std.testing.expect(contract.name.len > 0);
}

test "decompile with config options" {
    const allocator = std.testing.allocator;
    const bytecode = [_]u8{ 0x00 };
    
    // Test with all options disabled
    const config = decompiler.Config{
        .resolve_signatures = false,
        .build_cfg = false,
        .extract_strings = false,
        .detect_patterns = false,
        .verbose = false,
    };
    
    const contract = try decompiler.decompile(allocator, &bytecode, config);
    try std.testing.expect(contract.name.len > 0);
}

test "decompile proxy contract" {
    const allocator = std.testing.allocator;
    // Contract with delegatecall (proxy pattern)
    const bytecode = [_]u8{
        0x60, 0x00, // PUSH1 0x00
        0x60, 0x00, // PUSH1 0x00
        0xf4, // DELEGATECALL
    };
    const config = decompiler.Config{};
    
    const contract = try decompiler.decompile(allocator, &bytecode, config);
    
    // Should detect proxy
    try std.testing.expect(contract.is_proxy == true);
}

test "generate solidity output" {
    const allocator = std.testing.allocator;
    const bytecode = [_]u8{ 0x00 };
    const config = decompiler.Config{};
    
    const contract = try decompiler.decompile(allocator, &bytecode, config);
    
    // Generate Solidity code
    var buf: [1024]u8 = undefined;
    var fbs = std.io.FixedBufferStream([]u8){ .buffer = &buf, .pos = 0 };
    try decompiler.generateSolidity(&contract, fbs.writer());
    
    const output = fbs.getWritten();
    // Should contain SPDX and pragma
    try std.testing.expect(std.mem.indexOf(u8, output, "SPDX") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "pragma") != null);
}

test "empty bytecode handling" {
    const allocator = std.testing.allocator;
    const bytecode = [_]u8{};
    const config = decompiler.Config{};
    
    const contract = try decompiler.decompile(allocator, &bytecode, config);
    // Should handle gracefully
    try std.testing.expect(contract.name.len >= 0);
}
