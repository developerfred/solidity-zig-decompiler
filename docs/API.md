# API Documentation

Complete API reference for the Solidity Zig Decompiler library.

## Table of Contents

1. [EVM Module](#evm-module)
2. [Decompiler Module](#decompiler-module)
3. [Analysis Module](#analysis-module)
4. [Vulnerability Module](#vulnerability-module)
5. [Deployment Module](#deployment-module)
6. [Protocol Detection](#protocol-detection)
7. [Formal Verification](#formal-verification)
8. [Multi-Chain Support](#multi-chain-support)
9. [Output Modules](#output-modules)
10. [Vyper Support](#vyper-support)

---

## EVM Module

### Parser

```zig
const parser = @import("evm/parser.zig");
```

#### Types

```zig
pub const OpCode = enum(u8) {
    STOP = 0x00,
    ADD = 0x01,
    // ... all EVM opcodes
    PUSH0 = 0x5f,
    INVALID = 0xfe,
};

pub const Instruction = struct {
    pc: usize,                    // Program counter
    opcode: OpCode,               // Opcode enum
    name: []const u8,            // Opcode name
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

---

##### `deinit`

```zig
pub fn deinit(parsed: *ParsedBytecode) void
```

Free parsed bytecode memory.

---

### Signatures

```zig
const signatures = @import("evm/signatures.zig");
```

#### Types

```zig
pub const ResolvedSignature = struct {
    selector: [4]u8,           // 4-byte function selector
    signature: []const u8,    // Function signature string
    confidence: f32,          // Confidence score (0.0-1.0)
    source: SignatureSource,  // Source of signature
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
    
    pub fn init(allocator: std.mem.Allocator) SignatureCache
    pub fn deinit(self: *SignatureCache) void
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

---

##### `hexToSelector`

```zig
pub fn hexToSelector(hex: []const u8) ?[4]u8
```

Convert hex string to 4-byte selector.

**Parameters:**
- `hex`: Hex string (e.g., "0xa9059cbb")

**Returns:** 4-byte selector or null if invalid

---

##### `selectorToSlice`

```zig
pub fn selectorToSlice(sel: [4]u8) []const u8
```

Convert selector to hex string slice.

---

### Strings

```zig
const strings = @import("evm/strings.zig");
```

#### Types

```zig
pub const EmbeddedString = struct {
    offset: usize,
    value: []const u8,
};

pub const ExtractedStrings = struct {
    strings: []EmbeddedString,
    allocator: std.mem.Allocator,
};
```

#### Functions

##### `extract`

```zig
pub fn extract(allocator: std.mem.Allocator, bytecode: []const u8) !ExtractedStrings
```

Extract printable strings from bytecode.

**Parameters:**
- `allocator`: Memory allocator
- `bytecode`: Raw bytecode

**Returns:** `ExtractedStrings` with all found strings

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

### Dispatcher

```zig
const dispatcher = @import("evm/dispatcher.zig");
```

#### Types

```zig
pub const SelectorInfo = struct {
    selector: [4]u8,
    offset: usize,
};

pub const DispatcherResult = struct {
    selectors: []SelectorInfo,
    allocator: std.mem.Allocator,
};
```

#### Functions

##### `analyzeDispatchers`

```zig
pub fn analyzeDispatchers(allocator: std.mem.Allocator, bytecode: []const u8) !DispatcherResult
```

Extract function selectors from bytecode.

---

## Decompiler Module

```zig
const decompiler = @import("decompiler/main.zig");
```

### Types

```zig
pub const DecompiledFunction = struct {
    name: []const u8,
    selector: [4]u8,
    signature: ?[]const u8,
};

pub const DecompiledContract = struct {
    name: []const u8,
    functions: []DecompiledFunction,
    embedded_strings: []evm_strings.EmbeddedString,
    is_proxy: bool,
    is_erc20: bool,
    is_erc721: bool,
    is_vyper: bool,
    vyper_version: ?vyper.VyperVersion,
    allocator: std.mem.Allocator,
};

pub const StorageVariable = struct {
    slot: usize,
    var_type: []const u8,
    name: []const u8,
};

pub const Config = struct {
    resolve_signatures: bool = true,
    build_cfg: bool = true,
    extract_strings: bool = true,
    detect_patterns: bool = true,
    verbose: bool = false,
};
```

### Functions

##### `decompile`

```zig
pub fn decompile(allocator: std.mem.Allocator, bytecode: []const u8, config: Config) !DecompiledContract
```

Decompile contract bytecode to structured representation.

**Parameters:**
- `allocator`: Memory allocator
- `bytecode`: Raw EVM bytecode
- `config`: Decompiler configuration

**Returns:** `DecompiledContract` with all extracted information

---

##### `generateSolidity`

```zig
pub fn generateSolidity(contract: *const DecompiledContract, writer: anytype) !void
```

Generate pseudo-Solidity code from decompiled contract.

**Parameters:**
- `contract`: Decompiled contract
- `writer`: Output writer

---

## Analysis Module

### Gas Analysis

```zig
const gas = @import("analysis/gas.zig");
```

#### Types

```zig
pub const GasCosts = struct {
    // Base costs
    base: u64 = 2,
    jumpdest: u64 = 1,
    // ... all opcode costs
};

pub const GasAnalysis = struct {
    total_gas: u64,
    breakdown: []GasItem,
    memory_expansion: u64,
    storage_ops: usize,
};

pub const GasItem = struct {
    opcode: []const u8,
    count: usize,
    gas: u64,
};
```

#### Functions

##### `analyze`

```zig
pub fn analyze(allocator: std.mem.Allocator, bytecode: []const u8) !GasAnalysis
```

Analyze bytecode and estimate gas costs.

---

## Vulnerability Module

```zig
const scanner = @import("vulnerability/scanner.zig");
```

### Types

```zig
pub const Vulnerability = struct {
    cwe_id: []const u8,
    title: []const u8,
    severity: Severity,
    location: usize,
    description: []const u8,
    confidence: f32,
};

pub const Severity = enum {
    Info,
    Low,
    Medium,
    High,
    Critical,
};

pub const ScanResult = struct {
    vulnerabilities: []Vulnerability,
    obfuscation_detected: bool,
    mev_opportunities: []MEVOpportunity,
    allocator: std.mem.Allocator,
};

pub const MEVOpportunity = struct {
    op_type: MEVType,
    description: []const u8,
    severity: Severity,
};

pub const MEVType = enum {
    arbitrage,
    sandwich,
    liquidation,
    front_running,
};
```

### Functions

##### `scan`

```zig
pub fn scan(allocator: std.mem.Allocator, bytecode: []const u8) !ScanResult
```

Scan bytecode for vulnerabilities and security issues.

---

### Obfuscation Detection

```zig
const obfuscation = @import("vulnerability/obfuscation.zig");
```

#### Types

```zig
pub const ObfuscationType = enum {
    push0_injection,
    dead_code,
    abnormal_density,
    unusual_jumps,
};

pub const ObfuscationResult = struct {
    detected: bool,
    types: []ObfuscationType,
    confidence: f32,
};
```

---

## Deployment Module

```zig
const deployment = @import("deployment/detector.zig");
```

### Types

```zig
pub const DeploymentType = enum {
    regular,
    factory,
    proxy,
    minimal_proxy,
    transparent_proxy,
    uups_proxy,
    beacon_proxy,
    clone,
    diamond,
};

pub const DeploymentInfo = struct {
    deployment_type: DeploymentType,
    is_factory: bool,
    is_upgradeable: bool,
    uses_create2: bool,
    uses_create: bool,
    child_contract_count: usize,
    implementation_slot: ?u64,
    beacon_address: ?[]const u8,
    detected_patterns: []const []const u8,
    allocator: std.mem.Allocator,
};
```

### Functions

##### `detect`

```zig
pub fn detect(allocator: std.mem.Allocator, bytecode: []const u8) !DeploymentInfo
```

Detect contract deployment patterns in bytecode.

**Returns:** `DeploymentInfo` with deployment type and patterns

---

##### `estimateDeploymentGas`

```zig
pub fn estimateDeploymentGas(bytecode: []const u8) u64
```

Estimate deployment gas cost.

---

## Protocol Detection

### Registry

```zig
const protocols = @import("protocols/registry.zig");
```

#### Types

```zig
pub const ProtocolType = enum {
    unknown,
    erc20,
    erc721,
    erc1155,
    proxy,
    diamond,
    lifi,
    aave,
    uniswap,
    curve,
    compound,
    yearn,
    gnosis_safe,
    makerdao,
};

pub const DetectedProtocol = struct {
    protocol_type: ProtocolType,
    name: []const u8,
    version: ?[]const u8,
    confidence: f32,
};
```

#### Functions

##### `detectProtocol`

```zig
pub fn detectProtocol(allocator: std.mem.Allocator, bytecode: []const u8, address: ?[]const u8) ![]DetectedProtocol
```

Detect protocols from bytecode and optional address.

---

### Li.FI Protocol

```zig
const lifi = @import("protocols/lifi.zig");
```

#### Types

```zig
pub const LiFiContract = struct {
    is_lifi: bool,
    version: ?LiFiVersion,
    is_diamond: bool,
    facets_detected: []LiFiFacet,
    detected_bridges: [][]const u8,
    detected_dexs: [][]const u8,
    allocator: std.mem.Allocator,
};

pub const LiFiFacet = struct {
    name: []const u8,
    address: [20]u8,
    function_count: usize,
};
```

#### Functions

##### `detectInBytecode`

```zig
pub fn detectInBytecode(bytecode: []const u8) bool
```

Detect Li.FI patterns in bytecode.

---

##### `isKnownLiFiDiamond`

```zig
pub fn isKnownLiFiDiamond(address: []const u8) bool
```

Check if address is known Li.FI Diamond contract.

---

## Formal Verification

```zig
const formal = @import("formal/verifier.zig");
```

### Functions

##### `generateCertoraSpec`

```zig
pub fn generateCertoraSpec(allocator: std.mem.Allocator, contract: *const decompiler.DecompiledContract) ![]const u8
```

Generate Certora specification file for formal verification.

---

##### `generateCertoraConfig`

```zig
pub fn generateCertoraConfig(allocator: std.mem.Allocator, contract: *const decompiler.DecompiledContract, spec_path: []const u8) ![]const u8
```

Generate Certora configuration file.

---

##### `generateSmokeTests`

```zig
pub fn generateSmokeTests(allocator: std.mem.Allocator, contract: *const decompiler.DecompiledContract) ![]const u8
```

Generate smoke test rules for basic contract behavior.

---

## Multi-Chain Support

```zig
const chains = @import("multichain/chains.zig");
```

### Types

```zig
pub const ChainConfig = struct {
    name: []const u8,
    chain_id: u64,
    rpc_urls: [][]const u8,
    explorer_urls: [][]const u8,
    native_currency: NativeCurrency,
};

pub const NativeCurrency = struct {
    name: []const u8,
    symbol: []const u8,
    decimals: u8,
};
```

### Supported Chains

| Chain | Chain ID | Module |
|-------|----------|--------|
| Ethereum | 1 | ethereum |
| Polygon | 137 | polygon |
| BSC | 56 | bsc |
| Avalanche | 43114 | avalanche |
| Arbitrum | 42161 | arbitrum |
| Optimism | 10 | optimism |
| Base | 8453 | base |
| zkSync Era | 324 | zksync |
| Gnosis | 100 | gnosis |

---

## Output Modules

### JSON Output

```zig
const json_output = @import("output/json.zig");
```

```zig
pub fn generateJSON(contract: *const decompiler.DecompiledContract, writer: anytype) !void
```

Generate JSON output from decompiled contract.

---

### HTML Output

```zig
const html_output = @import("output/html.zig");
```

```zig
pub fn generateHTML(contract: *const decompiler.DecompiledContract, writer: anytype) !void
```

Generate HTML report with syntax highlighting.

---

### Diff Output

```zig
const diff_output = @import("output/diff.zig");
```

```zig
pub fn generateDiff(original: []const u8, decompiled: []const u8, writer: anytype) !void
```

Generate diff between original and decompiled code.

---

## Vyper Support

```zig
const vyper = @import("vyper/mod.zig");
```

### Types

```zig
pub const VyperVersion = struct {
    major: u8,
    minor: u8,
    patch: u8,
};

pub const VyperContract = struct {
    is_vyper: bool,
    version: ?VyperVersion,
    name: []const u8,
    functions: []VyperFunction,
};

pub const Language = enum {
    solidity,
    vyper,
    unknown,
};
```

### Functions

##### `detectLanguage`

```zig
pub fn detectLanguage(bytecode: []const u8, embedded_strings: []const struct { offset: usize, value: []const u8 }) Language
```

Detect if bytecode was compiled from Vyper vs Solidity.

---

##### `detectVersion`

```zig
pub fn detectVersion(embedded_strings: []const struct { offset: usize, value: []const u8 }) ?VyperVersion
```

Extract Vyper version from embedded strings.

---

##### `resolveVyperSignature`

```zig
pub fn resolveVyperSignature(selector: [4]u8) ?[]const u8
```

Resolve Vyper-specific function signatures.

---

## Contract Verification

```zig
const verifier = @import("verification/contract_verifier.zig");
```

### Types

```zig
pub const VerificationStatus = enum(u8) {
    verified,
    mismatch,
    partial_match,
    not_found,
    error,
};

pub const ContractVerification = struct {
    contract_address: []const u8,
    status: VerificationStatus,
    chain: []const u8,
    functions: []FunctionVerification,
    verified_at: i64,
    source_match_score: f32,
};

pub const FunctionVerification = struct {
    function_name: []const u8,
    selector: []const u8,
    status: VerificationStatus,
    differences: ?[]const u8,
};
```

---

## Example Usage

### Full Decompilation Pipeline

```zig
const std = @import("std");
const parser = @import("evm/parser.zig");
const signatures = @import("evm/signatures.zig");
const scanner = @import("vulnerability/scanner.zig");
const decompiler = @import("decompiler/main.zig");
const deployment = @import("deployment/detector.zig");
const protocols = @import("protocols/registry.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Example bytecode
    const bytecode = try parseHex("608060405234801561000f575f80fd5b5061012a8061001f5f395ff3335");
    
    // 1. Parse bytecode
    const parsed = try parser.parse(allocator, bytecode);
    defer parser.deinit(&parsed);
    
    // 2. Resolve function selectors
    var cache = signatures.SignatureCache.init(allocator);
    defer cache.deinit();
    
    // 3. Scan for vulnerabilities
    const vulns = try scanner.scan(allocator, bytecode);
    
    // 4. Detect deployment patterns
    const deploy_info = try deployment.detect(allocator, bytecode);
    
    // 5. Detect protocols
    const detected = try protocols.detectProtocol(allocator, bytecode, null);
    
    // 6. Decompile
    const contract = try decompiler.decompile(allocator, bytecode, .{});
    
    std.debug.print("Contract: {s}\n", .{contract.name});
    std.debug.print("Functions: {d}\n", .{contract.functions.len});
    std.debug.print("Vulnerabilities: {d}\n", .{vulns.vulnerabilities.len});
    std.debug.print("Deployment: {s}\n", .{@tagName(deploy_info.deployment_type)});
}
```

---

## Error Handling

All functions return `!error` for failure cases:

```zig
// Common errors
try parser.parse(allocator, bytecode);     // OutOfMemory, InvalidBytecode
try signatures.resolve(selector, &cache);  // InvalidSelector
try decompiler.decompile(allocator, code);  // InvalidBytecode, ParseError
try scanner.scan(allocator, bytecode);      // OutOfMemory
```

Always handle errors appropriately in production code.

---

## Performance Notes

- **Parser**: O(n) where n is bytecode length
- **Signature Resolution**: O(1) with cache, O(n) without
- **Vulnerability Scan**: O(n) with configurable depth
- **Gas Analysis**: O(n) with memory tracking
- **Deployment Detection**: O(n) for pattern matching

---

## Thread Safety

The library is not thread-safe by default. For concurrent analysis:

1. Create separate allocator instances per thread
2. Use thread-local signature caches
3. Parse bytecode independently per analysis

---

## Memory Management

All functions that allocate memory require an allocator:

```zig
const allocator = std.heap.page_allocator;
// or
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();
const allocator = arena.allocator();
```

Always free or deinit results when no longer needed.
