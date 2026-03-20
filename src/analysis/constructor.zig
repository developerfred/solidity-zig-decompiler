/// Constructor analysis module
/// Detects constructor bytecode, extracts constructor arguments, and identifies immutable variables

const std = @import("std");
const evm_opcodes = @import("../evm/opcodes.zig");

/// Constructor information
pub const ConstructorInfo = struct {
    /// Whether constructor was detected
    has_constructor: bool,
    /// Constructor bytecode offset (where runtime code starts)
    constructor_end: usize,
    /// Runtime bytecode offset
    runtime_offset: usize,
    /// Constructor arguments detected
    arguments: []const Argument,
    /// Immutable variables detected
    immutables: []const ImmutableVar,
    /// Deployer address detected
    deployer: ?[]const u8,
    /// Salt value (for CREATE2)
    salt: ?[]const u8,

    pub fn deinit(self: *ConstructorInfo, alloc: std.mem.Allocator) void {
        for (self.arguments) |arg| {
            alloc.free(arg.name);
        }
        alloc.free(self.arguments);
        for (self.immutables) |imm| {
            alloc.free(imm.name);
        }
        alloc.free(self.immutables);
    }
};

/// Constructor argument
pub const Argument = struct {
    /// Argument name
    name: []const u8,
    /// Argument type (inferred)
    type_str: []const u8,
    /// Position in bytecode
    position: usize,
    /// Value (if detectable)
    value: ?u64,
};

/// Immutable variable
pub const ImmutableVar = struct {
    /// Variable name
    name: []const u8,
    /// Storage slot
    slot: u64,
    /// Value set in constructor
    value: ?u256,
    /// Type inference
    type_str: []const u8,
};

/// Analyze constructor bytecode
pub fn analyzeConstructor(bytecode: []const u8, alloc: std.mem.Allocator) !ConstructorInfo {
    var info = ConstructorInfo{
        .has_constructor = false,
        .constructor_end = 0,
        .runtime_offset = 0,
        .arguments = &.{},
        .immutables = &.{},
        .deployer = null,
        .salt = null,
    };

    // Try to detect constructor pattern
    const constructor_result = detectConstructor(bytecode, alloc);
    
    if (constructor_result.found) {
        info.has_constructor = true;
        info.constructor_end = constructor_result.constructor_end;
        info.runtime_offset = constructor_result.runtime_offset;
        
        // Extract constructor arguments
        info.arguments = try extractConstructorArgs(bytecode, alloc);
        
        // Detect immutable variables
        info.immutables = try detectImmutables(bytecode, alloc);
    }

    return info;
}

/// Result of constructor detection
const DetectionResult = struct {
    found: bool,
    constructor_end: usize,
    runtime_offset: usize,
};

/// Detect constructor bytecode pattern
fn detectConstructor(bytecode: []const u8, alloc: std.mem.Allocator) DetectionResult {
    _ = alloc; // Reserved for future use
    // Pattern 1: Library linking (0xfe)
    // Libraries have 0xfe at the beginning (INVALID opcode as marker)
    if (bytecode.len > 0 and bytecode[0] == 0xfe) {
        // Try to find actual code start
        var i: usize = 0;
        while (i < bytecode.len and bytecode[i] == 0xfe) : (i += 1) {}
        if (i < bytecode.len and bytecode[i] == 0x61) { // PUSH2
            return DetectionResult{
                .found = true,
                .constructor_end = 0,
                .runtime_offset = i - 1,
            };
        }
    }

    // Pattern 2: EIP-170 (contract size limit) - not relevant for constructor
    
    // Pattern 3: Check for metadata hash at the end (0xa2 0x65...)
    // This indicates runtime code exists
    var runtime_start: usize = 0;
    
    // Try to find where runtime code starts by looking for common patterns
    // Constructor typically ends with RETURN or REVERT
    var i: usize = 0;
    while (i < bytecode.len) : (i += 1) {
        const opcode = bytecode[i];
        
        // RETURN (0xf3) followed by codecopy pattern indicates end of constructor
        if (opcode == 0xf3) { // RETURN
            // Check if there's code after RETURN (runtime code)
            if (i + 1 < bytecode.len) {
                // Look for CODECOPY (0x39) or similar
                runtime_start = i + 1;
                break;
            }
        }
        
        // CREATE2 (0xf5) also marks end of deployment code
        if (opcode == 0xf5) {
            if (i + 1 < bytecode.len) {
                runtime_start = i + 1;
                break;
            }
        }
    }

    // If we found a runtime section
    if (runtime_start > 0 and runtime_start < bytecode.len) {
        return DetectionResult{
            .found = true,
            .constructor_end = runtime_start,
            .runtime_offset = runtime_start,
        };
    }

    // No clear constructor boundary found
    // Assume it's all runtime code (library or direct deployment)
    return DetectionResult{
        .found = false,
        .constructor_end = 0,
        .runtime_offset = 0,
    };
}

