// Control Flow Graph Analyzer - Simplified

const std = @import("std");
const parser = @import("parser.zig");

pub const BasicBlock = struct {
    id: usize,
    start_pc: usize,
    end_pc: usize,
};

pub const ControlFlowGraph = struct {
    blocks: []BasicBlock,
    allocator: std.mem.Allocator,
};

pub fn buildCFG(allocator: std.mem.Allocator, parsed: *const parser.ParsedBytecode) !ControlFlowGraph {
    // Find jumpdests
    var jumpdests = std.ArrayList(usize).init(allocator);
    defer jumpdests.deinit();
    
    for (parsed.instructions) |instr| {
        if (instr.opcode == .jumpdest) {
            try jumpdests.append(instr.pc);
        }
    }
    
    try jumpdests.append(0); // Entry point
    std.sort.sort(usize, jumpdests.items, {}, std.sort.asc(usize));
    
    var blocks = try allocator.alloc(BasicBlock, jumpdests.items.len);
    for (jumpdests.items, 0..) |start_pc, i| {
        blocks[i] = .{ .id = i, .start_pc = start_pc, .end_pc = start_pc };
    }
    
    return .{ .blocks = blocks, .allocator = allocator };
}

pub fn deinit(cfg: *ControlFlowGraph) void {
    cfg.allocator.free(cfg.blocks);
}
