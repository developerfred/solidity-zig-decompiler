/// EVM Opcodes definitions for the Solidity decompiler
/// Reference: https://ethereum.github.io/yellowpaper/paper.pdf

const std = @import("std");

/// EVM Opcode enumeration
pub const Opcode = enum(u8) {
    // Stop and Arithmetic Operations
    stop = 0x00,
    add = 0x01,
    mul = 0x02,
    sub = 0x03,
    div = 0x04,
    sdiv = 0x05,
    mod = 0x06,
    smod = 0x07,
    addmod = 0x08,
    mulmod = 0x09,
    exp = 0x0a,
    signextend = 0x0b,

    // Comparison & Bitwise Operations
    lt = 0x10,
    gt = 0x11,
    slt = 0x12,
    sgt = 0x13,
    eq = 0x14,
    iszero = 0x15,
    bitand = 0x16,
    bitor = 0x17,
    xor = 0x18,
    not = 0x19,
    byte = 0x1a,
    shl = 0x1b,
    shr = 0x1c,
    sar = 0x1d,

    // SHA3
    keccak256 = 0x20,

    // Environmental Information
    address = 0x30,
    balance = 0x31,
    origin = 0x32,
    caller = 0x33,
    callvalue = 0x34,
    calldataload = 0x35,
    calldatasize = 0x36,
    calldatacopy = 0x37,
    codesize = 0x38,
    codecopy = 0x39,
    gasprice = 0x3a,
    extcodesize = 0x3b,
    extcodecopy = 0x3c,
    returndatasize = 0x3d,
    returndatacopy = 0x3e,
    extcodehash = 0x3f,

    // Block Information
    blockhash = 0x40,
    coinbase = 0x41,
    timestamp = 0x42,
    number = 0x43,
    difficulty = 0x44,
    gaslimit = 0x45,
    chainid = 0x46,
    selfbalance = 0x47,
    basefee = 0x48,
    blobhash = 0x49,
    blobbasefee = 0x4a,

    // Stack, Memory, Storage and Flow Operations
    pop = 0x50,
    mload = 0x51,
    mstore = 0x52,
    mstore8 = 0x53,
    sload = 0x54,
    sstore = 0x55,
    jump = 0x56,
    jumpi = 0x57,
    pc = 0x58,
    msize = 0x59,
    gas = 0x5a,
    jumpdest = 0x5b,

    // Push Operations
    push1 = 0x60,
    push2 = 0x61,
    push3 = 0x62,
    push4 = 0x63,
    push5 = 0x64,
    push6 = 0x65,
    push7 = 0x66,
    push8 = 0x67,
    push9 = 0x68,
    push10 = 0x69,
    push11 = 0x6a,
    push12 = 0x6b,
    push13 = 0x6c,
    push14 = 0x6d,
    push15 = 0x6e,
    push16 = 0x6f,
    push17 = 0x70,
    push18 = 0x71,
    push19 = 0x72,
    push20 = 0x73,
    push21 = 0x74,
    push22 = 0x75,
    push23 = 0x76,
    push24 = 0x77,
    push25 = 0x78,
    push26 = 0x79,
    push27 = 0x7a,
    push28 = 0x7b,
    push29 = 0x7c,
    push30 = 0x7d,
    push31 = 0x7e,
    push32 = 0x7f,

    // Duplicate Operations
    dup1 = 0x80,
    dup2 = 0x81,
    dup3 = 0x82,
    dup4 = 0x83,
    dup5 = 0x84,
    dup6 = 0x85,
    dup7 = 0x86,
    dup8 = 0x87,
    dup9 = 0x88,
    dup10 = 0x89,
    dup11 = 0x8a,
    dup12 = 0x8b,
    dup13 = 0x8c,
    dup14 = 0x8d,
    dup15 = 0x8e,
    dup16 = 0x8f,

    // Exchange Operations
    swap1 = 0x90,
    swap2 = 0x91,
    swap3 = 0x92,
    swap4 = 0x93,
    swap5 = 0x94,
    swap6 = 0x95,
    swap7 = 0x96,
    swap8 = 0x97,
    swap9 = 0x98,
    swap10 = 0x99,
    swap11 = 0x9a,
    swap12 = 0x9b,
    swap13 = 0x9c,
    swap14 = 0x9d,
    swap15 = 0x9e,
    swap16 = 0x9f,

    // Log Operations
    log0 = 0xa0,
    log1 = 0xa1,
    log2 = 0xa2,
    log3 = 0xa3,
    log4 = 0xa4,

    // System Operations
    create = 0xf0,
    call_op = 0xf1,
    callcode = 0xf2,
    return_op = 0xf3,
    delegatecall = 0xf4,
    create2 = 0xf5,
    staticcall = 0xfa,
    revert = 0xfd,
    invalid_op = 0xfe,
    selfdestruct = 0xff,
};

