# Nucleor Language Reference (v1.1)

This document describes the Nucleor language implemented by the self-hosted
compiler (`bin/nucleor.exe`, version `1.1.0`). For a gentler introduction, see
[language-tour.md](language-tour.md).

## 1. Lexical Structure

### 1.1 Source Encoding

Source files are UTF-8. Line endings may be `\n` or `\r\n`. Bare carriage
returns are rejected with `LEX-CR-ONLY`. NUL bytes embedded in source are
rejected with `LEX-002`.

A UTF-8 byte-order mark at the start of a file is rejected with `LEX-001`.
Embedded BOMs, zero-width spaces, smart quotes, and right-to-left control bytes
inside source are also rejected with `LEX-001`.

String literals may not contain raw line breaks. Use `\n` or `\r\n` escapes, or
split and concatenate the string. Unterminated strings and strings ending with a
bare trailing backslash are hard lexer errors (`LEX-STRING-EOF`).

### 1.2 Comments

```nr
// line comment to end of line
```

Line comments are supported. Block comments (`/* ... */`) are rejected with a
frontend diagnostic.

### 1.3 Identifiers

```text
identifier ::= [A-Za-z_][A-Za-z0-9_]*
```

Identifiers are case-sensitive.

### 1.4 Literals

| Form | Type | Example |
|---|---|---|
| Decimal integer | `i64` | `42`, `-17` |
| Hexadecimal integer | `i64` | `0xFF` |
| Binary integer | `i64` | `0b1010` |
| Underscored integer | `i64` | `1_000_000` |
| Width-suffixed integer | suffix-selected | `100u8`, `42i32` |
| Float | `f64` | `1.5`, `-3.14` |
| Width-suffixed float | suffix-selected | `1.5f32`, `2.71828f64` |
| String | `str` | `"hello\n"` |
| Boolean | `bool` | `true`, `false` |

Width and signedness suffixes parse and type-check for `i8`, `i16`, `i32`,
`i64`, `u8`, `u16`, `u32`, `u64`, `usize`, `isize`, `f16`, `bf16`, `f32`, and
`f64`. Strict integer arithmetic is the default: `+`, `-`, and `*` panic on
overflow instead of wrapping silently. Use `wrapping { ... }`,
`saturating { ... }`, or `checked { ... }` blocks for explicit overflow
semantics.

Mixed-width integer arithmetic without an explicit `as` cast is rejected with
`NUM-001` during type-check.

String escapes recognized by the lexer: `\n`, `\r`, `\t`, `\\`, `\"`, `\'`,
and `\0`. Other escape sequences are hard errors (`NR025`).

Numeric-literal hygiene rules:

- `0x`, `0o`, and `0b` prefixes require at least one digit.
- Underscores must separate digits.
- Hex, octal, binary, and decimal literals must fit their target width.
- Leading-zero decimals such as `007` are rejected.
- Unknown alphabetic suffixes are rejected.
- Float literals that overflow finite IEEE-754 range are rejected.
- Leading-dot and trailing-dot floats are rejected; write `0.5` and `1.0`.

### 1.5 Keywords

`fn`, `let`, `mut`, `return`, `if`, `else`, `while`, `for`, `in`, `match`,
`loop`, `break`, `continue`, `struct`, `enum`, `trait`, `impl`, `where`, `as`,
`const`, `type`, `import`, `use`, `mod`, `extern`, `pub`, `pure`, `true`,
`false`.

`dyn` and `move` are contextual keywords. Reserved words used as binding names
are rejected at parse time.

### 1.6 Operators

| Category | Operators |
|---|---|
| Arithmetic | `+`, `-`, `*`, `/`, `%` |
| Comparison | `==`, `!=`, `<`, `<=`, `>`, `>=` |
| Logical | `&&`, `||`, `!` |
| Bitwise | `&`, `|`, `^`, `<<`, `>>` |
| Compound assignment | `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=` |
| Postfix increment | `++`, `--` |
| Range | `..`, `..=` |
| Assignment | `=` |
| Field access | `.` |
| Path | `::` |
| Closure pipe | `|` ... `|` |
| Result/Option propagation | `?` |

## 2. Types

| Type | Description |
|---|---|
| `i64` | 64-bit signed integer |
| `i32` | 32-bit signed integer |
| `f64` | 64-bit floating point |
| `bool` | Boolean |
| `str` | UTF-8 string |
| `Vec<T>` | Dynamic array of uniform 64-bit slots |
| `struct` | User-defined product type |
| `enum` | User-defined sum type |

Numeric primitives are not implicitly converted between widths. Use explicit
casts or runtime conversion helpers.

## 3. Functions and Closures

```nr
fn name(p1: T1, p2: T2) -> ReturnType {
    statements...
    return value;
}
```

- Every parameter requires a type annotation.
- Functions may omit `-> ReturnType`; the implicit return type is `()`.
- Function names are first-class values when evaluated outside a call.
- Prefix a function with `pub` to export it from `nuc build-shared`.

Closures are stored as function-pointer or closure-handle values:

```nr
let f: i64 = |x, y| x + y;
let g: i64 = |x| { if x < 0 { return 0 - x; }; return x; };
let z: i64 = || 42;
```

Apply closures with normal call syntax: `f(1, 2)`.

## 4. Structs

```nr
struct Point {
    x: i64,
    y: i64
}
```

- Construct with `Point { x: 3, y: 4 }`.
- Access fields with `p.x`.
- Field assignment requires a mutable binding.
- Struct values move by default. Reusing a moved binding is reported as
  `OWN-001`.

