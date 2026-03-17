# API Documentation

## EVM Module

### Parser

```zig
const parser = @import("evm/parser.zig");
```

#### Types

```zig
pub const Instruction = struct {
    pc: usize,           // Program counter
    opcode: OpCode,      // Opcode enum
    name: []const u8,   // Opcode name
    push_data: ?[]const u8 = null, // Data for PUSH instructions
};

pub const ParsedBytecode = struct {
    instructions: []Instruction,
    allocator: std.mem.Allocator,
};
```

#### Functions

##### `parse`

```zig
pub fn parse(allocator: std.mem.Allocator, bytecode: []const u8) !ParsedBytecode
```

Parse raw EVM bytecode into structured instructions.

**Parameters:**
- `allocator`: Memory allocator
- `bytecode`: Raw bytecode as bytes

**Returns:** `ParsedBytecode` with all instructions

##### `deinit`

```zig
pub fn deinit(parsed: *ParsedBytecode) void
```

Free parsed bytecode memory.

##### `getInstruction`

```zig
pub fn getInstruction(parsed: *const ParsedBytecode, pc: usize) ?Instruction
```

Get instruction at specific program counter.

---

### Signatures

```zig
const signatures = @import("evm/signatures.zig");
```

#### Types

```zig
pub const ResolvedSignature = struct {
    selector: [4]u8,           // 4-byte function selector
    signature: []const u8,     // Function signature string
    confidence: f32,           // Confidence score (0.0-1.0)
    source: SignatureSource,   // Source of signature
};

pub const SignatureSource = enum { 
    builtin,   // Built-in signature
    api,       // Fetched from API
    inferred,  // Inferred from context
    unknown    // Unknown selector
};

pub const SignatureCache = struct {
    entries: std.StringHashMap(ResolvedSignature),
    allocator: std.mem.Allocator,
};
```

#### Functions

##### `resolve`

```zig
pub fn resolve(selector: [4]u8, cache: *SignatureCache) !ResolvedSignature
```

Resolve a function selector to its signature.

**Parameters:**
- `selector`: 4-byte function selector
- `cache`: Signature cache for memoization

**Returns:** `ResolvedSignature` with signature details

##### `hexToSelector`

```zig
pub fn hexToSelector(hex: []const u8) ?[4]u8
```

Convert hex string to 4-byte selector.

**Parameters:**
- `hex`: Hex string (e.g., "0xa9059cbb")

**Returns:** 4-byte selector or null if invalid

##### `selectorToSlice`

```zig
pub fn selectorToSlice(sel: [4]u8) []const u8
```

Convert selector to hex string slice.

---

### Opcodes

```zig
const opcodes = @import("evm/opcodes.zig");
```

#### Types

```zig
pub const OpCode = enum(u8) {
    STOP = 0x00,
    ADD = 0x01,
    MUL = 0x02,
    // ... all EVM opcodes
    INVALID = 0xfe,
    PUSH0 = 0x5f,
};
```

#### Functions

##### `getName`

```zig
pub fn getName(opcode: OpCode) []const u8
```

Get opcode name as string.

##### `getGas`

```zig
pub fn getGas(opcode: OpCode, stack_len: usize) u64
```

Calculate gas cost for opcode.

---

### Strings

```zig
const strings = @import("evm/strings.zig");
```

#### Functions

##### `extractStrings`

```zig
pub fn extractStrings(allocator: std.mem.Allocator, bytecode: []const u8, min_len: usize) ![][]const u8
```

Extract printable strings from bytecode.

---

### Control Flow Graph

```zig
const cfg = @import("evm/cfg.zig");
```

#### Types

```zig
pub const BasicBlock = struct {
    start_pc: usize,
    end_pc: usize,
    instructions: []Instruction,
    successors: []usize,
};

pub const CFG = struct {
    blocks: []BasicBlock,
    allocator: std.mem.Allocator,
};
```

#### Functions

##### `build`

```zig
pub fn build(allocator: std.mem.Allocator, parsed: *const ParsedBytecode) !CFG
```

Build control flow graph from parsed bytecode.

---

## Analysis Module

### Gas Analysis

```zig
const gas = @import("analysis/gas.zig");
```

#### Types

