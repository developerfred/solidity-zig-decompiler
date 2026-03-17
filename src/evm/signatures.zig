// Function Signature Resolver - Ultra Simplified

const std = @import("std");

pub const ResolvedSignature = struct {
    selector: [4]u8,
    signature: []const u8,
    confidence: f32,
};

pub const SignatureSource = enum { builtin, api, inferred, unknown };

pub const SignatureCache = struct {
    entries: std.StringHashMap(ResolvedSignature),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) SignatureCache {
        return .{
            .entries = std.StringHashMap(ResolvedSignature).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *SignatureCache) void {
        self.entries.deinit();
    }
};

fn lookupSignature(hex: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, hex, "0xa9059cbb")) return "transfer(address,uint256)";
    if (std.mem.eql(u8, hex, "0x095ea7b3")) return "approve(address,uint256)";
    if (std.mem.eql(u8, hex, "0x23b872dd")) return "transferFrom(address,address,uint256)";
    if (std.mem.eql(u8, hex, "0xdd62ed3e")) return "allowance(address,address)";
    if (std.mem.eql(u8, hex, "0x18160ddd")) return "totalSupply()";
    if (std.mem.eql(u8, hex, "0x70a08231")) return "balanceOf(address)";
    if (std.mem.eql(u8, hex, "0x6352211e")) return "ownerOf(uint256)";
    if (std.mem.eql(u8, hex, "0x8da5cb5b")) return "owner()";
    if (std.mem.eql(u8, hex, "0xf2fde38b")) return "transferOwnership(address)";
    if (std.mem.eql(u8, hex, "0x3659cfe6")) return "renounceOwnership()";
    if (std.mem.eql(u8, hex, "0x5c60da1b")) return "paused()";
    if (std.mem.eql(u8, hex, "0x8456cb59")) return "pause()";
    if (std.mem.eql(u8, hex, "0x3f4ba83a")) return "unpause()";
    if (std.mem.eql(u8, hex, "0x06fdde03")) return "name()";
    if (std.mem.eql(u8, hex, "0x95d89b41")) return "symbol()";
    if (std.mem.eql(u8, hex, "0x313ce567")) return "decimals()";
    return null;
}

pub fn resolve(selector: [4]u8, cache: *SignatureCache) !ResolvedSignature {
    const hex = selectorToHex(selector);
    const hex_slice: []const u8 = &hex;
    
    if (cache.entries.get(hex_slice)) |*cached| return cached.*;
    
    if (lookupSignature(hex_slice)) |sig| {
        const resolved = ResolvedSignature{
            .selector = selector,
            .signature = sig,
            .confidence = 1.0,
        };
        try cache.entries.put(hex_slice, resolved);
        return resolved;
    }
    
    return .{
        .selector = selector,
        .signature = "unknown()",
        .confidence = 0.0,
    };
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

pub fn selectorToSlice(sel: [4]u8) []const u8 {
    var buf: [10]u8 = selectorToHex(sel);
    return &buf;
}

pub fn hexToSelector(hex: []const u8) ?[4]u8 {
    if (hex.len != 10) return null;
    if (!std.mem.startsWith(u8, hex, "0x")) return null;
    
    var result: [4]u8 = undefined;
    for (0..4) |i| {
        const byte_hex = hex[2 + i * 2 .. 4 + i * 2];
        result[i] = std.fmt.parseInt(u8, byte_hex, 16) catch return null;
    }
    return result;
}
