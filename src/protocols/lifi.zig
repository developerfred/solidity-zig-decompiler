// Li.FI Protocol Detection Module
// Detect and analyze Li.FI cross-chain contracts

const std = @import("std");

pub const LiFiVersion = struct {
    major: u8,
    minor: u8,
    patch: u8,
};

pub const LiFiContract = struct {
    is_lifi: bool,
    version: ?LiFiVersion,
    is_diamond: bool,
    facets_detected: []LiFiFacet,
    detected_bridges: [][]const u8,
    detected_dexs: [][]const u8,
    allocator: std.mem.Allocator,
};

pub const LiFiFacet = struct {
    name: []const u8,
    address: [20]u8,
    function_count: usize,
};

// Known Li.FI Diamond address on mainnets
pub const KNOWN_LIFI_DIAMOND_ADDRESSES = [_][]const u8{
    "0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE", // Ethereum, Polygon, BSC, etc.
    "0xb5b8Arc94A65d4551C28e6455C7681fA6eD65A5c", // Some sidechains
};

// Known facet names for Li.FI
pub const LIFI_FACET_NAMES = [_]struct { selector: [4]u8, name: []const u8 }{
    .{ .selector = .{ 0xa1, 0x25, 0x7d, 0x8f }, .name = "SwapFacet" },
    .{ .selector = .{ 0x7c, 0x66, 0x5d, 0xfc }, .name = "BridgeFacet" },
    .{ .selector = .{ 0x1e, 0x1d, 0x1d, 0x6f }, .name = "SwapAndBridgeFacet" },
    .{ .selector = .{ 0x2a, 0x1e, 0xc8, 0x7e }, .name = "BridgeGenericFacet" },
    .{ .selector = .{ 0x3b, 0xe2, 0xa2, 0x4b }, .name = "SwapAndBridgeGenericFacet" },
    .{ .selector = .{ 0x54, 0x78, 0x7c, 0x40 }, .name = "GenericSwapFacet" },
    .{ .selector = .{ 0x1f, 0x93, 0x1c, 0x1c }, .name = "DiamondCutFacet" },
    .{ .selector = .{ 0xcd, 0xff, 0xac, 0xc6 }, .name = "DiamondLoupeFacet" },
    .{ .selector = .{ 0x52, 0xef, 0x6b, 0x2c }, .name = "OwnershipFacet" },
};

// Known bridges integrated with Li.FI
pub const KNOWN_BRIDGES = [_][]const u8{
    "Stargate",
    "Across",
    "ThorChain",
    "Symbiosis",
    "CCTP",
    "Allbridge",
    "Hop",
    "LayerZero",
    "Axelar",
    "Wormhole",
};

// Known DEXs integrated with Li.FI
pub const KNOWN_DEXS = [_][]const u8{
    "Uniswap",
    "SushiSwap",
    "Curve",
    "Balancer",
    "1inch",
    "0x",
    "Odos",
    "Enso",
    "Paraswap",
    "Kyber",
};

/// Check if an address is a known Li.FI Diamond contract
pub fn isKnownLiFiDiamond(address: []const u8) bool {
    for (KNOWN_LIFI_DIAMOND_ADDRESSES) |known| {
        if (std.mem.eql(u8, address, known)) {
            return true;
        }
    }
    return false;
}

/// Detect Li.FI patterns in bytecode
pub fn detectInBytecode(bytecode: []const u8) bool {
    // Look for Li.FI diamond patterns
    // 1. EIP-2535 diamondCut signature: 0x1f931c1c
    var diamond_cut_count: usize = 0;
    var generic_swap_count: usize = 0;
    var bridge_count: usize = 0;

    for (0..bytecode.len - 3) |i| {
        // diamondCut
        if (bytecode[i] == 0x1f and bytecode[i + 1] == 0x93 and
            bytecode[i + 2] == 0x1c and bytecode[i + 3] == 0x1c) {
            diamond_cut_count += 1;
        }

        // swapTokensGeneric: 0xa1257d8f
        if (bytecode[i] == 0xa1 and bytecode[i + 1] == 0x25 and
            bytecode[i + 2] == 0x7d and bytecode[i + 3] == 0x8f) {
            generic_swap_count += 1;
        }

        // startBridgeTokensViaLiFi: 0x7c665dfc
        if (bytecode[i] == 0x7c and bytecode[i + 1] == 0x66 and
            bytecode[i + 2] == 0x5d and bytecode[i + 3] == 0xfc) {
            bridge_count += 1;
        }
    }

    // Li.FI diamond contracts have these characteristic patterns
    return diamond_cut_count >= 1 or (generic_swap_count >= 1 and bridge_count >= 1);
}

/// Detect which bridges are used based on bytecode patterns
pub fn detectBridges(bytecode: []const u8) []const []const u8 {
    var detected = std.ArrayList([]const u8).init(std.heap.page_allocator);

    // These are simplified detection patterns
    // Real detection would require more sophisticated analysis

    // Stargate patterns
    if (std.mem.indexOf(u8, bytecode, "stargate") != null or
        std.mem.indexOf(u8, bytecode, "STARGATE") != null) {
        detected.append("Stargate") catch {};
    }

    // Across patterns
    if (std.mem.indexOf(u8, bytecode, "across") != null or
        std.mem.indexOf(u8, bytecode, "ACROSS") != null) {
        detected.append("Across") catch {};
    }

    // ThorChain
    if (std.mem.indexOf(u8, bytecode, "thorchain") != null or
        std.mem.indexOf(u8, bytecode, "THORCHAIN") != null) {
        detected.append("ThorChain") catch {};
    }

    // LayerZero
    if (std.mem.indexOf(u8, bytecode, "layerzero") != null or
        std.mem.indexOf(u8, bytecode, "LAYERZERO") != null) {
        detected.append("LayerZero") catch {};
    }

    // Wormhole
    if (std.mem.indexOf(u8, bytecode, "wormhole") != null or
        std.mem.indexOf(u8, bytecode, "WORMHOLE") != null) {
        detected.append("Wormhole") catch {};
    }

    return detected.items;
}

/// Get Li.FI version from known deployments
pub fn getVersionForAddress(address: []const u8) ?LiFiVersion {
    // Mainnet diamond (v2+)
    if (std.mem.eql(u8, address, "0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE")) {
        return LiFiVersion{ .major = 2, .minor = 0, .patch = 0 };
    }

    return null;
}

/// Get human-readable description of Li.FI transaction
pub fn describeTransaction(function_selector: [4]u8) ?[]const u8 {
    const hex = selectorToHex(function_selector);

    if (std.mem.eql(u8, &hex, "0xa1257d8f")) {
        return "Li.FI: Swap tokens (generic DEX aggregation)";
    }
    if (std.mem.eql(u8, &hex, "0x7c665dfc")) {
        return "Li.FI: Start bridge tokens";
    }
    if (std.mem.eql(u8, &hex, "0x1e1d1d6f")) {
        return "Li.FI: Swap and start bridge tokens";
    }
    if (std.mem.eql(u8, &hex, "0x2a1ec87e")) {
        return "Li.FI: Start bridge tokens (generic)";
    }
    if (std.mem.eql(u8, &hex, "0x3be2a24b")) {
        return "Li.FI: Swap and bridge tokens (generic)";
    }
    if (std.mem.eql(u8, &hex, "0x54787c40")) {
        return "Li.FI: Generic swap (single hop)";
    }

    return null;
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
