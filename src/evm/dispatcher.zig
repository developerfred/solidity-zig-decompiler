// EVM Dispatcher Analyzer - Simplified

const std = @import("std");
const parser = @import("parser.zig");

pub const Selector = struct {
    selector: [4]u8,
    name: ?[]const u8 = null,
    pc: usize,
    confidence: f32 = 1.0,
};

pub const DispatcherAnalysis = struct {
    selectors: []Selector,
    dispatch_type: DispatchType,
    allocator: std.mem.Allocator,
};

pub const DispatchType = enum {
    legacy,
    meta_transactions,
    diamond,
    proxy,
    none,
};

pub fn analyzeDispatchers(allocator: std.mem.Allocator, bytecode: []const u8) !DispatcherAnalysis {
    var parsed = try parser.parse(allocator, bytecode);
    defer parser.deinit(&parsed);

    var list = std.ArrayListUnmanaged(Selector){};

    var dispatch_type: DispatchType = .none;

    // Look for PUSH instructions with 4 bytes (potential selectors)
    for (parsed.instructions) |instr| {
        if (instr.opcode == .push4 and instr.push_data != null and instr.push_data.?.len == 4) {
            var selector: [4]u8 = undefined;
            @memcpy(&selector, instr.push_data.?);

            // Check if already exists
            var exists = false;
            for (list.items) |s| {
                if (std.mem.eql(u8, &s.selector, &selector)) {
                    exists = true;
                    break;
                }
            }

            if (!exists) {
                try list.append(allocator, .{ .selector = selector, .pc = instr.pc, .confidence = 0.7 });
            }
        }
    }

    if (list.items.len > 0) {
        dispatch_type = .legacy;
    }

    return .{ .selectors = try list.toOwnedSlice(allocator), .dispatch_type = dispatch_type, .allocator = allocator };
}

pub fn deinit(analysis: *DispatcherAnalysis) void {
    analysis.allocator.free(analysis.selectors);
}
