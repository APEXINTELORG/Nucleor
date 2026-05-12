# RFC-0027 — Explicit Lifetime Parameters

| Field | Value |
|---|---|
| **Number** | 0027 |
| **Title** | Explicit lifetime parameters — `fn f<'a>(x: &'a str) -> &'a str` |
| **Status** | Implemented (parser-only) — lifetime parameters parse cleanly as advisory metadata (T2.5, v0.2.x); the borrow checker does NOT yet enforce them. Full lifetime inference + region analysis deferred to v0.4 / v0.5 follow-up. |
| **Author** | Nucleor maintainers |
| **Created** | 2026-04-22 |
| **Target release** | v0.4.0 |
| **Depends on** | none (extension to existing borrow checker) |

---

## 1. Summary

Add explicit lifetime parameter syntax to function and struct
declarations. The borrow checker already tracks lifetimes; this
exposes them in the type system for cases where elision rules are
insufficient.

```nucleor
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { x } else { y }
}

struct Parser<'src> {
    source: &'src str,
    pos: usize,
}

impl<'src> Parser<'src> {
    fn new(source: &'src str) -> Self { Parser { source, pos: 0 } }
    fn peek(&self) -> Option<&'src str> { self.source.get(self.pos..) }
}

fn longest_static<'a>() -> &'a str { "hello" }   // 'a outlives anything
const STR: &'static str = "compile-time";
```

---

## 2. Motivation

Lifetime elision handles ~70% of cases ("input → output" defaults).
The other 30% need explicit annotations:
- Returning a borrow that ties to a specific input
- Structs that hold borrows
- Trait methods with non-trivial lifetimes
- Static lifetime declarations

Today Nucleor's borrow checker infers basic lifetimes; explicit
annotation is needed for the cases above.

Prior art: Rust (canonical, modern model). Cyclone (research origin).

---

## 3. Design

### 3.1 Lifetime parameter syntax

```nucleor
'a, 'b, 'src, 'static          // lifetime names; lowercase, leading apostrophe
&'a T                          // reference with lifetime
&'a mut T                      // mutable reference with lifetime
fn f<'a, T>(x: &'a T) -> &'a T // generic over lifetime AND type
```

### 3.2 The `'static` lifetime

Built-in. Means "lives for the entire program."
- String literals: `&'static str`
- Const data: `&'static T`

### 3.3 Lifetime bounds

```nucleor
struct Wrapper<'a, T: 'a> { x: &'a T }     // T must live at least as long as 'a
fn f<'a, 'b: 'a>(x: &'a T, y: &'b T)        // 'b outlives 'a
```

### 3.4 Lifetime elision rules (unchanged from v0.1)

When all input lifetimes are inferable and the output is a single
borrow, no annotation needed:

```nucleor
fn first(s: &str) -> &str { ... }      // implied: <'a>(s: &'a str) -> &'a str
fn pair(s: &str, t: &str) -> &str {... } // ERROR (ambiguous; need annotation)
```

For `&self`-methods: output lifetime defaults to `&self`'s lifetime.

### 3.5 Higher-ranked trait bounds

```nucleor
fn apply<F>(f: F) where F: for<'a> Fn(&'a str) -> &'a str { ... }
```

`for<'a>` introduces a universal lifetime quantifier. Defer
implementation polish to v0.5; ship parsing in v0.4.

### 3.6 Composition with `Frame<>` (RFC-0003) and `Allocator` (RFC-0002)

Lifetimes thread through every reference type, including those in
typed-frame and allocator-typed APIs:

```nucleor
fn use_arena<'a>(arena: &'a Arena, items: &'a [Item]) -> Vec<Box<Item, &'a Arena>> { ... }
```

### 3.7 NLL (Non-Lexical Lifetimes)

Borrows end at last use, not at scope end. Simpler than the original
Rust model. Implement via dataflow on the IR. Already partially
present; formalize in this RFC.

### 3.8 Diagnostics

| Code | Meaning |
|---|---|
| LIFE-001 | Cannot infer lifetime; explicit annotation required |
| LIFE-002 | Borrow does not live long enough |
| LIFE-003 | Conflicting lifetime requirements |
| LIFE-004 | `'static` claim not justified |
| LIFE-005 | Higher-ranked bound cannot be inferred |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Parser | `'a` syntax in fn / struct / impl / where | ~250 |
| Type checker | Lifetime variable solving (Polonius-style) | ~1500 |
| Borrow checker | NLL formalized | ~600 |
| Diagnostics | LIFE-001…005 with span-rich output | ~400 |
| **Total** | | **~2750** |

The hardest item in v0.4. Lifetime inference is famously tricky
(Polonius is the modern Rust solver; we model on it).

---

## 5. Alternatives considered

- **Stay with elision-only** — too restrictive for real APIs.
- **Reference counting (Arc)** — defeats purpose; we want the
  zero-cost story.
- **Region inference** (Cyclone-style) — too automatic; users want
  explicit control for non-trivial cases.

## 6. Open questions

1. Borrow-checker design — Polonius vs NLL classic? Recommend Polonius
   from start (more permissive).
2. Lifetime inference for closure captures — Rust has long-standing
   issues; we mostly inherit them.
3. Self-referential structs — Rust forbids; we follow.
4. `'static` promotion of literals — automatic.

## 7. Definition of done

- [ ] Parser accepts all lifetime annotation forms
- [ ] Borrow checker handles cross-fn lifetime constraints
- [ ] NLL works
- [ ] Higher-ranked bounds parse (resolution may be partial in v0.4)
- [ ] CHANGELOG documents

## 8. Future extensions

- Polonius-style permissive borrow checker (full)
- Implicit lifetime captures in `impl Trait`
- GAT (Generic Associated Types) — major; v0.6+

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~2750 fits
- [ ] Borrow-checker test corpus expanded
