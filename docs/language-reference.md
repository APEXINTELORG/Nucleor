# Nucleor Language Reference (v0.2)

This document describes the Nucleor language as implemented by the self-hosted compiler (`bin/nucleor.exe`, version `0.2.0-v2` plus the v0.2.x post-RC sub-chain). It is intended as a normative-style reference. For a gentler introduction, see [language-tour.md](language-tour.md). For v0.2-deferred language extensions (iterators, closures, lifetimes, trait objects, format strings, pattern-matching extensions), see [docs/milestones/v0.4.0.md](milestones/v0.4.0.md).

## 1. Lexical structure

### 1.1 Source encoding

Source files are UTF-8. Line endings may be `\n` or `\r\n`.

### 1.2 Comments

```
// line comment to end of line
/* block comment, can span lines */
```

Both line and block comments are supported.

### 1.3 Identifiers

```
identifier ::= [A-Za-z_][A-Za-z0-9_]*
```

Identifiers are case-sensitive. There is no length limit.

### 1.4 Literals

| Form | Type | Example |
|---|---|---|
| Decimal integer | `i64` | `42`, `-17` |
| Hexadecimal integer | `i64` | `0xFF` (= 255) |
| Binary integer | `i64` | `0b1010` (= 10) |
| Underscored integer | `i64` | `1_000_000` |
| Width-suffixed integer | as suffix | `100u8`, `42i32`, `1_000_000i64` |
| Float | `f64` | `1.5`, `-3.14` |
| Width-suffixed float | as suffix | `1.5f32`, `2.71828f64` |
| String | `str`  | `"hello\n"` |
| Boolean | `bool` | `true`, `false` |

(Width / signedness suffixes parse and type-check per
RFC-0015 §3.6 — `i8` / `i16` / `i32` / `i64` / `u8` / `u16` /
`u32` / `u64` / `usize` / `isize` / `f8e4m3` / `f8e5m2` / `f16` /
`bf16` / `f32` / `f64`. The strict-mode mixed-width-arithmetic
warning NUM-001 is staged behind `nuc fix --numeric` until the
v0.4 stdlib audit completes.)

String escape sequences: `\n`, `\r`, `\t`, `\\`, `\"`.

### 1.5 Keywords

`fn`, `let`, `mut`, `return`, `if`, `else`, `while`, `match`, `struct`, `enum`, `import`, `extern`, `pub`, `true`, `false`.

### 1.6 Operators

| Category | Operators |
|---|---|
| Arithmetic | `+`, `-`, `*`, `/` |
| Comparison | `==`, `!=`, `<`, `<=`, `>`, `>=` |
| Logical | `&&`, `||`, `!` |
| Assignment | `=` |
| Field access | `.` |
| Path | `::` (e.g. `Option::Some`, `Vec::new`) |

## 2. Types

| Type | Description |
|---|---|
| `i64` | 64-bit signed integer (the workhorse type) |
| `i32` | 32-bit signed integer (used for `main` return; mostly equivalent to `i64` in expressions) |
| `f64` | 64-bit floating point (passed as `i64`-bitcast through the C ABI; see `stdlib/rods/complex.nr` for helpers) |
| `bool` | Boolean (`true`/`false`) |
| `str` | UTF-8 string (immutable, ref-counted) |
| `Vec<T>` | Dynamic array of 64-bit slots; element type is by convention `i32` even when storing `i64` |
| `struct` | User-defined product type (see §4) |
| `enum`   | User-defined sum type (see §5) |

Numeric primitives are not implicitly converted between widths. Use the runtime helpers (`f64_from_int`, `f64_to_str_6`, etc., from `stdlib/rods/complex.nr`) for explicit conversion.

## 3. Functions

```
fn name(p1: T1, p2: T2, ...) -> ReturnType {
    statements...
    return value;
}
```

- Every parameter requires a type annotation.
- Every function requires a return type. `void`-returning functions return `()` (rare; most `void` cases are modeled as `-> i64` returning `0`).
- Functions are first-class: a function name evaluated outside of a call expression yields a function pointer (`i64`).

### 3.1 Closures

```
let f: i64 = |x, y| x + y;
let g: i64 = |x| { if x < 0 { return 0 - x; }; return x; };
let z: i64 = || 42;
```

Closures are stored as `i64` (a pointer or handle). Apply with normal call syntax: `f(1, 2)`.

### 3.2 `pub`

