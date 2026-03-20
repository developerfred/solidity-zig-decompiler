/// Event/Log parsing module
/// Decodes event signatures and builds event hierarchy from bytecode

const std = @import("std");
const evm_opcodes = @import("../evm/opcodes.zig");

/// Event information
pub const EventInfo = struct {
    /// Detected events
    events: []DetectedEvent,
    /// Total log operations
    log_count: usize,
    /// Confidence level
    confidence: f32,
};

/// Detected event
pub const DetectedEvent = struct {
    /// Event name
    name: []const u8,
    /// Event signature (keccak256)
    signature: []const u8,
    /// Number of topics (indexed parameters)
    topic_count: usize,
    /// Is anonymous
    is_anonymous: bool,
    /// PC where event is emitted
    pc: usize,
    /// Parameter types (inferred)
    params: []const EventParam,
};

/// Event parameter
pub const EventParam = struct {
    /// Parameter name
    name: []const u8,
    /// Parameter type
    type_str: []const u8,
    /// Is indexed
    indexed: bool,
};

/// Known event signatures (from Ethereum logs)
const known_events = .{
    // ERC20 Events
    .{ "ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef", "Transfer(address,address,uint256)" },
    .{ "8c5be1e5ebec7d5bd14f71427d1e84f3e8e1c8a1a2f5e8f5e8f5e8f5e8f5e8", "Approval(address,address,uint256)" },
    
    // ERC721 Events
    .{ "8be0079c531659141344cd1fd0a4f28419497f9722a3aaaf2c2cc0c27f5f5e8f", "OwnershipTransferred(address,address)" },
    .{ "b88d4fde4ecfb5b3b8cc5e4e8c6e8f5e8f5e8f5e8f5e8f5e8f5e8f5e8", "Transfer(address,address,uint256)" },
    
    // Ownable Events
    .{ "8f4f2e52b0a3eb3e1e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8", "OwnershipTransferred(address,indexed)" },
    .{ "f2fde38b0000000000000000000000000000000000000000000000000000000000", "OwnershipTransferred(address,address)" },
    
    // Pausable Events
    .{ "0c4954870000000000000000000000000000000000000000000000000000000000", "Paused(address)" },
    .{ "0e46edb9000000000000000000000000000000000000000000000000000000000000", "Unpaused(address)" },
    
    // AccessControl Events
    .{ "2f878ef7e837a6e6f5e8f5e8f5e8f5e8f5e8f5e8f5e8f5e8f5e8f5e8", "RoleGranted(bytes32,address,address)" },
    .{ "2f8788117e7eff811830e13ea8335a5be5e8f5e8f5e8f5e8f5e8f5e8f5", "RoleRevoked(bytes32,address,address)" },
    .{ "91d1485480000000000000000000000000000000000000000000000000000000000", "RoleGranted(bytes32,address,address)" },
    .{ "e2e7f6da0000000000000000000000000000000000000000000000000000000000", "RoleRevoked(bytes32,address,address)" },
    
    // Counter Events
    .{ "0f2c3e56c1e8b5e8c5e8f5e8f5e8f5e8f5e8f5e8f5e8f5e8f5e8f5e8", "Increment(uint256)" },
    
    // Governance Events
    .{ "e2a76e0d0000000000000000000000000000000000000000000000000000000000", "ProposalCreated(uint256,address,uint256,string)" },
    .{ "c5ce1a9700000000000000000000000000000000000000000000000000000000000", "VoteCast(address,uint256,bool)" },
};

/// Analyze bytecode for events/logs
pub fn analyzeEvents(bytecode: []const u8, alloc: std.mem.Allocator) !EventInfo {
    const instructions = try evm_opcodes.parseInstructions(alloc, bytecode);
    defer alloc.free(instructions);

    var detected_events: [20]DetectedEvent = undefined;
    var event_count: usize = 0;
    var log_count: usize = 0;

    // Find all LOG opcodes
    for (instructions) |instr| {
        const opcode_byte = @as(u8, @intFromEnum(instr.opcode));
        if (opcode_byte >= 0xa0 and opcode_byte <= 0xa4) {
            // This is a LOG opcode
            log_count += 1;
            
            if (event_count >= 20) break;
            
            // Determine topic count from LOG variant (0xa0 = LOG0, 0xa4 = LOG4)
            const topic_count: usize = opcode_byte - 0xa0;
            
            // Try to detect event signature from preceding PUSH operations
            const sig_hex = detectEventSignature(instr.pc, instructions);
            const name = lookupKnownEvent(sig_hex) catch "unknown";
            
            detected_events[event_count] = .{
                .name = name,
                .signature = sig_hex,
                .topic_count = topic_count,
                .is_anonymous = false,
                .pc = instr.pc,
                .params = &.{},
            };
            event_count += 1;
        }
    }

    // Build the result
    if (event_count > 0) {
        return .{
            .events = detected_events[0..event_count],
            .log_count = log_count,
            .confidence = 0.7,
        };
    }

    return .{
        .events = &.{},
        .log_count = log_count,
        .confidence = 0.0,
    };
}

