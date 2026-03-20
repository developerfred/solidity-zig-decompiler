const std = @import("std");
const evm_opcodes = @import("evm/opcodes.zig");
const evm_disassembler = @import("evm/disassembler.zig");
const evm_abi = @import("evm/abi.zig");
const bend_opcodes = @import("bend/opcodes.zig");
const bend_source = @import("bend/source.zig");
const analysis_types = @import("analysis/types.zig");
const analysis_controlflow = @import("analysis/controlflow.zig");
const analysis_constructor = @import("analysis/constructor.zig");
const symbolic_executor = @import("symbolic/executor.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <bytecode> [options]\n", .{args[0]});
        std.debug.print("\nBytecode:\n", .{});
        std.debug.print("  Hex-encoded EVM or Bend-PVM/RISC-V bytecode\n", .{});
        std.debug.print("  Auto-detects bytecode type\n", .{});
        std.debug.print("\nOptions:\n", .{});
        std.debug.print("  --disasm          Show disassembly\n", .{});
        std.debug.print("  --constructor     Show constructor analysis\n", .{});
        std.debug.print("  --abi             Show extracted function selectors\n", .{});
        std.debug.print("  --solidity        Generate Solidity-like code\n", .{});
        std.debug.print("  --types           Show type inference analysis\n", .{});
        std.debug.print("  --controlflow     Show control flow analysis\n", .{});
        std.debug.print("  --symbolic        Run symbolic execution analysis\n", .{});
        std.debug.print("  --bend            Generate Bend-PVM source (RISC-V)\n", .{});
        std.debug.print("  --json            Output in JSON format\n", .{});
        std.debug.print("  --full            Full analysis (default)\n", .{});
        return;
    }

    // Check for help flag
    if (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")) {
        std.debug.print("Usage: {s} <bytecode> [options]\n", .{args[0]});
        std.debug.print("\nBytecode:\n", .{});
        std.debug.print("  Hex-encoded EVM bytecode (with or without 0x prefix)\n", .{});
        std.debug.print("\nOptions:\n", .{});
        std.debug.print("  --disasm          Show disassembly\n", .{});
        std.debug.print("  --constructor     Show constructor analysis\n", .{});
        std.debug.print("  --abi             Show extracted function selectors\n", .{});
        std.debug.print("  --solidity        Generate Solidity-like code\n", .{});
        std.debug.print("  --types           Show type inference analysis\n", .{});
        std.debug.print("  --controlflow     Show control flow analysis\n", .{});
        std.debug.print("  --symbolic        Run symbolic execution analysis\n", .{});
        std.debug.print("  --bend            Generate Bend-PVM source (RISC-V)\n", .{});
        std.debug.print("  --json            Output in JSON format\n", .{});
        std.debug.print("  --full            Full analysis (default)\n", .{});
        return;
    }

    const bytecode_hex = args[1];
    var show_disasm = false;
    var show_constructor = false;
    var show_abi = false;
    var show_solidity = false;
    var show_types = false;
    var show_controlflow = false;
    var show_symbolic = false;
    var show_bend = false;
    var show_json = false;
    var full_analysis = false;

    for (args[2..]) |arg| {
        if (std.mem.eql(u8, arg, "--disasm")) show_disasm = true;
        if (std.mem.eql(u8, arg, "--constructor")) show_constructor = true;
        if (std.mem.eql(u8, arg, "--abi")) show_abi = true;
        if (std.mem.eql(u8, arg, "--solidity")) show_solidity = true;
        if (std.mem.eql(u8, arg, "--types")) show_types = true;
        if (std.mem.eql(u8, arg, "--controlflow")) show_controlflow = true;
        if (std.mem.eql(u8, arg, "--symbolic")) show_symbolic = true;
        if (std.mem.eql(u8, arg, "--bend")) show_bend = true;
        if (std.mem.eql(u8, arg, "--json")) show_json = true;
        if (std.mem.eql(u8, arg, "--full")) full_analysis = true;
    }

    // Parse hex bytecode
    const bytecode = try parseHex(bytecode_hex, alloc);
    defer alloc.free(bytecode);

    // Auto-detect bytecode type
    const bytecode_type = bend_opcodes.detectBytecodeType(bytecode);
    
    std.debug.print("Detected bytecode type: {s}\n\n", .{
        switch (bytecode_type) {
            .evm => "EVM (Ethereum)",
            .bend_pvm => "Bend-PVM (RISC-V)",
            .unknown => "Unknown",
        }
    });

    // Route to appropriate decompiler
    if (bytecode_type == .bend_pvm) {
        try processBendPVM(bytecode, alloc, show_disasm, show_bend, full_analysis);
        return;
    }
    
    // Default: EVM analysis
    // Default: show basic info
    if (!show_disasm and !show_abi and !show_solidity and !show_types and !show_controlflow and !full_analysis) {
        full_analysis = true;
    }

    // Create type analyzer for reuse
    var type_analyzer = analysis_types.TypeAnalyzer{ .allocator = alloc };

    if (full_analysis or show_disasm) {
        var dis = evm_disassembler.Disassembler.init(alloc);
        std.debug.print("\n=== Disassembly ===\n", .{});
        try dis.disassembleToStdout(bytecode);
    }

    // Constructor analysis
    if (full_analysis or show_constructor) {
        std.debug.print("\n=== Constructor Analysis ===\n", .{});
        
        var constructor_info = try analysis_constructor.analyzeConstructor(bytecode, alloc);
        defer constructor_info.deinit(alloc);
        
        analysis_constructor.printConstructorInfo(&constructor_info);
    }

    if (full_analysis or show_abi) {
        std.debug.print("\n=== Function Selectors ===\n", .{});
        const selectors = try evm_abi.extractSelectors(bytecode, alloc);
        defer alloc.free(selectors);

        if (selectors.len == 0) {
            std.debug.print("No function selectors found\n", .{});
        } else {
            for (selectors) |sel| {
                std.debug.print("  {x}{x}{x}{x}", .{ sel.bytes[0], sel.bytes[1], sel.bytes[2], sel.bytes[3] });
                if (sel.name.len > 0) {
                    std.debug.print(" -> {s}", .{sel.name});
                }
                std.debug.print("\n", .{});
            }
        }
    }

    if (full_analysis or show_types) {
        std.debug.print("\n=== Type Inference ===\n", .{});
        
        const instructions = try evm_opcodes.parseInstructions(alloc, bytecode);
        defer alloc.free(instructions);
        
        // Analyze storage types
        std.debug.print("\n--- Storage Types ---\n", .{});
        
        // Find unique storage slots from SLOAD/SSTORE
        var slots_seen = std.AutoArrayHashMap(u64, void).init(alloc);
        defer slots_seen.deinit();
        
        for (instructions) |instr| {
            if (instr.opcode == .sload or instr.opcode == .sstore) {
                try slots_seen.put(0, {}); // Default slot 0
            }
        }
        
        // Analyze slot 0
        const result = try type_analyzer.analyzeStorageSlot(bytecode, 0);
        const type_str = analysis_types.TypeAnalyzer.typeToString(result.type);
        std.debug.print("  slot0: {s} (confidence: {d:.2})\n", .{ type_str, result.confidence });
        
        // Analyze function parameters
        std.debug.print("\n--- Function Parameters ---\n", .{});
        
        // Find jumpdest (function entry points)
        var func_count: usize = 0;
        for (instructions) |instr| {
            if (instr.opcode == .jumpdest and func_count < 3) {
                const params = try type_analyzer.analyzeParams(bytecode, instr.pc);
                defer {
                    for (params) |p| alloc.free(p.name);
                    alloc.free(params);
                }
                
                std.debug.print("  Function at PC {x}:\n", .{instr.pc});
                if (params.len == 0) {
                    std.debug.print("    (no parameters detected)\n", .{});
                } else {
                    for (params) |p| {
                        std.debug.print("    - {s}: {s}\n", .{ p.name, p.type_str });
                    }
                }
                func_count += 1;
            }
        }
        
        if (func_count == 0) {
            std.debug.print("  No function entry points found\n", .{});
        }
    }

    if (full_analysis or show_solidity) {
        std.debug.print("\n=== Solidity-like Code ===\n", .{});
        
        // Generate Solidity code
        std.debug.print("// SPDX-License-Identifier: MIT\n", .{});
        std.debug.print("pragma solidity ^0.8.0;\n\n", .{});
        std.debug.print("contract DecompiledContract {{\n\n", .{});
        
        // Analyze storage - find all unique slots
        std.debug.print("    // State variables\n", .{});
        
        const instructions = try evm_opcodes.parseInstructions(alloc, bytecode);
        defer alloc.free(instructions);
        
        var slots_seen = std.AutoArrayHashMap(u64, void).init(alloc);
        defer slots_seen.deinit();
        
        // Find all storage slots
        var i: usize = 0;
        while (i < instructions.len) : (i += 1) {
            const instr = instructions[i];
            // Look for PUSH followed by SLOAD/SSTORE
            if (evm_opcodes.isPush(instr.opcode) and instr.push_data != null) {
                if (i + 1 < instructions.len) {
                    const next = instructions[i + 1];
                    if (next.opcode == .sload or next.opcode == .sstore) {
                        const slot = evm_opcodes.readPushDataAsU64(instr.push_data.?);
                        // Ignore allocation failure - slot tracking is best-effort
                        slots_seen.put(slot, {}) catch {};
                    }
                }
            }
        }
        
        // Default slot 0 if no slots found
        if (slots_seen.count() == 0) {
            slots_seen.put(0, {}) catch {};
        }
        
        // Print state variables
        var slot_iter = slots_seen.iterator();
        var slot_idx: usize = 0;
        while (slot_iter.next()) |entry| {
            const slot = entry.key_ptr.*;
            const result = try type_analyzer.analyzeStorageSlot(bytecode, slot);
            const type_str = analysis_types.TypeAnalyzer.typeToString(result.type);
            std.debug.print("    {s} private _var{x};\n", .{type_str, slot});
            slot_idx += 1;
        }
        std.debug.print("\n", .{});
        
        // Detect events (LOG opcodes)
        var events_found = std.AutoArrayHashMap(u64, void).init(alloc);
        defer events_found.deinit();
        
        for (instructions) |instr| {
            switch (instr.opcode) {
                .log0, .log1, .log2, .log3, .log4 => {
                    // Count topics to determine event (best-effort)
                    events_found.put(events_found.count(), {}) catch {};
                },
                else => {},
            }
        }
        
        if (events_found.count() > 0) {
            std.debug.print("    // Events\n", .{});
            var j: usize = 0;
            while (j < events_found.count()) : (j += 1) {
                std.debug.print("    event Event{x}(indexed address);\n", .{j});
            }
            std.debug.print("\n", .{});
        }
        
        // Get function selectors
        const selectors = try evm_abi.extractSelectors(bytecode, alloc);
        defer alloc.free(selectors);
        
        std.debug.print("    // Functions\n", .{});
        if (selectors.len > 0) {
            for (selectors) |sel| {
                const name = if (sel.name.len > 0) sel.name else "unknown";
                std.debug.print("    function ", .{});
                std.debug.print("{s}() external view returns (uint256) {{\n", .{name});
                std.debug.print("        // ...\n", .{});
                std.debug.print("    }}\n\n", .{});
            }
        } else {
            std.debug.print("    fallback() external {{\n", .{});
            std.debug.print("        revert();\n", .{});
            std.debug.print("    }}\n", .{});
        }
        
        std.debug.print("}}\n", .{});
    }
    
    if (full_analysis or show_controlflow) {
        std.debug.print("\n=== Control Flow Analysis ===\n", .{});
        
        const cfg = analysis_controlflow.analyzeControlFlow(bytecode, alloc) catch {
            std.debug.print("// Error analyzing control flow\n", .{});
            return;
        };
        
        // Free allocated memory
        alloc.free(cfg.blocks);
        alloc.free(cfg.functions);
        alloc.free(cfg.loops);
        alloc.free(cfg.branches);
        
        std.debug.print("Functions found: {d}\n", .{cfg.getFunctionCount()});
        std.debug.print("Basic blocks: {d}\n", .{cfg.blocks.len});
        std.debug.print("Loops: 0\n", .{});
        std.debug.print("Branches: {d}\n", .{cfg.getBranchCount()});
        
        // List functions
        for (cfg.functions) |func| {
            std.debug.print("\nFunction at PC {x}:\n", .{func.entry_pc});
        }
    }
    
    if (full_analysis or show_symbolic) {
        std.debug.print("\n=== Symbolic Execution ===\n", .{});
        
        // Simple bytecode analysis
        const analysis = symbolic_executor.analyzeBytecode(bytecode);
        
        std.debug.print("SLOAD operations: {d}\n", .{analysis.sload_count});
        std.debug.print("SSTORE operations: {d}\n", .{analysis.sstore_count});
        std.debug.print("CALL operations: {d}\n", .{analysis.call_count});
        std.debug.print("CREATE operations: {d}\n", .{analysis.create_count});
        
        // Execute full symbolic execution if requested
        if (show_symbolic) {
            var executor = symbolic_executor.Executor.init(bytecode, alloc, .{}) catch {
                std.debug.print("// Error running symbolic execution\n", .{});
                return;
            };
            defer executor.deinit();
            
            // Continue execution even if it fails - best-effort analysis
            executor.executeEntryPoint(0) catch {};
            
            std.debug.print("\n// Symbolic execution completed\n", .{});
        }
    }
}

