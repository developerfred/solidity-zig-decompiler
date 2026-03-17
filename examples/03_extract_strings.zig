// Example 3: Extract Embedded Strings
// Run: zig run examples/03_extract_strings.zig

const std = @import("std");
const strings = @import("evm/strings.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Bytecode with embedded strings (hex representation)
    // This contains "Example" and "Token" as ASCII
    const bytecode_hex = "0x45678616d706c6500546f6b656e496e6974";
    const bytecode = try std.fmt.parseHex(allocator, bytecode_hex[2..]);
    defer allocator.free(bytecode);
    
    std.debug.print("Extracting strings from bytecode...\n\n", .{});
    
    const extracted = try strings.extractStrings(allocator, bytecode, 3);
    defer {
        for (extracted) |s| allocator.free(s);
        allocator.free(extracted);
    }
    
    if (extracted.len == 0) {
        std.debug.print("No strings found.\n", .{});
    } else {
        std.debug.print("Found {d} string(s):\n", .{extracted.len});
        for (extracted) |s| {
            std.debug.print("  - \"{s}\"\n", .{s});
        }
    }
}
