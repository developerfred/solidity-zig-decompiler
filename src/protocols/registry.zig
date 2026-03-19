// Protocol Detection Registry
// Centralized protocol detection for DeFi and cross-chain protocols

const std = @import("std");
const lifi = @import("lifi.zig");

pub const ProtocolType = enum {
    unknown,
    erc20,
    erc721,
    erc1155,
    proxy,
    diamond,
    lifi,
    aave,
    uniswap,
    curve,
    compound,
    yearn,
    gnosis_safe,
    makerdao,
};

pub const DetectedProtocol = struct {
    protocol_type: ProtocolType,
    name: []const u8,
    version: ?[]const u8,
    confidence: f32,
};

/// Detect protocol from bytecode and address
pub fn detectProtocol(allocator: std.mem.Allocator, bytecode: []const u8, address: ?[]const u8) ![]DetectedProtocol {
    var protocols = std.ArrayList(DetectedProtocol).init(allocator);

    // Check for Li.FI
    if (lifi.detectInBytecode(bytecode)) {
        try protocols.append(.{
            .protocol_type = .lifi,
            .name = "Li.FI",
            .version = if (address) |addr| blk: {
                if (lifi.getVersionForAddress(addr)) |ver| {
                    break :blk try std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ ver.major, ver.minor, ver.patch });
                }
                break :blk null;
            } else null,
            .confidence = 0.95,
        });
    }

    // Check for known Li.FI diamond addresses
    if (address) |addr| {
        if (lifi.isKnownLiFiDiamond(addr)) {
            // Check if already added
            var found = false;
            for (protocols.items) |p| {
                if (p.protocol_type == .lifi) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try protocols.append(.{
                    .protocol_type = .lifi,
                    .name = "Li.FI",
                    .version = if (lifi.getVersionForAddress(addr)) |ver|
                        try std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ ver.major, ver.minor, ver.patch })
                    else
                        "2.0+",
                    .confidence = 1.0,
                });
            }
        }
    }

    return protocols.items;
}

/// Get all supported protocol names
pub fn getSupportedProtocols() [][]const u8 {
    return &.{
        "Li.FI",
        "Uniswap",
        "Curve",
        "Aave",
        "Compound",
        "Yearn",
        "Gnosis Safe",
        "MakerDAO",
    };
}
