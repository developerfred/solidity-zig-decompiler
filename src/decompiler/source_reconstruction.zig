// Solidity Source Code Reconstruction Module
// Generate more readable and compilable Solidity code from bytecode

const std = @import("std");
const decompiler = @import("../decompiler/main.zig");

pub const ReconstructedContract = struct {
    name: []const u8,
    solidity_version: []const u8,
    license: []const u8,
    state_variables: []StateVariable,
    functions: []ReconstructedFunction,
    events: []ReconstructedEvent,
    structs: []ReconstructedStruct,
    imports: [][]const u8,
};

pub const StateVariable = struct {
    name: []const u8,
    var_type: []const u8,
    visibility: []const u8,
    slot: ?usize,
};

pub const ReconstructedFunction = struct {
    name: []const u8,
    visibility: []const u8,
    state_mutability: []const u8,
    parameters: []Parameter,
    returns: []Parameter,
    body: []const u8,
    modifiers: [][]const u8,
    selectors: [][]const u8,
};

pub const Parameter = struct {
    name: []const u8,
    param_type: []const u8,
};

pub const ReconstructedEvent = struct {
    name: []const u8,
    parameters: []Parameter,
};

pub const ReconstructedStruct = struct {
    name: []const u8,
    fields: []StructField,
};

pub const StructField = struct {
    name: []const u8,
    field_type: []const u8,
};

/// Reconstruct Solidity code from decompiled contract
pub fn reconstruct(allocator: std.mem.Allocator, contract: *const decompiler.DecompiledContract) !ReconstructedContract {
    var state_vars = std.ArrayList(StateVariable).init(allocator);
    defer state_vars.deinit();
    
    var functions = std.ArrayList(ReconstructedFunction).init(allocator);
    defer functions.deinit();
    
    var events = std.ArrayList(ReconstructedEvent).init(allocator);
    defer events.deinit();
    
    // Detect contract type and add appropriate state variables
    if (contract.is_erc20) {
        try state_vars.append(.{ .name = "name", .var_type = "string", .visibility = "private", .slot = null });
        try state_vars.append(.{ .name = "symbol", .var_type = "string", .visibility = "private", .slot = null });
        try state_vars.append(.{ .name = "decimals", .var_type = "uint8", .visibility = "private", .slot = null });
        try state_vars.append(.{ .name = "_totalSupply", .var_type = "uint256", .visibility = "private", .slot = null });
        try state_vars.append(.{ .name = "_balances", .var_type = "mapping(address => uint256)", .visibility = "private", .slot = null });
        try state_vars.append(.{ .name = "_allowances", .var_type = "mapping(address => mapping(address => uint256))", .visibility = "private", .slot = null });
    }
    
    if (contract.is_erc721) {
        try state_vars.append(.{ .name = "_name", .var_type = "string", .visibility = "private", .slot = null });
        try state_vars.append(.{ .name = "_symbol", .var_type = "string", .visibility = "private", .slot = null });
        try state_vars.append(.{ .name = "_owners", .var_type = "mapping(uint256 => address)", .visibility = "private", .slot = null });
        try state_vars.append(.{ .name = "_balances", .var_type = "mapping(address => uint256)", .visibility = "private", .slot = null });
    }
    
    // Reconstruct functions from decompiled functions
    for (contract.functions) |func| {
        const reconstructed = try reconstructFunction(allocator, func);
        try functions.append(reconstructed);
    }
    
    // Generate common events for recognized contracts
    if (contract.is_erc20) {
        try events.append(.{ .name = "Transfer", .parameters = &.{
            .{ .name = "from", .param_type = "address" },
            .{ .name = "to", .param_type = "address" },
            .{ .name = "value", .param_type = "uint256" },
        }});
        try events.append(.{ .name = "Approval", .parameters = &.{
            .{ .name = "owner", .param_type = "address" },
            .{ .name = "spender", .param_type = "address" },
            .{ .name = "value", .param_type = "uint256" },
        }});
    }
    
    return ReconstructedContract{
        .name = contract.name,
        .solidity_version = "^0.8.0",
        .license = "UNLICENSED",
        .state_variables = try state_vars.toOwnedSlice(),
        .functions = try functions.toOwnedSlice(),
        .events = try events.toOwnedSlice(),
        .structs = &.{},
        .imports = &.{},
    };
}

