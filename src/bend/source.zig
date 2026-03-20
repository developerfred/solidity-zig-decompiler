/// Bend-PVM Source Reconstruction
/// Generates pseudo-Bend code from RISC-V bytecode

const std = @import("std");
const opcodes = @import("./opcodes.zig");
const Instruction = opcodes.Instruction;

/// Bend function
pub const BendFunction = struct {
    name: []const u8,
    params: []const BendParam,
    returns: ?[]const BendParam,
    locals: []const BendLocal,
    body: []const BendStmt,
};

pub const BendParam = struct {
    name: []const u8,
    type_str: []const u8,
};

pub const BendLocal = struct {
    name: []const u8,
    type_str: []const u8,
};

pub const BendStmt = struct {
    text: []const u8,
};

/// Analyze RISC-V instructions and generate Bend-like pseudocode
pub fn generateSource(instructions: []Instruction, allocator: std.mem.Allocator) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    const w = buf.writer();
    
    // Generate header
    try w.writeAll("// Bend-PVM / RISC-V Decompiled Source\n");
    try w.writeAll("// This is a reconstruction, not exact original source\n\n");
    
    // Identify functions by analyzing jal/jalr calls
    const functions = try identifyFunctions(instructions, allocator);
    defer {
        for (functions) |func| {
            allocator.free(func.name);
            for (func.params) |p| allocator.free(p.name);
            for (func.returns) |r| allocator.free(r.name);
            for (func.body) |s| allocator.free(s.text);
            allocator.free(func.params);
            allocator.free(func.body);
        }
        allocator.free(functions);
    }
    
    // Generate main function
    try w.writeAll("pub fn main() {\n");
    
    for (functions) |func| {
        try w.print("    // Function at offset {x}\n", .{func.locals[0].type_str}); // placeholder
        try w.writeAll("}\n");
    }
    
    // Fallback: generate simple statements for each instruction
    try w.writeAll("\n// Instruction-by-instruction breakdown:\n");
    try w.writeAll("pub fn _start() {\n");
    
    for (instructions) |instr| {
        const name = opcodes.getName(instr);
        
        switch (instr.opcode_byte) {
            0x13 => { // arithmetic immediate
                if (instr.funct3 == 0) { // addi
                    try w.print("    let x{} = x{} + {};\n", .{ instr.rd, instr.rs1, instr.imm });
                } else if (instr.funct3 == 0x2) { // slti
                    try w.print("    let x{} = (x{} < {});\n", .{ instr.rd, instr.rs1, instr.imm });
                } else {
                    try w.print("    // {s} x{}, x{}, {}\n", .{ name, instr.rd, instr.rs1, instr.imm });
                }
            },
            0x33 => { // arithmetic
                try w.print("    let x{} = x{} {} x{};\n", .{ 
                    instr.rd, instr.rs1, 
                    switch (instr.funct3) {
                        0 => if (instr.funct7 & 0x20 != 0) "sub" else "add",
                        1 => "shl",
                        2 => "slt",
                        3 => "sltu",
                        4 => "xor",
                        5 => if (instr.funct7 & 0x20 != 0) "sra" else "shr",
                        6 => "or",
                        7 => "and",
                        else => "op",
                    },
                    instr.rs2 
                });
            },
            0x03 => { // load
                try w.print("    let x{} = load(x{} + {});\n", .{ instr.rd, instr.rs1, instr.imm });
            },
            0x23 => { // store
                try w.print("    store(x{} + {}, x{});\n", .{ instr.rs1, instr.imm, instr.rs2 });
            },
            0x63 => { // branch
                const cond = switch (instr.funct3) {
                    0x0 => "==",
                    0x1 => "!=",
                    0x4 => "<",
                    0x5 => ">=",
                    0x6 => "<",
                    0x7 => ">=",
                    else => "cond",
                };
                try w.print("    if (x{} {} x{}) {{ goto {} }}\n", .{ instr.rs1, cond, instr.rs2, instr.imm });
            },
            0x6f => { // jal
                try w.print("    // jal x{}, {}\n", .{ instr.rd, instr.imm });
            },
            0x67 => { // jalr
                try w.print("    // jalr x{}, {}(x{})\n", .{ instr.rd, instr.imm, instr.rs1 });
            },
            0x37 => { // lui
                try w.print("    let x{} = {};\n", .{ instr.rd, instr.imm });
            },
            0x17 => { // auipc
                try w.print("    let x{} = pc + {};\n", .{ instr.rd, instr.imm });
            },
            0x73 => { // ecall
                try w.writeAll("    // ecall\n");
            },
            else => {
                try w.print("    // {s}\n", .{name});
            },
        }
    }
    
    try w.writeAll("}\n");
    
    return buf.toOwnedSlice(allocator);
}