/// Get the name of an opcode
pub fn getName(opcode: Opcode) []const u8 {
    return switch (opcode) {
        .stop => "STOP",
        .add => "ADD",
        .mul => "MUL",
        .sub => "SUB",
        .div => "DIV",
        .sdiv => "SDIV",
        .mod => "MOD",
        .smod => "SMOD",
        .addmod => "ADDMOD",
        .mulmod => "MULMOD",
        .exp => "EXP",
        .signextend => "SIGNEXTEND",
        .lt => "LT",
        .gt => "GT",
        .slt => "SLT",
        .sgt => "SGT",
        .eq => "EQ",
        .iszero => "ISZERO",
        .bitand => "AND",
        .bitor => "OR",
        .xor => "XOR",
        .not => "NOT",
        .byte => "BYTE",
        .shl => "SHL",
        .shr => "SHR",
        .sar => "SAR",
        .keccak256 => "KECCAK256",
        .address => "ADDRESS",
        .balance => "BALANCE",
        .origin => "ORIGIN",
        .caller => "CALLER",
        .callvalue => "CALLVALUE",
        .calldataload => "CALLDATALOAD",
        .calldatasize => "CALLDATASIZE",
        .calldatacopy => "CALLDATACOPY",
        .codesize => "CODESIZE",
        .codecopy => "CODECOPY",
        .gasprice => "GASPRICE",
        .extcodesize => "EXTCODESIZE",
        .extcodecopy => "EXTCODECOPY",
        .returndatasize => "RETURNDATASIZE",
        .returndatacopy => "RETURNDATACOPY",
        .extcodehash => "EXTCODEHASH",
        .blockhash => "BLOCKHASH",
        .coinbase => "COINBASE",
        .timestamp => "TIMESTAMP",
        .number => "NUMBER",
        .difficulty => "DIFFICULTY",
        .gaslimit => "GASLIMIT",
        .chainid => "CHAINID",
        .selfbalance => "SELFBALANCE",
        .basefee => "BASEFEE",
        .blobhash => "BLOBHASH",
        .blobbasefee => "BLOBBASEFEE",
        .pop => "POP",
        .mload => "MLOAD",
        .mstore => "MSTORE",
        .mstore8 => "MSTORE8",
        .sload => "SLOAD",
        .sstore => "SSTORE",
        .jump => "JUMP",
        .jumpi => "JUMPI",
        .pc => "PC",
        .msize => "MSIZE",
        .gas => "GAS",
        .jumpdest => "JUMPDEST",
        .push1 => "PUSH1",
        .push2 => "PUSH2",
        .push3 => "PUSH3",
        .push4 => "PUSH4",
        .push5 => "PUSH5",
        .push6 => "PUSH6",
        .push7 => "PUSH7",
        .push8 => "PUSH8",
        .push9 => "PUSH9",
        .push10 => "PUSH10",
        .push11 => "PUSH11",
        .push12 => "PUSH12",
        .push13 => "PUSH13",
        .push14 => "PUSH14",
        .push15 => "PUSH15",
        .push16 => "PUSH16",
        .push17 => "PUSH17",
        .push18 => "PUSH18",
        .push19 => "PUSH19",
        .push20 => "PUSH20",
        .push21 => "PUSH21",
        .push22 => "PUSH22",
        .push23 => "PUSH23",
        .push24 => "PUSH24",
        .push25 => "PUSH25",
        .push26 => "PUSH26",
        .push27 => "PUSH27",
        .push28 => "PUSH28",
        .push29 => "PUSH29",
        .push30 => "PUSH30",
        .push31 => "PUSH31",
        .push32 => "PUSH32",
        .dup1 => "DUP1",
        .dup2 => "DUP2",
        .dup3 => "DUP3",
        .dup4 => "DUP4",
        .dup5 => "DUP5",
        .dup6 => "DUP6",
        .dup7 => "DUP7",
        .dup8 => "DUP8",
        .dup9 => "DUP9",
        .dup10 => "DUP10",
        .dup11 => "DUP11",
        .dup12 => "DUP12",
        .dup13 => "DUP13",
        .dup14 => "DUP14",
        .dup15 => "DUP15",
        .dup16 => "DUP16",
        .swap1 => "SWAP1",
        .swap2 => "SWAP2",
        .swap3 => "SWAP3",
        .swap4 => "SWAP4",
        .swap5 => "SWAP5",
        .swap6 => "SWAP6",
        .swap7 => "SWAP7",
        .swap8 => "SWAP8",
        .swap9 => "SWAP9",
        .swap10 => "SWAP10",
        .swap11 => "SWAP11",
        .swap12 => "SWAP12",
        .swap13 => "SWAP13",
        .swap14 => "SWAP14",
        .swap15 => "SWAP15",
        .swap16 => "SWAP16",
        .log0 => "LOG0",
        .log1 => "LOG1",
        .log2 => "LOG2",
        .log3 => "LOG3",
        .log4 => "LOG4",
        .create => "CREATE",
        .call_op => "CALL",
        .callcode => "CALLCODE",
        .return_op => "RETURN",
        .delegatecall => "DELEGATECALL",
        .create2 => "CREATE2",
        .staticcall => "STATICCALL",
        .revert => "REVERT",
        .invalid_op => "INVALID",
        .selfdestruct => "SELFDESTRUCT",
    };
}

