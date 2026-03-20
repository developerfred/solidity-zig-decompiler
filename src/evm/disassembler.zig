/// Disassembler - converts bytecode to human-readable assembly

const std = @import("std");
const opcodes = @import("opcodes.zig");
const Opcode = opcodes.Opcode;
const Instruction = opcodes.Instruction;

pub const Disassembler = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Disassembler {
        return .{ .allocator = allocator };
    }

    /// Disassemble bytecode to a string
    pub fn disassemble(self: Disassembler, bytecode: []const u8) ![]u8 {
        const instructions = try opcodes.parseInstructions(self.allocator, bytecode);
        defer self.allocator.free(instructions);

        var buffer: std.ArrayListUnmanaged(u8) = .{};
        errdefer buffer.deinit(self.allocator);

        for (instructions) |instr| {
            try self.formatInstruction(self.allocator, &buffer, instr);
            try buffer.append(self.allocator, '\n');
        }

        return buffer.toOwnedSlice(self.allocator);
    }

    /// Format a single instruction - optimized with fixed buffer
    fn formatInstruction(_: Disassembler, allocator: std.mem.Allocator, buffer: *std.ArrayListUnmanaged(u8), instr: Instruction) !void {
        const name = opcodes.getName(instr.opcode);
        
        // Use fixed-size buffer for PC (4 hex chars = 2 bytes max)
        var pc_buf: [4]u8 = undefined;
        const pc_str = std.fmt.bufPrint(&pc_buf, "{x:0>4}", .{instr.pc}) catch "";
        try buffer.appendSlice(allocator, pc_str);

        if (instr.push_data) |data| {
            try buffer.appendSlice(allocator, " ");
            try buffer.appendSlice(allocator, name);
            try buffer.appendSlice(allocator, " 0x");
            // Use fixed buffer per byte (2 hex chars max)
            for (data) |b| {
                var byte_buf: [2]u8 = undefined;
                const byte_str = std.fmt.bufPrint(&byte_buf, "{x}", .{b}) catch "";
                try buffer.appendSlice(allocator, byte_str);
            }
        } else {
            try buffer.appendSlice(allocator, " ");
            try buffer.appendSlice(allocator, name);
        }
    }

    /// Disassemble and print to stdout
    pub fn disassembleToStdout(self: Disassembler, bytecode: []const u8) !void {
        const instructions = try opcodes.parseInstructions(self.allocator, bytecode);
        defer self.allocator.free(instructions);

        for (instructions) |instr| {
            std.debug.print("{x:0>4} ", .{instr.pc});
            const name = opcodes.getName(instr.opcode);
            if (instr.push_data) |data| {
                std.debug.print("{s} 0x", .{name});
                for (data) |b| {
                    std.debug.print("{x}", .{b});
                }
            } else {
                std.debug.print("{s}", .{name});
            }
            std.debug.print("\n", .{});
        }
    }
};

test "disassembler basic" {
    const bytecode = [_]u8{ 0x60, 0x05, 0x60, 0x03, 0x01, 0x56 }; // PUSH1 5, PUSH1 3, ADD, JUMP
    const allocator = std.testing.allocator;
    const dis = Disassembler.init(allocator);

    const result = try dis.disassemble(&bytecode);
    defer allocator.free(result);

    // Should contain the expected opcodes
    try std.testing.expect(std.mem.indexOf(u8, result, "PUSH1") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "ADD") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "JUMP") != null);
}

test "disassembler memory operations" {
    // PUSH1 0x40, MSTORE, PUSH1 0x00, MLOAD
    const bytecode = [_]u8{ 0x60, 0x40, 0x52, 0x60, 0x00, 0x51 };
    const allocator = std.testing.allocator;
    const dis = Disassembler.init(allocator);

    const result = try dis.disassemble(&bytecode);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "MSTORE") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "MLOAD") != null);
}

test "disassembler storage operations" {
    // PUSH1 0x00, SLOAD, PUSH1 0x00, SSTORE
    const bytecode = [_]u8{ 0x60, 0x00, 0x54, 0x60, 0x00, 0x55 };
    const allocator = std.testing.allocator;
    const dis = Disassembler.init(allocator);

    const result = try dis.disassemble(&bytecode);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "SLOAD") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "SSTORE") != null);
}

test "disassembler control flow" {
    // JUMPDEST, JUMP
    const bytecode = [_]u8{ 0x5b, 0x56 };
    const allocator = std.testing.allocator;
    const dis = Disassembler.init(allocator);

    const result = try dis.disassemble(&bytecode);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "JUMPDEST") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "JUMP") != null);
}

test "disassembler push values" {
    // PUSH2 with value
    const bytecode = [_]u8{ 0x61, 0x01, 0x02 };
    const allocator = std.testing.allocator;
    const dis = Disassembler.init(allocator);

    const result = try dis.disassemble(&bytecode);
    defer allocator.free(result);

    // Should contain PUSH2 and the pushed value
    try std.testing.expect(std.mem.indexOf(u8, result, "PUSH2") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "0x") != null);
}