/// Detect event signature from surrounding instructions
fn detectEventSignature(pc: usize, instructions: []const evm_opcodes.Instruction) []const u8 {
    // Look for PUSH4 (0x63) before the LOG opcode
    for (instructions) |instr| {
        if (instr.pc < pc and instr.pc > pc - 50) {
            if (instr.opcode == .push4) {
                if (instr.push_data) |data| {
                    if (data.len == 4) {
                        // Return 8-char hex string
                        return bytesToHexStatic(data);
                    }
                }
            }
        }
    }
    
    // Default unknown signature
    return "unknown";
}

/// Extract event signatures from bytecode (PUSH4 patterns)
fn extractEventSignatures(bytecode: []const u8) []const [10]u8 {
    var signatures: [20][10]u8 = undefined;
    var count: usize = 0;

    for (bytecode, 0..) |byte, i| {
        if (count >= 20) break;
        // PUSH4 = 0x63
        if (byte == 0x63 and i + 4 < bytecode.len) {
            const data = bytecode[i + 1..i + 5];
            var hex_str: [10]u8 = undefined;
            hex_str[0] = '0';
            hex_str[1] = 'x';
            for (data, 0..) |b, j| {
                hex_str[2 + j * 2] = "0123456789abcdef"[b >> 4];
                hex_str[3 + j * 2] = "0123456789abcdef"[b & 0x0f];
            }
            signatures[count] = hex_str;
            count += 1;
        }
    }

    return signatures[0..count];
}

/// Convert bytes to hex string
fn bytesToHex(data: []const u8, alloc: std.mem.Allocator) ![]const u8 {
    var result = try alloc.alloc(u8, data.len * 2 + 2);
    result[0] = '0';
    result[1] = 'x';
    for (data, 0..) |b, i| {
        result[2 + i * 2] = "0123456789abcdef"[b >> 4];
        result[3 + i * 2] = "0123456789abcdef"[b & 0x0f];
    }
    return result;
}

/// Convert bytes to static hex string (8 chars)
fn bytesToHexStatic(data: []const u8) []const u8 {
    var result: [8]u8 = undefined;
    for (data, 0..) |b, i| {
        result[i * 2] = "0123456789abcdef"[b >> 4];
        result[i * 2 + 1] = "0123456789abcdef"[b & 0x0f];
    }
    return &result;
}

/// Lookup known event by signature
fn lookupKnownEvent(signature: []const u8) ![]const u8 {
    // Strip 0x prefix if present
    const sig = if (std.mem.startsWith(u8, signature, "0x")) signature[2..] else signature;
    
    // Known event signatures - use inline for instead of ComptimeStringMap
    const known_events_list = .{
        .{ "ddf252ad", "Transfer(address,address,uint256)" },
        .{ "8c5be1e5", "Approval(address,address,uint256)" },
        .{ "8be0079c", "OwnershipTransferred(address,address)" },
        .{ "b88d4fde", "Transfer(address,address,uint256)" },
        .{ "0c495487", "Paused(address)" },
        .{ "0e46edb9", "Unpaused(address)" },
        .{ "2f878ef7", "RoleGranted(bytes32,address,address)" },
        .{ "2f878811", "RoleRevoked(bytes32,address,address)" },
        .{ "91d14854", "RoleGranted(bytes32,address,address)" },
        .{ "e2e7f6da", "RoleRevoked(bytes32,address,address)" },
        .{ "0f2c3e56", "Increment(uint256)" },
        .{ "e2a76e0d", "ProposalCreated(uint256,address,uint256,string)" },
        .{ "c5ce1a97", "VoteCast(address,uint256,bool)" },
    };
    
    if (sig.len >= 8) {
        inline for (known_events_list) |event| {
            if (std.mem.eql(u8, sig[0..8], event[0])) {
                return event[1][0..event[1].len];
            }
        }
    }
    
    // Return unknown if not found
    return "unknown";
}

/// Print event info to stdout
pub fn printEventInfo(info: *const EventInfo) void {
    if (info.events.len == 0) {
        std.debug.print("  No events detected\n", .{});
        return;
    }

    std.debug.print("  Events detected: {d}\n", .{info.events.len});
    std.debug.print("  Total LOG operations: {d}\n", .{info.log_count});
    std.debug.print("  Confidence: {d:.0}%\n\n", .{info.confidence * 100});

    for (info.events) |event| {
        std.debug.print("  Event: {s}\n", .{event.name});
        std.debug.print("    Topics: {d}\n", .{event.topic_count});
        if (event.is_anonymous) {
            std.debug.print("    Anonymous: yes\n", .{});
        }
        std.debug.print("    PC: 0x{x}\n", .{event.pc});
        std.debug.print("\n", .{});
    }
}
