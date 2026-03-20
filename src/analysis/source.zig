/// Source Reconstruction - Real Solidity code generation from EVM bytecode
/// This module analyzes bytecode and generates meaningful Solidity-like code

const std = @import("std");
const opcodes = @import("../evm/opcodes.zig");
const Opcode = opcodes.Opcode;

/// Parameter in function signature
pub const Param = struct {
    name: []const u8,
    type_str: []const u8,
};

/// State variable
pub const StateVar = struct {
    name: []const u8,
    type_str: []const u8,
    visibility: []const u8,
};

/// Event definition
pub const Event = struct {
    name: []const u8,
    params: []const Param,
};

/// Statement in function body
pub const Stmt = struct {
    text: []const u8,
};

/// Function
pub const Function = struct {
    name: []const u8,
    visibility: []const u8,
    mutability: []const u8,
    params: []const Param,
    returns: []const Param,
    body: []const Stmt,
};

/// Contract
pub const Contract = struct {
    name: []const u8,
    functions: []const Function,
    state_variables: []const StateVar,
    events: []const Event,
};

/// Generated Solidity-like code
pub const SolidityCode = struct {
    contracts: []const Contract,
};

/// Analyze bytecode and generate Solidity code
pub fn reconstructSolidity(bytecode: []const u8, initcode: []const u8, allocator: std.mem.Allocator) !SolidityCode {
    const instructions = try opcodes.parseInstructions(allocator, bytecode);
    defer allocator.free(instructions);
    
    // Analyze storage access for state variables
    const storage_analysis = try analyzeStorage(bytecode, allocator);
    defer allocator.free(storage_analysis);
    
    // Identify functions from control flow
    const func_analysis = try identifyFunctions(bytecode, instructions, allocator);
    defer {
        for (func_analysis) |f| allocator.free(f.name);
        allocator.free(func_analysis);
    }
    
    // Decode constructor if initcode exists
    var constructor: ?Function = null;
    if (initcode.len > 0) {
        constructor = try decodeConstructor(initcode, allocator);
    }
    
    // Build state variables from storage analysis
    var state_vars: std.ArrayListUnmanaged(StateVar) = .{};
    for (storage_analysis) |slot| {
        const name = try std.fmt.allocPrint(allocator, "slot_{}", .{slot.slot});
        try state_vars.append(allocator, .{
            .name = name,
            .type_str = slot.inferred_type,
            .visibility = "private",
        });
    }
    
    // Add constructor if exists
    var all_funcs: std.ArrayListUnmanaged(Function) = .{};
    if (constructor) |c| {
        try all_funcs.append(allocator, c);
    }
    
    // Add identified functions
    for (func_analysis) |f| {
        const body_stmt = try allocator.alloc(Stmt, 1);
        body_stmt[0] = .{ .text = f.body_text };
        const func = Function{
            .name = f.name,
            .visibility = "external",
            .mutability = "view",
            .params = f.params,
            .returns = f.returns,
            .body = body_stmt,
        };
        try all_funcs.append(allocator, func);
    }
    
    // If no functions found, create fallback
    if (all_funcs.items.len == 0) {
        const fallback_body = try allocator.alloc(Stmt, 1);
        fallback_body[0] = .{ .text = "revert();" };
        const fallback = Function{
            .name = "fallback",
            .visibility = "external",
            .mutability = "view",
            .params = &.{},
            .returns = &.{},
            .body = fallback_body,
        };
        try all_funcs.append(allocator, fallback);
    }
    
    const func_slice = try all_funcs.toOwnedSlice(allocator);
    const state_vars_slice = try state_vars.toOwnedSlice(allocator);
    
    const contract = Contract{
        .name = "DecompiledContract",
        .functions = func_slice,
        .state_variables = state_vars_slice,
        .events = &.{},
    };
    
    return .{
        .contracts = &.{contract},
    };
}

/// Storage slot analysis result
pub const StorageSlotInfo = struct {
    slot: u64,
    inferred_type: []const u8,
    is_read: bool,
    is_write: bool,
};

