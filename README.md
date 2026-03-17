# Solidity Zig Decompiler

[![CI](https://github.com/Developerfred/solidity-zig-decompiler/actions/workflows/ci.yml/badge.svg)](https://github.com/Developerfred/solidity-zig-decompiler/actions)
[![Zig Version](https://img.shields.io/badge/Zig-0.15.2+-yellow.svg)](https://ziglang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Project Stage](https://img.shields.io/badge/Stage-Alpha-orange.svg)](README.md)

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

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Developerfred/solidity-zig-decompiler.git
cd solidity-zig-decompiler

# Build
zig build

# Run
echo "0x608060405234801561000f575f80fd5b5061012a8061001f5f395ff3335" | zig build run

# Run tests
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
    const parsed = try decompiler.evm.parser.parse(allocator, bytecode);
    defer decompiler.evm.parser.deinit(&parsed);
    
    // Initialize signature cache
    var cache = decompiler.evm.signatures.SignatureCache.init(allocator);
    defer cache.deinit();
    
    // Resolve function selector
    const selector = try decompiler.evm.signatures.hexToSelector("0xa9059cbb");
    const sig = try decompiler.evm.signatures.resolve(selector.?, &cache);
    
    std.debug.print("Function: {s}\n", .{sig.signature});
}
```

## Project Structure

```
src/
├── evm/
│   ├── opcodes.zig          # EVM opcode definitions
│   ├── parser.zig           # Bytecode parser
│   ├── dispatcher.zig       # Function selector extraction
│   ├── signatures.zig       # Function signature resolver
│   ├── signatures_test.zig  # Signature tests
│   ├── parser_test.zig      # Parser tests
│   ├── strings.zig          # Embedded string extraction
│   └── cfg.zig              # Control flow graph
├── decompiler/
│   └── main.zig             # Main decompiler
├── analysis/
│   └── gas.zig              # Gas cost analysis
├── symbolic/
│   └── executor.zig         # Symbolic execution
├── vulnerability/
│   └── scanner.zig          # Security vulnerability scanner
├── main.zig                 # CLI entry point
└── root.zig                 # Library root exports
```

## Vulnerability Detection

The scanner detects:

| CWE ID | Vulnerability | Severity |
|--------|--------------|----------|
| CWE-416 | Reentrancy | High |
| CWE-252 | Unchecked Call | Medium |
| CWE-190 | Integer Overflow | High |
| CWE-191 | Integer Underflow | High |
| CWE-284 | Access Control | Critical |

## Testing

```bash
# Run all tests
zig build test

# Run specific test file
zig test src/evm/signatures_test.zig

# Run with verbose output
zig build test -v
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit with conventional commits (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Conventional Commits

- `feat:` New feature
- `fix:` Bug fix
- `test:` Add tests
- `docs:` Documentation
- `refactor:` Code refactoring
- `chore:` Build process or auxiliary tools

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

- [Smart Contract Sanctuary](https://github.com/tintinweb/smart-contract-sanctuary)
- [DeFi Llama](https://defillama.com)
- [OpenZeppelin](https://openzeppelin.com)
