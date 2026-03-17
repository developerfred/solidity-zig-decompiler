// ============================================================================
// Tests for Function Signature Resolver
// ============================================================================

const std = @import("std");
const signatures = @import("evm/signatures.zig");

test "resolve ERC-20 transfer selector" {
    const allocator = std.testing.allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    // transfer(address,uint256) = 0xa9059cbb
    const selector = [4]u8{ 0xa9, 0x05, 0x9c, 0xbb };
    const result = try signatures.resolve(selector, &cache);

    try std.testing.expectEqualStrings("transfer(address,uint256)", result.signature);
    try std.testing.expectEqual(@as(f32, 1.0), result.confidence);
    try std.testing.expectEqual(signatures.SignatureSource.builtin, result.source);
}

test "resolve ERC-20 approve selector" {
    const allocator = std.testing.allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    // approve(address,uint256) = 0x095ea7b3
    const selector = [4]u8{ 0x09, 0x5e, 0xa7, 0xb3 };
    const result = try signatures.resolve(selector, &cache);

    try std.testing.expectEqualStrings("approve(address,uint256)", result.signature);
}

test "resolve ERC-20 balanceOf selector" {
    const allocator = std.testing.allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    // balanceOf(address) = 0x70a08231
    const selector = [4]u8{ 0x70, 0xa0, 0x82, 0x31 };
    const result = try signatures.resolve(selector, &cache);

    try std.testing.expectEqualStrings("balanceOf(address)", result.signature);
}

test "resolve Aave flashLoan selector" {
    const allocator = std.testing.allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    // flashLoan(address,address,uint256,bytes) = 0x5cdea6c5
    const selector = [4]u8{ 0x5c, 0xde, 0xa6, 0xc5 };
    const result = try signatures.resolve(selector, &cache);

    try std.testing.expectEqualStrings("flashLoan(address,address,uint256,bytes)", result.signature);
}

test "resolve Uniswap V3 exactInputSingle selector" {
    const allocator = std.testing.allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    // exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160)) = 0x414bf389
    const selector = [4]u8{ 0x41, 0x4b, 0xf3, 0x89 };
    const result = try signatures.resolve(selector, &cache);

    try std.testing.expectEqualStrings("exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))", result.signature);
}

test "resolve unknown selector returns unknown" {
    const allocator = std.testing.allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    // Random unknown selector
    const selector = [4]u8{ 0x12, 0x34, 0x56, 0x78 };
    const result = try signatures.resolve(selector, &cache);

    try std.testing.expectEqualStrings("unknown()", result.signature);
    try std.testing.expectEqual(@as(f32, 0.0), result.confidence);
}

test "cache returns same result" {
    const allocator = std.testing.allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    const selector = [4]u8{ 0xa9, 0x05, 0x9c, 0xbb };

    const result1 = try signatures.resolve(selector, &cache);
    const result2 = try signatures.resolve(selector, &cache);

    try std.testing.expectEqualStrings(result1.signature, result2.signature);
}

test "hexToSelector parses valid hex" {
    const selector = signatures.hexToSelector("0xa9059cbb");
    try std.testing.expect(selector != null);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xa9, 0x05, 0x9c, 0xbb }, &selector.?);
}

test "hexToSelector rejects invalid hex" {
    try std.testing.expectNull(signatures.hexToSelector("0x12345")); // too short
    try std.testing.expectNull(signatures.hexToSelector("12345678")); // missing 0x
    try std.testing.expectNull(signatures.hexToSelector("0xgghhiijj")); // invalid chars
}

test "resolve Compound V3 supply selector" {
    const allocator = std.testing.allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    // supply(address,uint256) = 0xf2b90f97
    const selector = [4]u8{ 0xf2, 0xb9, 0x0f, 0x97 };
    const result = try signatures.resolve(selector, &cache);

    try std.testing.expectEqualStrings("supply(address,uint256)", result.signature);
}

test "resolve Gnosis Safe execTransaction selector" {
    const allocator = std.testing.allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    // execTransaction = 0x6101e604
    const selector = [4]u8{ 0x61, 0x01, 0xe6, 0x04 };
    const result = try signatures.resolve(selector, &cache);

    try std.testing.expectEqualStrings("execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)", result.signature);
}

test "resolve ERC-4337 validateUserOp selector" {
    const allocator = std.testing.allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    // validateUserOp = 0x2f63c8a9
    const selector = [4]u8{ 0x2f, 0x63, 0xc8, 0xa9 };
    const result = try signatures.resolve(selector, &cache);

    try std.testing.expectEqualStrings("validateUserOp((address,uint256,bytes,bytes32),(bytes32,uint256))", result.signature);
}

test "resolve Diamond diamondCut selector" {
    const allocator = std.testing.allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    // diamondCut = 0x1f931c1c
    const selector = [4]u8{ 0x1f, 0x93, 0x1c, 0x1c };
    const result = try signatures.resolve(selector, &cache);

    try std.testing.expectEqualStrings("diamondCut((address,uint8,bytes4[])[],address,bytes)", result.signature);
}

test "resolve Lido submit selector" {
    const allocator = std.testing.allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    // submit(address) = 0x3ca7b03d
    const selector = [4]u8{ 0x3c, 0xa7, 0xb0, 0x3d };
    const result = try signatures.resolve(selector, &cache);

    try std.testing.expectEqualStrings("submit(address)", result.signature);
}
