/// Bend-PVM / RISC-V Opcodes
/// Bend-PVM compiles to RISC-V bytecode for PolkaVM

const std = @import("std");

/// RISC-V opcode categories
pub const OpcodeCategory = enum {
    load,
    store,
    branch,
    jal,
    jalr,
    arith_imm,
    arith,
    fence,
    ecall,
    bend_ext,
    unknown,
};

/// Get opcode category from raw byte
pub fn getCategory(opcode_byte: u7) OpcodeCategory {
    return switch (opcode_byte) {
        0x03 => .load,
        0x23 => .store,
        0x63 => .branch,
        0x6f => .jal,
        0x67 => .jalr,
        0x13 => .arith_imm,
        0x33 => .arith,
        0x0f => .fence,
        0x73 => .ecall,
        0x5b...0x5f => .bend_ext,
        else => .unknown,
    };
}

/// Parse RISC-V instruction from bytecode
pub const Instruction = struct {
    raw: u32,
    opcode_byte: u7,
    rd: u5,
    rs1: u5,
    rs2: u5,
    funct3: u3,
    funct7: u7,
    imm: i32,
    pc: usize,
};

/// Parse RISC-V instructions from bytecode
pub fn parseInstructions(allocator: std.mem.Allocator, bytecode: []const u8) ![]Instruction {
    var instructions: std.ArrayListUnmanaged(Instruction) = .{};
    errdefer instructions.deinit(allocator);
    
    var pc: usize = 0;
    while (pc + 4 <= bytecode.len) {
        // Read 32-bit instruction (little endian)
        const word = std.mem.readInt(u32, bytecode[pc..][0..4], .little);
        
        // Decode RISC-V instruction fields
        const opcode_byte = @as(u7, @truncate(word & 0x7f));
        const rd = @as(u5, @truncate((word >> 7) & 0x1f));
        const funct3 = @as(u3, @truncate((word >> 12) & 0x7));
        const rs1 = @as(u5, @truncate((word >> 15) & 0x1f));
        const rs2 = @as(u5, @truncate((word >> 20) & 0x1f));
        const funct7 = @as(u7, @truncate((word >> 25) & 0x7f));
        
        // Calculate immediate based on RISC-V instruction format
        // I-type (0x13, 0x03, 0x67): bits [31:20] = 12-bit immediate
        // S-type (0x23): bits [31:25] + bits [11:7] = 12-bit immediate
        // B-type (0x63): bits [31:25] + bits [11:7], with special bit arrangement
        // U-type (0x37, 0x17): bits [31:12] = 20-bit immediate
        // J-type (0x6f): bits [31:12] with special bit arrangement
        var imm: i32 = 0;
        
        const opcode_byte_val: u7 = @as(u7, @truncate(word & 0x7f));
        
        switch (opcode_byte_val) {
            0x03, 0x13, 0x67 => { // I-type: load, arithmetic immediate, jalr
                const raw_imm12 = @as(u12, @truncate((word >> 20) & 0xfff));
                // Sign extend 12-bit immediate
                imm = if (raw_imm12 & 0x800 != 0)
                    @as(i32, @intCast(raw_imm12)) - 4096
                else
                    @as(i32, @intCast(raw_imm12));
            },
            0x23 => { // S-type: store
                const imm_high = (@as(i32, @intCast((word >> 25) & 0x7f))) << 5;
                const imm_low = @as(i32, @intCast((word >> 7) & 0x1f));
                imm = imm_high | imm_low;
                // Sign extend
                if (imm & 0x1000 != 0) {
                    imm -= 4096;
                }
            },
            0x63 => { // B-type: branch
                const bit11 = @as(i32, @intCast((word >> 7) & 1)) << 11;
                const bits10_5 = @as(i32, @intCast((word >> 25) & 0x3f)) << 5;
                const bits4_1 = @as(i32, @intCast((word >> 8) & 0xf)) << 1;
                const bit12 = @as(i32, @intCast((word >> 31) & 1)) << 12;
                imm = bit12 | bit11 | bits10_5 | bits4_1;
                // Sign extend (13-bit)
                if (imm & 0x2000 != 0) {
                    imm -= 8192;
                }
            },
            0x37, 0x17 => { // U-type: lui, auipc
                imm = @as(i32, @intCast((word >> 12) & 0xfffff));
            },
            0x6f => { // J-type: jal
                const bit20 = @as(i32, @intCast((word >> 31) & 1)) << 20;
                const bits19_12 = @as(i32, @intCast((word >> 12) & 0xff)) << 12;
                const bit11 = @as(i32, @intCast((word >> 20) & 1)) << 11;
                const bits10_1 = @as(i32, @intCast((word >> 21) & 0x3ff)) << 1;
                imm = bit20 | bits19_12 | bit11 | bits10_1;
                // Sign extend (21-bit)
                if (imm & 0x200000 != 0) {
                    imm -= 2097152;
                }
            },
            else => {
                // Default to I-type for unknown
                const raw_imm12 = @as(u12, @truncate((word >> 20) & 0xfff));
                imm = if (raw_imm12 & 0x800 != 0)
                    @as(i32, @intCast(raw_imm12)) - 4096
                else
                    @as(i32, @intCast(raw_imm12));
            },
        }
        
        try instructions.append(allocator, .{
            .raw = word,
            .opcode_byte = opcode_byte,
            .rd = rd,
            .rs1 = rs1,
            .rs2 = rs2,
            .funct3 = funct3,
            .funct7 = funct7,
            .imm = imm,
            .pc = pc,
        });
        
        pc += 4;
    }
    
    return instructions.toOwnedSlice(allocator);
}

