# RFC-0028 — Format Strings (`format!`, `println!`, `write!`)

| Field | Value |
|---|---|
| **Number** | 0028 |
| **Title** | Format strings — `format!("x = {}", x)`, `println!`, `write!`, `Display` / `Debug` traits |
| **Status** | Implemented (partial) v0.2.6 — `format_i64/str/hex/2_ii/2_si` builtins, one `{}` per call; full variadic + `Display` / `Debug` traits deferred to v0.4 |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.2 partial (v0.2.6 — `format_i64/str/hex/2_ii/2_si` builtins) → v0.4.0 (full variadic + `Display` / `Debug` traits) |
| **Depends on** | RFC-0017 (String) |

---

## 1. Summary

Replace `print(str_concat(…))` chains with first-class format strings.

```nucleor
let name = "Joe";
let count = 42;
let pi = 3.14159;

println!("Hello, {}!", name);
println!("count = {}, pi = {:.3}", count, pi);
println!("hex: {:08x}", 0xDEADBEEF);
println!("debug: {:?}", some_struct);
println!("right-aligned: {:>10}", "hi");

let s: String = format!("{} = {}", name, count);
write!(stderr(), "error: {}", err)?;
```

Standard `Display` and `Debug` traits make types printable.

---

## 2. Motivation

Today's `print(str_concat(fmt_int(n), str_concat(": ", s)))` is
verbose and error-prone. Modern languages all have format strings.

Prior art: Rust `format!` (canonical), Python f-strings, C printf
(unsafe), Swift string interpolation.

---

## 3. Design

### 3.1 Format syntax

`{<position>:<spec>}` placeholder. Same DSL as Rust:

```
{} {0} {name} {:?}
{:<width> {:>width} {:^width}    # alignment
{:0width}                         # zero pad
{:.precision}                     # precision
{:x} {:X} {:o} {:b} {:e} {:E}    # base/notation
{:width$}                         # width from arg
```

Examples:
- `{}` — Display
- `{:?}` — Debug
- `{:#?}` — Debug pretty-printed
- `{:>10}` — right-align width 10
- `{:08x}` — zero-pad width 8 hex
- `{:.3}` — 3 decimal places

### 3.2 The `Display` / `Debug` traits

```nucleor
trait Display {
    fn fmt(&self, f: &mut Formatter) -> Result<(), FmtError>;
}

trait Debug {
    fn fmt(&self, f: &mut Formatter) -> Result<(), FmtError>;
}
```

Stdlib provides Display+Debug for all numeric types, `bool`, `char`,
`str`, `String`, `Vec<T: Debug>`, `Option<T: Debug>`, etc.

User can derive Debug:

```nucleor
#[derive(Debug)]
struct Point { x: f64, y: f64 }
```

### 3.3 Macros

| Macro | Output |
|---|---|
| `format!(fmt, args...)` | `String` |
| `println!(fmt, args...)` | print to stdout + newline |
| `print!(fmt, args...)` | print to stdout, no newline |
| `eprintln!(fmt, args...)` | print to stderr + newline |
| `eprint!(fmt, args...)` | print to stderr, no newline |
| `write!(buf, fmt, args...)` | write to a `Write` impl, returns `Result` |
| `writeln!(buf, fmt, args...)` | write + newline |

### 3.4 Compile-time format-string parsing

The compiler parses the format string at compile time, type-checks
arg counts and types, and emits direct calls to formatter methods —
no runtime parsing.

```nucleor
println!("x={}", x);
// expands to:
{
    let __args = [&x as &dyn Display];
    __println_impl("x={}", &__args);
}
```

Format-string errors are compile errors:

```
error[FMT-001]: 2 positional arguments in format string, but 1 argument provided
  --> src/main.nr:14:5
   |
14 |     println!("{} = {}", count);
   |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

### 3.5 Diagnostics

| Code | Meaning |
|---|---|
| FMT-001 | Argument count mismatch |
| FMT-002 | Type doesn't implement Display/Debug |
| FMT-003 | Invalid format spec |
| FMT-004 | Width/precision arg type wrong |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Format-string parser (compile-time) | `format_args!` macro | ~600 |
| `Display` / `Debug` traits | Stdlib | ~150 |
| Stdlib derives + impls | All primitives + collections | ~800 |
| `Formatter` machinery | Buffered write, padding, alignment | ~500 |
| `Write` trait | Generic over destination | ~150 |
| Diagnostics | FMT-001…004 | ~150 |
| **Total** | | **~2350** |

---

## 5. Alternatives considered

- **printf-style** — unsafe; bypasses type system.
- **Python f-string interpolation** — `f"x = {x}"` reads cleaner but
  conflicts with our generic syntax `<...>`. Use `format!` macro.
- **String concatenation only** — current state; verbose.

## 6. Open questions

1. F-string syntax in addition to `format!()`? Defer.
2. Locale-aware formatting (thousands separators) — defer to community
   rod.
3. `#[derive(Display)]` — Rust says no (must be explicit); we follow.

## 7. Definition of done

- [ ] All 7 macros work
- [ ] `Display` / `Debug` for all stdlib types
- [ ] `#[derive(Debug)]` works
- [ ] Compile-time arg-count check
- [ ] CHANGELOG documents

## 8. Future extensions

- F-string syntax (v0.7?)
- `Display` derive (v0.6+ if accepted)
- Locale support (community)

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~2350 fits