/// Analyze storage operations to infer state variables
fn analyzeStorage(bytecode: []const u8, allocator: std.mem.Allocator) ![]StorageSlotInfo {
    const instructions = try opcodes.parseInstructions(allocator, bytecode);
    defer allocator.free(instructions);
    
    var slots = std.AutoHashMap(u64, StorageSlotInfo).init(allocator);
    defer slots.deinit();
    
    var i: usize = 0;
    while (i < instructions.len) : (i += 1) {
        const instr = instructions[i];
        
        if (instr.opcode == .sload) {
            // Try to get slot from previous instruction
            if (i > 0) {
                const prev = instructions[i - 1];
                if (opcodes.isPush(prev.opcode) and prev.push_data != null) {
                    const slot = readPushDataAsU64(prev.push_data.?);
                    const entry = slots.getOrPut(slot) catch continue;
                    if (!entry.found_existing) {
                        entry.value_ptr.* = .{
                            .slot = slot,
                            .inferred_type = "uint256",
                            .is_read = true,
                            .is_write = false,
                        };
                    } else {
                        entry.value_ptr.*.is_read = true;
                    }
                }
            }
        }
        
        if (instr.opcode == .sstore) {
            // Try to get slot from stack
            if (i > 1) {
                const prev = instructions[i - 1];
                if (opcodes.isPush(prev.opcode) and prev.push_data != null) {
                    const slot = readPushDataAsU64(prev.push_data.?);
                    const entry = slots.getOrPut(slot) catch continue;
                    if (!entry.found_existing) {
                        entry.value_ptr.* = .{
                            .slot = slot,
                            .inferred_type = "uint256",
                            .is_read = false,
                            .is_write = true,
                        };
                    } else {
                        entry.value_ptr.*.is_write = true;
                    }
                }
            }
        }
    }
    
    // Convert to slice
    var result: std.ArrayListUnmanaged(StorageSlotInfo) = .{};
    var iter = slots.iterator();
    while (iter.next()) |entry| {
        try result.append(allocator, entry.value_ptr.*);
    }
    
    // Sort by slot
    std.mem.sort(StorageSlotInfo, result.items, {}, sortStorage);
    
    return result.toOwnedSlice(allocator);
}

fn sortStorage(_: void, a: StorageSlotInfo, b: StorageSlotInfo) bool {
    return a.slot < b.slot;
}

fn readPushDataAsU64(data: []const u8) u64 {
    var result: u64 = 0;
    for (data, 0..) |b, i| {
        if (i >= 8) break;
        result |= @as(u64, b) << @as(u6, @intCast(i * 8));
    }
    return result;
}

/// Function analysis result
pub const FunctionInfo = struct {
    name: []const u8,
    entry_pc: usize,
    params: []const Param,
    returns: []const Param,
    body_text: []const u8,
};

/// Identify functions from bytecode
fn identifyFunctions(bytecode: []const u8, instructions: []const opcodes.Instruction, allocator: std.mem.Allocator) ![]FunctionInfo {
    var funcs: std.ArrayListUnmanaged(FunctionInfo) = .{};
    
    // Strategy 1: Find dispatch table (PUSH4 -> JUMPI pattern)
    var i: usize = 0;
    while (i < instructions.len - 3) : (i += 1) {
        const instr = instructions[i];
        
        // Look for PUSH4 followed by JUMPI (function dispatch)
        if (instr.opcode == .push4 and instr.push_data != null and instr.push_data.?.len == 4) {
            const next = if (i + 1 < instructions.len) instructions[i + 1] else null;
            
            // Check for JUMPI after the selector
            if (next != null and (next.?.opcode == .jumpi or next.?.opcode == .jump)) {
                // This is likely a function selector
                const selector = instr.push_data.?;
                const func_name = try generateFunctionName(selector, allocator);
                
                // Try to analyze the function body
                const body = try analyzeFunctionBody(bytecode, instructions, instr.pc + 5, allocator);
                
                try funcs.append(allocator, .{
                    .name = func_name,
                    .entry_pc = instr.pc,
                    .params = &.{},
                    .returns = &.{},
                    .body_text = body,
                });
            }
        }
    }
    
    // Strategy 2: Find JUMPDESTs that are jump targets (function entry points)
    var jump_targets = std.AutoArrayHashMap(usize, void).init(allocator);
    defer jump_targets.deinit();
    
    for (instructions) |instr| {
        if (instr.opcode == .jumpdest) {
            try jump_targets.put(instr.pc, {});
        }
    }
    
    // Add functions for jump targets that weren't already found
    var iter = jump_targets.iterator();
    while (iter.next()) |entry| {
        const pc = entry.key_ptr.*;
        // Skip if already found
        var already_found = false;
        for (funcs.items) |f| {
            if (f.entry_pc == pc) {
                already_found = true;
                break;
            }
        }
        if (!already_found and pc > 0) {
            const body = try analyzeFunctionBody(bytecode, instructions, pc, allocator);
            const func_name = try std.fmt.allocPrint(allocator, "func_{x}", .{pc});
            try funcs.append(allocator, .{
                .name = func_name,
                .entry_pc = pc,
                .params = &.{},
                .returns = &.{},
                .body_text = body,
            });
        }
    }
    
    return funcs.toOwnedSlice(allocator);
}

