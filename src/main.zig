// Solidity Zig Decompiler - Main Entry Point
// Advanced EVM bytecode decompiler with security focus

const std = @import("std");
const decompiler = @import("decompiler/main.zig");
const evm_signatures = @import("evm/signatures.zig");
const json_output = @import("output/json.zig");
const html_output = @import("output/html.zig");
const formal = @import("formal/verifier.zig");

pub const OutputFormat = enum {
    solidity,
    vyper,
    json,
    html,
};

pub const CLIConfig = struct {
    format: OutputFormat = .solidity,
    verbose: bool = false,
    chain: []const u8 = "ethereum",
    output_file: ?[]const u8 = null,
    verify_contract: bool = false,
    formal_spec: bool = false,
};

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

/// Print usage information
fn printUsage(program_name: []const u8) void {
    std.debug.print("Solidity Zig Decompiler v0.1.0\n", .{});
    std.debug.print("=============================\n\n", .{});
    std.debug.print("Usage: {s} <bytecode> [options]\n\n", .{program_name});
    std.debug.print("Arguments:\n", .{});
    std.debug.print("  <bytecode>    Hex-encoded EVM bytecode, file path, or address (0x...)\n\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("  -h, --help          Show this help message\n", .{});
    std.debug.print("  -v, --verbose       Enable verbose output\n", .{});
    std.debug.print("  -f, --format        Output format: solidity, vyper, json, html (default: solidity)\n", .{});
    std.debug.print("  -o, --output        Output file (default: stdout)\n", .{});
    std.debug.print("  -c, --chain         Target chain: ethereum, polygon, bsc, avalanche, arbitrum, optimism, base, zksync, gnosis\n", .{});
    std.debug.print("      --no-sig         Skip signature resolution\n", .{});
    std.debug.print("      --no-cfg         Skip CFG analysis\n", .{});
    std.debug.print("      --no-strings     Skip string extraction\n", .{});
    std.debug.print("      --no-patterns    Skip pattern detection\n", .{});
    std.debug.print("      --verify         Verify contract against source (requires address)\n", .{});
    std.debug.print("      --formal-spec    Generate Certora specification for formal verification\n", .{});
    std.debug.print("\nExamples:\n", .{});
    std.debug.print("  {s} 0x60806040...\n", .{program_name});
    std.debug.print("  {s} contract.hex -f json -o output.json\n", .{program_name});
    std.debug.print("  {s} 0x1234... --formal-spec -o contract.spec\n", .{program_name});
    std.debug.print("  {s} --chain polygon 0x5678...\n\n", .{program_name});
    std.debug.print("Supported Chains:\n", .{});
    std.debug.print("  ethereum    - Ethereum Mainnet\n", .{});
    std.debug.print("  polygon     - Polygon PoS\n", .{});
    std.debug.print("  bsc         - Binance Smart Chain\n", .{});
    std.debug.print("  avalanche   - Avalanche C-Chain\n", .{});
    std.debug.print("  arbitrum    - Arbitrum One\n", .{});
    std.debug.print("  optimism    - Optimism\n", .{});
    std.debug.print("  base        - Base\n", .{});
    std.debug.print("  zksync      - zkSync Era\n", .{});
    std.debug.print("  gnosis      - Gnosis Chain\n", .{});
}

/// Print verbose information
fn printVerboseInfo(contract: *const decompiler.DecompiledContract) void {
    std.debug.print("\n=== Contract Analysis ===\n", .{});
    std.debug.print("Name: {s}\n", .{contract.name});
    std.debug.print("Functions: {d}\n", .{contract.functions.len});
    std.debug.print("Embedded Strings: {d}\n", .{contract.embedded_strings.len});

    if (contract.is_erc20) {
        std.debug.print("Detected: ERC20 Token\n", .{});
    }
    if (contract.is_erc721) {
        std.debug.print("Detected: ERC721 NFT\n", .{});
    }
    if (contract.is_proxy) {
        std.debug.print("Detected: Proxy Contract\n", .{});
    }
    if (contract.is_vyper) {
        std.debug.print("Detected: Vyper Contract\n", .{});
        if (contract.vyper_version) |ver| {
            std.debug.print("Vyper Version: {d}.{d}.{d}\n", .{ ver.major, ver.minor, ver.patch });
        }
    }

    std.debug.print("\nFunction Selectors:\n", .{});
    for (contract.functions) |func| {
        std.debug.print("  {s} -> {s}\n", .{ func.name, evm_signatures.selectorToSlice(func.selector) });
    }
}

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    var config: decompiler.Config = .{};
    var cli_config: CLIConfig = .{};
    var bytecode_arg: ?[]const u8 = null;

    // Parse arguments
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printUsage(args[0]);
            return;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            cli_config.verbose = true;
            config.verbose = true;
        } else if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--format")) {
            if (i + 1 < args.len) {
                i += 1;
                const format = args[i];
                if (std.mem.eql(u8, format, "solidity")) {
                    cli_config.format = .solidity;
                } else if (std.mem.eql(u8, format, "vyper")) {
                    cli_config.format = .vyper;
                } else if (std.mem.eql(u8, format, "json")) {
                    cli_config.format = .json;
                } else if (std.mem.eql(u8, format, "html")) {
                    cli_config.format = .html;
                } else {
                    std.debug.print("Error: Unknown format '{s}'. Use solidity, vyper, json, or html.\n", .{format});
                    return error.InvalidFormat;
                }
            }
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            if (i + 1 < args.len) {
                i += 1;
                cli_config.output_file = args[i];
            }
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--chain")) {
            if (i + 1 < args.len) {
                i += 1;
                cli_config.chain = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--no-sig")) {
            config.resolve_signatures = false;
        } else if (std.mem.eql(u8, arg, "--no-cfg")) {
            config.build_cfg = false;
        } else if (std.mem.eql(u8, arg, "--no-strings")) {
            config.extract_strings = false;
        } else if (std.mem.eql(u8, arg, "--no-patterns")) {
            config.detect_patterns = false;
        } else if (std.mem.eql(u8, arg, "--verify")) {
            cli_config.verify_contract = true;
        } else if (std.mem.eql(u8, arg, "--formal-spec")) {
            cli_config.formal_spec = true;
        } else if (std.mem.startsWith(u8, arg, "0x")) {
            bytecode_arg = arg;
        } else {
            // Try as file path
            bytecode_arg = arg;
        }
    }

    const bytecode_source = bytecode_arg orelse {
        printUsage(args[0]);
        return error.InvalidArguments;
    };

    // Read bytecode
    var bytecode: []const u8 = undefined;

    if (std.fs.path.isAbsolute(bytecode_source)) {
        const file = try std.fs.openFileAbsolute(bytecode_source, .{});
        defer file.close();
        const file_size = try file.getEndPos();
        const buffer = try std.heap.page_allocator.alloc(u8, file_size);
        defer std.heap.page_allocator.free(buffer);
        _ = try file.read(buffer);
        bytecode = buffer;
    } else if (std.mem.startsWith(u8, bytecode_source, "0x")) {
        bytecode = try parseHexString(bytecode_source[2..]);
    } else {
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
            bytecode = bytecode_source;
        }
    }

    // Run decompiler
    const contract = try decompiler.decompile(std.heap.page_allocator, bytecode, config);

    // Print verbose info
    if (cli_config.verbose) {
        printVerboseInfo(&contract);
    }

    // Generate output based on format
    var output_buffer = std.ArrayList(u8).init(std.heap.page_allocator);
    defer output_buffer.deinit();

    switch (cli_config.format) {
        .solidity, .vyper => {
            try decompiler.generateSolidity(&contract, output_buffer.writer());
        },
        .json => {
            try json_output.generateJSON(&contract, output_buffer.writer());
        },
        .html => {
            try html_output.generateHTML(&contract, output_buffer.writer());
        },
    }

    // Generate formal spec if requested
    if (cli_config.formal_spec) {
        const spec = try formal.generateCertoraSpec(std.heap.page_allocator, &contract);
        defer std.heap.page_allocator.free(spec);

        if (cli_config.output_file) |path| {
            const file = try std.fs.cwd().createFile(path, .{});
            defer file.close();
            try file.writeAll(spec);
            std.debug.print("Certora spec written to: {s}\n", .{path});
        } else {
            std.debug.print("\n=== Certora Specification ===\n{s}\n", .{spec});
        }
    }

    // Output result
    if (cli_config.output_file) |path| {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(output_buffer.items);
        std.debug.print("Output written to: {s}\n", .{path});
    } else {
        std.debug.print("{s}", .{output_buffer.items});
    }
}