`@layout(soa)`, `@layout(aos)`, and `@layout(group(...))` control physical
layout without changing observable struct semantics.

## 5. Enums and Match

```nr
enum Option {
    None,
    Some(i64)
}

match x {
    Option::None => { return 0; },
    Option::Some(v) => { return v; },
};
```

Enums are tagged unions. Variants without payloads are nullary. Variants with
payloads take the payload value in parentheses. `match` is exhaustive over enum
variants and also supports literals, ranges, guards, captures, slice patterns,
and struct destructuring.

## 6. Control Flow

```nr
if cond { ... } else { ... };
while cond { ... };
for i in start..end { ... };
break;
continue;
return expr;
```

Blocks require braces. `else if` is written as a nested `if` inside the `else`
branch. `for i in N..M` iterates over the half-open range `[N, M)`.

## 7. Imports, Modules, and FFI

```nr
import "stdlib/rods/strings.nr"
import "../my_local_helper.nr"
```

Import paths are string-quoted and resolved relative to the working directory.
The compiler resolves the import graph and includes each unique source once.

Declare foreign functions with `extern fn`:

```nr
extern fn rust_regex_is_match(pattern: str, text: str) -> i64;
```

Build directives collected during module resolution:

| Directive | Effect |
|---|---|
| `#cfile "path/to/x.c"` | Compile and link a C source file. |
| `#link "lib_name"` | Link a static or import library. |
| `#libpath "dir/path"` | Add a library search path. |

## 8. Attributes

| Attribute | Effect |
|---|---|
| `@hot` | Enforce performance constraints such as no allocation or indirect dispatch in hot code. |
| `@const_fn` | Mark a function as eligible for compile-time evaluation. |
| `@law(...)` | Declare algebraic-law metadata used by checking and optimization tooling. |
| `@region(name)` | Bind allocations to a named arena or region allocator. |
| `#[require(...)]` | Runtime precondition. |
| `#[ensure(...)]` | Runtime postcondition. |
| `#[invariant(...)]` | Runtime invariant on an impl block. |
| `#[deadline(N)]` | Runtime deadline check. |

Run `nuc perf <file>.nr` to inspect optimizer and performance diagnostics.

## 9. Ownership, Safety, and Effects

The compiler runs ownership, move, initialization, Sendable, FFI, unsafe, and
effect checks by default.

| Code | Meaning |
|---|---|
| `OWN-001` | Use of moved variable |
| `OWN-008` | Cannot assign to immutable binding |
| `OWN-G4-USE-AFTER-DROP` | Heap-backed binding read after explicit free |
| `OWN-G8-COND-MOVE` | Conditional move leaves a later read path unsafe |
| `INIT-G11-READ-BEFORE-INIT` | Binding may be read before every path initializes it |
| `BORROW-G2-LIFETIME` | Returned or stored reference outlives its source scope |
| `ALIAS-G3-VEC-OF-REFS` | Reference stored in a reallocating `Vec` |
| `ALIAS-G3-HASHMAP-REHASH` | Reference/key alias can be invalidated by hashmap rehash |
| `SEND-G6-*` | Non-Send value crosses a spawned boundary |
| `FFI-G5-NULL-DEREF` | Direct FFI pointer dereference may be null |
| `FFI-G9-MISSING-ALLOW-DIRECT-FFI` | Direct FFI call requires explicit allow/unsafe annotation |
| `UNSAFE-G7-MISSING-ALLOW` | Unsafe block or expression is missing an allow annotation |
| `EFFECT-G10-*` | Effect row mismatch or missing capability |
| `TYP-*` | Type-checking diagnostics |
| `MATCH-*` | Pattern and exhaustiveness diagnostics |

Run `nuc check <file>.nr` for diagnostics-only mode.

## 10. Command-Line Interface

| Command | Purpose |
|---|---|
| `nuc init [name]` | Scaffold a project. |
| `nuc build [file]` | Compile to a native binary. |
| `nuc build-fast` | Fast core compile path. |
| `nuc build-strict` | Run all checkers. |
| `nuc build-shared` | Compile a shared library. |
| `nuc build-wasm` | Compile to WebAssembly. |
| `nuc build-ptx` | Compile to NVIDIA PTX. |
| `nuc run` | Compile and run. |
| `nuc emit` | Emit LLVM IR only. |
| `nuc test [path]` | Build and run tests. |
| `nuc bench [file]` | Benchmark repeated runs. |
| `nuc perf [file]` | Compile-path performance analysis. |
| `nuc check [file]` | Run checkers and diagnostics. |
| `nuc summary [file]` | Print a compact module interface card. |
| `nuc abi [file]` | Inspect C/Rust interop ABI. |
| `nuc graph [file]` | Print source-level call/effect graph. |
| `nuc impact <file> <fn>` | Print reverse call graph. |
| `nuc bootstrap status` | Report self-host bootstrap state. |
| `nuc stage-dump <stage>` | Dump stage summaries. |

Most commands accept `--json`, `-o <name>`, and `--time-passes`.

## 11. Project Layout

When invoked without an explicit source file in a directory containing
`Nucleor.toml`, `nuc` reads `[build].entry` as the entry point. Use
`nuc init [name]` to scaffold a project.

## 12. Not In This Release

- First-class `async` / `await`
- Inline assembly
- Macros / metaprogramming
- Reflection
- Prebuilt Linux/macOS release binaries
- Formatter (`nuc fmt`)
- Complete language-server experience
- Debugger symbols
- Full documentation generator
- REPL

These are tracked on the project roadmap.
