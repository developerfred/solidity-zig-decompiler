# Solidity Zig Decompiler

Advanced EVM bytecode decompiler built with Zig.

## Features

- **Bytecode Parsing**: Parse raw EVM bytecode into structured instructions
- **Function Signature Resolution**: Identify known function selectors (ERC-20, DeFi protocols)
- **Control Flow Graph**: Build CFG from bytecode
- **Symbolic Execution**: Basic symbolic execution engine
- **Gas Analysis**: Estimate gas costs
- **Vulnerability Detection**: Scan for common security issues
- **Embedded Strings**: Extract embedded strings from bytecode

## Supported Protocols

### Flash Loans
- Aave V2/V3
- Uniswap V2/V3 (Flash Swaps)
- dYdX
- Euler
- Balancer V2
- Yearn

### DeFi Protocols
- Uniswap V2/V3
- Aave V2/V3
- Compound V2/V3
- Curve
- MakerDAO
- Lido (stETH)
- Rocket Pool (rETH)
- Yearn Vaults
- Gnosis Safe

### Token Standards
- ERC-20
- ERC-721
- ERC-1155
- ERC-165
- ERC-4337 (Account Abstraction)

### Proxy Patterns
- UUPS
- Transparent Proxy
- Diamond Standard (EIP-2535)
- Beacon Proxy

## Installation

```bash
# Clone the repository
git clone https://github.com/Developerfred/solidity-zig-decompiler.git
cd solidity-zig-decompiler

# Build
zig build

# Run
zig build run -- <bytecode>

# Test
zig build test
```

## Usage

### Command Line

```bash
# Decompile bytecode
./zig-out/bin/solidity_zig_decompiler 0x608060405234...

# With options
./zig-out/bin/solidity_zig_decompiler --help
```

### As a Library

```zig
const decompiler = @import("solidity_zig_decompiler");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const bytecode = "0x608060405234...";
    
    // Parse bytecode
    const parsed = try parser.parse(allocator, bytecode);
    defer parser.deinit(&parsed);
    
    // Resolve function selector
    const selector = try signatures.hexToSelector("0xa9059cbb");
    const sig = try signatures.resolve(selector, &cache);
    
    std.debug.print("Function: {s}\n", .{sig.signature});
}
```

## Project Structure

```
src/
├── evm/
│   ├── opcodes.zig      # EVM opcode definitions
│   ├── parser.zig       # Bytecode parser
│   ├── dispatcher.zig   # Function selector extraction
│   ├── signatures.zig   # Function signature resolver
│   ├── strings.zig      # Embedded string extraction
│   └── cfg.zig          # Control flow graph
├── decompiler/
│   └── main.zig         # Main decompiler
├── analysis/
│   └── gas.zig          # Gas cost analysis
├── symbolic/
│   └── executor.zig     # Symbolic execution
├── vulnerability/
│   └── scanner.zig     # Security vulnerability scanner
└── main.zig             # CLI entry point
```

## Function Signatures

The decompiler includes built-in signatures for:

| Category | Count | Examples |
|----------|-------|----------|
| ERC-20 | 8 | transfer, approve, balanceOf |
| ERC-721 | 7 | ownerOf, safeTransferFrom |
| Flash Loans | 14 | Aave flashLoan, Uniswap flash |
| Uniswap V2/V3 | 20 | swapExactETHForTokens, exactInputSingle |
| Aave V2/V3 | 12 | deposit, borrow, withdraw |
| Compound | 10 | mint, redeem, borrow |
| Curve | 8 | add_liquidity, exchange |
| Proxy | 15 | upgradeTo, diamondCut |

## Vulnerability Detection

The scanner detects:

- Reentrancy vulnerabilities (CWE-416)
- Unchecked external calls (CWE-252)
- Integer overflow/underflow (CWE-190, CWE-191)
- Access control issues (CWE-284)
- Front-running susceptibility
- Delegatecall to untrusted contracts

## Testing

```bash
# Run all tests
zig build test

# Run specific test
zig test src/evm/signatures_test.zig
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit with conventional commits
4. Push and create PR

## License

MIT License - see LICENSE file for details.

## Credits

- [Smart Contract Sanctuary](https://github.com/tintinweb/smart-contract-sanctuary) for reference implementations
- [DeFi Llama](https://defillama.com) for protocol data
