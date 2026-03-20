# Decompile Contracts - Roadmap

## Project Overview

**Current State:** Production-ready EVM/Bend-PVM decompiler in Zig 0.15.2

**Current Features:**
- ✅ EVM disassembly (142 opcodes)
- ✅ Function selector extraction (keccak256)
- ✅ Type inference
- ✅ Control flow analysis
- ✅ Symbolic execution
- ✅ Solidity-like output
- ✅ Bend-PVM/RISC-V support
- ✅ JSON output
- ✅ CI/CD

---

## Phase 1: Core Enhancements (High Impact)

### 1.1 Constructor Analysis
- **Priority:** High
- Parse constructor bytecode
- Extract immutable/constant variables
- Analyze deployment calldata

### 1.2 Library Detection
- **Priority:** High
- Identify delegatecall patterns
- Detect known library patterns
- Label external library calls

### 1.3 Compiler Version Detection
- **Priority:** Medium
- Detect Solidity compiler version from bytecode
- Identify optimization patterns
- Match compiler metadata

### 1.4 Event/Log Parsing
- **Priority:** Medium
- Decode event signatures
- Parse anonymous events
- Build event hierarchy

---

## Phase 2: Advanced Analysis

### 2.1 Improved Type Inference
- **Priority:** High
- Better slot packing detection
- Array/mapping recognition
- Struct layout inference

### 2.2 Control Flow Improvements
- **Priority:** Medium
- Loop detection
- Reentrancy guard identification
- Access control pattern recognition

### 2.3 Gas Analysis
- **Priority:** Low
- Estimate gas costs
- Identify gas-heavy operations
- Optimization suggestions

### 2.4 Decompilation Quality
- **Priority:** High
- Better variable naming
- Improved code structure
- Inline assembly handling

---

## Phase 3: Ecosystem Expansion

### 3.1 Additional VM Support
- **Priority:** Medium
- **Solana SVM:** eBPF bytecode support
- **Cosmos/WASM:** CosmWasm contracts
- **Polygon/zkEVM:** Specific opcodes

### 3.2 Format Support
- **Priority:** Medium
- Input: Etherscan verification JSON
- Input: Hardhat/truffle artifacts
- Output: Vyper decompilation hints

### 3.3 Integration
- **Priority:** Medium
- GitHub Action for contract verification
- VS Code extension
- Web interface (WASM compilation)

---

## Phase 4: Polish & Community

### 4.1 Documentation
- Architecture deep-dive
- Contribution guidelines
- API documentation

### 4.2 Testing
- Fuzzing for edge cases
- Golden output tests
- Performance benchmarks

### 4.3 Performance
- Multi-threaded analysis
- Incremental analysis
- Cache results

---

## Priority Matrix

| Feature | Impact | Effort | Priority |
|---------|--------|--------|----------|
| Constructor analysis | High | Medium | P0 |
| Library detection | High | Low | P0 |
| Type inference v2 | High | High | P1 |
| Compiler version | Medium | Low | P1 |
| Event parsing | Medium | Medium | P1 |
| VS Code extension | Medium | Medium | P2 |
| Solana SVM support | Medium | High | P2 |
| WASM web interface | Medium | High | P2 |
| Gas analysis | Low | Medium | P3 |

---

## Technical Debt

### Known Gaps
- [ ] No proxy pattern detection
- [ ] No reentrancy guard identification  
- [ ] Limited inline assembly handling
- [ ] No NatSpec parsing
- [ ] Storage layout for complex types incomplete

### Performance
- [ ] No parallel analysis
- [ ] Memory allocation could be optimized
- [ ] No caching mechanism

---

## Contributing

See CONTRIBUTING.md for guidelines.

---

*Last Updated: 2024*
*Version: 0.1.0*
