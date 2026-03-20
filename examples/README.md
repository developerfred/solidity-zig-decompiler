# Example Bytecode Files

This directory contains example bytecode files for testing the decompiler.

## Quick Start

```bash
# Build the project first
zig build

# Run all examples
chmod +x run_all.sh
./run_all.sh

# Or run individual examples
./zig-out/bin/decompile_contracts $(cat simple_add.bin) --full
./zig-out/bin/decompile_contracts $(cat storage.bin) --full
./zig-out/bin/decompile_contracts $(cat erc20.bin) --full
./zig-out/bin/decompile_contracts $(cat addition.bin) --full
```

## Files

| File | Description | Type |
|------|-------------|------|
| `simple_add.bin` | Simple addition contract | EVM |
| `addition.bin` | More complex arithmetic | EVM |
| `storage.bin` | Contract with storage ops | EVM |
| `erc20.bin` | Minimal ERC-20 token | EVM |
| `run_all.sh` | Run all examples | Script |

## Adding New Examples

1. Add bytecode hex to a `.bin` file
2. Test with: `./zig-out/bin/decompile_contracts $(cat yourfile.bin) --full`
3. Update this README with description
