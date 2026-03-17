// Example 1: Basic Bytecode Parsing
// Run: zig run examples/01_parse_bytecode.zig

const std = @import("std");
const parser = @import("evm/parser.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Simple bytecode: PUSH1 0x01, PUSH1 0x02, ADD, STOP
    const bytecode = [_]u8{ 0x60, 0x01, 0x60, 0x02, 0x01, 0x00 };
    
    std.debug.print("Parsing bytecode: ", .{});
    for (bytecode) |b| {
        std.debug.print("{x} ", .{b});
    }
    std.debug.print("\n\n", .{});
    
    const result = try parser.parse(allocator, &bytecode);
    defer parser.deinit(&result);
    
    std.debug.print("Parsed {d} instructions:\n", .{result.instructions.len});
    
    for (result.instructions) |instr| {
        std.debug.print("  PC {d:>4}: {s}", .{ instr.pc, instr.name });
        if (instr.push_data) |data| {
            std.debug.print(" 0x{x}", .{std.mem.readInt(u32, data[0..@min(4, data.len)], .big)});
        }
        std.debug.print("\n", .{});
    }
}
