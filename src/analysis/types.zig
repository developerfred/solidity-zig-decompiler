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
