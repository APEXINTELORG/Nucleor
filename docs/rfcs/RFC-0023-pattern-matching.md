# RFC-0023 — Rich Pattern Matching

| Field | Value |
|---|---|
| **Number** | 0023 |
| **Title** | Rich pattern matching — ranges, guards, nested destructure, `|` or-patterns, `@`-bindings, slice patterns |
| **Status** | Implemented (partial) — range patterns `1..=9` / `1..10` shipped (T2.1, v0.2.x); int-literal + wildcard or-patterns (`A \| B \| _ => ...`) shipped v0.4.49 (T3.94); guards / slice / enum-and-binding or-patterns / `@`-bindings deferred to v0.4 / v0.5 follow-up |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.4.0 |
| **Depends on** | RFC-0016 (basic match) |

---

## 1. Summary

Extend RFC-0016's basic `match` to the full Rust-class pattern
language:

```nucleor
match (status, count) {
    (Status::Active, n) if n > 100  => high_load(),
    (Status::Active, 0..=100)       => normal(),
    (Status::Active | Status::Idle, _) => active_or_idle(),
    (Status::Failed, _)              => fail(),
    _                                => unknown(),
}

match arr {
    [first, .., last]               => first_and_last(first, last),
    [single]                        => one_element(single),
    []                              => empty(),
    [a, b, rest @ ..]              => head_and_rest(a, b, rest),
}

match config {
    Config { kind: K::Web, port: 80 | 443, .. }  => web_default(),
    Config { kind: K::Db, port, .. } if port > 1024 => db_alt(port),
    _ => use_default(),
}
```

---

## 2. Motivation

Basic match (RFC-0016) handles enums, but real code wants:
- **Ranges** (`0..=100`, `'a'..='z'`)
- **Or-patterns** (`A | B | C`)
- **Guards** (`if cond` after pattern)
- **`@`-bindings** (`name @ pattern`)
- **Slice patterns** (`[a, .., last]`)
- **Nested destructure** (struct-in-tuple-in-enum)

Rust's pattern language is the gold standard. We ship the same.

---

## 3. Design

### 3.1 Range patterns

```nucleor
match c {
    '0'..='9' => "digit",
    'a'..='z' | 'A'..='Z' => "letter",
    _ => "other",
}
```

Inclusive (`..=`) and exclusive (`..`) range patterns. Half-open
(`a..` or `..b`) for some types.

### 3.2 Or-patterns

```nucleor
match x {
    1 | 2 | 3 => "small",
    n if n < 100 => "medium",
    _ => "large",
}

// Within destructure
match opt {
    Some(0) | Some(1) => "low",
    Some(n) => format!("{}", n),
    None => "none",
}
```

### 3.3 `@`-bindings

```nucleor
match x {
    n @ 1..=10 => use_n(n),         // bind n AND match range
    msg @ Message::Error { code, .. } => log!("{} ({})", msg, code),
}
```

### 3.4 Slice / array patterns

```nucleor
match v.as_slice() {
    [] => "empty",
    [x] => format!("one: {}", x),
    [first, .., last] => format!("{}..{}", first, last),
    [a, b, c, rest @ ..] => format!("3+{}", rest.len()),
}
```

### 3.5 Reference patterns

```nucleor
let v = vec![1, 2, 3];
match v.first() {
    Some(&n) => use_value(n),     // copy out of &T
    None => default(),
}
```

### 3.6 Struct destructure with `..`

```nucleor
struct Point3 { x: f64, y: f64, z: f64 }
match p {
    Point3 { x: 0.0, .. } => "x-axis intercept",
    Point3 { x, y, .. } => format!("({}, {})", x, y),
}
```

### 3.7 Nested patterns

```nucleor
enum Event {
    Click(Position),
    Key(KeyCode),
}
struct Position { x: i32, y: i32 }

match event {
    Event::Click(Position { x: 0, y }) => left_edge(y),
    Event::Click(p) => any_click(p),
    Event::Key(KeyCode::Escape) => close(),
    Event::Key(_) => other_key(),
}
```

### 3.8 Exhaustiveness checking

Compiler enforces all variants/values covered. Range patterns
participate — `0..=255` for `u8` is exhaustive. Witness generation:
on non-exhaustive, compiler shows an example uncovered value.

### 3.9 Diagnostics

| Code | Meaning |
|---|---|
| MATCH-007 | Range pattern bounds in wrong order (`5..=1`) |
| MATCH-008 | Or-pattern arms have different bindings |
| MATCH-009 | Slice pattern overlaps (multiple `..`) |
| MATCH-010 | `@`-binding name collides with outer scope |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Parser | Range / or / @ / slice patterns | ~400 |
| Type checker | Pattern type check, exhaustiveness with ranges | ~600 |
| Codegen | Decision-tree compilation | ~500 |
| Diagnostics | MATCH-007…010 + improved exhaustiveness messages | ~250 |
| **Total** | | **~1750** |

---

## 5. Alternatives considered

- **Stay with basic match** — useful but doesn't compete with Rust.
- **Switch-style only (no ranges/guards)** — C-tier; rejected.

## 6. Open questions

1. `if let` chains (`if let Some(a) = x && let Some(b) = y`) — defer
   to v0.5.
2. Reference patterns ergonomics (`ref` keyword vs `&`) — Rust's
   model is awkward; reconsider.
3. Float pattern matching — Rust deprecated; recommend skip.

## 7. Definition of done

- [ ] All pattern forms parse, type-check, codegen
- [ ] Exhaustiveness with ranges works correctly
- [ ] CHANGELOG documents

## 8. Future extensions

- if let chains (v0.5)
- Box patterns (Rust unstable)
- Type ascription patterns

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~1750 fits
