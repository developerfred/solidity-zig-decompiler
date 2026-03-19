// Contract Deployment Detection Module
// Detect factory contracts, proxies, clones, and deployment patterns

const std = @import("std");
const opcodes = @import("../evm/opcodes.zig");
const parser = @import("../evm/parser.zig");

pub const DeploymentType = enum {
    regular,
    factory,
    proxy,
    minimal_proxy,
    transparent_proxy,
    uups_proxy,
    beacon_proxy,
    clone,
    diamond,
};

pub const DeploymentInfo = struct {
    deployment_type: DeploymentType,
    is_factory: bool,
    is_upgradeable: bool,
    uses_create2: bool,
    uses_create: bool,
    child_contract_count: usize,
    implementation_slot: ?u64,
    beacon_address: ?[]const u8,
    detected_patterns: []const []const u8,
    allocator: std.mem.Allocator,
};

/// Detect contract deployment patterns in bytecode
pub fn detect(allocator: std.mem.Allocator, bytecode: []const u8) !DeploymentInfo {
    var info = DeploymentInfo{
        .deployment_type = .regular,
        .is_factory = false,
        .is_upgradeable = false,
        .uses_create2 = false,
        .uses_create = false,
        .child_contract_count = 0,
        .implementation_slot = null,
        .beacon_address = null,
        .detected_patterns = &.{},
        .allocator = allocator,
    };

    var patterns = std.ArrayList([]const u8).init(allocator);

    // Parse bytecode for analysis
    const parsed = try parser.parse(allocator, bytecode);
    defer parser.deinit(&parsed);

    // Check for CREATE opcode (factory pattern)
    var create_count: usize = 0;

    for (parsed.instructions) |instr| {
        switch (instr.opcode) {
            .create => {
                create_count += 1;
                info.uses_create = true;
            },
            .create2 => {
                create_count += 1;
                info.uses_create2 = true;
            },
            else => {},
        }
    }

    // Factory detection: multiple CREATE/CREATE2 calls
    if (create_count >= 1) {
        info.is_factory = true;
        info.deployment_type = .factory;
        info.child_contract_count = create_count;
        try patterns.append("CREATE opcode detected");
    }

    if (info.uses_create2) {
        try patterns.append("CREATE2 deterministic deployment");
    }

    // Check for proxy patterns
    if (try detectProxyPatterns(bytecode, &patterns, allocator)) {
        info.is_upgradeable = true;
    }

    // Check for minimal proxy (EIP-1167)
    if (try detectMinimalProxy(bytecode)) {
        info.deployment_type = .minimal_proxy;
        try patterns.append("EIP-1167 Minimal Proxy");
    }

    // Check for diamond pattern (EIP-2535)
    if (try detectDiamondPattern(bytecode)) {
        info.deployment_type = .diamond;
        try patterns.append("EIP-2535 Diamond Standard");
    }

    // Check for beacon proxy
    if (try detectBeaconProxy(bytecode)) {
        info.deployment_type = .beacon_proxy;
        try patterns.append("Beacon Proxy");
    }

    // Check for clone pattern
    if (detectClonePattern(bytecode)) {
        info.deployment_type = .clone;
        try patterns.append("Clone pattern");
    }

    info.detected_patterns = try patterns.toOwnedSlice();

    return info;
}

/// Detect various proxy patterns
fn detectProxyPatterns(bytecode: []const u8, patterns: *std.ArrayList([]const u8), allocator: std.mem.Allocator) !bool {
    _ = allocator; // Reserved for future use
    var is_proxy = false;

    // Check for delegatecall (used in all proxy types)
    var delegatecall_count: usize = 0;
    var i: usize = 0;
    while (i < bytecode.len) : (i += 1) {
        if (bytecode[i] == 0xf4) { // DELEGATECALL
            delegatecall_count += 1;
        }
    }

    if (delegatecall_count > 0) {
        is_proxy = true;
        try patterns.append("delegatecall (proxy pattern)");

        // Check for UUPS (ERC1822)
        if (detectUUPS(bytecode)) {
            try patterns.append("UUPS Proxy (EIP-1822)");
        }

        // Check for Transparent proxy
        if (detectTransparentProxy(bytecode)) {
            try patterns.append("Transparent Proxy (EIP-1967)");
        }
    }

    return is_proxy;
}

/// Detect UUPS proxy pattern (EIP-1822)
fn detectUUPS(bytecode: []const u8) bool {
    // UUPS proxies typically have:
    // - proxyType() function selector: 0x5c60da1b
    // - proxiableUUID() function selector: 0x54d1c43e

    var found_proxy_type = false;
    var found_proxiable = false;

    for (0..bytecode.len - 4) |j| {
        if (bytecode[j] == 0x5c and bytecode[j+1] == 0x60 and
            bytecode[j+2] == 0xda and bytecode[j+3] == 0x1b) {
            found_proxy_type = true;
        }
        if (bytecode[j] == 0x54 and bytecode[j+1] == 0xd1 and
            bytecode[j+2] == 0xc4 and bytecode[j+3] == 0x3e) {
            found_proxiable = true;
        }
    }

    return found_proxy_type or found_proxiable;
}

