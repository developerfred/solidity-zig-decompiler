// ============================================================================
// Example: Fetch contract bytecode from Sourcify
// 
// This example demonstrates how to fetch contract bytecode by address
// using the Sourcify API.
// ============================================================================

const std = @import("std");
const sourcify = @import("sourcify/client.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Example: Fetch USDC contract bytecode on Ethereum
    const usdc_address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    
    std.debug.print("Fetching bytecode for {s}...\n", .{usdc_address});
    
    // Initialize client for Ethereum mainnet
    var client = sourcify.SourcifyClient.init(allocator, .ethereum);
    defer client.deinit();
    
    // Check if contract is verified
    const status = try client.checkVerification(usdc_address);
    std.debug.print("Verification status: {s}\n", .{@tagName(status)});
    
    // Fetch bytecode
    const metadata = try client.fetchBytecode(usdc_address);
    std.debug.print("\nContract: {s}\n", .{metadata.name orelse "Unknown"});
    std.debug.print("Chain ID: {d}\n", .{metadata.chain_id});
    std.debug.print("Bytecode length: {d} bytes\n", .{metadata.bytecode.len});
    std.debug.print("Runtime bytecode length: {d} bytes\n", .{metadata.runtime_bytecode.len});
    
    // Show first 100 chars of bytecode
    if (metadata.bytecode.len > 100) {
        std.debug.print("Bytecode (first 100 chars): {s}...\n", .{metadata.bytecode[0..100]});
    } else {
        std.debug.print("Bytecode: {s}\n", .{metadata.bytecode});
    }
    
    // Fetch multiple chains
    const chains = [_]sourcify.ChainId{ .ethereum, .polygon, .arbitrum_one };
    
    std.debug.print("\n--- Checking multiple chains ---\n", .{});
    
    for (chains) |chain| {
        var chain_client = sourcify.SourcifyClient.init(allocator, chain);
        defer chain_client.deinit();
        
        const chain_status = try chain_client.checkVerification(usdc_address);
        std.debug.print("{s}: {s}\n", .{ @tagName(chain), @tagName(chain_status) });
    }
}

// ============================================================================
// Supported Chains
// ============================================================================
//
// To check contracts on different chains, use these ChainId values:
//
// .ethereum         - Ethereum Mainnet
// .goerli           - Goerli Testnet (deprecated)
// .sepolia          - Sepolia Testnet
// .polygon          - Polygon
// .arbitrum_one     - Arbitrum One
// .arbitrum_sepolia - Arbitrum Sepolia
// .optimism         - Optimism
// .optimism_sepolia - Optimism Sepolia
// .base             - Base
// .base_sepolia     - Base Sepolia
// .avalanche        - Avalanche
// .bsc              - BNB Smart Chain
// .gnosis           - Gnosis Chain
//
// ============================================================================
