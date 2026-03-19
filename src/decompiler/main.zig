// Main Decompiler Module - Simplified for Zig 0.15

const std = @import("std");
const evm_parser = @import("../evm/parser.zig");
const evm_dispatcher = @import("../evm/dispatcher.zig");
const evm_strings = @import("../evm/strings.zig");
const evm_signatures = @import("../evm/signatures.zig");
const evm_cfg = @import("../evm/cfg.zig");
const vyper = @import("../vyper/mod.zig");

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
    is_vyper: bool,
    vyper_version: ?vyper.VyperVersion,
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
        .is_vyper = false,
        .vyper_version = null,
        .allocator = allocator,
    };

    const allocator_to_use = allocator;

    // Extract embedded strings first
    var embedded_strs: []evm_strings.EmbeddedString = &.{};
    if (config.extract_strings) {
        const str = try evm_strings.extract(allocator_to_use, bytecode);
        embedded_strs = str.strings;
        contract.embedded_strings = str.strings;

        // Detect language (Vyper vs Solidity)
        // Convert EmbeddedString to simpler format for detection
        var str_items: []const struct { offset: usize, value: []const u8 } = &.{};
        var str_list = std.ArrayList(struct { offset: usize, value: []const u8 }).init(allocator_to_use);
        defer str_list.deinit();

        for (str.strings) |s| {
            try str_list.append(.{ .offset = s.offset, .value = s.value });
        }
        str_items = try str_list.toOwnedSlice();

        const language = vyper.detectLanguage(bytecode, str_items);
        if (language == .vyper) {
            contract.is_vyper = true;
            contract.vyper_version = vyper.detectVersion(str_items);
            contract.name = "VyperContract";
        }
    }

    if (config.resolve_signatures) {
        var dispatcher = try evm_dispatcher.analyzeDispatchers(allocator_to_use, bytecode);
        defer evm_dispatcher.deinit(&dispatcher);

        var func_list = std.ArrayListUnmanaged(DecompiledFunction){};

        var signature_cache = evm_signatures.SignatureCache.init(allocator_to_use);
        defer signature_cache.deinit();

        for (dispatcher.selectors) |sel| {
            // First try Vyper signatures if detected as Vyper
            var resolved_sig: ?evm_signatures.ResolvedSignature = null;

            if (contract.is_vyper) {
                if (vyper.resolveVyperSignature(sel.selector)) |vyper_sig| {
                    resolved_sig = .{
                        .selector = sel.selector,
                        .signature = vyper_sig,
                        .confidence = 1.0,
                        .source = .builtin,
                    };
                }
            }

            // Fall back to standard signatures
            if (resolved_sig == null) {
                const resolved = evm_signatures.resolve(sel.selector, &signature_cache) catch continue;
                resolved_sig = resolved;
            }

            if (resolved_sig) |r| {
                try func_list.append(allocator_to_use, .{ .name = r.signature, .selector = sel.selector, .signature = r.signature });
            }
        }

        contract.functions = try func_list.toOwnedSlice(allocator_to_use);

        // Detect patterns
        var erc20_count: usize = 0;
        for (dispatcher.selectors) |s| {
            const hex = evm_signatures.selectorToSlice(s.selector);
            if (std.mem.startsWith(u8, hex, "0xa9059cbb") or
                std.mem.startsWith(u8, hex, "0x095ea7b3") or
                std.mem.startsWith(u8, hex, "0x70a08231") or
                std.mem.startsWith(u8, hex, "0x18160ddd"))
            {
                erc20_count += 1;
            }
        }
        if (erc20_count >= 3) {
            contract.is_erc20 = true;
            if (!contract.is_vyper) {
                contract.name = "ERC20";
            }
        }

        // Check for Vyper-specific templates
        if (contract.is_vyper) {
            if (vyper.detectVyperTemplate(bytecode)) |template| {
                contract.name = template;
            }
        }
    }

    // Check for proxy
    for (bytecode) |byte| {
        if (byte == 0xf4) {
            contract.is_proxy = true;
            if (!contract.is_erc20 and !contract.is_vyper) contract.name = "Proxy";
            break;
        }
    }

    return contract;
}

pub fn generateSolidity(contract: *const DecompiledContract, writer: anytype) !void {
    if (contract.is_vyper) {
        try generateVyper(contract, writer);
    } else {
        try generateSolidityCode(contract, writer);
    }
}

fn generateSolidityCode(contract: *const DecompiledContract, writer: anytype) !void {
    try writer.writeAll("# SPDX-License-Identifier: UNLICENSED\n\n");
    try writer.writeAll("pragma solidity ^0.8.0;\n\n");
    try writer.print("contract {s} {{\n\n", .{contract.name});

    for (contract.functions) |func| {
        try writer.writeAll("    # ");
        try writer.writeAll(evm_signatures.selectorToSlice(func.selector));
        try writer.writeAll("\n    function ");
        try writer.writeAll(func.name);
        try writer.writeAll("() external {\n");
        try writer.writeAll("        # [Decompiled bytecode - implementation hidden]\n");
        try writer.writeAll("    }\n\n");
    }

    try writer.writeAll("}\n");
}

fn generateVyper(contract: *const DecompiledContract, writer: anytype) !void {
    // Vyper source code output
    try writer.writeAll("# @version ^0.3.0\n\n");
    try writer.writeAll("\"\"\"\nAuto-generated Vyper decompilation\n");
    if (contract.vyper_version) |ver| {
        try writer.print("Detected Version: {d}.{d}.{d}\n", .{ ver.major, ver.minor, ver.patch });
    }
    try writer.writeAll("\"\"\"\n\n");

    // Import common interfaces
    try writer.writeAll("from vyper.interfaces import ERC20\n\n");

    try writer.print("@external\ndef __init__():\n    pass\n\n", .{});

    for (contract.functions) |func| {
        try writer.writeAll("@external\n");
        try writer.writeAll("def ");
        // Convert function signature to Vyper format
        try writer.writeAll(convertToVyperSignature(func.name));
        try writer.writeAll(":\n");
        try writer.writeAll("    # ");
        try writer.writeAll(evm_signatures.selectorToSlice(func.selector));
        try writer.writeAll("\n    pass\n\n");
    }
}

fn convertToVyperSignature(signature: []const u8) []const u8 {
    // Simple conversion from Solidity-style to Vyper-style
    // This is a simplified version - real implementation would parse the full signature

    // For now, just return a cleaned up version
    var result: [128]u8 = undefined;
    var pos: usize = 0;

    // Convert common patterns
    var i: usize = 0;
    while (i < signature.len) : (i += 1) {
        if (i + 4 < signature.len and std.mem.eql(u8, signature[i..i+4], "() ->")) {
            result[pos] = ' '; // Replace () with space
            pos += 1;
            i += 4;
        } else {
            result[pos] = signature[i];
            pos += 1;
        }
    }

    return result[0..pos];
}