Prefix a function with `pub` to mark it as part of a shared-library export surface (used by `nuc build-shared`). Default visibility is module-internal.

## 4. Structs

```
struct Point {
    x: i64,
    y: i64
}
```

- Constructed with `Point { x: 3, y: 4 }`.
- Accessed with `p.x`.
- Field assignment requires the binding to be `mut`: `let mut p: Point = ...; p.x = 7;`.
- Structs are move-by-default. Passing a struct into a function or storing it in another struct *moves* it; subsequent use of the original binding is reported as `OWN-001`.

### 4.1 `@layout(soa | aos | group(...))`

Annotate a struct to control memory layout.

```
@layout(soa)
struct Particle { x: i64, y: i64, z: i64, mass: i64 }
```

- `aos` (default): array-of-structs, dense rows.
- `soa`: struct-of-arrays, useful for SIMD or hot-fields-first access patterns.
- `group(hot: x y, cold: mass)`: split fields into separately-laid-out groups.

`@layout` does not change observable struct semantics, only memory layout.

## 5. Enums

```
enum Option {
    None,
    Some(i64)
}
```

- Variants without a payload are nullary: `Option::None`.
- Variants with a payload take their value: `Option::Some(42)`.
- Each enum is its own type. A function expecting an `Option` parameter cannot be called with an `i64` — declare the parameter type as the enum.

### 5.1 `match`

```
match x {
    Option::None => { return 0; },
    Option::Some(v) => { return v; },
};
```

`match` is exhaustive over the enum's variants. Each arm requires `=>` followed by a block; arms are comma-separated; the `match` expression itself is terminated by `;`.

## 6. Control flow

```
if cond { ... } else { ... };

while cond { ... };

for i in start..end { ... };  // half-open range

break;        // exit the innermost loop
continue;     // skip to the next iteration

return expr;
```

- `if`, `while`, `for` blocks always require braces.
- `else if` is written as a nested `if` inside the `else` branch.
- `for i in N..M` iterates over the half-open range `[N, M)`.
- `break` and `continue` are available inside `while` and `for` loops.

## 7. Imports and modules

```
import "stdlib/rods/strings.nr"
import "../my_local_helper.nr"
```

- Paths are string-quoted, evaluated relative to the working directory (typically the project root).
- The compiler resolves the import graph and includes each unique source exactly once.

### 7.1 `extern fn`

Declare a foreign function callable through the C ABI:

```
extern fn rust_regex_is_match(pattern: str, text: str) -> i64;
```

The actual symbol must be linked at build time (see §7.2).

### 7.2 Build directives

