// Vyper Bytecode Decompilation Support
// Detects and decompiles Vyper-compiled contracts

const std = @import("std");

pub const VyperVersion = struct {
    major: u8,
    minor: u8,
    patch: u8,
};

pub const VyperContract = struct {
    is_vyper: bool,
    version: ?VyperVersion,
    name: []const u8,
    functions: []VyperFunction,
};

pub const VyperFunction = struct {
    name: []const u8,
    selector: [4]u8,
    signature: []const u8,
    visibility: VyperVisibility,
    is_entry_point: bool,
};

pub const VyperVisibility = enum {
    @"external",
    @"public",
    @"internal",
    @"private",
};

pub const Language = enum {
    solidity,
    vyper,
    unknown,
};

// ============================================================================
// Vyper Detection
// ============================================================================

/// Detect if bytecode was compiled from Vyper
pub fn detectLanguage(bytecode: []const u8, embedded_strings: []const struct { offset: usize, value: []const u8 }) Language {
    // Check for Vyper version string in embedded strings
    for (embedded_strings) |str| {
        if (std.mem.indexOf(u8, str.value, "@version") != null) {
            return .vyper;
        }
        if (std.mem.indexOf(u8, str.value, "vyper") != null) {
            return .vyper;
        }
    }

    // Check for common Vyper bytecode patterns
    if (detectVyperPatterns(bytecode)) {
        return .vyper;
    }

    return .unknown;
}

/// Detect Vyper-specific bytecode patterns
fn detectVyperPatterns(bytecode: []const u8) bool {
    // Vyper contracts typically have a specific entry point pattern
    // Look for common Vyper dispatcher patterns

    // Pattern 1: Vyper 0.3.x+ uses PUSH0 (0x5f) for zero initialization
    var push0_count: usize = 0;
    var calldataload_count: usize = 0;

    // Pattern 2: Check for Vyper's characteristic function dispatch
    // Vyper uses: calldataload(0) -> shr(0xe0) to get selector
    var i: usize = 0;
    while (i < bytecode.len) : (i += 1) {
        switch (bytecode[i]) {
            0x5f => push0_count += 1, // PUSH0 (Vyper 0.3+)
            0x37 => calldataload_count += 1, // CALLDATALOAD
            else => {},
        }
    }

    // Vyper 0.3+ contracts often use PUSH0 extensively
    if (push0_count > 5) {
        return true;
    }

    // Pattern 3: Vyper memory initialization patterns
    // Vyper uses msize frequently for memory size checks
    var msize_count: usize = 0;
    i = 0;
    while (i < bytecode.len) : (i += 1) {
        if (bytecode[i] == 0x59) msize_count += 1; // MSIZE
    }

    // Vyper contracts tend to use MSIZE more than Solidity
    if (msize_count > 2) {
        return true;
    }

    return false;
}

/// Extract Vyper version from embedded strings
pub fn detectVersion(embedded_strings: []const struct { offset: usize, value: []const u8 }) ?VyperVersion {
    for (embedded_strings) |str| {
        // Look for version string like "0.3.10" or "^0.3.9"
        const value = str.value;
        if (std.mem.indexOf(u8, value, "0.") != null) {
            // Try to parse version
            var version_str = value;
            // Remove @version or ^ prefix
            if (std.mem.startsWith(u8, value, "@version")) {
                version_str = value["@version".len..];
            } else if (value[0] == '^' or value[0] == '>') {
                version_str = value[1..];
            }

            // Find the version number
            var major: u8 = 0;
            var minor: u8 = 0;
            var patch: u8 = 0;

            var parts = std.mem.split(u8, version_str, ".");
            if (parts.next()) |maj| {
                major = std.fmt.parseInt(u8, maj, 10) catch 0;
            }
            if (parts.next()) |min| {
                // Extract just the number part
                var num_str = min;
                for (min, 0..) |c, idx| {
                    if (c < '0' or c > '9') {
                        num_str = min[0..idx];
                        break;
                    }
                }
                minor = std.fmt.parseInt(u8, num_str, 10) catch 0;
            }
            if (parts.next()) |pat| {
                var num_str = pat;
                for (pat, 0..) |c, idx| {
                    if (c < '0' or c > '9') {
                        num_str = pat[0..idx];
                        break;
                    }
                }
                patch = std.fmt.parseInt(u8, num_str, 10) catch 0;
            }

            if (major > 0 or minor > 0) {
                return VyperVersion{ .major = major, .minor = minor, .patch = patch };
            }
        }
    }
    return null;
}