/// Reconstruct a single function
fn reconstructFunction(allocator: std.mem.Allocator, func: decompiler.DecompiledFunction) !ReconstructedFunction {
    // Parse parameters from signature if available
    var params = std.ArrayList(Parameter).init(allocator);
    defer params.deinit();
    
    if (func.signature != null) {
        // Simple parsing: extract parameter names/types from signature
        // This is a basic implementation
        try params.append(.{ .name = "params", .param_type = "bytes" });
    }
    
    // Determine visibility and mutability based on function name
    var visibility = "external";
    var mutability = "view";
    
    if (std.mem.indexOf(u8, func.name, "set") != null or 
        std.mem.indexOf(u8, func.name, "transfer") != null) {
        mutability = "nonpayable";
    }
    if (std.mem.indexOf(u8, func.name, "mint") != null) {
        mutability = "nonpayable";
    }
    if (std.mem.indexOf(u8, func.name, "admin") != null) {
        visibility = "public";
    }
    
    const selector_str = evm_signatures.selectorToSlice(func.selector);
    
    return ReconstructedFunction{
        .name = func.name,
        .visibility = visibility,
        .state_mutability = mutability,
        .parameters = try params.toOwnedSlice(),
        .returns = &.{},
        .body = "// Decompiled - implementation hidden",
        .modifiers = &.{},
        .selectors = &.{selector_str},
    };
}

/// Generate complete Solidity source code
pub fn generateSource(allocator: std.mem.Allocator, reconstructed: *const ReconstructedContract) ![]u8 {
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();
    
    const writer = output.writer();
    
    // SPDX License
    try writer.print("// SPDX-License-Identifier: {s}\n", .{reconstructed.license});
    try writer.writeAll("\n");
    
    // Pragma
    try writer.print("pragma solidity {s};\n\n", .{reconstructed.solidity_version});
    
    // Contract declaration
    try writer.print("contract {s} {{\n\n", .{reconstructed.name});
    
    // State variables
    for (reconstructed.state_variables) |state_var| {
        try writer.print("    {s} {s} {s}", .{ state_var.visibility, state_var.var_type, state_var.name });
        if (state_var.slot) |slot| {
            try writer.print(" // slot {d}", .{slot});
        }
        try writer.writeAll(";\n");
    }
    try writer.writeAll("\n");
    
    // Events
    for (reconstructed.events) |event| {
        try writer.print("    event {s}(", .{event.name});
        for (event.parameters, 0..) |param, i| {
            try writer.print("{s} {s}", .{ param.param_type, param.name });
            if (i < event.parameters.len - 1) try writer.writeAll(", ");
        }
        try writer.writeAll(");\n");
    }
    try writer.writeAll("\n");
    
    // Functions
    for (reconstructed.functions) |func| {
        // Function selector comments
        for (func.selectors) |sel| {
            try writer.print("    // {s}\n", .{sel});
        }
        
        try writer.print("    function {s}(", .{func.name});
        for (func.parameters, 0..) |param, i| {
            try writer.print("{s} {s}", .{ param.param_type, param.name });
            if (i < func.parameters.len - 1) try writer.writeAll(", ");
        }
        try writer.writeAll(") ");
        try writer.print("{s} {s}", .{ func.visibility, func.state_mutability });
        
        if (func.modifiers.len > 0) {
            try writer.writeAll(" ");
            for (func.modifiers, 0..) |mod, i| {
                try writer.writeAll(mod);
                if (i < func.modifiers.len - 1) try writer.writeAll(" ");
            }
        }
        
        try writer.writeAll(" {\n");
        try writer.print("        {s}\n", .{func.body});
        try writer.writeAll("    }\n\n");
    }
    
    try writer.writeAll("}\n");
    
    return try output.toOwnedSlice();
}

// Import for selector conversion
const evm_signatures = @import("../evm/signatures.zig");
