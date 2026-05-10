# Nucleor Language Reference (v1.0)

This document describes the Nucleor language as implemented by the self-hosted compiler (`bin/nucleor.exe`, version `1.1.0`). It is intended as a normative-style reference. For a gentler introduction, see [language-tour.md](language-tour.md). For the v1.0 memory-safety surface (RFC-0062 G-series gates: `OWN-G4`, `OWN-G8`, `INIT-G11`, `BORROW-G2`, `ALIAS-G3-*`, `SEND-G6-*`, `FFI-G5`, `FFI-G9`, `UNSAFE-G7`, `EFFECT-G10-*`), see [`rfcs/RFC-0062-effects-extension.md`](rfcs/RFC-0062-effects-extension.md). For the v1.x roadmap, see [`rfcs/RFC-0063-production-readiness-roadmap.md`](rfcs/RFC-0063-production-readiness-roadmap.md).

> **Status note (v1.0):** §13 below preserves the pre-v1.0 corrigenda — a record of the audits that hardened the v0.1.5 / v0.2.x chain into the shipping v1.0 surface. The corrigenda points are now part of the language proper; they are kept as a historical trail for adopters who reviewed the language during the v0.2.x window. New features and gates added since v0.2 — RFC-0062 memory-safety G-series, the effect-annotation framework (`#[effect(...)]`), the `with [...]` effect-rows-on-fn-types substrate, the `#[isr]` first pass, the `#[max_depth]` recursion bound, the auto-drop default flip — are described inline in the body sections rather than the §13 corrigenda.

## 1. Lexical structure

### 1.1 Source encoding

Source files are UTF-8. Line endings may be `\n` or `\r\n`. Bare carriage-returns (CR / 0x0D not followed by LF) are rejected with `LEX-CR-ONLY`. NUL bytes (0x00) embedded in source are rejected with `LEX-002` (pre-fix, the file was silently truncated at the first NUL via C-string semantics).

A UTF-8 byte-order-mark (`EF BB BF`) at the start of a file is rejected with `LEX-001`; embedded BOMs / zero-width spaces / smart-quotes / RTL bytes mid-source are also rejected with `LEX-001` (pre-fix, every non-ASCII byte was silently dropped — a known supply-chain attack vector, CVE-2021-42574 family).

String literals may not contain raw line breaks. Use `\n` / `\r\n` escapes, or split and concatenate the string. Unterminated strings and strings ending with a bare trailing backslash are hard lexer errors (`LEX-STRING-EOF`).

`fn` / `let` / `return` etc. are reserved words (§1.5) and cannot be used as binding names. The set of reserved words is small; any of the words listed in §1.5 used in a binding-name slot is rejected at parse time with `PARSE-LET-001`.

### 1.2 Comments

```
// line comment to end of line
/* block comment, currently rejected */
```

Line comments are supported. Block comments and doc-block comments (`/* ... */`, `/** ... */`) are rejected with a clear frontend diagnostic; convert them to `//` lines until block-comment skipping ships.

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
`bf16` / `f32` / `f64`. **Strict-mode integer arithmetic is the
default since v0.4.238** — `+`, `-`, `*` on signed and unsigned
integers panic on overflow rather than wrapping silently. Use
`wrapping { ... }` / `saturating { ... }` / `checked { ... }`
blocks or set `NUCLEOR_INT_STRICT_INTRIN=0` at compile time
to opt out. See [UPGRADE_v0.4.239.md](UPGRADE_v0.4.239.md)
and [UPGRADE_v0.4.241.md](UPGRADE_v0.4.241.md) for migration
details. Mixed-width integer arithmetic without an explicit `as`
cast is rejected with `NUM-001` during type-check.)

String escape sequences (recognised by the lexer): `\n`, `\r`, `\t`, `\\`, `\"`, `\'`, `\0`. Any other backslash sequence inside a string literal (e.g. `\v`, `\x...`, `\u{...}`) is a hard error (`NR025`).

Numeric-literal hygiene rules (Lane 4 audit close, F-016 through F-024):

