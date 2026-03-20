#!/bin/bash
# Run all examples through the decompiler

DECOMPILER="./zig-out/bin/decompile_contracts"

echo "======================================"
echo "  Decompile Contracts - Examples"
echo "======================================"
echo ""

for example in *.bin; do
    if [ -f "$example" ]; then
        echo "--- $example ---"
        BYTECODE=$(cat "$example")
        $DECOMPILER "$BYTECODE" --full 2>/dev/null | head -40
        echo ""
        echo "======================================"
    fi
done
