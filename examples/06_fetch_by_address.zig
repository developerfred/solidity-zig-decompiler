// ============================================================================
// Simple Sourcify Fetcher - No dependencies
// 
// Lightweight utility to fetch contract bytecode from Sourcify.
// Usage:
//   zig run examples/06_fetch_by_address.zig -- 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
// ============================================================================

const std = @import("std");

/// Chain ID mapping
const ChainId = enum(u64) {
    ethereum = 1,
    sepolia = 11155111,
    polygon = 137,
    arbitrum_one = 42161,
    optimism = 10,
    base = 8453,
    avalanche = 43114,
    bsc = 56,
    gnosis = 100,
};

const API_BASE = "https://api.sourcify.dev";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Get address from command line args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        std.debug.print("Usage: {s} <contract_address> [chain_id]\n", .{args[0]});
        std.debug.print("\nExamples:\n", .{});
        std.debug.print("  {s} 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48\n", .{args[0]});
        std.debug.print("  {s} 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 1\n", .{args[0]});
        std.debug.print("  {s} 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 137\n", .{args[0]});
        std.debug.print("\nChain IDs:\n", .{});
        std.debug.print("  1      - Ethereum\n", .{});
        std.debug.print("  137    - Polygon\n", .{});
        std.debug.print("  42161  - Arbitrum One\n", .{});
        std.debug.print("  10     - Optimism\n", .{});
        std.debug.print("  8453   - Base\n", .{});
        return;
    }
    
    const address = args[1];
    const chain_id: u64 = if (args.len > 2) std.fmt.parseInt(u64, args[2], 10) catch 1 else 1;
    
    std.debug.print("Fetching contract: {s}\n", .{address});
    std.debug.print("Chain ID: {d}\n\n", .{chain_id});
    
    // Fetch from Sourcify
    try fetchAndDisplay(allocator, address, chain_id);
}

fn fetchAndDisplay(allocator: std.mem.Allocator, address: []const u8, chain_id: u64) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();
    
    // Build URL
    const url_str = try std.fmt.allocPrint(allocator, "{s}/contracts/full/{d}/{s}", .{
        API_BASE, chain_id, address
    });
    defer allocator.free(url_str);
    
    const uri = try std.Uri.parse(url_str);
    
    var request = try client.request(.GET, uri, .{}, .{});
    defer request.deinit();
    
    try request.start();
    try request.wait();
    
    switch (request.response.status) {
        .ok => {
            const body = try request.reader().readAllAlloc(allocator, 1024 * 1024);
            defer allocator.free(body);
            
            try displayContractInfo(address, chain_id, body);
        },
        .not_found => {
            std.debug.print("Contract not found on chain {d}\n", .{chain_id});
            std.debug.print("Try checking on other chains or verify the address.\n", .{});
        },
        else => {
            std.debug.print("Error: HTTP {d}\n", .{@intFromEnum(request.response.status)});
        }
    }
}

fn displayContractInfo(address: []const u8, chain_id: u64, body: []const u8) !void {
    // Parse simplified JSON
    std.debug.print("=== Contract Information ===\n", .{});
    std.debug.print("Address: {s}\n", .{address});
    std.debug.print("Chain: {d}\n", .{chain_id});
    
    // Find contract name
    if (findJsonString(body, "name")) |name| {
        std.debug.print("Name: {s}\n", .{name});
    }
    
    // Find compiler version
    if (findJsonString(body, "compilerVersion")) |version| {
        std.debug.print("Compiler: {s}\n", .{version});
    }
    
    // Find bytecode
    if (findJsonString(body, "bytecode")) |bytecode| {
        std.debug.print("\nDeployment Bytecode:\n", .{});
        std.debug.print("  Length: {d} bytes\n", .{bytecode.len});
        if (bytecode.len > 64) {
            std.debug.print("  First 32 bytes: {s}...\n", .{bytecode[0..64]});
        }
    }
    
    // Find runtime bytecode
    if (findJsonString(body, "runtimeBytecode")) |runtime| {
        std.debug.print("\nRuntime Bytecode:\n", .{});
        std.debug.print("  Length: {d} bytes\n", .{runtime.len});
        if (runtime.len > 64) {
            std.debug.print("  First 32 bytes: {s}...\n", .{runtime[0..64]});
        }
    }
    
    // Find sources
    if (findJsonString(body, "sourceFiles")) |sources| {
        std.debug.print("\nSource Files: {s}\n", .{sources});
    }
    
    std.debug.print("\n========================\n", .{});
}

fn findJsonString(body: []const u8, key: []const u8) ?[]const u8 {
    const key_pattern = "\"" ++ key ++ "\":\"";
    const idx = std.mem.indexOf(u8, body, key_pattern) orelse return null;
    
    const start = idx + key_pattern.len;
    const end = std.mem.indexOfPos(u8, body, start, "\"") orelse return null;
    
    if (end > start) {
        return body[start..end];
    }
    return null;
}
