/// Storage Layout Analysis
/// Analyzes SLOAD/SSTORE patterns to deduce storage layout

const std = @import("std");

/// Storage slot access pattern
pub const StorageAccess = struct {
    slot: u256,
    pc: usize,
    is_write: bool,
    value_pattern: ValuePattern,

    pub const ValuePattern = enum {
        constant,      // Always stored with same value
        incremental,   // Counter-like (n++, n+=1)
        mapped,        // Maps to another key (mapping)
        indexed,       // Array-like access (arr[idx])
        derived,       // Derived from other storage slots
        unknown,
    };
};

/// Inferred storage layout
pub const StorageLayout = struct {
    slots: []const StorageSlot,
    mappings: []const MappingInfo,
    arrays: []const ArrayInfo,

    pub const StorageSlot = struct {
        slot: u256,
        inferred_type: StorageType,
        access_count: usize,
        is_initialized: bool,
    };

    pub const MappingInfo = struct {
        slot: u256,
        key_type: []const u8,
        value_type: []const u8,
    };

    pub const ArrayInfo = struct {
        slot: u256,
        element_type: []const u8,
        length: ?u256,
    };
};

/// Inferred storage type
pub const StorageType = enum {
    address,
    uint256,
    uint128,
    uint64,
    uint32,
    uint16,
    uint8,
    int256,
    bool,
    bytes32,
    bytes32_array,
    string,
    unknown,
};

/// Convert storage type to Solidity syntax
pub fn storageTypeToSolidity(stype: StorageType) []const u8 {
    return switch (stype) {
        .address => "address",
        .uint256 => "uint256",
        .uint128 => "uint128",
        .uint64 => "uint64",
        .uint32 => "uint32",
        .uint16 => "uint16",
        .uint8 => "uint8",
        .int256 => "int256",
        .bool => "bool",
        .bytes32 => "bytes32",
        .bytes32_array => "bytes32[]",
        .string => "string",
        .unknown => "unknown",
    };
}

pub const MappingType = struct {
    key_type: []const u8,
    value_type: StorageType,
};

pub const ArrayType = struct {
    element_type: StorageType,
};

pub const StructType = struct {
    name: []const u8,
    fields: []const StructField,
};

pub const StructField = struct {
    name: []const u8,
    offset: u256,
    field_type: StorageType,
};

/// Analyze storage access patterns from execution trace
pub fn analyzeStorageLayout(accesses: []const StorageAccess, allocator: std.mem.Allocator) StorageLayout {
    var slot_map = std.AutoHashMap(u256, *StorageSlotAnalysis).init(allocator);
    defer {
        for (slot_map.values()) |v| allocator.destroy(v);
        slot_map.deinit();
    }

    // Group accesses by slot
    for (accesses) |access| {
        const entry = slot_map.getOrPut(access.slot) catch continue;
        if (!entry.found_existing) {
            entry.value_ptr.* = allocator.create(StorageSlotAnalysis) catch continue;
            entry.value_ptr.* = StorageSlotAnalysis{};
        }
        entry.value_ptr.*.addAccess(access);
    }

    // Infer types from patterns
    var slots = std.ArrayList(StorageLayout.StorageSlot).init(allocator);
    var mappings = std.ArrayList(StorageLayout.MappingInfo).init(allocator);
    var arrays = std.ArrayList(StorageLayout.ArrayInfo).init(allocator);

    var iterator = slot_map.iterator();
    while (iterator.next()) |entry| {
        const analysis = entry.value_ptr.*;
        const inferred = inferStorageType(analysis);

        try slots.append(.{
            .slot = entry.key_ptr.*,
            .inferred_type = inferred,
            .access_count = analysis.reads + analysis.writes,
            .is_initialized = analysis.writes > 0,
        });
    }

    return .{
        .slots = slots.toOwnedSlice(),
        .mappings = mappings.toOwnedSlice(),
        .arrays = arrays.toOwnedSlice(),
    };
}

