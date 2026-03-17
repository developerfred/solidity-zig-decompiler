// Embedded String Extractor - Ultra Simplified

const std = @import("std");

const MIN_STRING_LEN = 4;
const MAX_STRING_LEN = 64;

pub const EmbeddedString = struct {
    value: []const u8,
    offset: usize,
};

pub const StringExtraction = struct {
    strings: []EmbeddedString,
    allocator: std.mem.Allocator,
};

pub fn extract(allocator: std.mem.Allocator, bytecode: []const u8) !StringExtraction {
    if (bytecode.len < MIN_STRING_LEN) {
        return .{ .strings = &.{}, .allocator = allocator };
    }

    // Simple extraction - just find printable strings
    var list = std.ArrayListUnmanaged(EmbeddedString){};

    var i: usize = 0;
    while (i + MIN_STRING_LEN <= bytecode.len) : (i += 1) {
        const remaining = bytecode[i..];
        const str = findAsciiString(remaining);

        if (str.len >= MIN_STRING_LEN and isLikelyString(str)) {
            try list.append(allocator, .{ .value = str, .offset = i });
            i += str.len - 1;
        }
    }

    return .{ .strings = try list.toOwnedSlice(allocator), .allocator = allocator };
}

fn findAsciiString(data: []const u8) []const u8 {
    var end: usize = 0;
    while (end < data.len and end < MAX_STRING_LEN) : (end += 1) {
        const byte = data[end];
        const is_printable = (byte >= 0x20 and byte <= 0x7e) or byte == 0x09 or byte == 0x0a or byte == 0x0d;
        if (!is_printable) break;
    }
    return data[0..end];
}

fn isLikelyString(str: []const u8) bool {
    if (str.len < MIN_STRING_LEN) return false;
    var alpha_count: usize = 0;
    for (str) |byte| {
        if ((byte >= 'a' and byte <= 'z') or (byte >= 'A' and byte <= 'Z')) alpha_count += 1;
    }
    return alpha_count * 2 >= str.len;
}

pub fn deinit(ext: *StringExtraction) void {
    ext.allocator.free(ext.strings);
}