/// Check if opcode is a push operation
pub fn isPush(opcode: Opcode) bool {
    return @intFromEnum(opcode) >= 0x60 and @intFromEnum(opcode) <= 0x7f;
}

/// Check if opcode is a dup operation
pub fn isDup(opcode: Opcode) bool {
    return @intFromEnum(opcode) >= 0x80 and @intFromEnum(opcode) <= 0x8f;
}

/// Check if opcode is a swap operation
pub fn isSwap(opcode: Opcode) bool {
    return @intFromEnum(opcode) >= 0x90 and @intFromEnum(opcode) <= 0x9f;
}

/// Check if opcode is a log operation
pub fn isLog(opcode: Opcode) bool {
    return @intFromEnum(opcode) >= 0xa0 and @intFromEnum(opcode) <= 0xa4;
}

/// Get the number of bytes for a push operation
pub fn getPushSize(opcode: Opcode) u8 {
    if (!isPush(opcode)) return 0;
    return @intFromEnum(opcode) - 0x60 + 1;
}

/// Get the stack height change for an opcode
/// Positive = pushes to stack, Negative = pops from stack
pub fn getStackDelta(opcode: Opcode) i8 {
    return switch (opcode) {
        .stop => 0,
        .add, .mul, .sub, .div, .sdiv, .mod, .smod, .bitand, .bitor, .xor, .lt, .gt, .slt, .sgt, .eq => -1,
        .addmod, .mulmod => -2,
        .exp => -1,
        .signextend => -1,
        .iszero, .not, .byte, .shl, .shr, .sar => 0,
        .keccak256 => -1,
        .address, .origin, .caller, .callvalue, .calldatasize, .codesize, .gasprice => 1,
        .balance, .gasprice, .extcodesize, .returndatasize, .selfbalance, .chainid, .basefee => 1,
        .calldataload => 0,
        .calldatacopy, .codecopy, .extcodecopy => -3,
        .blockhash, .coinbase, .timestamp, .number, .difficulty, .gaslimit, .blobhash, .blobbasefee => 1,
        .extcodehash => 1,
        .pop => -1,
        .mload, .sload => 0,
        .mstore, .sstore => -2,
        .mstore8 => -2,
        .jump => 0,
        .jumpi => -2,
        .pc, .msize, .gas => 1,
        .jumpdest => 0,
        .push1, .push2, .push3, .push4, .push5, .push6, .push7, .push8,
        .push9, .push10, .push11, .push12, .push13, .push14, .push15, .push16,
        .push17, .push18, .push19, .push20, .push21, .push22, .push23, .push24,
        .push25, .push26, .push27, .push28, .push29, .push30, .push31, .push32 => 1,
        .dup1, .dup2, .dup3, .dup4, .dup5, .dup6, .dup7, .dup8,
        .dup9, .dup10, .dup11, .dup12, .dup13, .dup14, .dup15, .dup16 => 1,
        .swap1, .swap2, .swap3, .swap4, .swap5, .swap6, .swap7, .swap8,
        .swap9, .swap10, .swap11, .swap12, .swap13, .swap14, .swap15, .swap16 => 0,
        .log0 => -2,
        .log1, .log2, .log3, .log4 => -2 - @as(i8, @intCast(@intFromEnum(opcode) - 0xa0)),
        .create, .call_op, .callcode, .delegatecall, .create2, .staticcall => -2,
        .return_op, .revert => -2,
        .invalid_op => 0,
        .selfdestruct => -1,
    };
}

