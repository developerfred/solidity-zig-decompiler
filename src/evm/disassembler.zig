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

    /// Format a single instruction
    fn formatInstruction(_: Disassembler, allocator: std.mem.Allocator, buffer: *std.ArrayListUnmanaged(u8), instr: Instruction) !void {
        const name = opcodes.getName(instr.opcode);
        const pc_str = std.fmt.allocPrint(allocator, "{x:0>4}", .{instr.pc}) catch "";
        defer allocator.free(pc_str);
        try buffer.appendSlice(allocator, pc_str);

        if (instr.push_data) |data| {
            try buffer.appendSlice(allocator, " ");
            try buffer.appendSlice(allocator, name);
            try buffer.appendSlice(allocator, " 0x");
            for (data) |b| {
                const byte_str = std.fmt.allocPrint(allocator, "{x}", .{b}) catch "";
                defer allocator.free(byte_str);
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

    std.debug.print("\nDisassembly:\n{s}\n", .{result});
}