/// Extract constructor arguments from deployment calldata
fn extractConstructorArgs(bytecode: []const u8, alloc: std.mem.Allocator) ![]const Argument {
    // In Solidity, constructor arguments are appended to the end of the bytecode
    // The metadata hash (at the end) contains information about the length
    
    // Look for patterns in constructor code that indicate argument handling
    // Common: calldataload, calldatasize, codecopy with argument lengths
    
    // Try to detect number of arguments by analyzing constructor
    const instructions = evm_opcodes.parseInstructions(alloc, bytecode[0..20]) catch {
        return &.{};
    };
    defer alloc.free(instructions);
    
    // Look for constructor pattern - typically loads calldata at position 0
    var calldata_args: usize = 0;
    
    for (instructions) |instr| {
        switch (instr.opcode) {
            .calldataload, .calldatasize, .calldatacopy => {
                calldata_args += 1;
            },
            else => {},
        }
    }

    // Heuristic: more calldata operations = more arguments
    // This is a rough estimate
    if (calldata_args > 0) {
        // Add inferred arguments
        const arg_count = @min(calldata_args, 5); // Cap at 5
        var args = try alloc.alloc(Argument, arg_count);
        for (0..arg_count) |j| {
            const name = try std.fmt.allocPrint(alloc, "arg_{d}", .{j});
            const arg_type = inferArgType(j, calldata_args);
            args[j] = Argument{
                .name = name,
                .type_str = arg_type,
                .position = j * 32,
                .value = null,
            };
        }
        return args;
    }

    return &.{};
}

/// Infer argument type based on position
fn inferArgType(index: usize, total: usize) []const u8 {
    _ = total;
    // Common constructor argument patterns
    switch (index) {
        0 => return "address",
        1 => return "uint256",
        2 => return "address",
        3 => return "uint256",
        else => return "bytes32",
    }
}

/// Detect immutable variables set in constructor
fn detectImmutables(bytecode: []const u8, alloc: std.mem.Allocator) ![]const ImmutableVar {
    // Parse instructions to find immutable patterns
    // Pattern: SLOAD after SSTORE in early bytecode (constructor)
    const instructions = evm_opcodes.parseInstructions(alloc, bytecode) catch {
        return &.{};
    };
    defer alloc.free(instructions);
    
    // Track SSTORE in first portion (constructor)
    const constructor_end = @min(instructions.len, 100);
    
    var slot_values = std.AutoArrayHashMap(u64, u256).init(alloc);
    defer slot_values.deinit();
    
    // Find SSTORE in constructor section
    for (instructions[0..constructor_end]) |instr| {
        if (instr.opcode == .sstore) {
            // Try to get slot from stack
            // This is simplified - real implementation would track stack
        }
    }
    
    // Check for common immutable patterns:
    // 1. SSTORE followed by SLOAD in runtime
    // 2. Specific slot patterns (e.g., keccak of "immutable:")

    // Look for storage operations in constructor - count SSTOREs
    var sstore_count: usize = 0;
    for (instructions, 0..) |instr, idx| {
        if (idx > constructor_end) break;
        
        if (instr.opcode == .sstore) {
            sstore_count += 1;
        }
    }

    // If we found potential immutable setters, create entries
    if (sstore_count > 0) {
        var immutables = try alloc.alloc(ImmutableVar, sstore_count);
        var slot_idx: usize = 0;
        for (instructions, 0..) |instr, idx| {
            if (idx > constructor_end) break;
            
            if (instr.opcode == .sstore) {
                const slot = @as(u64, @truncate(idx));
                const name = try std.fmt.allocPrint(alloc, "_immutable_{d}", .{slot_idx});
                immutables[slot_idx] = ImmutableVar{
                    .name = name,
                    .slot = slot,
                    .value = null,
                    .type_str = "uint256",
                };
                slot_idx += 1;
            }
        }
        return immutables;
    }

    return &.{};
}

/// Get runtime bytecode (without constructor)
pub fn getRuntimeBytecode(bytecode: []const u8, alloc: std.mem.Allocator) ![]const u8 {
    const info = try analyzeConstructor(bytecode, alloc);
    defer info.deinit(alloc);
    
    if (!info.has_constructor or info.runtime_offset == 0) {
        // No constructor - return full bytecode
        return bytecode;
    }
    
    return bytecode[info.runtime_offset..];
}

/// Print constructor analysis to stdout
pub fn printConstructorInfo(info: *const ConstructorInfo) void {
    if (!info.has_constructor) {
        std.debug.print("  No constructor detected\n", .{});
        return;
    }

    std.debug.print("  Constructor detected\n", .{});
    std.debug.print("    Runtime code starts at: 0x{x}\n", .{info.runtime_offset});
    
    if (info.arguments.len > 0) {
        std.debug.print("\n  Constructor arguments:\n", .{});
        for (info.arguments) |arg| {
            std.debug.print("    {s} {s}", .{ arg.type_str, arg.name });
            if (arg.value) |v| {
                std.debug.print(" = {d}", .{v});
            }
            std.debug.print("\n", .{});
        }
    }
    
    if (info.immutables.len > 0) {
        std.debug.print("\n  Immutable variables:\n", .{});
        for (info.immutables) |imm| {
            std.debug.print("    {s} {s} (slot: {d})\n", .{ imm.type_str, imm.name, imm.slot });
        }
    }
}
