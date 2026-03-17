// Diff Module - Compare two smart contracts

const std = @import("std");
const decompiler = @import("../decompiler/main.zig");
const evm_signatures = @import("../evm/signatures.zig");

pub const DiffResult = struct {
    added_functions: []decompiler.DecompiledFunction,
    removed_functions: []decompiler.DecompiledFunction,
    common_functions: usize,
    similarity_score: f32,
};

/// Compare two decompiled contracts
pub fn diffContracts(allocator: std.mem.Allocator, contract1: *const decompiler.DecompiledContract, contract2: *const decompiler.DecompiledContract) !DiffResult {
    // Find added and removed functions using simple approach
    var added_funcs = std.ArrayList(decompiler.DecompiledFunction).init(allocator);
    defer added_funcs.deinit();
    
    for (contract2.functions) |func2| {
        var found = false;
        for (contract1.functions) |func1| {
            if (std.mem.eql(u8, &func1.selector, &func2.selector)) {
                found = true;
                break;
            }
        }
        if (!found) {
            try added_funcs.append(func2);
        }
    }
    
    var removed_funcs = std.ArrayList(decompiler.DecompiledFunction).init(allocator);
    defer removed_funcs.deinit();
    
    for (contract1.functions) |func1| {
        var found = false;
        for (contract2.functions) |func2| {
            if (std.mem.eql(u8, &func1.selector, &func2.selector)) {
                found = true;
                break;
            }
        }
        if (!found) {
            try removed_funcs.append(func1);
        }
    }
    
    // Count common functions
    var common: usize = 0;
    for (contract1.functions) |func1| {
        for (contract2.functions) |func2| {
            if (std.mem.eql(u8, &func1.selector, &func2.selector)) {
                common += 1;
                break;
            }
        }
    }
    
    // Calculate similarity score
    const total1 = contract1.functions.len;
    const total2 = contract2.functions.len;
    var similarity: f32 = 0.0;
    if (total1 + total2 > 0) {
        similarity = @as(f32, @floatFromInt(common * 2)) / @as(f32, @floatFromInt(total1 + total2));
    } else {
        similarity = 1.0;
    }
    
    return DiffResult{
        .added_functions = try added_funcs.toOwnedSlice(),
        .removed_functions = try removed_funcs.toOwnedSlice(),
        .common_functions = common,
        .similarity_score = similarity,
    };
}

/// Generate diff output in text format
pub fn generateDiffText(allocator: std.mem.Allocator, contract1_name: []const u8, contract2_name: []const u8, diff: *const DiffResult) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    
    const writer = list.writer();
    
    try writer.writeAll("Contract Diff Report\n");
    try writer.writeAll("===================\n\n");
    
    try writer.print("Comparing: {s} vs {s}\n\n", .{contract1_name, contract2_name});
    
    const score_int = @as(u32, @intFromFloat(diff.similarity_score * 100.0));
    try writer.print("Similarity Score: {d}%\n\n", .{score_int});
    
    try writer.print("Common Functions: {d}\n", .{diff.common_functions});
    try writer.print("Added Functions: {d}\n", .{diff.added_functions.len});
    try writer.print("Removed Functions: {d}\n\n", .{diff.removed_functions.len});
    
    if (diff.added_functions.len > 0) {
        try writer.writeAll("=== ADDED FUNCTIONS ===\n");
        for (diff.added_functions) |func| {
            try writer.print("  + {s} ({s})\n", .{func.name, evm_signatures.selectorToSlice(func.selector)});
        }
        try writer.writeAll("\n");
    }
    
    if (diff.removed_functions.len > 0) {
        try writer.writeAll("=== REMOVED FUNCTIONS ===\n");
        for (diff.removed_functions) |func| {
            try writer.print("  - {s} ({s})\n", .{func.name, evm_signatures.selectorToSlice(func.selector)});
        }
        try writer.writeAll("\n");
    }
    
    if (diff.added_functions.len == 0 and diff.removed_functions.len == 0) {
        try writer.writeAll("No differences found - contracts have identical function sets.\n");
    }
    
    return try list.toOwnedSlice();
}

/// Generate diff output in JSON format
pub fn generateDiffJson(allocator: std.mem.Allocator, contract1_name: []const u8, contract2_name: []const u8, diff: *const DiffResult) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    
    const writer = list.writer();
    
    const score_int = @as(u32, @intFromFloat(diff.similarity_score * 100.0));
    
    try writer.writeAll("{\n");
    try writer.print("  \"contract1\": \"{s}\",\n", .{contract1_name});
    try writer.print("  \"contract2\": \"{s}\",\n", .{contract2_name});
    try writer.print("  \"similarity_score\": {d},\n", .{score_int});
    try writer.print("  \"common_functions\": {d},\n", .{diff.common_functions});
    try writer.print("  \"added_count\": {d},\n", .{diff.added_functions.len});
    try writer.print("  \"removed_count\": {d},\n", .{diff.removed_functions.len});
    
    try writer.writeAll("  \"added_functions\": [\n");
    for (diff.added_functions, 0..) |func, i| {
        try writer.writeAll("    {\n");
        try writer.print("      \"name\": \"{s}\",\n", .{func.name});
        try writer.print("      \"selector\": \"{s}\"\n", .{evm_signatures.selectorToSlice(func.selector)});
        try writer.writeAll("    }");
        if (i < diff.added_functions.len - 1) try writer.writeAll(",");
        try writer.writeAll("\n");
    }
    try writer.writeAll("  ],\n");
    
    try writer.writeAll("  \"removed_functions\": [\n");
    for (diff.removed_functions, 0..) |func, i| {
        try writer.writeAll("    {\n");
        try writer.print("      \"name\": \"{s}\",\n", .{func.name});
        try writer.print("      \"selector\": \"{s}\"\n", .{evm_signatures.selectorToSlice(func.selector)});
        try writer.writeAll("    }");
        if (i < diff.removed_functions.len - 1) try writer.writeAll(",");
        try writer.writeAll("\n");
    }
    try writer.writeAll("  ]\n");
    
    try writer.writeAll("}\n");
    
    return try list.toOwnedSlice();
}
