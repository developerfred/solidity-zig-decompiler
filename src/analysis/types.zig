/// Advanced Type Inference for Solidity decompilation
/// Analyzes bytecode patterns to infer Solidity types

const std = @import("std");
const opcodes = @import("../evm/opcodes.zig");
const Opcode = opcodes.Opcode;

/// Inferred Solidity type
pub const SolidityType = enum {
    unknown,
    uint256,
    uint128,
    uint64,
    uint32,
    uint16,
    uint8,
    int256,
    int128,
    int64,
    int32,
    address,
    bool,
    bytes32,
    bytes,
    string,
    array,
    mapping,
};

/// Slot packing information
pub const PackingInfo = struct {
    packed_slots: []PackedVar,
    confidence: f32,
};

/// Packed variable in a slot
pub const PackedVar = struct {
    slot_offset: usize,
    type_str: []const u8,
    byte_size: u8,
};

/// Mapping detection information
pub const MappingInfo = struct {
    mappings: []DetectedMapping,
    confidence: f32,
};

/// Detected mapping
pub const DetectedMapping = struct {
    key_type: []const u8,
    value_type: []const u8,
    slot: u64,
};

/// Array detection information
pub const ArrayInfo = struct {
    arrays: []DetectedArray,
    confidence: f32,
};

/// Detected array
pub const DetectedArray = struct {
    slot: u64,
    element_type: []const u8,
    is_dynamic: bool,
};

/// Struct detection information
pub const StructInfo = struct {
    structs: []StructField,
    confidence: f32,
};

/// Struct field
pub const StructField = struct {
    name: []const u8,
    field_type: []const u8,
    slot: u64,
};

/// Type with confidence
pub const InferredType = struct {
    type: SolidityType,
    confidence: f32, // 0.0 to 1.0
};

