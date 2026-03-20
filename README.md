# Decompile Contracts

A Solidity/Bend-PVM decompiler written in Zig 0.15.2. Analyzes EVM bytecode and RISC-V (Bend-PVM) bytecode to produce human-readable output.

## Features

- **EVM Disassembly**: Convert Ethereum bytecode to human-readable assembly
- **Function Selectors**: Extract and match known function signatures
- **Type Inference**: Infer Solidity types from bytecode patterns
- **Control Flow Analysis**: Generate CFGs and identify functions
- **Symbolic Execution**: Analyze storage access patterns
- **Solidity-like Output**: Generate pseudo-Solidity code
- **Bend-PVM Support**: Detect and disassemble RISC-V bytecode

## Installation

```bash
# Clone the repository
git clone https://github.com/codingsh/decompile-contracts
cd decompile-contracts

# Build
zig build

# Run
./zig-out/bin/decompile_contracts <bytecode> [options]
```

## Usage

```bash
# Basic disassembly
./zig-out/bin/decompile_contracts 0x608060405234801560011f5ffd5b505f80fd5b50634e3f15f3

# Full analysis
./zig-out/bin/decompile_contracts <bytecode> --full

# Specific analysis
./zig-out/bin/decompile_contracts <bytecode> --disasm
./zig-out/bin/decompile_contracts <bytecode> --abi
./zig-out/bin/decompile_contracts <bytecode> --solidity
./zig-out/bin/decompile_contracts <bytecode> --types
./zig-out/bin/decompile_contracts <bytecode> --controlflow
./zig-out/bin/decompile_contracts <bytecode> --symbolic

# Bend-PVM / RISC-V analysis
./zig-out/bin/decompile_contracts <bytecode> --bend
```

## CLI Options

| Flag | Description |
|------|-------------|
| `--disasm` | Show disassembly |
| `--abi` | Show extracted function selectors |
| `--solidity` | Generate Solidity-like code |
| `--types` | Show type inference analysis |
| `--controlflow` | Show control flow analysis |
| `--symbolic` | Run symbolic execution analysis |
| `--bend` | Generate Bend-PVM source (RISC-V) |
| `--full` | Full analysis (default) |

## Examples

### EVM Bytecode Analysis

```bash
./zig-out/bin/decompile_contracts 0x608060405234801560011f5ffd5b505f80fd5b50634e3f15f3
```

Output:
```
Detected bytecode type: EVM (Ethereum)

=== Disassembly ===
0000 PUSH1 0x80
0002 PUSH1 0x40
0004 MSTORE
0005 CALLVALUE
...

=== Function Selectors ===
0xa9059cbb -> transfer(address,uint256)
0x23b872dd -> transferFrom(address,address,uint256)
...
```

### Bend-PVM / RISC-V Analysis

```bash
./zig-out/bin/decompile_contracts 0x9300500013000000 --bend
```

Output:
```
Detected bytecode type: Bend-PVM (RISC-V)

=== Bend-PVM Source Reconstruction ===

pub fn main(x: Int) -> Result {
    // - 4 arithmetic operations
    0
}
```

## Development

### Requirements

- Zig 0.15.2

### Build

```bash
zig build
```

### Test

```bash
zig build test
```

### Run

```bash
zig build run -- <bytecode> [options]
```

## Project Structure

```
src/
├── main.zig              # CLI entry point
├── root.zig              # Library exports
├── evm/
│   ├── opcodes.zig       # EVM opcodes (142 opcodes)
│   ├── disassembler.zig  # Bytecode disassembly
│   └── abi.zig           # Function selector extraction
├── bend/
│   ├── opcodes.zig       # RISC-V opcodes
│   └── source.zig        # Bend-PVM source generation
├── symbolic/
│   └── executor.zig      # Symbolic execution engine
└── analysis/
    ├── storage.zig       # Storage layout analysis
    ├── controlflow.zig  # Control flow analysis
    ├── source.zig        # Solidity code generation
    └── types.zig         # Type inference
```

## Supported Opcodes

### EVM (142 opcodes)
- Arithmetic: ADD, MUL, SUB, DIV, MOD, SDIV, SMOD, ADDMOD, MULMOD, EXP, SIGNEXTEND
- Comparison: LT, GT, SLT, SGT, EQ, ISZERO, AND, OR, XOR, NOT, BYTE, SHL, SHR, SAR
- Environmental: ADDRESS, BALANCE, ORIGIN, CALLER, CALLVALUE, CALLDATALOAD, CALLDATASIZE, CALLDATACOPY, CODESIZE, CODECOPY, GASPRICE, EXTCODESIZE, EXTCODECOPY, RETURNDATASIZE, RETURNDATACOPY, EXTCODEHASH
- Block: COINBASE, TIMESTAMP, NUMBER, DIFFICULTY, GASLIMIT, CHAINID, BASEFEE, BLOBHASH, BLOBBASEFEE
- Stack: PUSH1-PUSH32, POP, DUP1-DUP16, SWAP1-SWAP16
- Memory: MLOAD, MSTORE, MSTORE8, SLOAD, SSTORE
- Control: JUMP, JUMPI, PC, JUMPDEST, RJUMPI
- Logging: LOG0-LOG4
- System: CREATE, CALL, CALLCODE, DELEGATECALL, STATICCALL, CREATE2, REVERT, RETURN, INVALID, SELFDESTRUCT
- And more...

### RISC-V (Base)
- LUI, AUIPC, JAL, JALR
- Load: LB, LH, LW, LBU, LHU
- Store: SB, SH, SW
- Branch: BEQ, BNE, BLT, BGE, BLTU, BGEU
- Arithmetic: ADD, SUB, SLT, SLTU, XOR, OR, AND, SLL, SRL, SRA
- Immediate: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI

## License

GNU General Public License v3 (GPL-3.0) - See LICENSE file
