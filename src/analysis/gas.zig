// Gas Analysis Module
// Estimates gas consumption for EVM bytecode

const std = @import("std");
const parser = @import("../evm/parser.zig");
const opcodes = @import("../evm/opcodes.zig");

/// Gas costs for EVM opcodes (EIP-2565)
pub const GasCosts = struct {
    // Base costs
    base: u64 = 2,
    jumpdest: u64 = 1,
    
    // Stack operations
    push: u64 = 3,
    pop: u64 = 2,
    
    // Memory operations
    mload: u64 = 3,
    mstore: u64 = 3,
    mstore8: u64 = 3,
    
    // Storage operations
    sload: u64 = 2100,
    sstore: u64 = 20000, // Cold storage
    
    // Arithmetic
    add: u64 = 5,
    mul: u64 = 8,
    sub: u64 = 5,
    div: u64 = 5,
    mod: u64 = 5,
    addmod: u64 = 8,
    mulmod: u64 = 8,
    exp: u64 = 10, // Base only
    
    // Comparison
    lt: u64 = 5,
    gt: u64 = 5,
    eq: u64 = 3,
    iszero: u64 = 3,
    
    // Bitwise
    and_op: u64 = 5,
    or_op: u64 = 5,
    xor: u64 = 5,
    not: u64 = 5,
    shl: u64 = 5,
    shr: u64 = 5,
    
    // Hashing
    keccak256: u64 = 30, // Base
    
    // Control flow
    jump: u64 = 8,
    jumpi: u64 = 10,
    jumpdest_op: u64 = 1,
    
    // Calls
    call: u64 = 100, // Plus gas forwarded
    delegatecall: u64 = 100,
    staticcall: u64 = 100,
    create: u64 = 32000,
    create2: u64 = 32000,
    
    // Terminating
    stop: u64 = 0,
    ret: u64 = 0,
    revert: u64 = 0,
    invalid: u64 = 0,
    selfdestruct: u64 = 5000, // New
    
    // Logging
    log0: u64 = 375,
    log1: u64 = 750,
    log2: u64 = 1125,
    log3: u64 = 1500,
    log4: u64 = 1875,
    
    // Environmental
    address: u64 = 2,
    balance: u64 = 400, // Cold
    origin: u64 = 2,
    caller: u64 = 2,
    callvalue: u64 = 2,
    calldataload: u64 = 3,
    calldatasize: u64 = 2,
    calldatacopy: u64 = 3,
    codesize: u64 = 2,
    codecopy: u64 = 3,
    gasprice: u64 = 2,
    extcodesize: u64 = 700, // Cold
    extcodecopy: u64 = 700, // Cold
    blockhash: u64 = 20,
    coinbase: u64 = 2,
    timestamp: u64 = 2,
    number: u64 = 2,
    difficulty: u64 = 2,
    gaslimit: u64 = 2,
    chainid: u64 = 2,
    selfbalance: u64 = 5,
    basefee: u64 = 2,
};

/// Gas analysis result
pub const GasAnalysis = struct {
    total_gas: u64,
    breakdown: []GasItem,
    memory_expansion: u64,
    storage_ops: usize,
};

/// Individual gas consumption item
pub const GasItem = struct {
    opcode: []const u8,
    count: usize,
    gas: u64,
};

/// Analyze gas consumption of bytecode
pub fn analyze(allocator: std.mem.Allocator, bytecode: []const u8) !GasAnalysis {
    var parsed = try parser.parse(allocator, bytecode);
    defer parser.deinit(&parsed);
    
    const costs = GasCosts{};
    
    var breakdown_map = std.StringHashMap(GasItem).init(allocator);
    defer breakdown_map.deinit();
    
    var total_gas: u64 = 0;
    var storage_ops: usize = 0;
    var memory_expansion: u64 = 0;
    var current_memory: usize = 0;
    
    for (parsed.instructions) |instr| {
        const gas = getGasCost(&costs, instr.opcode);
        total_gas += gas;
        
        // Track memory expansion
        if (instr.opcode == .mstore or instr.opcode == .mstore8) {
            if (instr.push_data) |data| {
                const offset = readU256(data);
                const size: usize = if (instr.opcode == .mstore8) 1 else 32;
                const new_size = offset + size;
                if (new_size > current_memory) {
                    memory_expansion += calculateMemoryExpansion(current_memory, new_size);
                    current_memory = new_size;
                }
            }
        }
        
        // Track storage operations
        if (instr.opcode == .sstore) {
            storage_ops += 1;
        }
        
        // Add to breakdown
        const name = opcodes.getName(instr.opcode);
        if (breakdown_map.get(name)) |*item| {
            item.count += 1;
            item.gas += gas;
        } else {
            try breakdown_map.put(name, .{ .opcode = name, .count = 1, .gas = gas });
        }
    }
    
    // Convert map to slice
    var breakdown = std.ArrayList(GasItem).init(allocator);
    defer breakdown.deinit();
    
    var iter = breakdown_map.iterator();
    while (iter.next()) |entry| {
        try breakdown.append(entry.value_ptr.*);
    }
    
    // Sort by gas consumption
    std.sort.sort(GasItem, breakdown.items, {}, gasDesc);
    
    return .{
        .total_gas = total_gas,
        .breakdown = try breakdown.toOwnedSlice(),
        .memory_expansion = memory_expansion,
        .storage_ops = storage_ops,
    };
}