```zig
pub const GasAnalysis = struct {
    total_gas: u64,
    breakdown: std.StringHashMap(u64),
};
```

#### Functions

##### `analyze`

```zig
pub fn analyze(parsed: *const ParsedBytecode) !GasAnalysis
```

Analyze bytecode and estimate gas costs.

---

## Symbolic Module

### Executor

```zig
const executor = @import("symbolic/executor.zig");
```

#### Types

```zig
pub const SymbolicValue = struct {
    concrete: ?u256,
    symbolic: ?[]const u8,
};

pub const ExecutionState = struct {
    stack: []SymbolicValue,
    memory: []u8,
    storage: std.AutoHashMap(u256, SymbolicValue),
};
```

#### Functions

##### `execute`

```zig
pub fn execute(allocator: std.mem.Allocator, parsed: *const ParsedBytecode, max_steps: usize) !ExecutionState
```

Execute bytecode symbolically.

---

## Vulnerability Module

### Scanner

```zig
const scanner = @import("vulnerability/scanner.zig");
```

#### Types

```zig
pub const Vulnerability = struct {
    cwe_id: []const u8,
    title: []const u8,
    severity: Severity,
    location: usize,
    description: []const u8,
};

pub const Severity = enum {
    Info,
    Low,
    Medium,
    High,
    Critical,
};
```

#### Functions

##### `scan`

```zig
pub fn scan(parsed: *const ParsedBytecode, cfg: *const CFG) ![]Vulnerability
```

Scan bytecode for vulnerabilities.

---

## Decompiler Module

### Main

```zig
const decompiler = @import("decompiler/main.zig");
```

#### Types

```zig
pub const DecompiledContract = struct {
    functions: []DecompiledFunction,
    storage_vars: []StorageVariable,
    events: []Event,
};

pub const DecompiledFunction = struct {
    selector: [4]u8,
    name: []const u8,
    params: []const Param,
    body: []const IR,
};
```

#### Functions

##### `decompile`

```zig
pub fn decompile(allocator: std.mem.Allocator, bytecode: []const u8) !DecompiledContract
```

Decompile contract bytecode to pseudo-Solidity.

---

## Example Usage

### Full Decompilation

```zig
const std = @import("std");
const parser = @import("evm/parser.zig");
const signatures = @import("evm/signatures.zig");
const scanner = @import("vulnerability/scanner.zig");
const decompiler = @import("decompiler/main.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Example bytecode
    const bytecode = "0x6080604052348015610010575f80fd5b5061012a8061001f5f395ff3335";
    
    // 1. Parse bytecode
    const parsed = try parser.parse(allocator, bytecode);
    defer parser.deinit(&parsed);
    
    // 2. Extract function selectors
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();
    
    for (parsed.instructions) |instr| {
        if (std.mem.eql(u8, instr.name, "PUSH4")) {
            const sig = try signatures.resolve(instr.push_data.?, &cache);
            std.debug.print("Found: {s}\n", .{sig.signature});
        }
    }
    
    // 3. Scan for vulnerabilities
    const vulns = try scanner.scan(&parsed, null);
    for (vulns) |v| {
        std.debug.print("Vulnerability: {s} ({s})\n", .{v.title, v.cwe_id});
    }
    
    // 4. Decompile to pseudo-Solidity
    const contract = try decompiler.decompile(allocator, bytecode);
    std.debug.print("Decompiled: {d} functions\n", .{contract.functions.len});
}
```

### Extract Embedded Strings

```zig
const strings = @import("evm/strings.zig");

pub fn extractStringsFromBytecode(bytecode: []const u8) !void {
    const allocator = std.heap.page_allocator;
    const extracted = try strings.extractStrings(allocator, bytecode, 4);
    defer {
        for (extracted) |s| allocator.free(s);
        allocator.free(extracted);
    }
    
    for (extracted) |s| {
        std.debug.print("Found string: \"{s}\"\n", .{s});
    }
}
```

---

## Error Handling

All functions return `!error` for failure cases:

```zig
// Common errors
try parser.parse(allocator, bytecode);     // OutOfMemory
try signatures.resolve(selector, &cache);  // InvalidSelector
try decompiler.decompile(allocator, code);  // InvalidBytecode
```

Always handle errors appropriately in production code.
