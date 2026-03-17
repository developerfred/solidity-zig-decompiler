// Example 2: Function Signature Resolution
// Run: zig run examples/02_resolve_signatures.zig

const std = @import("std");
const signatures = @import("evm/signatures.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();
    
    // Test selectors
    const test_cases = [_]struct { selector: [4]u8, expected: []const u8 }{
        .{ .selector = .{ 0xa9, 0x05, 0x9c, 0xbb }, .expected = "transfer(address,uint256)" },
        .{ .selector = .{ 0x09, 0x5e, 0xa7, 0xb3 }, .expected = "approve(address,uint256)" },
        .{ .selector = .{ 0x70, 0xa0, 0x82, 0x31 }, .expected = "balanceOf(address)" },
        .{ .selector = .{ 0x5c, 0xde, 0xa6, 0xc5 }, .expected = "flashLoan(address,address,uint256,bytes)" },
        .{ .selector = .{ 0x41, 0x4b, 0xf3, 0x89 }, .expected = "exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))" },
        .{ .selector = .{ 0x12, 0x34, 0x56, 0x78 }, .expected = "unknown()" },
    };
    
    std.debug.print("Function Signature Resolution Tests\n", .{});
    std.debug.print("===================================\n\n", .{});
    
    for (test_cases) |tc| {
        const result = try signatures.resolve(tc.selector, &cache);
        const match = std.mem.eql(u8, result.signature, tc.expected);
        
        std.debug.print("[{s}] Selector: 0x{x02x}{x02x}{x02x}{x02x}\n", .{
            if (match) "PASS" else "FAIL",
            tc.selector[0], tc.selector[1], tc.selector[2], tc.selector[3]
        });
        std.debug.print("  Expected: {s}\n", .{tc.expected});
        std.debug.print("  Got:      {s}\n\n", .{result.signature});
    }
}