fn gasDesc(context: void, a: GasItem, b: GasItem) bool {
    _ = context;
    return a.gas > b.gas;
}

fn getGasCost(costs: *const GasCosts, opcode: opcodes.OpCode) u64 {
    return switch (opcode) {
        .stop => costs.stop,
        .add => costs.add,
        .mul => costs.mul,
        .sub => costs.sub,
        .div => costs.div,
        .sdiv => costs.div,
        .mod => costs.mod,
        .smod => costs.mod,
        .addmod => costs.addmod,
        .mulmod => costs.mulmod,
        .exp => costs.exp,
        .lt => costs.lt,
        .gt => costs.gt,
        .eq => costs.eq,
        .iszero => costs.iszero,
        .and_op => costs.and_op,
        .or_op => costs.or_op,
        .xor => costs.xor,
        .not => costs.not,
        .shl => costs.shl,
        .shr => costs.shr,
        .sar => costs.shr,
        .keccak256 => costs.keccak256,
        .address => costs.address,
        .balance => costs.balance,
        .origin => costs.origin,
        .caller => costs.caller,
        .callvalue => costs.callvalue,
        .calldataload => costs.calldataload,
        .calldatasize => costs.calldatasize,
        .calldatacopy => costs.calldatacopy,
        .codesize => costs.codesize,
        .codecopy => costs.codecopy,
        .gasprice => costs.gasprice,
        .extcodesize => costs.extcodesize,
        .extcodecopy => costs.extcodecopy,
        .blockhash => costs.blockhash,
        .coinbase => costs.coinbase,
        .timestamp => costs.timestamp,
        .number => costs.number,
        .difficulty => costs.difficulty,
        .gaslimit => costs.gaslimit,
        .chainid => costs.chainid,
        .selfbalance => costs.selfbalance,
        .basefee => costs.basefee,
        .pop => costs.pop,
        .mload => costs.mload,
        .mstore => costs.mstore,
        .mstore8 => costs.mstore8,
        .sload => costs.sload,
        .sstore => costs.sstore,
        .jump => costs.jump,
        .jumpi => costs.jumpi,
        .jumpdest => costs.jumpdest_op,
        .push1, .push2, .push3, .push4, .push5, .push6, .push7, .push8,
        .push9, .push10, .push11, .push12, .push13, .push14, .push15, .push16,
        .push17, .push18, .push19, .push20, .push21, .push22, .push23, .push24,
        .push25, .push26, .push27, .push28, .push29, .push30, .push31, .push32, .push0 => costs.push,
        .dup1, .dup2, .dup3, .dup4, .dup5, .dup6, .dup7, .dup8,
        .dup9, .dup10, .dup11, .dup12, .dup13, .dup14, .dup15, .dup16 => costs.push,
        .swap1, .swap2, .swap3, .swap4, .swap5, .swap6, .swap7, .swap8,
        .swap9, .swap10, .swap11, .swap12, .swap13, .swap14, .swap15, .swap16 => costs.push,
        .log0 => costs.log0,
        .log1 => costs.log1,
        .log2 => costs.log2,
        .log3 => costs.log3,
        .log4 => costs.log4,
        .create => costs.create,
        .call => costs.call,
        .callcode => costs.delegatecall,
        .ret => costs.ret,
        .delegatecall => costs.delegatecall,
        .create2 => costs.create2,
        .staticcall => costs.staticcall,
        .revert => costs.revert,
        .invalid => costs.invalid,
        .selfdestruct => costs.selfdestruct,
        else => costs.base,
    };
}

fn calculateMemoryExpansion(old_size: usize, new_size: usize) u64 {
    // Memory cost formula: new_size * (new_size / 512 + 1) - old_size * (old_size / 512 + 1)
    const old_cost = (old_size / 512 + 1) * old_size;
    const new_cost = (new_size / 512 + 1) * new_size;
    return new_cost - old_cost;
}

fn readU256(data: []const u8) usize {
    var result: usize = 0;
    for (data) |b| {
        result = (result << 8) | b;
    }
    return result;
}