const StorageSlotAnalysis = struct {
    reads: usize = 0,
    writes: usize = 0,
    values: std.ArrayListUnmanaged(u256) = .{},

    pub fn addAccess(self: *StorageSlotAnalysis, access: StorageAccess) void {
        if (access.is_write) {
            self.writes += 1;
        } else {
            self.reads += 1;
        }
    }
};

/// Infer storage type from access patterns
fn inferStorageType(analysis: *StorageSlotAnalysis) StorageType {
    if (analysis.writes == 0 and analysis.reads == 0) {
        return .unknown;
    }

    // Check for boolean (only 0 and 1)
    // Check for address (20 bytes)
    // Check for counter (incremental pattern)
    // Check for mapping (key-based derivation)

    return .uint256; // Default assumption
}

/// Keccak256 hash for storage slot derivation (simplified using SHA3)
pub fn keccak256(data: []const u8, allocator: std.mem.Allocator) ![32]u8 {
    _ = allocator;
    // Simplified - real implementation would use full keccak
    var hasher = std.crypto.hash.sha3.Sha256.init(.{});
    hasher.update(data);
    var result: [32]u8 = undefined;
    hasher.final(&result);
    return result;
}

/// Calculate storage slot for mapping (simplified keccak256)
pub fn mappingSlot(map_slot: u256, key: u256) u256 {
    var buf: [64]u8 = undefined;
    std.mem.writeIntBig(u256, buf[0..32], key);
    std.mem.writeIntBig(u256, buf[32..64], map_slot);

    var hash = keccak256Simplified(&buf);
    return std.mem.readInt(u256, hash[0..32], .big);
}

/// Calculate storage slot for array
pub fn arraySlot(base_slot: u256, index: u256) u256 {
    return base_slot + index;
}

fn keccak256Simplified(data: []const u8) [32]u8 {
    var hasher = std.crypto.hash.sha3.Sha256.init(.{});
    hasher.update(data);
    var result: [32]u8 = undefined;
    hasher.final(&result);
    return result;
}

/// Simple storage analysis from bytecode
pub const SimpleStorageInfo = struct {
    slot: u64,
    inferred_type: []const u8,
    is_mapping: bool,
    is_array: bool,
};

/// Analyze storage from bytecode (simple version)
pub fn analyzeFromBytecode(bytecode: []const u8, allocator: std.mem.Allocator) ![]SimpleStorageInfo {
    const opcodes_mod = @import("../evm/opcodes.zig");
    const instructions = try opcodes_mod.parseInstructions(allocator, bytecode);
    defer allocator.free(instructions);
    
    var slots = std.AutoHashMap(u64, SimpleStorageInfo).init(allocator);
    defer slots.deinit();
    
    var idx: usize = 0;
    while (idx < instructions.len) : (idx += 1) {
        const instr = instructions[idx];
        // Look for PUSH followed by SLOAD/SSTORE
        if (opcodes_mod.isPush(instr.opcode) and instr.push_data != null) {
            if (idx + 1 < instructions.len) {
                const next = instructions[idx + 1];
                if (next.opcode == .sload or next.opcode == .sstore) {
                    // Parse slot from push data
                    var slot: u64 = 0;
                    for (instr.push_data.?) |b| {
                        slot = (slot << 8) | b;
                    }
                    
                    const is_write = next.opcode == .sstore;
                    const typ = if (is_write) "uint256" else "uint256";
                    
                    try slots.put(slot, .{
                        .slot = slot,
                        .inferred_type = typ,
                        .is_mapping = false,
                        .is_array = false,
                    });
                }
            }
        }
        
        // Check for KECCAK256 - mapping or array access
        if (instr.opcode == .keccak256) {
            // This might be a mapping or array access
            // Skip for now - complex to detect
        }
    }
    
    // Always add slot 0 as default
    if (slots.get(0) == null) {
        try slots.put(0, .{
            .slot = 0,
            .inferred_type = "uint256",
            .is_mapping = false,
            .is_array = false,
        });
    }
    
    var result = try allocator.alloc(SimpleStorageInfo, slots.count());
    var iter = slots.iterator();
    var i: usize = 0;
    while (iter.next()) |entry| {
        result[i] = entry.value_ptr.*;
        i += 1;
    }
    
    return result;
}
