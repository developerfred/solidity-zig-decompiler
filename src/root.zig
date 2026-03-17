//! Solidity Zig Decompiler - Root Module
//!
//! This is the main entry point for the decompiler library.
//! Export all public modules here for easy importing.

const std = @import("std");

// Re-export all public modules
pub const evm = struct {
    pub const parser = @import("evm/parser.zig");
    pub const signatures = @import("evm/signatures.zig");
    pub const opcodes = @import("evm/opcodes.zig");
    pub const strings = @import("evm/strings.zig");
    pub const dispatcher = @import("evm/dispatcher.zig");
    pub const cfg = @import("evm/cfg.zig");
};

pub const decompiler = @import("decompiler/main.zig");
pub const analysis = @import("analysis/gas.zig");
pub const symbolic = @import("symbolic/executor.zig");
pub const vulnerability = @import("vulnerability/scanner.zig");

/// Library version
pub const version = "0.1.0";

/// Initialize the decompiler with default settings
pub fn init() void {
    // Placeholder for any initialization logic
}

/// Get library info
pub fn getInfo() []const u8 {
    return "Solidity Zig Decompiler v" ++ version;
}

test "library version" {
    try std.testing.expectEqualStrings("0.1.0", version);
}