/// Detect Transparent proxy pattern (EIP-1967)
fn detectTransparentProxy(bytecode: []const u8) bool {
    // EIP-1967 storage slots:
    // - Implementation: 0x360894a13ba1ec321de624de2782eb72f294e3c56
    // - Admin: 0xb53127684a568b3173ae13b9f8a6016e243bb63

    // Check for common EIP-1967 related opcodes patterns
    // Look for immutable storage reads at specific positions
    var i: usize = 0;
    while (i < bytecode.len - 1) : (i += 1) {
        // Look for sload after push operations (storage slot access)
        if (bytecode[i] >= 0x60 and bytecode[i] <= 0x7f) { // PUSH
            if (i + 1 < bytecode.len and bytecode[i + 1] == 0x54) { // SLOAD
                return true;
            }
        }
    }

    return false;
}

/// Detect minimal proxy (EIP-1167)
fn detectMinimalProxy(bytecode: []const u8) bool {
    // Minimal proxy has a very specific bytecode pattern:
    // 363d3d373d3d3d363d30545f73eeeeeeeeeeeeeeee5af43d82803e903d91602b57fd5bf3

    // This is ~55 bytes of runtime code
    if (bytecode.len < 45 or bytecode.len > 55) {
        return false;
    }

    // Check for characteristic minimal proxy pattern
    // Should start with CALLDATASIZE (36) and have DELEGATECALL (f4)
    var has_delegatecall = false;
    var has_return = false;

    for (bytecode) |byte| {
        if (byte == 0xf4) has_delegatecall = true; // DELEGATECALL
        if (byte == 0xf3) has_return = true; // RETURN
    }

    // Also check for the "eeeeeeee" sentinel (commonly used in minimal proxies)
    for (0..bytecode.len - 1) |j| {
        if (bytecode[j] == 0xee and bytecode[j + 1] == 0xee and
            bytecode[j + 2] == 0xee and bytecode[j + 3] == 0xee) {
            return true;
        }
    }

    return has_delegatecall and has_return;
}

/// Detect Diamond standard (EIP-2535)
fn detectDiamondPattern(bytecode: []const u8) bool {
    // Diamond proxies use diamondCut function:
    // 1f931c1c (diamondCut)

    var i: usize = 0;
    while (i < bytecode.len - 3) : (i += 1) {
        if (bytecode[i] == 0x1f and bytecode[i + 1] == 0x93 and
            bytecode[i + 2] == 0x1c and bytecode[i + 3] == 0x1c) {
            return true;
        }
    }

    // Also check for multiple delegatecall patterns (diamond has multiple facets)
    var delegatecall_count: usize = 0;
    for (bytecode) |byte| {
        if (byte == 0xf4) delegatecall_count += 1;
    }

    return delegatecall_count >= 3;
}

/// Detect Beacon proxy pattern
fn detectBeaconProxy(bytecode: []const u8) bool {
    // Beacon proxies check a beacon contract for implementation
    // beacon() function: 0x5f360067

    var i: usize = 0;
    while (i < bytecode.len - 3) : (i += 1) {
        if (bytecode[i] == 0x5f and bytecode[i + 1] == 0x36 and
            bytecode[i + 2] == 0x00 and bytecode[i + 3] == 0x67) {
            return true;
        }
    }

    return false;
}

/// Detect clone pattern (minimal proxy variant)
fn detectClonePattern(bytecode: []const u8) bool {
    // Clone pattern is similar to minimal proxy but:
    // - Usually shorter
    // - Uses CREATE in init code

    if (bytecode.len > 100) {
        return false;
    }

    // Look for clone pattern signatures in shorter bytecode
    // Clones typically have: EXTCODESIZE check + DELEGATECALL
    var has_extcodesize = false;
    var has_delegatecall = false;

    for (bytecode) |byte| {
        if (byte == 0x3b) has_extcodesize = true; // EXTCODESIZE
        if (byte == 0xf4) has_delegatecall = true; // DELEGATECALL
    }

    return has_extcodesize and has_delegatecall;
}

/// Get human-readable description of deployment type
pub fn getDeploymentDescription(deployment_type: DeploymentType) []const u8 {
    return switch (deployment_type) {
        .regular => "Regular Contract",
        .factory => "Factory Contract",
        .proxy => "Generic Proxy",
        .minimal_proxy => "Minimal Proxy (EIP-1167)",
        .transparent_proxy => "Transparent Proxy (EIP-1967)",
        .uups_proxy => "UUPS Proxy (EIP-1822)",
        .beacon_proxy => "Beacon Proxy",
        .clone => "Clone/Minimal Proxy",
        .diamond => "Diamond Proxy (EIP-2535)",
    };
}

/// Estimate deployment gas cost
pub fn estimateDeploymentGas(bytecode: []const u8) u64 {
    // Base deployment cost: 32000 gas
    var gas: u64 = 32000;

    // Per byte of initcode: 200 gas
    gas += bytecode.len * 200;

    // Add costs for deployment operations
    var create_count: usize = 0;
    var create2_count: usize = 0;

    for (bytecode) |byte| {
        if (byte == 0xf0) create_count += 1; // CREATE
        if (byte == 0xf5) create2_count += 1; // CREATE2
    }

    // CREATE/CREATE2 cost
    gas += create_count * 32000;
    gas += create2_count * 32000;

    return gas;
}