- `0x` / `0o` / `0b` prefixes require at least one digit (`LEX-NUM-003` if missing).
- Underscores must separate digits — leading underscore (`0x_1`), consecutive underscores (`1__2`), and trailing underscore not followed by a numeric/`as`-cast suffix (`100_;`) are rejected (`LEX-NUM-001`/`002`/`004`).
- Hex/octal/binary literals exceeding the u64 width are rejected as `NUM-021` (mirrors the existing decimal check; pre-fix hex silently wrapped).
- A leading-zero decimal (`007`) is rejected (`LEX-NUM-005`) because Nucleor does not have C-style octal — adopters porting C/Java code who expect octal semantics get a clean diagnostic.
- An integer literal followed immediately by an alphabetic character that is not a recognised type suffix (`i8`/`i16`/`i32`/`i64`/`i128`/`isize`/`u8`/`u16`/`u32`/`u64`/`u128`/`usize`) is rejected (`LEX-NUM-SUFFIX`); pre-fix `1z42` silently dropped `z42` as a stray identifier.
- Float literals that overflow IEEE-754 finite range (`1e400`) are rejected (`LEX-NUM-FLOAT-OVERFLOW`); pre-fix the resulting Inf/NaN bit pattern was stored silently.
- Leading-dot and trailing-dot floats are rejected (`LEX-NUM-FLOAT-FORM`); write `0.5` and `1.0` instead of `.5` and `1.`.

### 1.5 Keywords

`fn`, `let`, `mut`, `return`, `if`, `else`, `while`, `for`, `in`, `match`, `loop`, `break`, `continue`, `struct`, `enum`, `trait`, `impl`, `where`, `as`, `const`, `type`, `import`, `use`, `mod`, `extern`, `pub`, `pure`, `true`, `false`.

The lexer recognises `dyn` and `move` as contextual keywords (only meaningful in trait-object-type and closure positions respectively); see §6 / §3.1 for usage. Any of the above words used as a binding name (`let fn: i64 = 5;`) is rejected with `PARSE-LET-001` rather than silently shadowed.

### 1.6 Operators

| Category | Operators |
|---|---|
| Arithmetic | `+`, `-`, `*`, `/`, `%` |
| Comparison | `==`, `!=`, `<`, `<=`, `>`, `>=` |
| Logical | `&&`, `||`, `!` |
| Bitwise | `&`, `|`, `^`, `<<`, `>>` |
| Compound assignment | `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=` |
| Postfix | `++`, `--` (statement form only — desugars to `x = x + 1` / `x = x - 1`) |
| Range | `..`, `..=` (only in for-loop heads — see §6) |
| Assignment | `=` |
| Field access | `.` |
| Path | `::` (e.g. `Option::Some`, `Vec::new`) |
| Closure pipe | `|` ... `|` (closure parameter delimiter) |
| Postfix Result/Option propagation | `?` |

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
- Functions may omit `-> ReturnType`, in which case the implicit return type is `()` (the unit / void type). The compiler accepts both `fn helper() { ... }` and `fn helper() -> () { ... }`. Most non-trivial functions declare a return type explicitly, and the audit recommends the explicit form for adopter clarity (the `-> ReturnType` shape is mandatory in adopter-facing documentation generators, e.g. `nuc explain`). v0.2-era versions of this spec required `-> ReturnType`; v1.0 relaxes this to match the implementation (Lane 4 audit, F-041 doc drift).
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
| `@law(...)`          | Declares algebraic-law metadata. Current builds capture and report the annotation; `nuc test --check-laws` generates bounded integer checks for low-risk forms (`commutative`, `associative`, `identity = E`, `absorbing = Z`, `idempotent`, `involution`, `distributive_over = g`) and hard-errors deprecated aliases, unsupported canonical forms, float/approximate modifiers, and unknown names. User-law-driven rewrites, Arbitrary-driven broad property tests, float tolerance, and SMT proof obligations are tracked for later RFC-0031 phases. Canonical laws (per `docs/spec/Nucleor_Algebraic_Laws_Schema.md`): `commutative`, `associative`, `identity = E`, `idempotent`, `involution`, `absorbing = Z`, `distributive_over = g`, `inverse = g`, `fusion`. (Pre-v0.8.264 aliases `zero = Z` and bare `distributive` are rejected by `--check-laws`; use `absorbing = Z` and `distributive_over = g`.) |
| `@region(name)`      | Binds the function's allocations to a named arena/region allocator. |

