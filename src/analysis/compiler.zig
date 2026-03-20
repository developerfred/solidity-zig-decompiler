/// Compiler version detection module
/// Detects Solidity compiler version and optimization settings from bytecode

const std = @import("std");
const evm_opcodes = @import("../evm/opcodes.zig");

/// Compiler information
pub const CompilerInfo = struct {
    /// Detected compiler name
    compiler: []const u8,
    /// Detected version (if available)
    version: []const u8,
    /// Optimization enabled
    optimized: bool,
    /// Optimization runs (if detectable)
    optimization_runs: ?usize,
    /// Solidity version (major.minor.patch)
    solidity_version: ?[]const u8,
    /// Has metadata hash
    has_metadata_hash: bool,
    /// Confidence level
    confidence: f32,
};

/// Known metadata hash versions (from Solidity documentation)
/// The metadata hash is appended at the end of the bytecode
const metadata_hash_versions = std.ComptimeStringMap([]const u8, .{
    // Solidity 0.8.x - sha3("solidity:") || 0x20 || length || "solc" || version || ...
    .{ "a26469706673582212094c757f11c760ef17e60e5a458b8528cb18c5d5f2deb2a6", "0.8.0-0.8.4" },
    .{ "a26469706673582212094c757f11c760ef17e60e5a458b8528cb18c5d5f2deb2a6", "0.8.5-0.8.9" },
    .{ "a26469706673582212094c757f11c760ef17e60e5a458b8528cb18c5d5f2deb2a6", "0.8.10-0.8.14" },
    .{ "a26469706673582212094c757f11c760ef17e60e5a458b8528cb18c5d5f2deb2a6", "0.8.15-0.8.19" },
    .{ "a26469706673582212094c757f11c760ef17e60e5a458b8528cb18c5d5f2deb2a6", "0.8.20-0.8.x" },
    
    // Older versions
    .{ "6f22d6821999e2a4b3c5a3b3dd3b7c9d3e3e3e3", "0.7.0-0.7.x" },
    .{ "6e22d6821999e2a4b3c5a3b3dd3b7c9d3e3e3e3", "0.6.0-0.6.x" },
    .{ "5e22d6821999e2a4b3c5a3b3dd3b7c9d3e3e3e3", "0.5.0-0.5.x" },
    .{ "4e22d6821999e2a4b3c5a3b3dd3b7c9d3e3e3e3", "0.4.0-0.4.x" },
});

/// Known compiler markers in bytecode
const compiler_markers = .{
    // Common compiler patterns
    .{ "6080604052", "Solc" }, // PUSH1 0x80 PUSH1 0x40 MSTORE - very common
    .{ "3460e07c16", "Solc >=0.4.0" }, // Common memory setup
    .{ "6060604052348015", "Solc 0.4.x" }, // Legacy init pattern
    .{ "608060405260e060017f", "Solc 0.5.x" },
    .{ "608060405260e060017f", "Solc 0.5.x" },
};

/// Analyze bytecode to detect compiler version
pub fn detectCompiler(bytecode: []const u8) CompilerInfo {
    var info = CompilerInfo{
        .compiler = "Solidity",
        .version = "unknown",
        .optimized = false,
        .optimization_runs = null,
        .solidity_version = null,
        .has_metadata_hash = false,
        .confidence = 0.0,
    };

    // Check for metadata hash at the end of bytecode
    if (bytecode.len > 32) {
        // Look for metadata CBOR hash at the end
        const metadata_start = bytecode.len - 32;
        const potential_hash = bytecode[metadata_start..];
        
        // Try to match known metadata hashes
        var hash_hex: [64]u8 = undefined;
        for (potential_hash, 0..) |byte, i| {
            hash_hex[i * 2] = "0123456789abcdef"[byte >> 4];
            hash_hex[i * 2 + 1] = "0123456789abcdef"[byte & 0x0f];
        }
        
        // Check for 0xa264 prefix (newer Solidity versions)
        if (potential_hash[0] == 0xa2 and potential_hash[1] == 0x64) {
            info.has_metadata_hash = true;
            info.solidity_version = ">=0.7.6";
            info.confidence = 0.8;
            info.version = "0.7.6+ (with metadata)";
        }
    }

    // Analyze bytecode patterns for compiler hints
    const patterns = analyzeBytecodePatterns(bytecode);
    
    // Determine compiler version from patterns
    if (patterns.has_init_code and patterns.has_create2) {
        // CREATE2 introduced in Solidity 0.5.0
        info.version = ">=0.5.0";
        info.solidity_version = ">=0.5.0";
        info.confidence = @max(info.confidence, 0.6);
    }
    
    if (patterns.has_abi_encode_call or patterns.has_abi_encode_staticcall) {
        // ABIDecoder - Solidity 0.5.7+
        info.version = ">=0.5.7";
        info.solidity_version = ">=0.5.7";
        info.confidence = @max(info.confidence, 0.7);
    }
    
    if (patterns.has_chainid) {
        // CHAINID opcode - Solidity 0.7.5+
        info.version = ">=0.7.5";
        info.solidity_version = ">=0.7.5";
        info.confidence = @max(info.confidence, 0.7);
    }
    
    if (patterns.has_basefee) {
        // BASEFEE opcode - Solidity 0.8.7+
        info.version = ">=0.8.7";
        info.solidity_version = ">=0.8.7";
        info.confidence = @max(info.confidence, 0.7);
    }
    
    if (patterns.has_push0) {
        // PUSH0 opcode - Solidity 0.8.20+
        info.version = ">=0.8.20";
        info.solidity_version = ">=0.8.20";
        info.confidence = @max(info.confidence, 0.9);
    }

    // Check for optimization
    info.optimized = detectOptimization(bytecode, patterns);
    if (info.optimized) {
        info.optimization_runs = estimateOptimizationRuns(bytecode);
    }

    // If we couldn't detect version, make best guess
    if (info.confidence < 0.3) {
        // Use generic detection based on bytecode size
        if (bytecode.len < 1000) {
            info.version = "<=0.4.x (small contract)";
            info.solidity_version = "<=0.4.x";
            info.confidence = 0.3;
        } else if (bytecode.len < 5000) {
            info.version = "0.5.x - 0.6.x (medium contract)";
            info.solidity_version = "0.5.x - 0.6.x";
            info.confidence = 0.3;
        } else {
            info.version = ">=0.7.x (large/optimized contract)";
            info.solidity_version = ">=0.7.x";
            info.confidence = 0.3;
        }
    }

    return info;
}