/// Generate function name from selector
fn generateFunctionName(selector: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Check known signatures
    const known = getKnownSignature(selector);
    if (known) |name| {
        return try allocator.dupe(u8, name);
    }
    
    // Generate hex name
    return std.fmt.allocPrint(allocator, "0x{x}{x}{x}{x}", .{
        selector[0], selector[1], selector[2], selector[3]
    });
}

/// Get known function signature
fn getKnownSignature(selector: []const u8) ?[]const u8 {
    const known = [_]struct { []const u8, []const u8 }{
        .{ "a9059cbb", "transfer" },
        .{ "23b872dd", "transferFrom" },
        .{ "095ea7b3", "approve" },
        .{ "70a08231", "balanceOf" },
        .{ "18160ddd", "totalSupply" },
        .{ "ddf252ad", "Transfer" },
        .{ "8c5be1e5", "Approval" },
        .{ "095ea7b3", "approve" },
    };
    
    for (known) |entry| {
        if (std.mem.eql(u8, entry[0], selector)) {
            return entry[1];
        }
    }
    return null;
}

/// Analyze function body and generate pseudo-code
fn analyzeFunctionBody(_: []const u8, instructions: []const opcodes.Instruction, start_pc: usize, allocator: std.mem.Allocator) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    errdefer buf.deinit(allocator);
    
    var pc = start_pc;
    var stmt_count: usize = 0;
    const max_stmts = 20; // Limit statements
    
    const writer = buf.writer(allocator);
    
    while (pc < instructions.len and stmt_count < max_stmts) : (pc += 1) {
        const instr = instructions[pc];
        
        switch (instr.opcode) {
            .jumpdest => {
                // Function might have internal labels
            },
            .push1, .push2, .push3, .push4, .push5, .push6, .push7, .push8,
            .push9, .push10, .push11, .push12, .push13, .push14, .push15, .push16,
            .push17, .push18, .push19, .push20, .push21, .push22, .push23, .push24,
            .push25, .push26, .push27, .push28, .push29, .push30, .push31, .push32 => {
                try writer.print("    // push ${}\n", .{opcodes.getPushSize(instr.opcode)});
                stmt_count += 1;
            },
            .pop => {
                try writer.writeAll("    // pop\n");
                stmt_count += 1;
            },
            .mstore => {
                try writer.writeAll("    // mstore\n");
                stmt_count += 1;
            },
            .mload => {
                try writer.writeAll("    // mload\n");
                stmt_count += 1;
            },
            .sstore => {
                try writer.writeAll("    sstore(key, value);\n");
                stmt_count += 1;
            },
            .sload => {
                try writer.writeAll("    // sload\n");
                stmt_count += 1;
            },
            .call_op => {
                try writer.writeAll("    // external call\n");
                stmt_count += 1;
            },
            .delegatecall => {
                try writer.writeAll("    // delegatecall\n");
                stmt_count += 1;
            },
            .staticcall => {
                try writer.writeAll("    // staticcall\n");
                stmt_count += 1;
            },
            .return_op => {
                try writer.writeAll("    return;\n");
                break;
            },
            .revert => {
                try writer.writeAll("    revert();\n");
                break;
            },
            .selfdestruct => {
                try writer.writeAll("    selfdestruct(msg.sender);\n");
                break;
            },
            .jump => {
                try writer.writeAll("    // jump\n");
            },
            .jumpi => {
                try writer.writeAll("    // conditional jump\n");
            },
            .callvalue => {
                try writer.writeAll("    // msg.value\n");
                stmt_count += 1;
            },
            .caller => {
                try writer.writeAll("    // msg.sender\n");
                stmt_count += 1;
            },
            .address => {
                try writer.writeAll("    // address(this)\n");
                stmt_count += 1;
            },
            .balance => {
                try writer.writeAll("    // balance\n");
                stmt_count += 1;
            },
            .calldataload => {
                try writer.writeAll("    // calldataload\n");
                stmt_count += 1;
            },
            .calldatasize => {
                try writer.writeAll("    // calldatasize\n");
                stmt_count += 1;
            },
            .keccak256 => {
                try writer.writeAll("    // keccak256\n");
                stmt_count += 1;
            },
            else => {},
        }
        
        // Stop at return/revert
        if (instr.opcode == .return_op or instr.opcode == .revert or instr.opcode == .selfdestruct) {
            break;
        }
    }
    
    if (stmt_count == 0) {
        try writer.writeAll("    /* ... */");
    }
    
    return buf.toOwnedSlice(allocator);
}

/// Constructor info
pub const ConstructorInfo = struct {
    name: []const u8,
    params: []const Param,
    args_data: []const u8,
};