/// Analyze bytecode to infer types
pub const TypeAnalyzer = struct {
    allocator: std.mem.Allocator,
    
    /// Analyze function parameters from bytecode
    pub fn analyzeParams(self: TypeAnalyzer, bytecode: []const u8, func_entry_pc: usize) ![]ParamType {
        const instructions = try opcodes.parseInstructions(self.allocator, bytecode);
        defer self.allocator.free(instructions);
        
        var params = std.ArrayListUnmanaged(ParamType){};
        
        // Find function start
        var start_idx: usize = 0;
        for (instructions, 0..) |instr, i| {
            if (instr.pc == func_entry_pc) {
                start_idx = i;
                break;
            }
        }
        
        // Look for common parameter patterns in first ~20 instructions
        var offset: usize = 0;
        var param_count: usize = 0;
        
        const end_idx = @min(start_idx + 20, instructions.len);
        for (instructions[start_idx..end_idx]) |instr| {
            // Pattern 1: calldataload with incrementing offset
            if (instr.opcode == .calldataload) {
                const param_type = self.inferFromCalldataLoad(instructions, start_idx + offset);
                try params.append(self.allocator, .{
                    .name = try std.fmt.allocPrint(self.allocator, "param{}", .{param_count}),
                    .type_str = param_type,
                });
                param_count += 1;
                offset += 1;
            }
            offset += 1;
        }
        
        return params.toOwnedSlice(self.allocator);
    }
    
    /// Infer type from calldataload context
    fn inferFromCalldataLoad(self: TypeAnalyzer, instructions: []const opcodes.Instruction, idx: usize) []const u8 {
        _ = self;
        
        // Look for 15 instructions around the calldataload for patterns
        const start = if (idx > 7) idx - 7 else 0;
        const end = @min(idx + 8, instructions.len);
        
        var i: usize = start;
        while (i < end) : (i += 1) {
            const instr = instructions[i];
            
            // Check for SHR (right shift) - address detection
            if (instr.opcode == .shr) {
                const next_idx = i + 1;
                if (next_idx < instructions.len) {
                    const next = instructions[next_idx];
                    if (next.opcode == .push1) {
                        if (next.push_data) |data| {
                            // SHR 0xe0 = right shift 224 = bytes20 = address
                            if (data.len == 1 and data[0] == 0xe0) {
                                return "address";
                            }
                            // SHR 0xf8 = right shift 248 = bytes1
                            if (data.len == 1 and data[0] == 0xf8) {
                                return "bytes1";
                            }
                        }
                    }
                }
            }
            
            // Check for AND - small integer detection
            if (instr.opcode == .bitand) {
                const next_idx = i + 1;
                if (next_idx < instructions.len) {
                    const next = instructions[next_idx];
                    if (next.opcode == .push1) {
                        if (next.push_data) |data| {
                            // AND 0xff = uint8/bytes1
                            if (data.len == 1 and data[0] == 0xff) {
                                return "uint8";
                            }
                            // AND 0xffff = uint16
                            if (data.len == 2 and data[0] == 0xff and data[1] == 0xff) {
                                return "uint16";
                            }
                            // AND 0xffffffff = uint32
                            if (data.len == 4) {
                                return "uint32";
                            }
                        }
                    }
                }
            }
            
            // Check for DIV - often used with uint64/uint128
            if (instr.opcode == .div) {
                const prev_idx = i - 1;
                if (prev_idx > 0) {
                    const prev = instructions[prev_idx];
                    if (prev.opcode == .push1) {
                        if (prev.push_data) |data| {
                            // DIV by 0x100 = shift right 8 = uint8 extraction
                            if (data.len == 1 and data[0] == 0x100) {
                                return "uint8";
                            }
                        }
                    }
                }
            }
            
            // Check for BYTE - extracting bytes from bytes32
            if (instr.opcode == .byte) {
                return "bytes32";
            }
        }
        
        return "uint256";
    }
    
    /// Analyze storage slot type
    pub fn analyzeStorageSlot(self: TypeAnalyzer, bytecode: []const u8, slot: u64) !InferredType {
        _ = slot;
        const instructions = try opcodes.parseInstructions(self.allocator, bytecode);
        defer self.allocator.free(instructions);
        
        var sload_count: usize = 0;
        var sstore_count: usize = 0;
        var uses_balance = false;
        var uses_caller = false;
        var uses_address = false;
        var comparison_count: usize = 0;
        var iszero_count: usize = 0;
        var byte_access_count: usize = 0;
        var mstore_count: usize = 0;
        
        for (instructions) |instr| {
            switch (instr.opcode) {
                .sload => sload_count += 1,
                .sstore => sstore_count += 1,
                .balance => uses_balance = true,
                .caller => uses_caller = true,
                .address => uses_address = true,
                .byte => byte_access_count += 1,
                .mstore, .mstore8 => mstore_count += 1,
                .eq, .lt, .gt, .slt, .sgt => comparison_count += 1,
                .bitand, .bitor, .xor => comparison_count += 1,
                .iszero => iszero_count += 1,
                else => {},
            }
        }
        
        // Infer type based on usage patterns (ordered by specificity)
        
        // Address detection - highest confidence when balance/caller/address used
        if (uses_balance or uses_caller) {
            return .{
                .type = .address,
                .confidence = 0.95,
            };
        }
        
        // Bool detection - ISZERO after loads/stores, or multiple comparisons
        if (iszero_count > 0 and sload_count > 0) {
            return .{
                .type = .bool,
                .confidence = 0.85,
            };
        }
        
        // bytes32 detection - byte access patterns
        if (byte_access_count > 0) {
            return .{
                .type = .bytes32,
                .confidence = 0.8,
            };
        }
        
        // Address - used with address opcode
        if (uses_address and sload_count > 0) {
            return .{
                .type = .address,
                .confidence = 0.75,
            };
        }
        
        // Bool - comparison-heavy code
        if (comparison_count > sload_count + sstore_count) {
            return .{
                .type = .bool,
                .confidence = 0.7,
            };
        }
        
        // uint256 - default for storage
        if (sstore_count > 0) {
            return .{
                .type = .uint256,
                .confidence = 0.65,
            };
        }
        
        // bytes32 - used with memory
        if (mstore_count > 0 and sload_count > 0) {
            return .{
                .type = .bytes32,
                .confidence = 0.5,
            };
        }
        
        return .{
            .type = .unknown,
            .confidence = 0.0,
        };
    }
    
    /// Get Solidity type string from inferred type
    pub fn typeToString(t: SolidityType) []const u8 {
        return switch (t) {
            .unknown => "uint256",
            .uint256 => "uint256",
            .uint128 => "uint128",
            .uint64 => "uint64",
            .uint32 => "uint32",
            .uint16 => "uint16",
            .uint8 => "uint8",
            .int256 => "int256",
            .int128 => "int128",
            .int64 => "int64",
            .int32 => "int32",
            .address => "address",
            .bool => "bool",
            .bytes32 => "bytes32",
            .bytes => "bytes",
            .string => "string",
            .array => "array",
            .mapping => "mapping",
        };
    }

    /// Detect slot packing - when multiple values share a storage slot
    /// Solidity can pack multiple small values into one slot
    pub fn detectSlotPacking(self: TypeAnalyzer, bytecode: []const u8) !PackingInfo {
        const instructions = try opcodes.parseInstructions(self.allocator, bytecode);
        defer self.allocator.free(instructions);

        // Find consecutive SSTORE patterns that might indicate packing
        var packed_vars: [10]PackedVar = undefined;
        var packed_count: usize = 0;

        var last_sstore_pc: usize = 0;
        var consecutive_sstores: usize = 0;

        for (instructions) |instr| {
            if (instr.opcode == .sstore) {
                if (last_sstore_pc > 0 and instr.pc - last_sstore_pc < 20) {
                    consecutive_sstores += 1;
                } else {
                    consecutive_sstores = 1;
                }
                last_sstore_pc = instr.pc;

                // If multiple consecutive SSTOREs, might be packed
                if (consecutive_sstores >= 2 and packed_count < 10) {
                    const var_type = self.inferPackedVarType(instructions, instr.pc);
                    packed_vars[packed_count] = .{
                        .slot_offset = consecutive_sstores - 1,
                        .type_str = var_type,
                        .byte_size = estimateByteSize(var_type),
                    };
                    packed_count += 1;
                }
            }
        }

        if (packed_count > 0) {
            const slice = try self.allocator.alloc(PackedVar, packed_count);
            @memcpy(slice, packed_vars[0..packed_count]);
            return .{
                .packed_slots = slice,
                .confidence = 0.7,
            };
        }

        return .{
            .packed_slots = &.{},
            .confidence = 0.0,
        };
    }

    /// Infer type for packed variable
    fn inferPackedVarType(self: TypeAnalyzer, instructions: []const opcodes.Instruction, pc: usize) []const u8 {
        _ = self;
        // Look for patterns around the SSTORE that indicate the value type
        for (instructions) |instr| {
            if (instr.pc >= pc and instr.pc < pc + 10) {
                // Check for small value patterns
                if (instr.opcode == .push1) {
                    if (instr.push_data) |data| {
                        if (data.len == 1) {
                            if (data[0] <= 0xff) return "uint8";
                            if (data[0] <= 0xffff) return "uint16";
                        }
                    }
                }
            }
        }
        return "uint256";
    }

    /// Estimate byte size from type string
    fn estimateByteSize(type_str: []const u8) u8 {
        if (std.mem.eql(u8, type_str, "uint8")) return 1;
        if (std.mem.eql(u8, type_str, "uint16")) return 2;
        if (std.mem.eql(u8, type_str, "uint32")) return 4;
        if (std.mem.eql(u8, type_str, "uint64")) return 8;
        if (std.mem.eql(u8, type_str, "uint128")) return 16;
        if (std.mem.eql(u8, type_str, "uint256")) return 32;
        if (std.mem.eql(u8, type_str, "address")) return 20;
        if (std.mem.eql(u8, type_str, "bool")) return 1;
        return 32;
    }

    /// Detect mappings - storage slots with keccak256-based access
    pub fn detectMappings(self: TypeAnalyzer, bytecode: []const u8) !MappingInfo {
        const instructions = try opcodes.parseInstructions(self.allocator, bytecode);
        defer self.allocator.free(instructions);

        // Look for KECCAK256 followed by SLOAD/SSTORE - indicates mapping
        var temp_mappings: [5]DetectedMapping = undefined;
        var map_count: usize = 0;

        for (instructions, 0..) |instr, i| {
            if (instr.opcode == .keccak256 and map_count < 5) {
                // Check if next instructions access storage
                const next_instrs = instructions[i..@min(i + 10, instructions.len)];
                for (next_instrs) |next| {
                    if (next.opcode == .sload or next.opcode == .sstore) {
                        // This looks like a mapping access
                        temp_mappings[map_count] = .{
                            .key_type = "bytes32",
                            .value_type = "uint256",
                            .slot = @as(u64, @truncate(instr.pc)),
                        };
                        map_count += 1;
                        break;
                    }
                }
            }
        }

        if (map_count > 0) {
            const slice = try self.allocator.alloc(DetectedMapping, map_count);
            @memcpy(slice, temp_mappings[0..map_count]);
            return .{
                .mappings = slice,
                .confidence = 0.6,
            };
        }

        return .{
            .mappings = &.{},
            .confidence = 0.0,
        };
    }

    /// Detect arrays - dynamic arrays have length at slot and data at keccak256(slot)
    pub fn detectArrays(self: TypeAnalyzer, bytecode: []const u8) !ArrayInfo {
        const instructions = try opcodes.parseInstructions(self.allocator, bytecode);
        defer self.allocator.free(instructions);

        // Look for patterns indicating arrays:
        // 1. KECCAK256 used to compute storage location
        // 2. Array length operations
        var temp_arrays: [5]DetectedArray = undefined;
        var arr_count: usize = 0;

        for (instructions, 0..) |instr, i| {
            if (instr.opcode == .keccak256 and arr_count < 5) {
                // Check for array-like access patterns
                const next_instrs = instructions[i..@min(i + 15, instructions.len)];
                var has_sload = false;
                var has_mload = false;

                for (next_instrs) |next| {
                    if (next.opcode == .sload) has_sload = true;
                    if (next.opcode == .mload) has_mload = true;
                }

                if (has_sload and has_mload) {
                    temp_arrays[arr_count] = .{
                        .slot = @as(u64, @truncate(instr.pc)),
                        .element_type = "uint256",
                        .is_dynamic = true,
                    };
                    arr_count += 1;
                }
            }
        }

        if (arr_count > 0) {
            const slice = try self.allocator.alloc(DetectedArray, arr_count);
            @memcpy(slice, temp_arrays[0..arr_count]);
            return .{
                .arrays = slice,
                .confidence = 0.5,
            };
        }

        return .{
            .arrays = &.{},
            .confidence = 0.0,
        };
    }

    /// Detect struct layouts - multiple related storage accesses
    pub fn detectStructs(self: TypeAnalyzer, bytecode: []const u8) !StructInfo {
        const instructions = try opcodes.parseInstructions(self.allocator, bytecode);
        defer self.allocator.free(instructions);

        // Group consecutive SSTOREs at sequential slots as potential struct
        var temp_fields: [10]StructField = undefined;
        var field_count: usize = 0;

        var last_slot: u64 = 0;
        var consecutive: usize = 0;

        for (instructions) |instr| {
            if (instr.opcode == .sstore) {
                const slot = @as(u64, @truncate(instr.pc));

                // Check if this is a consecutive slot (potential struct field)
                if (slot == last_slot + 1 or slot == last_slot) {
                    consecutive += 1;
                    if (consecutive >= 2 and field_count < 10) {
                        temp_fields[field_count] = .{
                            .name = "field",
                            .field_type = "uint256",
                            .slot = slot,
                        };
                        field_count += 1;
                    }
                } else {
                    consecutive = 1;
                }
                last_slot = slot;
            }
        }

        if (field_count >= 2) {
            const slice = try self.allocator.alloc(StructField, field_count);
            @memcpy(slice, temp_fields[0..field_count]);
            return .{
                .structs = slice,
                .confidence = 0.6,
            };
        }

        return .{
            .structs = &.{},
            .confidence = 0.0,
        };
    }
};