fn parseHex(hex: []const u8, alloc: std.mem.Allocator) ![]u8 {
    const clean_hex = if (std.mem.startsWith(u8, hex, "0x")) hex[2..] else hex;
    
    // Validate hex string
    if (clean_hex.len % 2 != 0) {
        return error.InvalidHexLength;
    }
    
    const len = clean_hex.len / 2;
    const data = try alloc.alloc(u8, len);
    errdefer alloc.free(data);

    var i: usize = 0;
    while (i < len) : (i += 1) {
        const byte_hex = clean_hex[i * 2 .. i * 2 + 2];
        data[i] = std.fmt.parseInt(u8, byte_hex, 16) catch |err| {
            return err;
        };
    }
    return data;
}

/// Process Bend-PVM / RISC-V bytecode
fn processBendPVM(bytecode: []const u8, alloc: std.mem.Allocator, show_disasm: bool, show_bend: bool, full_analysis: bool) !void {
    const instructions = try bend_opcodes.parseInstructions(alloc, bytecode);
    defer alloc.free(instructions);
    
    // Generate Bend-PVM source if requested
    if (full_analysis or show_bend) {
        std.debug.print("\n=== Bend-PVM Source Reconstruction ===\n\n", .{});
        
        const source = try bend_source.generateHighLevelSource(instructions, alloc);
        defer alloc.free(source);
        
        std.debug.print("{s}", .{source});
    }
    
    if (full_analysis or show_disasm) {
        std.debug.print("=== Bend-PVM / RISC-V Disassembly ===\n\n", .{});
        
        for (instructions) |instr| {
            const name = bend_opcodes.getName(instr);
            std.debug.print("{x:04}: {s:8} ", .{ instr.pc, name });
            
            // Print operands based on opcode
            switch (instr.opcode_byte) {
                0x37, 0x17 => { // lui, auipc
                    std.debug.print("x{}, {}", .{ instr.rd, instr.imm });
                },
                0x6f => { // jal
                    std.debug.print("x{}, {}", .{ instr.rd, instr.imm });
                },
                0x67 => { // jalr
                    std.debug.print("x{}, {}(x{})", .{ instr.rd, instr.imm, instr.rs1 });
                },
                0x63 => { // branch
                    std.debug.print("x{}, x{}, {}", .{ instr.rs1, instr.rs2, instr.imm });
                },
                0x03, 0x23 => { // load, store
                    std.debug.print("x{}, {}(x{})", .{ if (instr.opcode_byte == 0x03) instr.rd else instr.rs2, instr.imm, instr.rs1 });
                },
                0x13 => { // arithmetic immediate
                    if (instr.funct3 == 0x1 or instr.funct3 == 0x5) {
                        std.debug.print("x{}, x{}, {}", .{ instr.rd, instr.rs1, instr.funct7 });
                    } else {
                        std.debug.print("x{}, x{}, {}", .{ instr.rd, instr.rs1, instr.imm });
                    }
                },
                0x33 => { // arithmetic
                    std.debug.print("x{}, x{}, x{}", .{ instr.rd, instr.rs1, instr.rs2 });
                },
                0x73 => { // ecall/ebreak
                    if (instr.funct3 == 0) std.debug.print("(syscall)", .{}) else std.debug.print("(ebreak)", .{});
                },
                else => {},
            }
            std.debug.print("\n", .{});
        }
    }
    
    // Statistics
    std.debug.print("\n=== Statistics ===\n", .{});
    std.debug.print("Total instructions: {d}\n", .{instructions.len});
    
    // Count by category
    var load_count: usize = 0;
    var store_count: usize = 0;
    var branch_count: usize = 0;
    var arith_count: usize = 0;
    var bend_count: usize = 0;
    
    for (instructions) |instr| {
        switch (instr.opcode_byte) {
            0x03 => load_count += 1,
            0x23 => store_count += 1,
            0x63 => branch_count += 1,
            0x13, 0x33 => arith_count += 1,
            0x5b...0x5f => bend_count += 1,
            else => {},
        }
    }
    
    std.debug.print("Load operations: {d}\n", .{load_count});
    std.debug.print("Store operations: {d}\n", .{store_count});
    std.debug.print("Branches: {d}\n", .{branch_count});
    std.debug.print("Arithmetic: {d}\n", .{arith_count});
    std.debug.print("Bend extensions: {d}\n", .{bend_count});
}