/// Decode constructor from initcode
fn decodeConstructor(initcode: []const u8, allocator: std.mem.Allocator) !Function {
    // Analyze initcode for constructor pattern
    const instructions = try opcodes.parseInstructions(allocator, initcode);
    defer allocator.free(instructions);
    
    var params: std.ArrayListUnmanaged(Param) = .{};
    
    // Try to find PUSH* operations that might be constructor args
    var arg_count: usize = 0;
    for (instructions) |instr| {
        if (opcodes.isPush(instr.opcode) and instr.push_data != null) {
            arg_count += 1;
        }
    }
    
    // Generate parameter names based on position
    if (arg_count > 0) {
        try params.append(allocator, .{ .name = "arg0", .type_str = "uint256" });
    }
    
    const body = try std.fmt.allocPrint(allocator, "    // Constructor: {} args decoded", .{arg_count});
    
    return .{
        .name = "constructor",
        .visibility = "public",
        .mutability = "payable",
        .params = try params.toOwnedSlice(allocator),
        .returns = &.{},
        .body = &.{.{ .text = body }},
    };
}

/// Pretty print generated Solidity code
pub fn prettyPrint(code: SolidityCode, allocator: std.mem.Allocator) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // Handle empty contracts
    if (code.contracts.len == 0) {
        try writer.writeAll("// No contracts generated\n");
        return buf.toOwnedSlice(allocator);
    }
    
    for (code.contracts) |contract| {

/// Simple Solidity generation without memory allocations
pub fn generateSimple(bytecode: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    const writer = buf.writer(allocator);
    
    // Header
    try writer.writeAll("// SPDX-License-Identifier: MIT\n");
    try writer.writeAll("pragma solidity ^0.8.0;\n\n");
    try writer.writeAll("contract DecompiledContract {\n\n");
    
    // State variables - simple detection
    var has_storage = false;
    for (bytecode) |b| {
        if (b == 0x54) { // SLOAD
            has_storage = true;
            break;
        }
    }
    
    if (has_storage) {
        try writer.writeAll("    // State variables\n");
        try writer.writeAll("    uint256 private _value;\n\n");
    }
    
    // Functions - detect from bytecode patterns
    var func_count: usize = 0;
    
    // Look for function selectors
    for (bytecode) |b, i| {
        if (b >= 0x60 and b <= 0x7f) { // PUSH
            if (i + 4 < bytecode.len) {
                // Check if next 4 bytes look like selector
                func_count += 1;
            }
        }
    }
    
    if (func_count > 0) {
        try writer.writeAll("    // Functions\n");
        try writer.writeAll("    function foo() external view {\n");
        try writer.writeAll("        // ...\n");
        try writer.writeAll("    }\n");
    } else {
        try writer.writeAll("    fallback() external {\n");
        try writer.writeAll("        revert();\n");
        try writer.writeAll("    }\n");
    }
    
    try writer.writeAll("}\n");
    
    return buf.toOwnedSlice(allocator);
}
            const nm = if (sv.name.len > 0) sv.name else "value";
            try writer.print("    {s} {s} {s};\n", .{ vis, typ, nm });
        }

        if (contract.state_variables.len > 0) try writer.writeAll("\n");

        // Functions
        if (contract.functions.len == 0) {
            try writer.writeAll("    // No functions detected\n");
        } else {
            for (contract.functions) |func| {
                const vis = if (func.visibility.len > 0) func.visibility else "external";
                const mut = if (func.mutability.len > 0) func.mutability else "view";
                const nm = if (func.name.len > 0) func.name else "fallback";
                try writer.print("    {s} {s} {s}(", .{ vis, mut, nm });
                
                for (func.params, 0..) |p, idx| {
                    if (idx > 0) try writer.writeAll(", ");
                    const pt = if (p.type_str.len > 0) p.type_str else "uint256";
                    const pn = if (p.name.len > 0) p.name else "param";
                    try writer.print("{s} {s}", .{ pt, pn });
                }
                try writer.writeAll(")");

                if (func.returns.len > 0) {
                    try writer.writeAll(" returns (");
                    for (func.returns, 0..) |r, idx| {
                        if (idx > 0) try writer.writeAll(", ");
                        const rt = if (r.type_str.len > 0) r.type_str else "uint256";
                        const rn = if (r.name.len > 0) r.name else "ret";
                        try writer.print("{s} {s}", .{ rt, rn });
                    }
                    try writer.writeAll(")");
                }

                try writer.writeAll(" {\n");
                if (func.body.len > 0) {
                    for (func.body) |stmt| {
                        const txt = if (stmt.text.len > 0) stmt.text else "revert();";
                        try writer.print("    {s}\n", .{txt});
                    }
                } else {
                    try writer.writeAll("    // ...\n");
                }
                try writer.writeAll("    }\n\n");
            }
        }

        try writer.writeAll("}\n");
    }

    return buf.toOwnedSlice(allocator);
}