/// Function parameter type
pub const ParamType = struct {
    name: []const u8,
    type_str: []const u8,
};

/// Analyze bytecode for return types
pub fn inferReturnType(bytecode: []const u8, instructions: []const opcodes.Instruction, func_start: usize, allocator: std.mem.Allocator) ![]const ParamType {
    _ = bytecode;
    
    var returns = std.ArrayListUnmanaged(ParamType){};
    
    // Look for return pattern after function entry
    var found_return = false;
    var stack_at_return: usize = 0;
    
    for (instructions) |instr| {
        if (instr.pc < func_start) continue;
        
        // Track stack height changes
        const delta = opcodes.getStackDelta(instr.opcode);
        stack_at_return = @as(i32, @intCast(stack_at_return)) + delta;
        
        if (instr.opcode == .return_op and stack_at_return > 0) {
            found_return = true;
            // Each value on stack is a return value
            var i: usize = 0;
            while (i < @as(usize, @intCast(stack_at_return))) : (i += 1) {
                try returns.append(allocator, .{
                    .name = try std.fmt.allocPrint(allocator, "r{}", .{i}),
                    .type_str = "uint256",
                });
            }
            break;
        }
        
        // Stop if we hit another function
        if (instr.opcode == .jumpdest and instr.pc > func_start + 10) break;
    }
    
    return returns.toOwnedSlice(allocator);
}

/// Analyze function mutability (pure/view/payable/nonpayable)
pub fn inferMutability(bytecode: []const u8, instructions: []const opcodes.Instruction, func_start: usize) []const u8 {
    _ = bytecode;
    
    var reads_state = false;
    var writes_state = false;
    var reads_tx = false;
    
    for (instructions) |instr| {
        if (instr.pc < func_start) continue;
        
        switch (instr.opcode) {
            .sload => reads_state = true,
            .sstore => writes_state = true,
            .balance, .origin, .gasprice, .timestamp, .number, .difficulty, .chainid, .coinbase, .blockhash => reads_state = true,
            .callvalue => reads_tx = true,
            else => {},
        }
        
        // Stop at function end
        if (instr.opcode == .return_op or instr.opcode == .revert) break;
    }
    
    if (writes_state) return "nonpayable";
    if (reads_state) return "view";
    if (reads_tx) return "payable";
    return "pure";
}

test "type analyzer basic" {
    const allocator = std.testing.allocator;
    const analyzer = TypeAnalyzer{ .allocator = allocator };
    
    // Simple bytecode with address storage
    const bytecode = &[_]u8{0x55}; // SSTORE
    
    const result = try analyzer.analyzeStorageSlot(bytecode, 0);
    _ = result;
}