| Directive | Effect |
|---|---|
| `#cfile "path/to/x.c"` | Compile and link `x.c` (relative to the rod file's directory). |
| `#link "lib_name"`     | Link against the static or DLL import library `lib_name`. |
| `#libpath "dir/path"`  | Add `dir/path` to the linker's library search path. |

These appear at module top level, before function declarations. Multiple directives may be present and are collected during module resolution.

## 8. Performance attributes

| Attribute | Effect |
|---|---|
| `@hot`               | Strict performance enforcement: no heap allocation, no string formatting, no indirect dispatch in the function's body. The compiler reports violations as performance diagnostics. |
| `@const_fn`          | Marks the function as eligible for compile-time evaluation when called with constant arguments. |
| `@law(...)`          | Declares algebraic laws the optimizer may use to rewrite call sites. Supported laws: `commutative`, `associative`, `identity=N`, `absorbing=N`, `idempotent`, `involution`, `distributive`, `fusion`. |
| `@region(name)`      | Binds the function's allocations to a named arena/region allocator. |

Run `nuc perf <file>.nr` to see which laws fired and which violations were reported.

## 9. Ownership and effects

The compiler runs an ownership/move checker by default (`OWN-*` codes) and a type checker (`TYP-*` codes).

| Code | Meaning |
|---|---|
| `OWN-001` | Use of moved variable |
| `OWN-008` | Cannot assign to immutable binding (missing `mut`) |
| `TYP-005` | Wrong number of arguments in call |
| `TYP-006` | Argument type mismatch |
| `TYP-008` | Type mismatch for binding |

Run `nuc check <file>.nr` for diagnostics-only mode (no codegen).

## 10. The `nuc` command-line interface

| Command | Purpose |
|---|---|
| `nuc init [name]`     | Scaffold a new project with `Nucleor.toml` |
| `nuc build [file]`    | Compile to a native binary |
| `nuc build-fast`      | Fast core compile path |
| `nuc build-strict`    | Run all checkers (ownership, type, source, taint, effect) |
| `nuc build-shared`    | Compile a shared library (`.dll`/`.lib`) from `pub fn` exports |
| `nuc build-wasm`      | Compile to WebAssembly |
| `nuc build-ptx`       | Compile to NVIDIA PTX |
| `nuc run`             | Compile and run |
| `nuc emit`            | Emit LLVM IR only (no link) |
| `nuc test [path]`     | Build and run tests |
| `nuc bench [file]`    | Benchmark repeated runs |
| `nuc perf [file]`     | Compile-path performance analysis |
| `nuc check [file]`    | Run all checkers, report diagnostics |
| `nuc summary [file]`  | Compact module interface card |
| `nuc abi [file]`      | Inspect the C/Rust interop ABI of imports/exports |
| `nuc graph [file]`    | Source-level call/effect graph |
| `nuc bootstrap status` | Report self-host bootstrap state |
| `nuc stage-dump <stage>` | Dump compiler stage summaries (`tokens`, `ast`, `typed`, `ir`, `all`) |

Most commands accept `--json` for machine-readable output, `-o <name>` for the output base name, and `--time-passes` for per-phase compile timings.

## 11. Project layout (`Nucleor.toml`)

When invoked without an explicit source file in a directory containing `Nucleor.toml`, `nuc` reads `[build].entry` to find the entry point. See `nuc init [name]` for a scaffold.

## 12. What this version does not have (yet)

- `async` / `await` (RFC-0030 declined — see RFC for rationale)
- Inline assembly
- Macros / metaprogramming
- Reflection
- Cross-platform binaries (Windows-only through v0.2.x; Linux + macOS native binaries scoped for v0.3 — see [`docs/milestones/v0.3.0.md`](milestones/v0.3.0.md))
- Formatter (`nuc fmt`)
- Language server (LSP)
- Debugger / DWARF or PDB symbol info
- Documentation generator (skeleton ships v0.2; full version in v0.4 — see [`docs/milestones/v0.4.0.md`](milestones/v0.4.0.md) RFC-0029)
- REPL

These are tracked as v0.3 / v0.4 work. The full deferral list with
target releases lives in [`docs/milestones/v0.4.0.md`](milestones/v0.4.0.md).
Contributions welcome.

## 13. Historical corrigenda

### 13.1 v0.1.5 audit (now redundant — features are gate-tested)

The pre-v0.1.5 reference listed the following as missing. They
have been gate-tested under `tests/features/` and `tests/lang/`
through the entire v0.1.x → v0.2.x chain:

- `for i in N..M { ... }` half-open range loops
- `break` and `continue` inside loops (`tests/features/break_continue.nr`)
- Block comments `/* ... */`
- Generics: `fn id<T>(x: T) -> T { return x; }`
  (`tests/features/generic_fn.nr` + `generic_struct.nr` +
  `generic_enum.nr`)
- Traits + impl: `trait Greet { fn hi(self) -> str; }` +
  `impl Greet for P` (`tests/features/trait_basic.nr` +
  `trait_bounds.nr` + `trait_default.nr` + `trait_method.nr`)
- `where` clauses (`tests/features/where_clauses.nr`)
- `match` on integer literals (in addition to enum variants)
- `getcwd()` and `getenv(name)` builtins (added in v0.1.5)
- Hex (`0xFF`) / binary (`0b1010`) / underscored (`1_000_000`)
  numeric literals (added v0.1.x; gate-tested via
  `tests/lang/atomic_bit_ops.nr` and others — see §1.4)

### 13.2 v0.2.x additions

The v0.2.x sub-chain added: `?` postfix operator (v0.1.50,
RFC-0016), `if let` / `while let` sugar (v0.1.13 / v0.1.16),
`as` cast operator (RFC-0015 §3.5), narrow-width overflow
helpers (`wrapping_*`, `saturating_*`, `checked_*` for
i8/i16/i32/u8/u16/u32/u64), 75+ runtime helpers across
math/fs/env/time/path/parse/stringify/padding/hashmap/stats/
random/checked-arithmetic, plus the `String` / `HashMap` /
`HashSet` / `BTreeMap` / `BTreeSet` / `VecDeque` collection
runtime + rod surface. The full enrichment table is in
[CHANGELOG.md](../CHANGELOG.md) and
[docs/migrations/v0.1-to-v0.2.md](migrations/v0.1-to-v0.2.md).
