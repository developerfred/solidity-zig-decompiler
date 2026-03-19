// ============================================================================
// Tests for Vyper Bytecode Decompilation
// ============================================================================

const std = @import("std");
const vyper = @import("vyper/mod.zig");

test "detect Vyper version string" {
    const test_strings = [_]struct { offset: usize, value: []const u8 }{
        .{ .offset = 100, .value = "@version 0.3.10" },
    };

    const version = vyper.detectVersion(&test_strings);
    try std.testing.expect(version != null);
    try std.testing.expectEqual(@as(u8, 0), version.?.major);
    try std.testing.expectEqual(@as(u8, 3), version.?.minor);
    try std.testing.expectEqual(@as(u8, 10), version.?.patch);
}

test "detect Vyper version with caret" {
    const test_strings = [_]struct { offset: usize, value: []const u8 }{
        .{ .offset = 100, .value = "^0.3.9" },
    };

    const version = vyper.detectVersion(&test_strings);
    try std.testing.expect(version != null);
    try std.testing.expectEqual(@as(u8, 0), version.?.major);
    try std.testing.expectEqual(@as(u8, 3), version.?.minor);
    try std.testing.expectEqual(@as(u8, 9), version.?.patch);
}

test "resolve Vyper sqrt signature" {
    const selector = [_]u8{ 0x2a, 0x0c, 0x8d, 0x70 };
    const sig = vyper.resolveVyperSignature(selector);

    try std.testing.expect(sig != null);
    try std.testing.expectEqualStrings("sqrt(uint256) -> uint256", sig.?);
}

test "resolve Vyper transfer signature" {
    // Same as Solidity but we should detect it as Vyper context
    const selector = [_]u8{ 0xa9, 0x05, 0x9c, 0xbb };
    const sig = vyper.resolveVyperSignature(selector);

    // Vyper version
    try std.testing.expect(sig != null);
}

test "resolve Vyper chainid signature" {
    const selector = [_]u8{ 0x43, 0x71, 0x9c, 0x1c };
    const sig = vyper.resolveVyperSignature(selector);

    try std.testing.expect(sig != null);
    try std.testing.expectEqualStrings("chainid() -> uint256", sig.?);
}

test "detect language from version string" {
    const test_strings = [_]struct { offset: usize, value: []const u8 }{
        .{ .offset = 50, .value = "@version ^0.3.0" },
    };

    // Empty bytecode, but version string should trigger Vyper detection
    const bytecode = [_]u8{};
    const language = vyper.detectLanguage(&bytecode, &test_strings);

    try std.testing.expect(language == .vyper);
}

test "detect language from vyper keyword" {
    const test_strings = [_]struct { offset: usize, value: []const u8 }{
        .{ .offset = 50, .value = "Compiled with Vyper 0.3.10" },
    };

    const bytecode = [_]u8{};
    const language = vyper.detectLanguage(&bytecode, &test_strings);

    try std.testing.expect(language == .vyper);
}

test "unknown language without vyper markers" {
    const test_strings = [_]struct { offset: usize, value: []const u8 }{};

    const bytecode = [_]u8{ 0x60, 0x01, 0x60, 0x02, 0x01 }; // Simple PUSH1, PUSH1, ADD
    const language = vyper.detectLanguage(&bytecode, &test_strings);

    try std.testing.expect(language == .unknown);
}

test "vyper pattern detection with PUSH0" {
    // Vyper 0.3+ uses PUSH0 extensively
    var bytecode = [_]u8{0} ** 100;
    // Add multiple PUSH0 opcodes (0x5f)
    bytecode[0] = 0x5f;
    bytecode[1] = 0x5f;
    bytecode[2] = 0x5f;
    bytecode[3] = 0x5f;
    bytecode[4] = 0x5f;
    bytecode[5] = 0x5f;

    const test_strings = [_]struct { offset: usize, value: []const u8 }{};
    const language = vyper.detectLanguage(&bytecode, &test_strings);

    try std.testing.expect(language == .vyper);
}

test "vyper ERC20 template detection" {
    // Simulate bytecode with ERC20 signatures
    var bytecode = [_]u8{0} ** 200;

    // Insert some selectors that match ERC20
    // These are simplified - real bytecode would have more complex patterns
    const sig1 = "a9059cbb"; // transfer
    const sig2 = "095ea7b3"; // approve
    const sig3 = "70a08231"; // balanceOf
    const sig4 = "18160ddd"; // totalSupply

    // Copy signatures into bytecode (as hex representation would appear)
    @memcpy(bytecode[0..4], sig1[0..4].*);
    @memcpy(bytecode[10..14], sig2[0..4].*);
    @memcpy(bytecode[20..24], sig3[0..4].*);
    @memcpy(bytecode[30..34], sig4[0..4].*);

    const template = vyper.detectVyperTemplate(&bytecode);
    try std.testing.expect(template != null);
    try std.testing.expectEqualStrings("ERC20", template.?);
}

test "vyper Ownable template detection" {
    var bytecode = [_]u8{0} ** 100;

    // Insert owner signature
    const sig = "8da5cb5b"; // owner
    @memcpy(bytecode[0..4], sig[0..4].*);

    const template = vyper.detectVyperTemplate(&bytecode);
    try std.testing.expect(template != null);
    try std.testing.expectEqualStrings("Ownable", template.?);
}