/// Gas costs for each opcode (approximate)
pub fn getGasCost(opcode: Opcode) u64 {
    return switch (opcode) {
        .stop => 0,
        .add, .mul, .sub, .div, .sdiv, .mod, .smod, .addmod, .mulmod => 5,
        .exp => 10,
        .signextend => 5,
        .lt, .gt, .slt, .sgt, .eq, .iszero, .bitand, .bitor, .xor, .not, .byte => 3,
        .shl, .shr, .sar => 3,
        .keccak256 => 30,
        .address, .origin, .caller, .callvalue, .calldataload, .calldatasize, .calldatacopy => 2,
        .codesize, .codecopy, .gasprice => 2,
        .extcodesize => 20,
        .extcodecopy => 20,
        .extcodehash => 20,
        .returndatasize, .returndatacopy => 2,
        .balance => 20,
        .blockhash => 20,
        .coinbase, .timestamp, .number, .difficulty, .gaslimit => 2,
        .chainid, .selfbalance, .basefee => 2,
        .blobhash, .blobbasefee => 2,
        .pop => 2,
        .mload => 3,
        .mstore => 3,
        .mstore8 => 3,
        .sload => 20,
        .sstore => 20,
        .jump, .jumpi => 8,
        .pc, .msize, .gas => 2,
        .jumpdest => 1,
        .push1, .push2, .push3, .push4, .push5, .push6, .push7, .push8,
        .push9, .push10, .push11, .push12, .push13, .push14, .push15, .push16,
        .push17, .push18, .push19, .push20, .push21, .push22, .push23, .push24,
        .push25, .push26, .push27, .push28, .push29, .push30, .push31, .push32 => 3,
        .dup1, .dup2, .dup3, .dup4, .dup5, .dup6, .dup7, .dup8,
        .dup9, .dup10, .dup11, .dup12, .dup13, .dup14, .dup15, .dup16 => 3,
        .swap1, .swap2, .swap3, .swap4, .swap5, .swap6, .swap7, .swap8,
        .swap9, .swap10, .swap11, .swap12, .swap13, .swap14, .swap15, .swap16 => 3,
        .log0 => 375,
        .log1 => 750,
        .log2 => 1125,
        .log3 => 1500,
        .log4 => 1875,
        .create => 32000,
        .call_op => 25000,
        .callcode => 25000,
        .delegatecall => 25000,
        .create2 => 32000,
        .staticcall => 25000,
        .return_op => 0,
        .revert => 0,
        .invalid_op => 0,
        .selfdestruct => 0,
    };
}

/// Instruction representation
pub const Instruction = struct {
    opcode: Opcode,
    pc: usize,
    push_data: ?[]const u8 = null,
};

/// Parse bytecode into instructions
pub fn parseInstructions(allocator: std.mem.Allocator, bytecode: []const u8) ![]Instruction {
    var instructions: std.ArrayListUnmanaged(Instruction) = .{};
    errdefer instructions.deinit(allocator);

    var pc: usize = 0;
    while (pc < bytecode.len) {
        const opcode_byte = bytecode[pc];
        
        // Handle invalid opcodes by treating as data/INVALID
        const opcode = std.meta.intToEnum(Opcode, opcode_byte) catch {
            // Unknown opcode - treat as INVALID and skip
            try instructions.append(allocator, .{
                .opcode = .invalid_op,
                .pc = pc,
                .push_data = null,
            });
            pc += 1;
            continue;
        };

        if (isPush(opcode)) {
            const push_size = getPushSize(opcode);
            var push_data: ?[]const u8 = null;

            if (pc + 1 + push_size <= bytecode.len) {
                push_data = bytecode[pc + 1 .. pc + 1 + push_size];
            }

            try instructions.append(allocator, .{
                .opcode = opcode,
                .pc = pc,
                .push_data = push_data,
            });
            pc += 1 + push_size;
        } else {
            try instructions.append(allocator, .{
                .opcode = opcode,
                .pc = pc,
            });
            pc += 1;
        }
    }

    return instructions.toOwnedSlice(allocator);
}

/// Read push data as a u64 value
pub fn readPushDataAsU64(data: []const u8) u64 {
    var result: u64 = 0;
    for (data) |byte| {
        result = (result << 8) | byte;
    }
    return result;
}

test "opcode parsing" {
    const bytecode = [_]u8{ 0x60, 0x05, 0x01 }; // PUSH1 5, ADD
    const instructions = try parseInstructions(std.testing.allocator, &bytecode);

    try std.testing.expectEqual(@as(usize, 2), instructions.len);
    try std.testing.expectEqual(Opcode.push1, instructions[0].opcode);
    try std.testing.expectEqual(Opcode.add, instructions[1].opcode);
}