/// Register names
pub fn registerName(reg: u5) []const u8 {
    const names = [_][]const u8{
        "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
        "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
        "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
        "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6",
    };
    return names[reg];
}

/// Get instruction name from opcode
pub fn getName(instr: Instruction) []const u8 {
    const op = instr.opcode_byte;
    const f3 = instr.funct3;
    const f7 = instr.funct7;
    
    return switch (op) {
        0x37 => "lui",
        0x17 => "auipc",
        0x6f => "jal",
        0x67 => "jalr",
        0x63 => switch (f3) {
            0x0 => "beq",
            0x1 => "bne",
            0x4 => "blt",
            0x5 => "bge",
            0x6 => "bltu",
            0x7 => "bgeu",
            else => "branch",
        },
        0x03 => switch (f3) {
            0x0 => "lb",
            0x1 => "lh",
            0x2 => "lw",
            0x4 => "lbu",
            0x5 => "lhu",
            else => "load",
        },
        0x23 => switch (f3) {
            0x0 => "sb",
            0x1 => "sh",
            0x2 => "sw",
            else => "store",
        },
        0x13 => switch (f3) {
            0x0 => "addi",
            0x2 => "slti",
            0x3 => "sltiu",
            0x4 => "xori",
            0x6 => "ori",
            0x7 => "andi",
            else => if (f3 == 0x1) "slli" else if (f3 == 0x5) (if (f7 & 0x20 != 0) "srai" else "srli") else "arith_imm",
        },
        0x33 => {
            if (f3 == 0) return if (f7 & 0x20 != 0) "sub" else "add";
            if (f3 == 1) return "sll";
            if (f3 == 2) return "slt";
            if (f3 == 3) return "sltu";
            if (f3 == 4) return "xor_op";
            if (f3 == 5) return if (f7 & 0x20 != 0) "sra" else "srl";
            if (f3 == 6) return "or_op";
            if (f3 == 7) return "and_op";
            return "arith";
        },
        0x0f => "fence",
        0x73 => switch (f3) {
            0x0 => "ecall",
            0x1 => "ebreak",
            else => "syscall",
        },
        0x5b => "bend.alloc",
        0x5c => "bend.free",
        0x5d => "bend.call",
        0x5e => "bend.ret",
        0x5f => "bend.match",
        else => "unknown",
    };
}

/// Disassemble single instruction to string
pub fn disassemble(instr: Instruction, allocator: std.mem.Allocator) ![]u8 {
    const name = getName(instr);
    var buf = std.ArrayList(u8).init(allocator);
    const w = buf.writer();
    
    try w.print("{s:8} ", .{name});
    
    switch (instr.opcode_byte) {
        0x37, 0x17 => { // lui, auipc
            try w.print("x{}, {}", .{instr.rd, instr.imm});
        },
        0x6f => { // jal
            try w.print("x{}, {}", .{instr.rd, instr.imm});
        },
        0x67 => { // jalr
            try w.print("x{}, {}(x{})", .{instr.rd, instr.imm, instr.rs1});
        },
        0x63 => { // branch
            try w.print("x{}, x{}, {}", .{instr.rs1, instr.rs2, instr.imm});
        },
        0x03, 0x23 => { // load, store
            try w.print("x{}, {}(x{})", .{instr.rd, instr.imm, instr.rs1});
        },
        0x13 => { // arithmetic immediate
            if (instr.funct3 == 0x1 or instr.funct3 == 0x5) {
                try w.print("x{}, x{}, {}", .{instr.rd, instr.rs1, instr.funct7});
            } else {
                try w.print("x{}, x{}, {}", .{instr.rd, instr.rs1, instr.imm});
            }
        },
        0x33 => { // arithmetic
            try w.print("x{}, x{}, x{}", .{instr.rd, instr.rs1, instr.rs2});
        },
        0x73 => {}, // ecall/ebreak
        else => {},
    }
    
    return buf.toOwnedSlice();
}

