/// Main decompiler module - orchestrates disassembly and analysis

const std = @import("std");
const opcodes = @import("../evm/opcodes.zig");
const disassembler = @import("../evm/disassembler.zig");
const symbolic = @import("../symbolic/executor.zig");

pub const Decompiler = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Decompiler {
        return .{ .allocator = allocator };
    }

    /// Decompile bytecode and return analysis result
    pub fn decompile(self: *Decompiler, bytecode: []const u8) !DecompileResult {
        // Separate initcode from runtime bytecode
        const separated = try self.separateBytecode(bytecode);
        const initcode = separated[0];
        const runtime = separated[1];

        var result = DecompileResult{
            .initcode = try self.allocator.dupe(u8, initcode),
            .runtime = try self.allocator.dupe(u8, runtime),
            .disassembly = undefined,
            .functions = &.{},
            .constructor_args = null,
        };

        // Disassemble runtime bytecode
        const dis = disassembler.Disassembler.init(self.allocator);
        result.disassembly = try dis.disassemble(runtime);

        // Run symbolic execution to find functions
        const config = symbolic.SymbolicConfig{};
        var executor = try symbolic.Executor.init(runtime, self.allocator, config);
        defer executor.deinit();

        // Find function entry points
        const entry_points = try self.findFunctionSelectors(runtime);
        for (entry_points) |pc| {
            executor.executeEntryPoint(pc) catch {};
        }

        return result;
    }

    /// Separate initcode from runtime bytecode
    /// Initcode is the creation bytecode, runtime is what's deployed
    fn separateBytecode(_: *Decompiler, bytecode: []const u8) !struct { []const u8, []const u8 } {
        // Simple heuristic: find the deploy code pattern
        // In Solidity: PUSHn <runtime> PUSH0 MSTORE ... RETURN
        // This is a simplification - more sophisticated detection would use contract metadata

        if (bytecode.len < 32) {
            return .{ bytecode, bytecode };
        }

        // Try to find the runtime code boundary
        // Common pattern: deploy code ends with RETURN
        var i: usize = 0;
        while (i < bytecode.len - 1) {
            if (bytecode[i] == 0xf3) { // RETURN
                // Found potential boundary
                if (i + 1 < bytecode.len) {
                    const offset = bytecode[i];
                    const length = bytecode[i + 1];
                    if (offset + length <= bytecode.len) {
                        const runtime = bytecode[i + 2 ..];
                        if (runtime.len > 10) { // Minimum reasonable runtime
                            return .{ bytecode[0..i + 2], runtime };
                        }
                    }
                }
            }
            i += 1;
        }

        // Fallback: assume entire bytecode is runtime (library or old EVM)
        return .{ bytecode, bytecode };
    }

    /// Find potential function entry points by analyzing JUMPDEST instructions
    fn findFunctionSelectors(self: *Decompiler, bytecode: []const u8) ![]usize {
        var entry_points: std.ArrayListUnmanaged(usize) = .{};
        errdefer entry_points.deinit(self.allocator);

        const instructions = try opcodes.parseInstructions(self.allocator, bytecode);
        defer self.allocator.free(instructions);

        // First few JUMPDESTs after PUSH operations are likely function entry points
        var found_push = false;
        for (instructions) |instr| {
            if (opcodes.isPush(instr.opcode)) {
                found_push = true;
            } else if (instr.opcode == .jumpdest and found_push) {
                try entry_points.append(self.allocator, instr.pc);
                found_push = false;
            }
        }

        return entry_points.toOwnedSlice(self.allocator);
    }

    /// Decode constructor arguments from initcode
    /// Constructor arguments are passed during contract creation and are appended to the initcode
    pub fn decodeConstructorArgs(self: *Decompiler, initcode: []const u8, abi_json: ?[]const u8) !?[]const u8 {
        _ = self; // Reserved for future use (e.g., parsing ABI)
        // Find where initcode ends (look for RETURN opcode)
        // Constructor args start after RETURN
        var return_idx: ?usize = null;
        
        for (initcode, 0..) |byte, i| {
            if (byte == 0xf3) { // RETURN opcode
                return_idx = i;
                break;
            }
        }
        
        if (return_idx == null) {
            return null;
        }
        
        const args_start = return_idx.? + 1;
        if (args_start >= initcode.len) {
            return null;
        }
        
        const constructor_args = initcode[args_start..];
        
        if (constructor_args.len < 4) {
            // No meaningful constructor args (need at least a function selector)
            return null;
        }
        
        // If we have ABI, we can try to decode the arguments
        if (abi_json) |_| {
            // For now, just return the raw args as hex
            // Full ABI decoding would require parsing the ABI JSON
            return constructor_args;
        }
        
        return constructor_args;
    }
    
    /// Analyze constructor to extract deployed bytecode
    /// In Solidity, the runtime bytecode is returned by the constructor
    pub fn extractRuntimeBytecode(self: *Decompiler, initcode: []const u8) ![]const u8 {
        _ = self; // Reserved for future use
        var return_idx: ?usize = null;
        
        // Find RETURN or REVERT in initcode
        for (initcode, 0..) |byte, i| {
            if (byte == 0xf3 or byte == 0xfd) { // RETURN or REVERT
                return_idx = i;
                break;
            }
        }
        
        if (return_idx == null) {
            // No explicit return, assume entire initcode is just runtime
            return initcode;
        }
        
        // Stack should have: [size, offset]
        // We need to look at stack before RETURN to find what memory region is returned
        // For simplicity, assume standard pattern: INITCODE + CREATION_CODE = full bytecode
        
        // In standard creation: the deployed bytecode is in memory at some location
        // This is complex to analyze without symbolic execution
        
        return initcode; // Placeholder - return initcode as runtime for now
    }
};

pub const DecompileResult = struct {
    initcode: []const u8,
    runtime: []const u8,
    disassembly: []const u8,
    functions: []const symbolic.DiscoveredFunction,
    constructor_args: ?[]const u8,

    pub fn deinit(self: *DecompileResult, allocator: std.mem.Allocator) void {
        allocator.free(self.initcode);
        allocator.free(self.runtime);
        allocator.free(self.disassembly);
    }
};

/// Command line options
pub const Options = struct {
    bytecode: ?[]const u8 = null,
    address: ?[]const u8 = null,
    output_format: OutputFormat = .text,
    verbose: bool = false,

    pub const OutputFormat = enum {
        text,
        json,
        solidity,
    };
};
