# Example Bytecode Files

This directory contains example bytecode files for testing the decompiler.

## Usage

```bash
# Run with a file
./zig-out/bin/decompile_contracts $(cat examples/simple_add.bin) --full
```

## Files

- `simple_add.bin` - Simple addition contract
- `erc20.bin` - Minimal ERC-20 token
- `storage.bin` - Contract with storage operations