/// Identify functions in the bytecode
fn identifyFunctions(instructions: []Instruction, allocator: std.mem.Allocator) ![]BendFunction {
    var funcs = std.ArrayListUnmanaged(BendFunction){};
    
    // Look for jal instructions (function calls)
    // and jalr (function returns)
    for (instructions) |instr| {
        if (instr.opcode_byte == 0x6f or instr.opcode_byte == 0x67) {
            // Found a function call/return
            const name = try std.fmt.allocPrint(allocator, "func_{x}", .{instr.imm});
            errdefer allocator.free(name);
            
            try funcs.append(allocator, .{
                .name = name,
                .params = &.{},
                .returns = null,
                .locals = &.{},
                .body = &.{},
            });
        }
    }
    
    // If no functions found, create a default one
    if (funcs.items.len == 0) {
        const name = try std.fmt.allocPrint(allocator, "main", .{});
        errdefer allocator.free(name);
        
        try funcs.append(allocator, .{
            .name = name,
            .params = &.{},
            .returns = null,
            .locals = &.{},
            .body = &.{},
        });
    }
    
    return funcs.toOwnedSlice(allocator);
}

/// Generate high-level Bend source with function signatures
pub fn generateHighLevelSource(instructions: []Instruction, allocator: std.mem.Allocator) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    errdefer buf.deinit(allocator);
    const w = buf.writer(allocator);
    
    // Count operations
    var load_count: usize = 0;
    var store_count: usize = 0;
    var branch_count: usize = 0;
    var call_count: usize = 0;
    var arithmetic_count: usize = 0;
    
    for (instructions) |instr| {
        switch (instr.opcode_byte) {
            0x03 => load_count += 1,
            0x23 => store_count += 1,
            0x63 => branch_count += 1,
            0x6f, 0x67 => call_count += 1,
            0x13, 0x33 => arithmetic_count += 1,
            else => {},
        }
    }
    
    try w.writeAll("// Bend-PVM High-Level Reconstruction\n");
    try w.writeAll("// Runtime estimates based on instruction analysis\n\n");
    
    try w.print("/// Estimated memory operations: {} loads, {} stores\n", .{ load_count, store_count });
    try w.print("/// Estimated branches: {}, function calls: {}\n", .{ branch_count, call_count });
    try w.print("/// Total arithmetic operations: {}\n\n", .{ arithmetic_count });
    
    // Generate a more readable function structure
    try w.writeAll("pub type Result = Int;\n");
    try w.writeAll("pub type Address = Int;\n\n");
    
    try w.writeAll("pub fn deploy() -> Result {\n");
    try w.writeAll("    // Constructor / deployment logic\n");
    try w.writeAll("    // TODO: Reconstruct deployment logic\n");
    try w.writeAll("}\n\n");
    
    try w.writeAll("pub fn main(x: Int) -> Result {\n");
    try w.writeAll("    // Main entry point\n");
    try w.writeAll("    // Based on instruction analysis:\n");
    try w.print("    // - {} memory loads\n", .{load_count});
    try w.print("    // - {} memory stores\n", .{store_count});
    try w.print("    // - {} arithmetic operations\n", .{arithmetic_count});
    try w.writeAll("    \n");
    try w.writeAll("    // TODO: Reconstruct actual logic from CFG\n");
    try w.writeAll("    0\n");
    try w.writeAll("}\n");
    
    return buf.toOwnedSlice(allocator);
}