// ============================================================================
// Vyper Function Signatures
// ============================================================================

/// Vyper built-in function signatures
fn lookupVyperSignature(hex: []const u8) ?[]const u8 {
    // Vyper built-in functions and common patterns

    // Vyper math builtins
    if (std.mem.eql(u8, hex, "0x2a0c8d70")) return "sqrt(uint256) -> uint256";
    if (std.mem.eql(u8, hex, "0x0e3ee67b")) return "sqrt(decimal) -> decimal";

    // Vyper bitwise builtins
    if (std.mem.eql(u8, hex, "0x1e5b6d3e")) return "uint256_addmod(uint256,uint256,uint256) -> uint256";
    if (std.mem.eql(u8, hex, "0xac1d865f")) return "uint256_mulmod(uint256,uint256,uint256) -> uint256";

    // Vyper ethereum builtins
    if (std.mem.eql(u8, hex, "0x4d2301cc")) return "raw_call(address,bytes,uint256,uint256) -> bytes";
    if (std.mem.eql(u8, hex, "0x2e1a7d4d")) return "raw_call(address,bytes) -> bytes";
    if (std.mem.eql(u8, hex, "0x0c52e5aa")) return "raw_call(address,bytes,uint256) -> bytes";
    if (std.mem.eql(u8, hex, "0xa9059cbb")) return "raw_transfer(address,uint256) -> bool";
    if (std.mem.eql(u8, hex, "0x23b872dd")) return "raw_call(address,address,uint256) -> uint256";
    if (std.mem.eql(u8, hex, "0x54fd4d50")) return "raw_revert(bytes) -> bool";

    // Vyper blockchain builtins
    if (std.mem.eql(u8, hex, "0x43719c1c")) return "chainid() -> uint256";
    if (std.mem.eql(u8, hex, "0x8c9dd3e5")) return "msg.sender";
    if (std.mem.eql(u8, hex, "0x1e7d0f2e")) return "block.coinbase";
    if (std.mem.eql(u8, hex, "0x0c52e5aa")) return "block.timestamp";
    if (std.mem.eql(u8, hex, "0x0297cde6")) return "block.number";
    if (std.mem.eql(u8, hex, "0x2a1afcd9")) return "block.difficulty";
    if (std.mem.eql(u8, hex, "0x4b1d4c15")) return "block.gaslimit";
    if (std.mem.eql(u8, hex, "0x56a8d42e")) return "block.chainid() -> uint256";

    // Vyper address builtins
    if (std.mem.eql(u8, hex, "0x2e1a7d4d")) return "selfdestruct(address)";
    if (std.mem.eql(u8, hex, "0x0c52e5aa")) return "address";

    // Vyper hash builtins
    if (std.mem.eql(u8, hex, "0x3e8dd5fa")) return "keccak256(bytes) -> bytes32";
    if (std.mem.eql(u8, hex, "0x016d8020")) return "keccak256(uint256) -> bytes32";
    if (std.mem.eql(u8, hex, "0x7aa6b9dd")) return "sha256(bytes) -> bytes32";

    // Vyper EC recover (common in Vyper contracts)
    if (std.mem.eql(u8, hex, "0x1e7d0f2e")) return "ecrecover(bytes32,uint8,bytes32,bytes32) -> address";

    // Vyper contract interface
    if (std.mem.eql(u8, hex, "0x5c60da1b")) return "paused() -> bool";
    if (std.mem.eql(u8, hex, "0x8456cb59")) return "pause()";
    if (std.mem.eql(u8, hex, "0x3f4ba83a")) return "unpause()";

    // Vyper ownable
    if (std.mem.eql(u8, hex, "0x8da5cb5b")) return "owner() -> address";
    if (std.mem.eql(u8, hex, "0xf2fde38b")) return "transfer_ownership(address)";
    if (std.mem.eql(u8, hex, "0x173825d9")) return "__Ownable_owner() -> address";
    if (std.mem.eql(u8, hex, "0x787c6ded")) return "__Ownable_transfer_ownership(address)";

    // Vyper ERC20-like (Vyper's ownable-erc20 implementation)
    if (std.mem.eql(u8, hex, "0xa9059cbb")) return "transfer(address,uint256) -> bool";
    if (std.mem.eql(u8, hex, "0x095ea7b3")) return "approve(address,uint256) -> bool";
    if (std.mem.eql(u8, hex, "0x23b872dd")) return "transferFrom(address,address,uint256) -> bool";
    if (std.mem.eql(u8, hex, "0xdd62ed3e")) return "allowance(address,address) -> uint256";
    if (std.mem.eql(u8, hex, "0x18160ddd")) return "total_supply() -> uint256";
    if (std.mem.eql(u8, hex, "0x70a08231")) return "balance_of(address) -> uint256";

    // Vyper metadata
    if (std.mem.eql(u8, hex, "0x06fdde03")) return "name() -> String[100]";
    if (std.mem.eql(u8, hex, "0x95d89b41")) return "symbol() -> String[100]";
    if (std.mem.eql(u8, hex, "0x313ce567")) return "decimals() -> uint8";

    // Common Vyper entry points
    if (std.mem.eql(u8, hex, "0x4acd6f2b")) return "__default__() -> bool";
    if (std.mem.eql(u8, hex, "0x5b44f95a")) return "__fallback__() -> bool";

    return null;
}