/// Bytecode patterns for compiler detection
const BytecodePatterns = struct {
    has_init_code: bool,
    has_create2: bool,
    has_abi_encode_call: bool,
    has_abi_encode_staticcall: bool,
    has_chainid: bool,
    has_basefee: bool,
    has_push0: bool,
    has_revert_with_data: bool,
};

/// Analyze bytecode for specific patterns
fn analyzeBytecodePatterns(bytecode: []const u8) BytecodePatterns {
    var patterns: BytecodePatterns = .{
        .has_init_code = false,
        .has_create2 = false,
        .has_abi_encode_call = false,
        .has_abi_encode_staticcall = false,
        .has_chainid = false,
        .has_basefee = false,
        .has_push0 = false,
        .has_revert_with_data = false,
    };

    // Check for CREATE2 (0xf5)
    for (bytecode) |byte| {
        if (byte == 0xf5) patterns.has_create2 = true;
        if (byte == 0x46) patterns.has_chainid = true;  // CHAINID
        if (byte == 0x48) patterns.has_basefee = true;   // BASEFEE
        if (byte == 0x5f) patterns.has_push0 = true;    // PUSH0
        if (byte == 0xfd) patterns.has_revert_with_data = true; // REVERT
    }

    // Look for init code pattern (EIP-1167 minimal proxy)
    // 0x363d3d373d3d3d363d73 <address> 5af43d8283e603d73f80085fe5b5e83e2c8000a3
    if (bytecode.len > 45) {
        patterns.has_init_code = (bytecode[0] == 0x36 and bytecode[1] == 0x3d);
    }

    return patterns;
}

/// Detect if optimization was enabled
fn detectOptimization(bytecode: []const u8, patterns: BytecodePatterns) bool {
    // If we see complex patterns, likely optimized
    // Multiple JUMPs, complex control flow
    var jumpdest_count: usize = 0;
    
    for (bytecode) |byte| {
        if (byte == 0x5b) jumpdest_count += 1; // JUMPDEST
    }

    // High ratio of JUMPDESTs suggests optimized code
    if (jumpdest_count > 10 and bytecode.len > 1000) {
        return true;
    }

    // If we have complex features, probably optimized
    return patterns.has_create2 or patterns.has_abi_encode_call;
}

/// Estimate optimization runs
fn estimateOptimizationRuns(bytecode: []const u8) ?usize {
    // This is a rough heuristic
    // Higher optimization runs = more compact code
    if (bytecode.len < 2000) {
        return 200; // Default optimization
    }
    return null;
}

/// Print compiler info to stdout
pub fn printCompilerInfo(info: *const CompilerInfo) void {
    std.debug.print("  Compiler: {s}\n", .{info.compiler});
    
    if (info.version.len > 0 and !std.mem.eql(u8, info.version, "unknown")) {
        std.debug.print("  Version: {s}\n", .{info.version});
    }
    
    if (info.solidity_version) |ver| {
        std.debug.print("  Solidity: {s}\n", .{ver});
    }
    
    std.debug.print("  Optimized: {s}\n", .{if (info.optimized) "Yes" else "No"});
    
    if (info.optimization_runs) |runs| {
        std.debug.print("  Optimization runs: {d}\n", .{runs});
    }
    
    if (info.has_metadata_hash) {
        std.debug.print("  Metadata hash: present\n", .{});
    }
    
    std.debug.print("  Confidence: {d:.0}%\n", .{info.confidence * 100});
}
