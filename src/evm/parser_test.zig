// ============================================================================
// Tests for EVM Bytecode Parser
// ============================================================================

const std = @import("std");
const parser = @import("evm/parser.zig");
const opcodes = @import("evm/opcodes.zig");

test "parse simple bytecode with PUSH and ADD" {
    const allocator = std.testing.allocator;
    
    // PUSH1 0x01, PUSH1 0x02, ADD
    // 60 01 60 02 01
    const bytecode = [_]u8{ 0x60, 0x01, 0x60, 0x02, 0x01 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 3);
    try std.testing.expectEqualStrings("PUSH1", result.instructions[0].name);
    try std.testing.expectEqualStrings("PUSH1", result.instructions[1].name);
    try std.testing.expectEqualStrings("ADD", result.instructions[2].name);
}

test "parse bytecode extracts push data" {
    const allocator = std.testing.allocator;
    
    // PUSH1 0x42
    // 60 42
    const bytecode = [_]u8{ 0x60, 0x42 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("PUSH1", result.instructions[0].name);
    try std.testing.expect(result.instructions[0].push_data != null);
    if (result.instructions[0].push_data) |data| {
        try std.testing.expectEqual(@as(u8, 0x42), data[0]);
    }
}

test "parse bytecode with PUSH32" {
    const allocator = std.testing.allocator;
    
    // PUSH32 with 32 bytes of data
    var bytecode = [_]u8{ 0x7f }; // PUSH32
    // Add 32 bytes of push data
    for (0..32) |i| {
        bytecode[i + 1] = @truncate(i);
    }
    
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("PUSH32", result.instructions[0].name);
    try std.testing.expect(result.instructions[0].push_data != null);
    if (result.instructions[0].push_data) |data| {
        try std.testing.expectEqual(@as(usize, 32), data.len);
    }
}

test "parse STOP instruction" {
    const allocator = std.testing.allocator;
    
    // STOP
    const bytecode = [_]u8{ 0x00 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("STOP", result.instructions[0].name);
}

test "parse RETURN instruction" {
    const allocator = std.testing.allocator;
    
    // RETURN
    const bytecode = [_]u8{ 0xf3 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("RETURN", result.instructions[0].name);
}

test "parse REVERT instruction" {
    const allocator = std.testing.allocator;
    
    // REVERT
    const bytecode = [_]u8{ 0xfd };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("REVERT", result.instructions[0].name);
}

test "parse DUP1 instruction" {
    const allocator = std.testing.allocator;
    
    // DUP1
    const bytecode = [_]u8{ 0x80 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("DUP1", result.instructions[0].name);
}

test "parse SWAP1 instruction" {
    const allocator = std.testing.allocator;
    
    // SWAP1
    const bytecode = [_]u8{ 0x90 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("SWAP1", result.instructions[0].name);
}

test "parse LOG0 instruction" {
    const allocator = std.testing.allocator;
    
    // LOG0
    const bytecode = [_]u8{ 0xa0 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("LOG0", result.instructions[0].name);
}

test "parse CREATE instruction" {
    const allocator = std.testing.allocator;
    
    // CREATE
    const bytecode = [_]u8{ 0xf0 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("CREATE", result.instructions[0].name);
}

test "parse CALL instruction" {
    const allocator = std.testing.allocator;
    
    // CALL
    const bytecode = [_]u8{ 0xf1 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("CALL", result.instructions[0].name);
}

test "parse STATICCALL instruction" {
    const allocator = std.testing.allocator;
    
    // STATICCALL
    const bytecode = [_]u8{ 0xfa };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("STATICCALL", result.instructions[0].name);
}

test "parse DELEGATECALL instruction" {
    const allocator = std.testing.allocator;
    
    // DELEGATECALL
    const bytecode = [_]u8{ 0xf4 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("DELEGATECALL", result.instructions[0].name);
}

test "parse empty bytecode" {
    const allocator = std.testing.allocator;
    
    // Empty bytecode
    const bytecode = [_]u8{};
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expectEqual(@as(usize, 0), result.instructions.len);
}

test "getInstruction returns correct instruction" {
    const allocator = std.testing.allocator;
    
    // PUSH1 0x01, PUSH1 0x02, ADD
    const bytecode = [_]u8{ 0x60, 0x01, 0x60, 0x02, 0x01 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    const instr = parser.getInstruction(&result, 0);
    try std.testing.expect(instr != null);
    try std.testing.expectEqualStrings("PUSH1", instr.?.name);
}

test "getInstruction returns null for invalid PC" {
    const allocator = std.testing.allocator;
    
    const bytecode = [_]u8{ 0x00 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    const instr = parser.getInstruction(&result, 999);
    try std.testing.expect(instr == null);
}

test "parse SLOAD instruction" {
    const allocator = std.testing.allocator;
    
    // SLOAD
    const bytecode = [_]u8{ 0x54 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("SLOAD", result.instructions[0].name);
}

test "parse SSTORE instruction" {
    const allocator = std.testing.allocator;
    
    // SSTORE
    const bytecode = [_]u8{ 0x55 };
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    try std.testing.expect(result.instructions.len >= 1);
    try std.testing.expectEqualStrings("SSTORE", result.instructions[0].name);
}