Run `nuc perf <file>.nr` to see optimizer and performance diagnostics.

## 9. Ownership and effects

The compiler runs an ownership/move checker by default (`OWN-*` codes) and a type checker (`TYP-*` codes).

| Code | Meaning |
|---|---|
| `OWN-001` | Use of moved variable |
| `OWN-008` | Cannot assign to immutable binding (missing `mut`) |
| `OWN-G4-USE-AFTER-DROP` | Heap-backed binding read after explicit free |
| `OWN-G8-COND-MOVE` | Conditional move leaves a later read path unsafe |
| `INIT-G11-READ-BEFORE-INIT` | Binding may be read before every path initializes it |
| `BORROW-G2-LIFETIME` | Returned/stored reference outlives its source scope |
| `ALIAS-G3-VEC-OF-REFS` | Reference element stored in a reallocating `Vec` |
| `ALIAS-G3-HASHMAP-REHASH` | Reference/key alias can be invalidated by hashmap rehash |
| `SEND-G6-HASHMAP` | Non-Send hashmap payload crosses a spawned boundary |
| `SEND-G6-CLOSURE-CAPTURE` | Spawned closure captures a non-Send value |
| `SEND-G6-TUPLE` | Tuple containing a non-Send field crosses a spawned boundary |
| `SEND-G6-ENUM` | Enum containing a non-Send variant crosses a spawned boundary |
| `FFI-G5-NULL-DEREF` | Direct FFI pointer dereference may be null |
| `FFI-G9-MISSING-ALLOW-DIRECT-FFI` | Direct FFI call requires explicit allow/unsafe annotation |
| `UNSAFE-G7-MISSING-ALLOW` | Unsafe block/expression is missing an allow annotation |
| `EFFECT-G10-UNDECLARED` | Function body performs an effect missing from its row |
| `EFFECT-G10-MISSING-ALLOW` | Effect requires an allow/capability annotation |
| `EFFECT-G10-WRONG-ROW` | Declared effect row does not match produced effects |
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
| `nuc graph [file]`    | Source-level call/effect graph (see §10.1) |
| `nuc impact <file> <fn>` | Reverse call graph — every fn that depends on `<fn>` (see §10.2) |
| `nuc bootstrap status` | Report self-host bootstrap state |
| `nuc stage-dump <stage>` | Dump compiler stage summaries (`tokens`, `ast`, `typed`, `ir`, `all`) |

Most commands accept `--json` for machine-readable output, `-o <name>` for the output base name, and `--time-passes` for per-phase compile timings.

### 10.1 `nuc graph [file]` — source-level call/effect graph

Lists every function in the source file plus the calls each one makes (forward edges) and the side effects each one declares or reaches via transitive closure (`io`, `panic`, `alloc`, etc.). Output is a flat per-function block — easy to grep, easy to feed into a graph tool. Use this verb when you need to **read** the call structure or audit which fns reach a given effect.

```
$ nuc graph examples/server.nr
fn main:
  calls: configure, listen, run_loop
  effects: io, panic, alloc
fn configure:
  calls: parse_args, env_lookup
  effects: io
fn listen:
  calls: socket_bind, socket_listen
  effects: io, panic
...
```

Pass `--json` for machine-readable output (suitable for piping into the graph remediation tool surface added in v0.7.78–v0.7.81 — see `stdlib/rods/graph.nr` `graph_*` API).

### 10.2 `nuc impact <file> <fn>` — reverse call graph

Inverse of `nuc graph`. Given a target function `<fn>`, report **every fn in the module that depends on it transitively** — direct callers plus their callers, and so on, up to fn-graph fixpoint. Use this verb when you need to **change** a function's signature or behavior and want to know which downstream fns are affected.

```
$ nuc impact examples/server.nr socket_bind
socket_bind is called (transitively) by:
  listen          (direct)
  main            (via listen)
```

If `<fn>` is unreachable from any other fn (only entry points or unused), the verb prints an empty list — useful as a "is this fn safe to delete?" check.

Pass `--json` for machine-readable output. Pairs cleanly with the lock graph (`nuc deps`) and the source call graph (`nuc graph`) — three different views of the same project, intended to compose.

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
