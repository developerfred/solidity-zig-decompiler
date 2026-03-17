// EVM Opcodes definitions for Zig
// Based on EIP-3675 and Ethereum Yellow Paper

pub const OpCode = enum(u8) {
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
    and_op = 0x16,
    or_op = 0x17,
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
    txgasprice = 0x4a, // alias for gasprice

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
    push0 = 0x5f,
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

    // Logging Operations
    log0 = 0xa0,
    log1 = 0xa1,
    log2 = 0xa2,
    log3 = 0xa3,
    log4 = 0xa4,

    // System Operations
    create = 0xf0,
    call = 0xf1,
    callcode = 0xf2,
    ret = 0xf3,
    delegatecall = 0xf4,
    create2 = 0xf5,
    staticcall = 0xfa,
    revert = 0xfd,
    invalid = 0xfe,
    selfdestruct = 0xff,

    // EVM Object Format (EOF) - EIP-3540
    eof1 = 0xef,

    // Unknown/Reserved
    reserved_0c = 0x0c,
    reserved_0d = 0x0d,
    reserved_0e = 0x0e,
    reserved_0f = 0x0f,
    reserved_1e = 0x1e,
    reserved_1f = 0x1f,
};

/// Returns the name of an opcode
pub fn getName(op: OpCode) []const u8 {
    return switch (op) {
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
        .and_op => "AND",
        .or_op => "OR",
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
        .txgasprice => "TXGASPRICE",
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
        .push0 => "PUSH0",
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
        .call => "CALL",
        .callcode => "CALLCODE",
        .ret => "RETURN",
        .delegatecall => "DELEGATECALL",
        .create2 => "CREATE2",
        .staticcall => "STATICCALL",
        .revert => "REVERT",
        .invalid => "INVALID",
        .selfdestruct => "SELFDESTRUCT",
        .eof1 => "EOF1",
        .reserved_0c, .reserved_0d, .reserved_0e, .reserved_0f,
        .reserved_1e, .reserved_1f => "RESERVED",
    };
}

/// Returns the number of stack inputs for an opcode
pub fn getStackInputs(op: OpCode) u8 {
    return switch (op) {
        .stop, .ret, .revert, .selfdestruct, .invalid, .log0, .log1, .log2, .log3, .log4 => 0,
        .pop, .jumpdest, .pc, .msize, .gas, .address, .origin, .caller, .callvalue, .calldatasize, .codesize, .gasprice, .timestamp, .number, .difficulty, .gaslimit, .coinbase, .chainid, .selfbalance, .basefee, .blobhash, .returndatasize => 0,
        .push0 => 0,
        .push1, .push2, .push3, .push4, .push5, .push6, .push7, .push8, .push9, .push10, .push11, .push12, .push13, .push14, .push15, .push16, .push17, .push18, .push19, .push20, .push21, .push22, .push23, .push24, .push25, .push26, .push27, .push28, .push29, .push30, .push31, .push32 => 0,
        .dup1, .dup2, .dup3, .dup4, .dup5, .dup6, .dup7, .dup8, .dup9, .dup10, .dup11, .dup12, .dup13, .dup14, .dup15, .dup16 => 1,
        .swap1, .swap2, .swap3, .swap4, .swap5, .swap6, .swap7, .swap8, .swap9, .swap10, .swap11, .swap12, .swap13, .swap14, .swap15, .swap16 => 2,
        .add, .mul, .sub, .div, .sdiv, .mod, .smod, .and_op, .or_op, .xor, .shl, .shr, .sar, .lt, .gt, .slt, .sgt, .eq => 2,
        .addmod, .mulmod, .exp => 3,
        .signextend, .byte => 2,
        .iszero,         .not, .extcodesize, .extcodehash, .balance => 1,
        .calldataload, .mload, .sload => 1,
        .mstore, .mstore8, .sstore => 2,
        .keccak256 => 2,
        .codecopy, .calldatacopy, .extcodecopy, .returndatacopy => 3,
        .blockhash => 1,
        .jump => 1,
        .jumpi => 2,
        .create, .call, .callcode, .delegatecall, .create2, .staticcall => 7,
    };
}

/// Returns the number of stack outputs for an opcode
pub fn getStackOutputs(op: OpCode) u8 {
    return switch (op) {
        .stop, .ret, .revert, .selfdestruct, .invalid, .pop, .mstore, .mstore8, .sstore, .log0, .log1, .log2, .log3, .log4, .jump, .jumpi => 0,
        .push0, .push1, .push2, .push3, .push4, .push5, .push6, .push7, .push8, .push9, .push10, .push11, .push12, .push13, .push14, .push15, .push16, .push17, .push18, .push19, .push20, .push21, .push22, .push23, .push24, .push25, .push26, .push27, .push28, .push29, .push30, .push31, .push32 => 1,
        .dup1, .dup2, .dup3, .dup4, .dup5, .dup6, .dup7, .dup8, .dup9, .dup10, .dup11, .dup12, .dup13, .dup14, .dup15, .dup16 => 2,
        .swap1, .swap2, .swap3, .swap4, .swap5, .swap6, .swap7, .swap8, .swap9, .swap10, .swap11, .swap12, .swap13, .swap14, .swap15, .swap16 => 2,
        .add, .mul, .sub, .div, .sdiv, .mod, .smod, .addmod, .mulmod, .exp, .signextend, .and_op, .or_op, .xor, .not, .shl, .shr, .sar => 1,
        .iszero, .lt, .gt, .slt, .sgt, .eq, .byte, .not => 1,
        .address, .origin, .caller, .callvalue, .calldataload, .calldatasize, .codesize, .gasprice, .timestamp, .number, .difficulty, .gaslimit, .coinbase, .chainid, .selfbalance, .basefee, .blobhash, .pc, .msize, .gas, .returndatasize, .extcodesize, .extcodehash, .balance => 1,
        .calldatacopy, .codecopy, .extcodecopy, .returndatacopy, .keccak256, .mload, .sload => 1,
        .blockhash => 1,
        .create, .call, .callcode, .delegatecall, .create2, .staticcall => 1,
    };
}

/// Check if opcode is a push operation
pub fn isPush(op: OpCode) bool {
    return @intFromEnum(op) >= 0x60 and @intFromEnum(op) <= 0x7f;
}

/// Check if opcode is a dup operation
pub fn isDup(op: OpCode) bool {
    return @intFromEnum(op) >= 0x80 and @intFromEnum(op) <= 0x8f;
}

/// Check if opcode is a swap operation
pub fn isSwap(op: OpCode) bool {
    return @intFromEnum(op) >= 0x90 and @intFromEnum(op) <= 0x9f;
}

/// Check if opcode is a jump operation
pub fn isJump(op: OpCode) bool {
    return switch (op) {
        .jump, .jumpi => true,
        else => false,
    };
}

/// Check if opcode terminates execution
pub fn isTerminating(op: OpCode) bool {
    return switch (op) {
        .stop, .ret, .revert, .invalid, .selfdestruct => true,
        else => false,
    };
}

/// Get push data size for push opcodes
pub fn getPushSize(op: OpCode) u8 {
    const opcode_val = @intFromEnum(op);
    if (opcode_val >= 0x60 and opcode_val <= 0x7f) {
        return opcode_val - 0x60 + 1;
    }
    if (opcode_val == 0x5f) return 1; // PUSH0
    return 0;
}
