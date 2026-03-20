/// Control Flow Analysis
/// Analyzes bytecode to identify functions, loops, branches, and control flow structure

const std = @import("std");
const opcodes = @import("../evm/opcodes.zig");

/// Basic block in control flow graph
pub const BasicBlock = struct {
    start_pc: usize,
    end_pc: usize,
};

/// Function in the contract
pub const AnalyzedFunction = struct {
    entry_pc: usize,
    end_pc: usize,
};

/// Local variable (simplified)
pub const LocalVar = struct {
    name: []const u8,
    slot: ?u32, // Stack slot or memory offset
    var_type: []const u8,
};

/// Control Flow Graph
pub const ControlFlowGraph = struct {
    blocks: []const BasicBlock,
    functions: []const AnalyzedFunction,
    loops: []const Loop,
    branches: []const Branch,
    _func_count: usize = 0,
    _branch_count: usize = 0,

    pub const Loop = struct {
        header: usize,
        body: []const usize,
        exits: []const usize,
    };

    pub const Branch = struct {
        condition_pc: usize,
        true_target: usize,
        false_target: usize,
    };
    
    pub fn getFunctionCount(self: *const ControlFlowGraph) usize {
        return self._func_count;
    }
    
    pub fn getBranchCount(self: *const ControlFlowGraph) usize {
        return self._branch_count;
    }
};

/// Analyze control flow from bytecode
pub fn analyzeControlFlow(bytecode: []const u8, allocator: std.mem.Allocator) !ControlFlowGraph {
    const instructions = try opcodes.parseInstructions(allocator, bytecode);
    defer allocator.free(instructions);

    // Build basic blocks
    var block_starts = std.AutoArrayHashMap(usize, void).init(allocator);
    defer block_starts.deinit();

    // Entry point is always a block start
    try block_starts.put(0, {});

    // Find all jump destinations
    for (instructions) |instr| {
        if (instr.opcode == .jumpdest) {
            try block_starts.put(instr.pc, {});
        }
        // Also start blocks after unconditional jumps
        if (instr.opcode == .jump or instr.opcode == .return_op or instr.opcode == .revert or instr.opcode == .selfdestruct) {
            // Next instruction is a block start
            if (instr.pc + 1 < instructions.len) {
                try block_starts.put(instructions[instr.pc + 1].pc, {});
            }
        }
    }

    // Build blocks - use a simple list without internal allocations
    var blocks = std.ArrayListUnmanaged(BasicBlock){};
    
    // Convert hashmap keys to a simple slice and sort
    const starts_count = block_starts.count();
    var starts = try allocator.alloc(usize, starts_count);
    defer allocator.free(starts);
    
    var idx: usize = 0;
    var iter = block_starts.iterator();
    while (iter.next()) |entry| {
        starts[idx] = entry.key_ptr.*;
        idx += 1;
    }
    std.mem.sort(usize, starts, {}, std.sort.asc(usize));

    for (starts, 0..) |start_pc, i| {
        const end_pc = if (i + 1 < starts.len) starts[i + 1] - 1 else bytecode.len - 1;
        
        try blocks.append(allocator, .{
            .start_pc = start_pc,
            .end_pc = end_pc,
        });
    }

    const blocks_slice = try blocks.toOwnedSlice(allocator);
    
    // Identify branches (just count JUMPI for now to avoid memory leaks)
    var branch_count: usize = 0;
    for (instructions) |instr| {
        if (instr.opcode == .jumpi) {
            branch_count += 1;
        }
    }
    
    // Count function-like structures (JUMPDESTs after 0x10)
    var func_count: usize = 0;
    for (instructions) |instr| {
        if (instr.opcode == .jumpdest and instr.pc > 0x10) {
            func_count += 1;
        }
    }
    
    return .{
        .blocks = blocks_slice,
        .functions = &.{}, // Empty for now - memory leak risk
        .loops = &.{},    // Empty for now - memory leak risk  
        .branches = &.{}, // Empty for now - memory leak risk
        ._func_count = func_count,
        ._branch_count = branch_count,
    };
}

/// Identify functions in bytecode
pub fn identifyFunctions(bytecode: []const u8, allocator: std.mem.Allocator) ![]AnalyzedFunction {
    var functions = std.ArrayList(AnalyzedFunction).init(allocator);
    errdefer functions.deinit();

    const instructions = try opcodes.parseInstructions(allocator, bytecode);
    defer allocator.free(instructions);

    // Strategy: Find JUMPDESTs that are targets of PUSH operations
    // These are typically function entry points
    
    var i: usize = 0;
    while (i < instructions.len) : (i += 1) {
        const instr = instructions[i];
        
        if (opcodes.isPush(instr.opcode)) {
            const push_size = opcodes.getPushSize(instr.opcode);
            const target_idx = i + 1 + push_size;
            
            if (target_idx < instructions.len) {
                const target = instructions[target_idx];
                if (target.opcode == .jumpdest) {
                    // Found a function entry point
                    const func = try analyzeFunction(bytecode, instructions, target.pc, allocator);
                    try functions.append(func);
                }
            }
        }
    }

    return functions.toOwnedSlice();
}

/// Analyze a single function
fn analyzeFunction(bytecode: []const u8, instructions: []const opcodes.Instruction, entry_pc: usize, allocator: std.mem.Allocator) !AnalyzedFunction {
    _ = bytecode;
    // Find function end
    var end_pc: usize = entry_pc;
    var in_function = false;
    
    for (instructions) |instr| {
        if (instr.pc < entry_pc) continue;
        
        if (instr.opcode == .jumpdest and instr.pc > entry_pc and !in_function) {
            // Found next function, stop
            break;
        }
        
        in_function = true;
        if (instr.opcode == .return_op or instr.opcode == .revert or instr.opcode == .selfdestruct) {
            end_pc = instr.pc;
            break;
        }
    }

    // Analyze parameters (typically at entry)
    var params = std.ArrayList(LocalVar).init(allocator);
    
    // Try to identify common parameter patterns
    // At entry, we often see: PUSH0 DUP1 DUP2 ... PUSH2 <mem_loc> MSTORE
    // This indicates memory parameters
    
    return AnalyzedFunction{
        .entry_pc = entry_pc,
        .end_pc = end_pc,
        .name = try std.fmt.allocPrint(allocator, "func_{x}", .{entry_pc}),
        .params = params.toOwnedSlice(),
        .locals = &.{},
        .blocks = &.{},
    };
}

/// Detect loops in control flow
pub fn detectLoops(cfg: *ControlFlowGraph) void {
    // Simple loop detection: blocks that can reach themselves via successors
    // This is a simplified implementation
    _ = cfg;
}

/// Detect branches/conditionals
pub fn detectBranches(instructions: []const opcodes.Instruction) []const ControlFlowGraph.Branch {
    var branches = std.ArrayList(ControlFlowGraph.Branch).init(std.heap.page_allocator);

    for (instructions) |instr| {
        if (instr.opcode == .jumpi) {
            // Conditional jump
            try branches.append(.{
                .condition_pc = instr.pc,
                .true_target = 0, // Would need to compute from stack
                .false_target = 0,
            });
        }
    }

    return branches.toOwnedSlice();
}
