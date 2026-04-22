# RFC-0016 — Result, Option, match, and the `?` operator

| Field | Value |
|---|---|
| **Number** | 0016 |
| **Title** | `Result<T, E>`, `Option<T>`, exhaustive `match`, `?` early-return |
| **Status** | Draft |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.2.0 |
| **Depends on** | RFC-0015 (numeric types — for narrow returns) |

---

## 1. Summary

Ship `Result<T, E>` + `Option<T>` as built-in stdlib types,
exhaustive `match` with payload destructuring, and the `?` operator
that early-returns the `Err`/`None` arm.

```nucleor
fn read_config(path: &str) -> Result<Config, IoError> {
    let bytes: Vec<u8> = read_file(path)?;       // early-return on Err
    let cfg: Config = parse(bytes).ok_or(IoError::ParseFailed)?;
    return Ok(cfg);
}

match read_config("a.toml") {
    Ok(cfg)  => use_config(cfg),
    Err(e)   => log!("config error: {}", e),
}
```

Closes the single biggest ergonomic gap with Rust. ~80% of Rust's
day-one appeal comes from this trio.

---

## 2. Motivation

Today every fallible op returns `i64` and you check by convention.
Sentinel-i64 is the C model and produces the C error-handling bugs.
Result/Option + `?` is the modern answer (Rust, Swift, Kotlin
follow this).

Prior art: Rust (canonical), Haskell (Either), OCaml (option/result),
F# (Result), Swift (throws/try, optionals), Kotlin (Result).

---

## 3. Design

### 3.1 Types

```nucleor
enum Option<T> {
    Some(T),
    None,
}

enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

Defined in `stdlib/rods/option.nr` and `stdlib/rods/result.nr`.
Re-exported as `std::Option`, `std::Result`. Variants `Ok`, `Err`,
`Some`, `None` available without prefix at any usage site.

### 3.2 `match` expression

```nucleor
match expr {
    Pattern_1 => arm_1,
    Pattern_2 if guard => arm_2,
    _ => default_arm,
}
```

- Patterns: literal, identifier-bind, struct-destructure,
  tuple-destructure, enum-variant-with-payload, `_` wildcard,
  `..` rest, range (`1..=10`).
- Guards: `if expr` after pattern.
- Exhaustiveness: compiler errors if not all variants/values covered.
- All arms must produce the same type.

### 3.3 `?` operator

```nucleor
let x: T = expr?;
```

Desugars to:

```nucleor
let x: T = match expr {
    Ok(v)  => v,
    Err(e) => return Err(e.into()),
};
```

For `Option`:

```nucleor
let x: T = expr?;
// =>
let x: T = match expr {
    Some(v) => v,
    None    => return None,
};
```

The function's return type must be `Result<_, E2>` (where `E: Into<E2>`)
for `Result?`, or `Option<_>` for `Option?`.

### 3.4 Pattern destructuring (tuples, structs, enums)

```nucleor
struct Point { x: f64, y: f64 }
let p = Point { x: 1.0, y: 2.0 };

let Point { x, y } = p;        // bind both
let Point { x, .. } = p;       // bind x only

match shape {
    Shape::Rect { w, h }  => w * h,
    Shape::Circle { r }   => PI * r * r,
    Shape::Triangle(a, b, c) => triangle_area(a, b, c),   // tuple variant
}
```

### 3.5 `if let` and `while let`

Sugar for single-arm match:

```nucleor
if let Some(v) = opt { use(v) }
while let Some(item) = queue.try_pop() { process(item) }
```

### 3.6 Inherent methods on Option/Result

Standard set:
- `is_some`, `is_none`, `is_ok`, `is_err`
- `unwrap`, `unwrap_or(default)`, `unwrap_or_else(f)`,
  `unwrap_or_default`
- `map(f)`, `map_err(f)`, `and_then(f)`, `or_else(f)`
- `ok()`, `err()` (Result → Option)
- `ok_or(e)`, `ok_or_else(f)` (Option → Result)
- `as_ref`, `as_mut`, `take`, `replace`
- `iter`, `into_iter`

`unwrap` panics on None/Err; `#[no_panic]` rejects bare `unwrap`.
Use `unwrap_or` / `?` / `match`.

### 3.7 `From`/`Into` for error conversion

`?` calls `E::into()` to convert error types. Users implement
`From<SubError>` for their `AppError` enum. Stdlib provides standard
conversions.

### 3.8 Composition with RFC-0001

`Option`/`Result` are POD. `match` is straight-line code, no
allocation, no panic (except `unwrap`). Compose cleanly with
`#[no_alloc, no_panic, deadline]`.

### 3.9 Diagnostics

| Code | Meaning |
|---|---|
| MATCH-001 | Non-exhaustive match (missing variants listed) |
| MATCH-002 | Unreachable arm |
| MATCH-003 | Type mismatch between arms |
| MATCH-004 | `?` in a function not returning Result/Option |
| MATCH-005 | `?` error type doesn't `Into` the function's error type |
| MATCH-006 | `unwrap()` in `#[no_panic]` function |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Lexer | `?` operator token | ~20 |
| Parser | `match`, `if let`, `while let`, `?` postfix | ~400 |
| Type checker | Pattern type check + exhaustiveness | ~800 |
| IR | Tagged-union layout for sum types | ~400 |
| Codegen | Match → switch with payload extract | ~500 |
| Stdlib | `option.nr`, `result.nr` with all methods | ~600 |
| Diagnostics | MATCH-001…006 | ~300 |
| **Total** | | **~3020** |

---

## 5. Alternatives considered

- **C-style sentinels** — current; bug-prone; rejected.
- **Exceptions** — runtime cost, no `#[no_panic]` story; rejected.
- **Multiple return values (Go-style)** — better than sentinels but
  no exhaustiveness, no `?` ergonomics; rejected.
- **`try`/`catch`** — heavier syntax; Rust's `?` won this race.

## 6. Open questions

1. `try { … }` block (Rust-experimental) — defer to v0.4.
2. `match` on slices — defer to v0.4 with iterator support.
3. Partial-match warning vs error (`if let` with side effects in the
   "else" path) — recommend warning only.
4. `Option<&T>` ergonomics — `as_deref` etc.; ship per Rust's set.

## 7. Definition of done

- [ ] `Option`/`Result` types ship in stdlib
- [ ] `match` parses, type-checks, codegens with exhaustiveness
- [ ] `?` desugars correctly for both Option and Result
- [ ] `if let` / `while let` work
- [ ] All inherent methods implemented
- [ ] `From`/`Into` traits for error conversion
- [ ] Verify gate green
- [ ] CHANGELOG documents the trio + migration

## 8. Future extensions

- `try { … }` blocks (v0.4)
- Slice patterns (v0.4)
- Or-patterns (`A | B`) (v0.4)
- @-bindings (`name @ pattern`) (v0.4)

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] Compatible with v0.2 schedule
- [ ] LOC budget ~3020 fits
- [ ] Pitch survives ("the Rust-trio that gives 80% of the safety
      ergonomics")
