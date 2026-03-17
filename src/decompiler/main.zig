// Main Decompiler Module - Simplified for Zig 0.15

const std = @import("std");
const evm_parser = @import("../evm/parser.zig");
const evm_dispatcher = @import("../evm/dispatcher.zig");
const evm_strings = @import("../evm/strings.zig");
const evm_signatures = @import("../evm/signatures.zig");
const evm_cfg = @import("../evm/cfg.zig");

pub const DecompiledFunction = struct {
    name: []const u8,
    selector: [4]u8,
    signature: ?[]const u8,
};

pub const DecompiledContract = struct {
    name: []const u8,
    functions: []DecompiledFunction,
    embedded_strings: []evm_strings.EmbeddedString,
    is_proxy: bool,
    is_erc20: bool,
    is_erc721: bool,
    allocator: std.mem.Allocator,
};

pub const StorageVariable = struct {
    slot: usize,
    var_type: []const u8,
    name: []const u8,
};

pub const Config = struct {
    resolve_signatures: bool = true,
    build_cfg: bool = true,
    extract_strings: bool = true,
    detect_patterns: bool = true,
    verbose: bool = false,
};

pub fn decompile(allocator: std.mem.Allocator, bytecode: []const u8, config: Config) !DecompiledContract {
    var contract = DecompiledContract{
        .name = "Unknown",
        .functions = &.{},
        .embedded_strings = &.{},
        .is_proxy = false,
        .is_erc20 = false,
        .is_erc721 = false,
        .allocator = allocator,
    };
    
    const allocator_to_use = allocator;
    
    if (config.extract_strings) {
        const str = try evm_strings.extract(allocator_to_use, bytecode);
        contract.embedded_strings = str.strings;
    }
    
    if (config.resolve_signatures) {
        var dispatcher = try evm_dispatcher.analyzeDispatchers(allocator_to_use, bytecode);
        defer evm_dispatcher.deinit(&dispatcher);
        
        var func_list = std.ArrayListUnmanaged(DecompiledFunction){};
        
        var signature_cache = evm_signatures.SignatureCache.init(allocator_to_use);
        defer signature_cache.deinit();
        
        for (dispatcher.selectors) |sel| {
            const resolved = evm_signatures.resolve(sel.selector, &signature_cache) catch continue;
            try func_list.append(allocator_to_use, .{ .name = resolved.signature, .selector = sel.selector, .signature = resolved.signature });
        }
        
        contract.functions = try func_list.toOwnedSlice(allocator_to_use);
        
        // Detect patterns
        var erc20_count: usize = 0;
        for (dispatcher.selectors) |s| {
            const hex = evm_signatures.selectorToSlice(s.selector);
            if (std.mem.startsWith(u8, hex, "0xa9059cbb") or
                std.mem.startsWith(u8, hex, "0x095ea7b3") or
                std.mem.startsWith(u8, hex, "0x70a08231") or
                std.mem.startsWith(u8, hex, "0x18160ddd")) {
                erc20_count += 1;
            }
        }
        if (erc20_count >= 3) {
            contract.is_erc20 = true;
            contract.name = "ERC20";
        }
    }
    
    // Check for proxy
    for (bytecode) |byte| {
        if (byte == 0xf4) {
            contract.is_proxy = true;
            if (!contract.is_erc20) contract.name = "Proxy";
            break;
        }
    }
    
    return contract;
}

pub fn generateSolidity(contract: *const DecompiledContract, writer: anytype) !void {
    try writer.writeAll("// SPDX-License-Identifier: UNLICENSED\n\n");
    try writer.writeAll("pragma solidity ^0.8.0;\n\n");
    try writer.print("contract {s} {{\n\n", .{ contract.name });
    
    for (contract.functions) |func| {
        try writer.writeAll("    // ");
        try writer.writeAll(evm_signatures.selectorToSlice(func.selector));
        try writer.writeAll("\n    function ");
        try writer.writeAll(func.name);
        try writer.writeAll("() external {\n");
        try writer.writeAll("        // [Decompiled bytecode - implementation hidden]\n");
        try writer.writeAll("    }\n\n");
    }
    
    try writer.writeAll("}\n");
}