/// Resolve a function selector to its Vyper signature
pub fn resolveVyperSignature(selector: [4]u8) ?[]const u8 {
    const hex = selectorToHex(selector);
    return lookupVyperSignature(&hex);
}

fn selectorToHex(sel: [4]u8) [10]u8 {
    var result: [10]u8 = .{ '0', 'x', 0, 0, 0, 0, 0, 0, 0, 0 };
    const hex_chars = "0123456789abcdef";
    for (sel, 0..) |b, i| {
        result[2 + i * 2] = hex_chars[b >> 4];
        result[3 + i * 2] = hex_chars[b & 0xf];
    }
    return result;
}

// ============================================================================
// Vyper Decompilation Helper
// ============================================================================

/// Vyper storage slot pattern - different from Solidity
/// Vyper: keccak256(slot + key)
/// Solidity: keccak256(key + slot)
pub fn isVyperStorageAccess(bytecode: []const u8) bool {
    // Look for keccak256 followed by pattern that indicates Vyper storage
    // This is a heuristic - exact detection requires more analysis

    var i: usize = 0;
    while (i < bytecode.len - 1) : (i += 1) {
        // Look for DUP2 before keccak256 (Vyper pattern)
        if (bytecode[i] == 0x80 and i + 1 < bytecode.len and bytecode[i + 1] == 0x20) {
            // DUP2 followed by KECCAK256 is common in Vyper mapping access
            // where arguments are in different order than Solidity
            return true;
        }
    }

    return false;
}

/// Check if contract is a common Vyper template
pub fn detectVyperTemplate(bytecode: []const u8) ?[]const u8 {
    // Vyper ERC20 template signatures
    const erc20_signatures = [_][]const u8{
        "0xa9059cbb", // transfer
        "0x095ea7b3", // approve
        "0x23b872dd", // transferFrom
        "0xdd62ed3e", // allowance
        "0x18160ddd", // totalSupply
        "0x70a08231", // balanceOf
    };

    var match_count: usize = 0;
    for (erc20_signatures) |sig| {
        if (std.mem.indexOf(u8, bytecode, sig[2..]) != null) {
            match_count += 1;
        }
    }

    if (match_count >= 4) {
        return "ERC20";
    }

    // Vyper ownable template
    const ownable_signatures = [_][]const u8{
        "0x8da5cb5b", // owner
        "0xf2fde38b", // transferOwnership
    };

    match_count = 0;
    for (ownable_signatures) |sig| {
        if (std.mem.indexOf(u8, bytecode, sig[2..]) != null) {
            match_count += 1;
        }
    }

    if (match_count >= 1) {
        return "Ownable";
    }

    return null;
}
