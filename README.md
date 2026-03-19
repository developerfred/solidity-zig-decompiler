# Solidity Zig Decompiler

[![CI](https://github.com/Developerfred/solidity-zig-decompiler/actions/workflows/ci.yml/badge.svg)](https://github.com/Developerfred/solidity-zig-decompiler/actions)
[![Zig Version](https://img.shields.io/badge/Zig-0.15.2+-yellow.svg)](https://ziglang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Project Stage](https://img.shields.io/badge/Stage-Beta-green.svg)](README.md)

Advanced EVM bytecode decompiler built with Zig. A comprehensive security-focused tool for analyzing, decompiling, and auditing Ethereum smart contracts.

## Table of Contents

- [Features](#features)
- [Supported Protocols](#supported-protocols)
- [Quick Start](#quick-start)
- [CLI Usage](#cli-usage)
- [Output Formats](#output-formats)
- [Configuration](#configuration)
- [As a Library](#as-a-library)
- [Project Structure](#project-structure)
- [Vulnerability Detection](#vulnerability-detection)
- [Security Analysis](#security-analysis)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

---

## Features

### Core Decompilation
- **Bytecode Parsing**: Parse raw EVM bytecode into structured instructions
- **Function Signature Resolution**: Identify known function selectors
- **Control Flow Graph**: Build CFG from bytecode
- **Embedded Strings**: Extract embedded strings from bytecode
- **Source Code Reconstruction**: Generate pseudo-Solidity/Vyper code

### Security & Analysis
- **Vulnerability Detection**: Scan for common security issues
- **Gas Analysis**: Estimate gas costs
- **Obfuscation Detection**: Detect bytecode obfuscation patterns
- **MEV Detection**: Identify MEV extraction opportunities
- **Formal Verification**: Generate Certora specifications

### Multi-Chain Support
- Ethereum Mainnet
- Polygon PoS
- Binance Smart Chain (BNB Chain)
- Avalanche C-Chain
- Arbitrum One
- Optimism
- Base
- zkSync Era
- Gnosis Chain

### Advanced Features
- **Contract Verification**: Compare decompiled code with source from block explorers
- **Deployment Detection**: Identify factory, proxy, and clone patterns
- **Vyper Support**: Detect and decompile Vyper-compiled contracts
- **Protocol Detection**: Identify DeFi protocols from bytecode

---

## Supported Protocols

### Cross-Chain & Bridges
- **Li.FI**: Cross-chain liquidity aggregation (diamond proxy)
- Stargate, Across, ThorChain, LayerZero, Wormhole

### Flash Loans
- Aave V2/V3
- Uniswap V2/V3 (Flash Swaps)
- dYdX, Euler, Balancer V2, Yearn

### DeFi Protocols
- Uniswap V2/V3
- Aave V2/V3
- Compound V2/V3
- Curve
- MakerDAO
- Lido (stETH)
- Yearn Vaults
- Gnosis Safe

### Token Standards
- ERC-20, ERC-721, ERC-1155
- ERC-165, ERC-4337 (Account Abstraction)

### Proxy Patterns
- UUPS (EIP-1822)
- Transparent Proxy (EIP-1967)
- Diamond Standard (EIP-2535)
- Beacon Proxy
- Minimal Proxy (EIP-1167)

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Developerfred/solidity-zig-decompiler.git
cd solidity-zig-decompiler

# Build
zig build

# Run with help
zig build run -- --help

# Run tests
zig build test
```

---

## CLI Usage

### Basic Usage

```bash
# Decompile bytecode from hex string
./zig-out/bin/solidity_zig_decompiler 0x608060405234801561000f575f80fd5b5061012a8061001f5f395ff3335

# Decompile from file
./zig-out/bin/solidity_zig_decompiler contract.hex

# Decompile from Ethereum address (via RPC)
./zig-out/bin/solidity_zig_decompiler 0x1234567890abcdef1234567890abcdef12345678
```

### Options

```bash
-h, --help                    Show help message
-v, --verbose                Enable verbose output
-f, --format                 Output format: solidity, vyper, json, html (default: solidity)
-o, --output                 Output file (default: stdout)
-c, --chain                  Target chain: ethereum, polygon, bsc, avalanche, arbitrum, optimism, base, zksync, gnosis
    --no-sig                 Skip signature resolution
    --no-cfg                 Skip CFG analysis
    --no-strings             Skip string extraction
    --no-patterns            Skip pattern detection
    --verify                 Verify contract against source (requires address)
    --formal-spec           Generate Certora specification for formal verification
```

### Examples

```bash
# Output JSON format
./zig-out/bin/solidity_zig_decompiler 0x608060405234... -f json -o output.json

# Verbose mode with contract analysis
./zig-out/bin/solidity_zig_decompiler 0x1234... -v

# Generate formal verification spec
./zig-out/bin/solidity_zig_decompiler 0x5678... --formal-spec -o contract.spec

# Target specific chain
./zig-out/bin/solidity_zig_decompiler 0xabcd... --chain polygon
```

---

## Output Formats

### Solidity (Default)
```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract ERC20 {
    // 0xa9059cbb
    function transfer(address,uint256) external {
        // [Decompiled bytecode - implementation hidden]
    }
}
```

### Vyper (for Vyper contracts)
```python
# @version ^0.3.0

@external
def transfer(address, uint256) -> bool:
    pass
```

### JSON
```json
{
  "name": "ERC20",
  "functions": [
    {
      "selector": "0xa9059cbb",
      "signature": "transfer(address,uint256)"
    }
  ],
  "is_erc20": true,
  "vulnerabilities": []
}
```

### HTML
Generates a styled HTML report with syntax highlighting and contract visualization.

---

## Configuration

### Configuration File

Create a `.decompiler.json` in your project root:

```json
{
  "default_chain": "ethereum",
  "resolve_signatures": true,
  "build_cfg": true,
  "extract_strings": true,
  "detect_patterns": true,
  "verbose": false,
  "output_format": "solidity"
}
```

### Environment Variables

```bash
# Ethereum RPC endpoint
export ETH_RPC_URL="https://eth-mainnet.alchemyapi.io/v2/your-key"

# Polygon RPC
export POLYGON_RPC_URL="https://polygon-rpc.com"

# BSC RPC
export BSC_RPC_URL="https://bsc-dataseed.binance.org"
```

---

## As a Library

### Basic Usage

```zig
const std = @import("std");
const decompiler = @import("decompiler/main.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const bytecode = try std.fmt.parseHex("608060405234801561000f575f80fd5b5061012a8061001f5f395ff3335");
    
    var config: decompiler.Config = .{
        .resolve_signatures = true,
        .build_cfg = true,
        .extract_strings = true,
        .detect_patterns = true,
    };
    
    const contract = try decompiler.decompile(allocator, bytecode, config);
    
    std.debug.print("Contract: {s}\n", .{contract.name});
    std.debug.print("Functions: {d}\n", .{contract.functions.len});
}
```

### Using Individual Modules

```zig
// Parse bytecode
const parser = @import("evm/parser.zig");
const parsed = try parser.parse(allocator, bytecode);

// Resolve signatures
const signatures = @import("evm/signatures.zig");
var cache = signatures.SignatureCache.init(allocator);
const sig = try signatures.resolve(selector, &cache);

// Scan for vulnerabilities
const scanner = @import("vulnerability/scanner.zig");
const vulns = try scanner.scan(allocator, bytecode);

// Gas analysis
const gas = @import("analysis/gas.zig");
const analysis = try gas.analyze(allocator, bytecode);

// Deployment detection
const deployment = @import("deployment/detector.zig");
const info = try deployment.detect(allocator, bytecode);

// Protocol detection
const protocols = @import("protocols/registry.zig");
const detected = try protocols.detectProtocol(allocator, bytecode, address);
```

---

## Project Structure

```
src/
├── evm/                          # Core EVM parsing
│   ├── opcodes.zig              # EVM opcode definitions (140+ opcodes)
│   ├── parser.zig               # Bytecode parser
│   ├── dispatcher.zig           # Function selector extraction
│   ├── signatures.zig           # Function signature resolver (1000+ signatures)
│   ├── signatures_test.zig      # Signature resolution tests
│   ├── parser_test.zig          # Parser tests
│   ├── strings.zig              # Embedded string extraction
│   └── cfg.zig                  # Control flow graph builder
│
├── decompiler/                   # Main decompilation
│   ├── main.zig                 # Core decompiler
│   └── source_reconstruction.zig # Solidity code generator
│
├── analysis/                     # Code analysis
│   └── gas.zig                  # Gas cost estimation
│
├── vulnerability/                # Security scanning
│   ├── scanner.zig              # Vulnerability scanner
│   ├── scanner_test.zig         # Scanner tests
│   ├── registry.zig             # Vulnerability registry
│   └── templates/               # Vulnerability templates
│
├── symbolic/                    # Symbolic execution
│   └── executor.zig            # Symbolic executor
│
├── deployment/                  # Deployment pattern detection
│   └── detector.zig            # Factory, proxy, clone detection
│
├── multichain/                  # Multi-chain support
│   └── chains.zig              # Chain configurations
│
├── verification/                # Contract verification
│   └── contract_verifier.zig   # Source code verification
│
├── formal/                      # Formal verification
│   └── verifier.zig            # Certora spec generator
│
├── vyper/                       # Vyper support
│   ├── mod.zig                 # Vyper detection & signatures
│   └── vyper_test.zig          # Vyper tests
│
├── protocols/                   # Protocol detection
│   ├── lifi.zig                # Li.FI protocol
│   └── registry.zig            # Protocol registry
│
├── output/                      # Output formatters
│   ├── json.zig                # JSON output
│   ├── html.zig                # HTML report
│   └── diff.zig                # Diff output
│
├── sourcify/                    # Sourcify integration
│   └── client.zig              # Sourcify API client
│
├── main.zig                     # CLI entry point
└── root.zig                    # Library root exports
```

---

## Vulnerability Detection

The scanner detects the following security issues:

### Critical
| CWE ID | Vulnerability | Description |
|--------|--------------|-------------|
| CWE-284 | Access Control | Missing or broken access controls |
| CWE-94 | Code Injection | Delegatecall to untrusted address |
| CWE-347 | Improper Verification | Missing signature verification |

### High
| CWE ID | Vulnerability | Description |
|--------|--------------|-------------|
| CWE-416 | Reentrancy | Dangerous call after state change |
| CWE-190 | Integer Overflow | Arithmetic overflow possible |
| CWE-754 | Unchecked Return | Missing return value check |

### Medium
| CWE ID | Vulnerability | Description |
|--------|--------------|-------------|
| CWE-252 | Unchecked Call | Call return value not checked |
| CWE-400 | Denial of Service | Unbounded operation |
| CWE-401 | Memory Leak | Missing cleanup |

### Low
| CWE ID | Vulnerability | Description |
|--------|--------------|-------------|
| CWE-478 | Missing Default | Missing default case in switch |
| CWE-483 | Parameter Mixing | Incorrect parameter order |

---

## Security Analysis

### Obfuscation Detection
The tool detects various bytecode obfuscation techniques:
- PUSH0 pattern injection (EIP-3855)
- Dead code injection
- Abnormal code density
- Unusual jump patterns

### MEV Detection
Identifies potential MEV extraction opportunities:
- Arbitrage opportunities
- Sandwich attack patterns
- Liquidation patterns
- Front-running vulnerable functions

### Deployment Pattern Detection
Identifies contract deployment patterns:
- Factory contracts (CREATE/CREATE2)
- Proxy patterns (UUPS, Transparent, Beacon, Diamond)
- Clone patterns
- Minimal proxies

---

## Testing

```bash
# Run all tests
zig build test

# Run specific test file
zig test src/evm/signatures_test.zig
zig test src/evm/parser_test.zig
zig test src/vulnerability/scanner_test.zig

# Run with verbose output
zig build test -v

# Run with coverage
zig build test --summary all
```

### Test Categories
- **Parser Tests**: Bytecode parsing accuracy
- **Signature Tests**: Function selector resolution
- **Vulnerability Tests**: Security pattern detection
- **Integration Tests**: End-to-end decompilation

---

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

### Code Style

- Follow Zig coding conventions
- Use `zig fmt` before committing
- Add tests for new features
- Update documentation for API changes

---

## API Reference

See [API.md](docs/API.md) for complete API documentation.

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

## Credits

- [Smart Contract Sanctuary](https://github.com/tintinweb/smart-contract-sanctuary)
- [DeFi Llama](https://defillama.com)
- [OpenZeppelin](https://openzeppelin.com)
- [EVM Opcodes](https://evm.codes)
- [Li.FI Protocol](https://li.fi)

---

## Disclaimer

This tool is for educational and security research purposes. Always verify decompiled code with official source code when possible.
