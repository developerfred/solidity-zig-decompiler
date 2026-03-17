// Example 4: DeFi Protocol Detection
// Run: zig run examples/04_defi_detection.zig

const std = @import("std");
const signatures = @import("src/evm/signatures.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();

    // Common DeFi protocol function selectors
    const defi_signatures = [_]struct { selector: [4]u8, protocol: []const u8, function: []const u8 }{
        // Aave
        .{ .selector = .{ 0x5c, 0xde, 0xa6, 0xc5 }, .protocol = "Aave V2", .function = "flashLoan" },
        .{ .selector = .{ 0x0d, 0x4f, 0xd0, 0xcb }, .protocol = "Aave V3", .function = "flash" },

        // Uniswap V2
        .{ .selector = .{ 0x7f, 0xf3, 0x6a, 0xb5 }, .protocol = "Uniswap V2", .function = "swapExactETHForTokens" },
        .{ .selector = .{ 0x38, 0xed, 0x17, 0x39 }, .protocol = "Uniswap V2", .function = "swapExactTokensForTokens" },

        // Uniswap V3
        .{ .selector = .{ 0x41, 0x4b, 0xf3, 0x89 }, .protocol = "Uniswap V3", .function = "exactInputSingle" },
        .{ .selector = .{ 0xb0, 0x43, 0x11, 0x82 }, .protocol = "Uniswap V3", .function = "exactInput" },

        // Compound
        .{ .selector = .{ 0xa0, 0x71, 0x2d, 0x68 }, .protocol = "Compound V2", .function = "mint" },
        .{ .selector = .{ 0x0e, 0x75, 0x27, 0x02 }, .protocol = "Compound V2", .function = "redeem" },

        // Curve
        .{ .selector = .{ 0x45, 0x15, 0xce, 0xf3 }, .protocol = "Curve", .function = "add_liquidity" },
        .{ .selector = .{ 0xa4, 0x1f, 0x6d, 0x44 }, .protocol = "Curve", .function = "exchange" },

        // Lido
        .{ .selector = .{ 0x3c, 0xa7, 0xb0, 0x3d }, .protocol = "Lido", .function = "submit" },

        // Gnosis Safe
        .{ .selector = .{ 0x61, 0x01, 0xe6, 0x04 }, .protocol = "Gnosis Safe", .function = "execTransaction" },

        // ERC-4337 Account Abstraction
        .{ .selector = .{ 0x2f, 0x63, 0xc8, 0xa9 }, .protocol = "ERC-4337", .function = "validateUserOp" },
        .{ .selector = .{ 0x64, 0xc9, 0xac, 0xad }, .protocol = "ERC-4337", .function = "execute" },

        // Diamond Standard
        .{ .selector = .{ 0x1f, 0x93, 0x1c, 0x1c }, .protocol = "Diamond", .function = "diamondCut" },
    };

    std.debug.print("DeFi Protocol Function Detection\n", .{});
    std.debug.print("=================================\n\n", .{});

    for (defi_signatures) |entry| {
        const result = try signatures.resolve(entry.selector, &cache);

        std.debug.print("[{s}] {s}.{s}\n", .{ if (std.mem.eql(u8, result.signature, "unknown()")) "UNKNOWN" else "DETECTED", entry.protocol, entry.function });

        if (!std.mem.eql(u8, result.signature, "unknown()")) {
            std.debug.print("  Signature: {s}\n", .{result.signature});
            std.debug.print("  Source: {s}\n", .{@tagName(result.source)});
        }
        std.debug.print("\n", .{});
    }
}
