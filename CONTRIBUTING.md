# Contributing to Decompile Contracts

Thank you for your interest in contributing!

## Getting Started

### Prerequisites

- Zig 0.15.2 or later
- Git

### Development Setup

```bash
# Clone the repository
git clone https://github.com/codingsh/decompile-contracts
cd decompile-contracts

# Build the project
zig build

# Run tests
zig build test

# Run the CLI
./zig-out/bin/decompile_contracts 0x608060405234801560011f5ffd5b505f80fd --full
```

## Project Structure

```
src/
├── main.zig              # CLI entry point
├── root.zig              # Library exports
├── evm/                  # EVM bytecode analysis
│   ├── opcodes.zig      # Opcode definitions
│   ├── disassembler.zig # Disassembly
│   └── abi.zig         # Function selectors
├── bend/                 # Bend-PVM/RISC-V support
│   ├── opcodes.zig      # RISC-V opcodes
│   └── source.zig      # Source generation
├── symbolic/             # Symbolic execution
│   └── executor.zig
└── analysis/            # Code analysis
    ├── storage.zig
    ├── controlflow.zig
    ├── source.zig
    └── types.zig
```

## Coding Standards

This project follows Zig best practices. See `.opencode/skills/zig-best-practices.md` for detailed guidelines.

### Key Points

- Use `snake_case` for functions and variables
- Use `PascalCase` for types
- Use `try`/`catch` for error handling
- Use `errdefer` for cleanup
- Add `@inline` to hot path functions
- Pre-allocate collections when possible

### Before Submitting

1. Run `zig build test` - all tests must pass
2. Run `zig build` - no warnings or errors
3. Check for memory leaks with debug build
4. Add tests for new functionality

## Common Tasks

### Adding New Opcodes

1. Add to `src/evm/opcodes.zig` enum
2. Add gas cost in `getGasCost()`
3. Add stack delta in `getStackDelta()`
4. Add name in `getName()`

### Adding New Analysis

1. Create module in `src/analysis/`
2. Export from `src/root.zig`
3. Add CLI flag in `src/main.zig`
4. Add tests

### Adding Examples

1. Add bytecode to `examples/*.bin`
2. Test with `./zig-out/bin/decompile_contracts`
3. Update `examples/README.md`

## Commit Messages

Follow conventional commits:

```
feat: add new analysis module
fix: resolve memory leak in parser
perf: optimize bytecode parsing
docs: update README
test: add tests for storage analysis
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and build
5. Submit a PR with description

## Questions?

Open an issue for:
- Bug reports
- Feature requests
- Questions about the codebase