/// Detect if bytecode is Bend-PVM/RISC-V
pub fn isBendPVM(bytecode: []const u8) bool {
    if (bytecode.len < 4) return false;
    
    // RISC-V instructions are 4-byte aligned
    // If bytecode length is divisible by 4, likely RISC-V
    if (bytecode.len % 4 != 0) return false;
    
    // Check for valid RISC-V instruction patterns
    var riscv_count: usize = 0;
    var total_checked: usize = 0;
    var i: usize = 0;
    while (i + 4 <= bytecode.len and i < 64) : (i += 4) {
        total_checked += 1;
        const word = std.mem.readInt(u32, bytecode[i..][0..4], .little);
        const opcode = word & 0x7f;
        
        // Valid RISC-V opcodes: 0x03, 0x07, 0x0f, 0x13, 0x17, 0x1b, 0x23, 0x2f, 0x33, 0x37, 0x3b, 0x5b, 0x5f, 0x63, 0x67, 0x6f, 0x73
        if (opcode == 0x03 or opcode == 0x0f or opcode == 0x13 or opcode == 0x17 or 
            opcode == 0x23 or opcode == 0x33 or opcode == 0x37 or opcode == 0x5b or
            opcode == 0x5f or opcode == 0x63 or opcode == 0x67 or opcode == 0x6f or opcode == 0x73) {
            riscv_count += 1;
        }
    }
    
    // If more than 50% of first 16 instructions are valid RISC-V, likely Bend-PVM
    return riscv_count >= 3;
}

/// Detect if bytecode is EVM
pub fn isEVM(bytecode: []const u8) bool {
    if (bytecode.len < 2) return false;
    
    // Check for EVM opcodes (0x00-0xff)
    var evm_count: usize = 0;
    for (bytecode[0..@min(32, bytecode.len)]) |b| {
        // Common EVM opcodes
        if (b == 0x00 or b == 0x60 or b == 0x61 or b == 0x80 or b == 0x81 or 
            b == 0x54 or b == 0x55 or b == 0x56 or b == 0x57 or 
            b == 0xf1 or b == 0xf2 or b == 0xfa) {
            evm_count += 1;
        }
    }
    
    // If we find EVM-specific opcodes, it's likely EVM
    return evm_count >= 2;
}
    
/// Auto-detect bytecode type
pub const BytecodeType = enum {
    evm,
    bend_pvm,
    unknown,
};

pub fn detectBytecodeType(bytecode: []const u8) BytecodeType {
    if (isBendPVM(bytecode)) return .bend_pvm;
    if (isEVM(bytecode)) return .evm;
    return .unknown;
}

test "registerName basic" {
    const name0 = registerName(0);
    try std.testing.expectEqualStrings("zero", name0);
    
    const name1 = registerName(1);
    try std.testing.expectEqualStrings("ra", name1);
    
    const name10 = registerName(10);
    try std.testing.expectEqualStrings("a0", name10);
}

test "getName basic" {
    // I-type: addi
    const instr_addi = Instruction{
        .raw = 0x00000093, // addi x1, x0, 0
        .opcode_byte = 0x13,
        .rd = 1,
        .rs1 = 0,
        .rs2 = 0,
        .funct3 = 0,
        .funct7 = 0,
        .imm = 0,
        .pc = 0,
    };
    const name = getName(instr_addi);
    try std.testing.expectEqualStrings("addi", name);
}

test "isBendPVM valid" {
    // Valid RISC-V: 4-byte aligned, valid opcodes
    const riscv_bytecode = "\x93\x00\x00\x00\x13\x00\x00\x00";
    try std.testing.expect(isBendPVM(riscv_bytecode));
}

test "isBendPVM invalid" {
    // Too short
    try std.testing.expect(!isBendPVM("\x00\x00"));
    
    // Not 4-byte aligned
    try std.testing.expect(!isBendPVM("\x00\x00\x00"));
}

test "isEVM basic" {
    // Valid EVM bytecode
    const evm_bytecode = "\x60\x80\x60\x40\x52\x60\x00"; // PUSH1 0x80 PUSH1 0x40 MSTORE PUSH1 0x00
    try std.testing.expect(isEVM(evm_bytecode));
}

test "detectBytecodeType riscv" {
    const riscv_bytecode = "\x93\x00\x00\x00\x13\x00\x00\x00";
    const bt = detectBytecodeType(riscv_bytecode);
    try std.testing.expectEqual(BytecodeType.bend_pvm, bt);
}

test "detectBytecodeType evm" {
    const evm_bytecode = "\x60\x80\x60\x40\x52";
    const bt = detectBytecodeType(evm_bytecode);
    try std.testing.expectEqual(BytecodeType.evm, bt);
}
