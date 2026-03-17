// EVM Bytecode Parser - Simplified for Zig 0.15
// Parses raw EVM bytecode into structured instructions

const std = @import("std");
const opcodes = @import("opcodes.zig");
const OpCode = opcodes.OpCode;

/// Represents a single EVM instruction with its operands
pub const Instruction = struct {
    pc: usize,
    opcode: OpCode,
    name: []const u8,
    push_data: ?[]const u8 = null,
};

/// Result of parsing bytecode
pub const ParsedBytecode = struct {
    instructions: []Instruction,
    allocator: std.mem.Allocator,
};

/// Parse raw EVM bytecode into instructions
pub fn parse(allocator: std.mem.Allocator, bytecode: []const u8) !ParsedBytecode {
    // First pass: count instructions
    var count: usize = 0;
    var pc: usize = 0;
    while (pc < bytecode.len) : (pc += 1) {
        const opcode_byte = bytecode[pc];
        if (opcode_byte >= 0x60 and opcode_byte <= 0x7f) {
            pc += opcode_byte - 0x60;
        }
        count += 1;
    }
    
    // Allocate instructions
    var instructions = try allocator.alloc(Instruction, count);
    
    // Second pass: fill instructions
    pc = 0;
    var idx: usize = 0;
    while (pc < bytecode.len) : (pc += 1) {
        const opcode_byte = bytecode[pc];
        
        // Skip bytes that are not valid opcodes (0x0b-0x0f, 0x1e-0x1f, 0xc0-0xde)
        if ((opcode_byte >= 0x0c and opcode_byte <= 0x0f) or
            (opcode_byte >= 0x1e and opcode_byte <= 0x1f) or
            (opcode_byte >= 0x5c and opcode_byte <= 0x5f) or
            (opcode_byte >= 0xa5 and opcode_byte <= 0xef)) {
            idx += 1;
            continue;
        }
        
        const opcode = @as(OpCode, @enumFromInt(opcode_byte));
        
        var push_data: ?[]const u8 = null;
        
        if (opcode_byte >= 0x60 and opcode_byte <= 0x7f) {
            const push_size = opcode_byte - 0x60 + 1;
            if (pc + 1 + push_size <= bytecode.len) {
                push_data = bytecode[pc + 1 .. pc + 1 + push_size];
                pc += push_size;
            }
        }
        
        instructions[idx] = .{
            .pc = pc,
            .opcode = opcode,
            .name = opcodes.getName(opcode),
            .push_data = push_data,
        };
        idx += 1;
    }
    
    return .{ .instructions = instructions, .allocator = allocator };
}

pub fn deinit(parsed: *ParsedBytecode) void {
    parsed.allocator.free(parsed.instructions);
}

/// Get instruction at specific PC
pub fn getInstruction(parsed: *const ParsedBytecode, pc: usize) ?Instruction {
    for (parsed.instructions) |instr| {
        if (instr.pc == pc) return instr;
    }
    return null;
}
