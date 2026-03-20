# Skill: Zig Best Practices

## Descrição
Desenvolvedor especializado em escrever código Zig idiomático, limpo e de alta performance seguindo as melhores práticas da linguagem Zig 0.15+.

## Quando Usar
- Revisar código Zig para qualidade
- Auditear projetos Zig
- Refatorar código Zig para melhores práticas
- Ensinar/write Zig code conventions

## Regras Fundamentais

### 1. Error Handling

**✅ DO:**
```zig
// Usar try para propagar erros
fn parseHex(hex: []const u8) ![]u8 {
    const data = try allocator.alloc(u8, len);
    errdefer allocator.free(data);  // Cleanup!
    // ...
    return data;
}

// Usar error unions explicitamente
pub fn parse(data: []const u8) !ParsedResult {
    // ...
}

// Captura específica de erros
fn read() !void {
    something() catch |err| switch (err) {
        error.OutOfMemory => return error.CustomError,
        else => {},
    };
}
```

**❌ DON'T:**
```zig
// Não usar empty catch
data.put(key, value) catch {};  // ERRADO!

// Usar _ = para discard explícito (se intencional)
_ = data.put(key, value);  // CORRETO - explícito
```

### 2. Memory Management

**✅ DO:**
```zig
// Usar ArrayListUnmanaged para performance
var list: std.ArrayListUnmanaged(T) = .{};
errdefer list.deinit(allocator);

// Pre-alocar quando possível
try list.ensureTotalCapacity(allocator, estimated_count);

// Usar errdefer para cleanup
fn process() !void {
    var resource = try openResource();
    errdefer resource.close();
    // ...
}
```

**❌ DON'T:**
```zig
// Não usar defer em loops (pode ser caro)
for (items) |item| {
    defer item.cleanup();  // Desnecessário em muitos casos
}

// Não alocar desnecessariamente
var buffer = std.ArrayList(u8).init(allocator);  // Preferir Unmanaged
```

### 3. Naming Conventions

**✅ DO:**
```zig
// snake_case para funções e variáveis
fn parse_instructions() void {}
const max_stack_depth: usize = 0;

// PascalCase para tipos
const Instruction = struct { ... };
const OpcodeCategory = enum { ... };

// CamelCase para campos de enum
const Opcode = enum {
    stop,
    add,
    mul,
    // ...
};
```

**❌ DON'T:**
```zig
// Não usar Hungarian notation
var i32Count: i32 = 0;  // ERRADO!
const MAX_COUNT: i32 = 0;  // ERRADO! Constantes não são SCREAMING_SNAKE
```

### 4. Performance

**✅ DO:**
```zig
// Inline para hot paths
pub inline fn getName(opcode: Opcode) []const u8 {
    return switch (opcode) { ... };
}

// Usar bufPrint em vez de allocPrint quando possível
var buf: [256]u8 = undefined;
const result = std.fmt.bufPrint(&buf, "{}", .{value}) catch "";

// Usar inline em funções pequenas chamadas frequentemente
pub inline fn isPush(opcode: Opcode) bool {
    return @intFromEnum(opcode) >= 0x60;
}
```

**❌ DON'T:**
```zig
// Não usar @inline(.always) - deixe o compilador decidir
pub inline fn small() void {}  // OK - hint

// Evitar allocações em loops
for (items) |item| {
    const str = try std.fmt.allocPrint(allocator, "{}", .{item}); // ERRADO!
    // ...
}
```

### 5. Funções e organization

**✅ DO:**
```zig
// Funções small e focadas
pub fn getName(opcode: Opcode) []const u8 { ... }

// Documentar funções públicas
/// Parse bytecode into instructions
/// Returns slice of Instruction structs
pub fn parseInstructions(allocator: std.mem.Allocator, bytecode: []const u8) ![]Instruction {}

// Usar const para funções sem side effects
pub const Disassembler = struct {
    pub fn init(allocator: std.mem.Allocator) Disassembler {
        return .{ .allocator = allocator };
    }
};
```

**❌ DON'T:**
```zig
// Não criar funções muito grandes - quebre em partes
fn giant_function() !void {  // ERRADO se muito grande
    // 500 linhas...
}
```

### 6. Testing

**✅ DO:**
```zig
test "parseInstructions basic" {
    const bytecode = [_]u8{ 0x60, 0x05, 0x01 };
    const result = try parse(bytecode);
    try std.testing.expect(result.len > 0);
}

test "disassembler outputs valid assembly" {
    const dis = Disassembler.init(std.testing.allocator);
    const result = try dis.disassemble(&bytecode);
    defer std.testing.allocator.free(result);
    try std.testing.expect(result.len > 0);
}
```

### 7. Anti-patterns to Avoid

```zig
// ❌ EVITAR: @as(any) casts
const bad = @as(any, value);  // NUNCA!

// ❌ EVITAR: suppress errors desnecessários
_ = try maybeFails();  // ERRADO! Use try ou catch

// ❌ EVITAR: sentinel values em vez de optionals
var count: i32 = -1; // ERRADO! Use ?i32

// ❌ EVITAR: global state
var global_state: u32 = 0;  // Evitar!

// ❌ EVITAR: silent failures
function() catch {  // ERRADO! Handle properly
    // silent...
};
```

### 8. Code Organization

```zig
// Estrutura recomendada:
// 1. Imports
const std = @import("std");
const opcodes = @import("opcodes.zig");

// 2. Constants (opcional)
const MAX_DEPTH = 1024;

// 3. Types
pub const Instruction = struct { ... };
pub const Config = struct { ... };

// 4. Functions
pub fn init() void { ... }
pub fn parse() !void { ... }

// 5. Tests
test "basic" { ... }
```

## Checklist de Auditoria

Ao auditar código Zig, verifique:

- [ ] Error handling correto (try/catch, errdefer)
- [ ] Sem empty catch blocks (usar `_ =` se intencional)
- [ ] Nomes seguindoconventions (snake_case, PascalCase)
- [ ] Funções hot path com `inline`
- [ ] Pre-alocação quando possível
- [ ] Sem casts perigosos (@as any, @intCast sem bounds)
- [ ] Tests presentes e passando
- [ ] Documentação de APIs públicas
- [ ] Sem memory leaks (verificar defers)
- [ ] Optionals em vez de sentinel values

## Referências
- Zig Language Reference
- Zig Standard Library Documentation
- Zig News, Learn Zig in 2024
