// Contract Verification Module
// Verify decompiled contracts against source code from block explorers

const std = @import("std");
const decompiler = @import("../decompiler/main.zig");

pub const VerificationStatus = enum(u8) {
    verified,
    mismatch,
    partial_match,
    not_found,
    error,
};

pub const FunctionVerification = struct {
    function_name: []const u8,
    selector: []const u8,
    status: VerificationStatus,
    differences: ?[]const u8,
};

pub const ContractVerification = struct {
    contract_address: []const u8,
    status: VerificationStatus,
    chain: []const u8,
    functions: []FunctionVerification,
    verified_at: i64,
    source_match_score: f32, // 0-100%
};

/// Verify contract by comparing decompiled functions with source
pub fn verifyContract(
    allocator: std.mem.Allocator,
    decompiled: *const decompiler.DecompiledContract,
    source_functions: []const SourceFunction,
) !ContractVerification {
    var verified_functions = std.ArrayList(FunctionVerification).init(allocator);
    defer verified_functions.deinit();

    var match_count: usize = 0;

    // Match each decompiled function with source
    for (decompiled.functions) |dec_func| {
        const selector_str = evm_signatures.selectorToSlice(dec_func.selector);
        
        // Try to find matching source function
        var matched = false;
        var differences: ?[]const u8 = null;
        
        for (source_functions) |src_func| {
            if (std.mem.eql(u8, src_func.selector, selector_str)) {
                matched = true;
                
                // Compare function names/signatures
                if (!std.mem.eql(u8, dec_func.name, src_func.name)) {
                    differences = try std.fmt.allocPrint(
                        allocator,
                        "Name mismatch: decompiled='{s}' vs source='{s}'",
                        .{ dec_func.name, src_func.name },
                    );
                }
                break;
            }
        }
        
        const status: VerificationStatus = if (matched) 
            (if (differences != null) .partial_match else .verified)
        else 
            .not_found;
        
        if (status == .verified) match_count += 1;
        
        try verified_functions.append(.{
            .function_name = dec_func.name,
            .selector = selector_str,
            .status = status,
            .differences = differences,
        });
    }
    
    const total_funcs = decompiled.functions.len;
    const score: f32 = if (total_funcs > 0) 
        @floatFromInt(match_count * 100) / @floatFromInt(total_funcs)
    else 
        0.0;
    
    const overall_status: VerificationStatus = if (match_count == total_funcs)
        .verified
    else if (match_count > 0)
        .partial_match
    else
        .not_found;
    
    return ContractVerification{
        .contract_address = "unknown",
        .status = overall_status,
        .chain = "ethereum",
        .functions = try verified_functions.toOwnedSlice(),
        .verified_at = std.time.timestamp(),
        .source_match_score = score,
    };
}

/// Source function from block explorer API
pub const SourceFunction = struct {
    name: []const u8,
    selector: []const u8,
    signature: []const u8,
};

// Helper to format verification result
pub fn formatVerification(result: *const ContractVerification, writer: anytype) !void {
    try writer.print("Contract Verification Report\n", .{});
    try writer.writeAll("==========================\n\n");
    
    try writer.print("Status: {s}\n", .{ @tagName(result.status) });
    try writer.print("Match Score: {d}%\n", .{ @intFromFloat(result.source_match_score) });
    try writer.print("Chain: {s}\n", .{result.chain});
    try writer.writeAll("\nFunction Results:\n");
    try writer.writeAll("----------------\n");
    
    for (result.functions) |func| {
        const status_icon = switch (func.status) {
            .verified => "[✓]",
            .mismatch => "[✗]",
            .partial_match => "[~]",
            .not_found => "[?]",
            .error => "[!]",
        };
        try writer.print("  {s} {s} ({s})\n", .{ status_icon, func.function_name, func.selector });
        if (func.differences) |diff| {
            try writer.print("      Difference: {s}\n", .{diff});
        }
    }
}

// Import for selector conversion
const evm_signatures = @import("../evm/signatures.zig");
