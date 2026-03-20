/// Library detection module
/// Identifies delegatecall patterns and known library calls

const std = @import("std");
const evm_opcodes = @import("../evm/opcodes.zig");

/// Known library selector lookup - simplified
fn isKnownLibrary(selector: *const [8]u8) bool {
    // Common selectors (without 0x prefix)
    const selectors = &[_][]const u8{
        "a9059cbb", // ERC20.transfer
        "23b872dd", // ERC20.transferFrom
        "095ea7b3", // ERC20.approve
        "18160ddd", // ERC20.totalSupply
        "00fdd58e", // ERC20.balanceOf
        "f2fde38b", // Ownable.transferOwnership
        "4c5f5b8c", // ReentrancyGuard.nonReentrant
    };
    
    for (selectors) |s| {
        if (std.mem.eql(u8, selector, s)) {
            return true;
        }
    }
    return false;
}

/// Library information
pub const LibraryInfo = struct {
    /// Whether library calls were detected
    has_libraries: bool,
    /// Detected library calls
    calls: []LibraryCall,
    /// Delegatecall patterns found
    delegate_calls: usize,

    pub fn deinit(self: *LibraryInfo, alloc: std.mem.Allocator) void {
        for (self.calls) |call| {
            alloc.free(call.name);
            alloc.free(call.library_name);
        }
        alloc.free(self.calls);
    }
};

/// Library call information
pub const LibraryCall = struct {
    /// Name of the function being called
    name: []const u8,
    /// Name of the library (if known)
    library_name: []const u8,
    /// Call type
    call_type: CallType,
    /// PC where the call occurs
    pc: usize,
    /// Address (if detectable)
    address: ?u64,
};

/// Type of call
pub const CallType = enum {
    delegatecall,
    staticcall,
    call,
    callcode,
};

/// Analyze bytecode for library usage
pub fn analyzeLibraries(bytecode: []const u8, alloc: std.mem.Allocator) !LibraryInfo {
    var info = LibraryInfo{
        .has_libraries = false,
        .calls = &.{},
        .delegate_calls = 0,
    };

    // Parse instructions
    const instructions = evm_opcodes.parseInstructions(alloc, bytecode) catch {
        return info;
    };
    defer alloc.free(instructions);

    // Count all CALL, DELEGATECALL, STATICCALL, CALLCODE
    var external_calls: usize = 0;
    
    for (instructions) |instr| {
        const opcode = instr.opcode;

        switch (opcode) {
            .delegatecall => {
                info.delegate_calls += 1;
            },
            .staticcall, .call_op, .callcode => {
                external_calls += 1;
            },
            else => {},
        }
    }

    // Look for known library selectors
    var known_count: usize = 0;
    
    // Simple pattern matching for known selectors
    // PUSH4 = 0x63
    for (bytecode, 0..) |byte, i| {
        if (byte == 0x63 and i + 4 < bytecode.len) {
            const sel = bytecode[i + 1..i + 5];
            // Check if it's a known library
            var sel_str: [8]u8 = undefined;
            for (sel, 0..) |b, j| {
                sel_str[j * 2] = "0123456789abcdef"[b >> 4];
                sel_str[j * 2 + 1] = "0123456789abcdef"[b & 0x0f];
            }
            if (isKnownLibrary(&sel_str)) {
                known_count += 1;
            }
        }
    }

    // Only report if we found library usage
    info.has_libraries = info.delegate_calls > 0 or known_count > 0;

    // If we have libraries, create a simple summary
    if (info.has_libraries) {
        const name = try std.fmt.allocPrint(alloc, "{d} external calls", .{external_calls});
        const lib_name = try std.fmt.allocPrint(alloc, "Detected", .{});
        
        info.calls = try alloc.alloc(LibraryCall, 1);
        info.calls[0] = LibraryCall{
            .name = name,
            .library_name = lib_name,
            .call_type = .call,
            .pc = 0,
            .address = null,
        };
    }

    return info;
}

/// Extract function selectors from bytecode
fn extractSelectors(bytecode: []const u8) ![]const [4]u8 {
    var selectors = std.ArrayList([4]u8).init(std.heap.page_allocator);
    defer selectors.deinit();

    // Look for PUSH4 followed by common function patterns
    // This is a simplified extraction
    for (bytecode, 0..) |byte, i| {
        // PUSH4 is 0x63
        if (byte == 0x63 and i + 4 < bytecode.len) {
            const sel: [4]u8 = bytecode[i + 1..i + 5].*;
            selectors.append(sel) catch {};
        }
    }

    return selectors.items;
}

/// Print library analysis to stdout
pub fn printLibraryInfo(info: *const LibraryInfo) void {
    if (!info.has_libraries) {
        std.debug.print("  No library calls detected\n", .{});
        return;
    }

    std.debug.print("  Library calls detected: {d}\n", .{info.calls.len});
    std.debug.print("  Delegate calls: {d}\n", .{info.delegate_calls});

    if (info.calls.len > 0) {
        std.debug.print("\n  Calls:\n", .{});
        for (info.calls) |call| {
            std.debug.print("    PC 0x{x}: {s} -> {s}\n", .{ 
                call.pc, 
                call.library_name,
                call.name 
            });
        }
    }
}

/// Check if bytecode is a library (starts with 0xfe INVALID)
pub fn isLibrary(bytecode: []const u8) bool {
    if (bytecode.len == 0) return false;
    // Libraries often have 0xfe at the start as a marker
    // But modern Solidity doesn't do this
    // Check for library linking pattern
    var invalid_count: usize = 0;
    for (bytecode) |byte| {
        if (byte == 0xfe) {
            invalid_count += 1;
        } else {
            break;
        }
    }
    return invalid_count > 0;
}

/// Get library name from function selector
pub fn getKnownLibrary(selector: [4]u8) ?[]const u8 {
    var sel_str: [8]u8 = undefined;
    for (selector, 0..) |b, i| {
        sel_str[i * 2] = "0123456789abcdef"[b >> 4];
        sel_str[i * 2 + 1] = "0123456789abcdef"[b & 0x0f];
    }
    return isKnownLibrary(&sel_str);
}
