//! Root source file for the Solidity decompiler library
const std = @import("std");

pub const evm_opcodes = @import("evm/opcodes.zig");
pub const evm_disassembler = @import("evm/disassembler.zig");
pub const evm_abi = @import("evm/abi.zig");
pub const bend_opcodes = @import("bend/opcodes.zig");
pub const bend_source = @import("bend/source.zig");
pub const symbolic = @import("symbolic/executor.zig");
pub const decompiler_module = @import("decompiler/main.zig");
pub const analysis_storage = @import("analysis/storage.zig");
pub const analysis_controlflow = @import("analysis/controlflow.zig");
pub const analysis_source = @import("analysis/source.zig");
pub const analysis_types = @import("analysis/types.zig");

pub fn bufferedPrint() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Solidity Zig Decompiler v0.1.0\n", .{});
    try stdout.flush();
}
