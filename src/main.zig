// Solidity Zig Decompiler - Main Entry Point
// Advanced EVM bytecode decompiler with security focus

const std = @import("std");
const decompiler = @import("decompiler/main.zig");

/// Parse hex string to bytes
fn parseHexString(hex: []const u8) ![]const u8 {
    if (hex.len % 2 != 0) return error.InvalidHexLength;

    const bytes = try std.heap.page_allocator.alloc(u8, hex.len / 2);

    for (0..hex.len / 2) |i| {
        const hex_pair = hex[i * 2 .. i * 2 + 2];
        bytes[i] = try std.fmt.parseInt(u8, hex_pair, 16);
    }

    return bytes;
}

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 2) {
        std.debug.print("Solidity Zig Decompiler\n", .{});
        std.debug.print("=======================\n\n", .{});
        std.debug.print("Usage: {s} <bytecode> [options]\n", .{args[0]});
        std.debug.print("\nArguments:\n", .{});
        std.debug.print("  <bytecode>    Hex-encoded EVM bytecode (0x...)\n", .{});
        std.debug.print("\nOptions:\n", .{});
        std.debug.print("  --verbose     Enable verbose output\n", .{});
        std.debug.print("  --no-sig      Skip signature resolution\n", .{});
        std.debug.print("  --no-cfg      Skip CFG analysis\n", .{});
        std.debug.print("  --no-strings  Skip string extraction\n", .{});
        std.debug.print("  --no-patterns Skip pattern detection\n", .{});
        return;
    }

    var config: decompiler.Config = .{};
    var bytecode_arg: ?[]const u8 = null;

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--verbose")) {
            config.verbose = true;
        } else if (std.mem.eql(u8, arg, "--no-sig")) {
            config.resolve_signatures = false;
        } else if (std.mem.eql(u8, arg, "--no-cfg")) {
            config.build_cfg = false;
        } else if (std.mem.eql(u8, arg, "--no-strings")) {
            config.extract_strings = false;
        } else if (std.mem.eql(u8, arg, "--no-patterns")) {
            config.detect_patterns = false;
        } else if (std.mem.startsWith(u8, arg, "0x")) {
            bytecode_arg = arg;
        } else {
            // Try as file path
            if (std.fs.path.isAbsolute(arg)) {
                bytecode_arg = arg;
            } else {
                // Relative path
                bytecode_arg = arg;
            }
        }
    }

    const bytecode_source = bytecode_arg orelse {
        std.debug.print("Error: No bytecode or file provided\n", .{});
        return error.InvalidArguments;
    };

    // Check if it's a file
    var bytecode: []const u8 = undefined;

    if (std.fs.path.isAbsolute(bytecode_source)) {
        // It's a file path - read it
        const file = try std.fs.openFileAbsolute(bytecode_source, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const buffer = try std.heap.page_allocator.alloc(u8, file_size);
        defer std.heap.page_allocator.free(buffer);
        _ = try file.read(buffer);
        bytecode = buffer;
        defer std.heap.page_allocator.free(bytecode);
    } else if (std.mem.startsWith(u8, bytecode_source, "0x")) {
        // It's hex bytecode
        const hex_bytes = bytecode_source[2..];
        bytecode = try parseHexString(hex_bytes);
    } else {
        // Try as relative file path - try to open it
        const cwd = std.fs.cwd();
        const file = cwd.openFile(bytecode_source, .{}) catch null;
        if (file) |f| {
            defer f.close();
            const file_size = try f.getEndPos();
            const file_buffer = try std.heap.page_allocator.alloc(u8, file_size);
            defer std.heap.page_allocator.free(file_buffer);
            _ = try f.read(file_buffer);
            bytecode = file_buffer;
        } else {
            // Treat as hex string
            bytecode = bytecode_source;
        }
    }

    // Run decompiler
    const contract = try decompiler.decompile(std.heap.page_allocator, bytecode, config);

    // Output result
    var buf: [4096]u8 = undefined;
    var fbs = std.io.FixedBufferStream([]u8){ .buffer = &buf, .pos = 0 };
    try decompiler.generateSolidity(&contract, fbs.writer());
    std.debug.print("{s}", .{fbs.getWritten()});
}
