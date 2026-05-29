# RFC-0032 — Effects System (resurrect V1 quarantine)

| Field | Value |
|---|---|
| **Number** | 0032 |
| **Title** | Effects system — `pure fn`, `requires [io.read]`, `restricts [...]` |
| **Status** | Draft |
| **Author** | Nucleor maintainers |
| **Created** | 2026-04-22 |
| **Target release** | v0.6.0 |
| **Depends on** | RFC-0001, RFC-0031 (laws + effects compose) |

---

## 1. Summary

Resurrect the V1-quarantined effects syntax (currently in
`tests/err/_unimplemented/err_pure_*`, `err_effect_*`,
`err_restricts_*`). Adds compile-time tracking of side effects:

```nucleor
pure fn fib(n: u32) -> u64 { ... }       // no side effects, deterministic

fn read_config(path: &str) -> Result<Config> requires [io.read] { ... }

fn pure_compute(x: f64) -> f64 restricts [io, alloc] { x * 2.0 }
```

The compiler checks:
- `pure fn` cannot call effectful fn
- `requires [io.read]` propagates to callers
- `restricts [...]` rejects callees with the listed effects

**Stronger than RFC-0001 RT attributes** — those track concrete
operations (alloc, panic); effects track logical capabilities (io,
network, random, time).

Koka, Eff, Frank — this is the modern research direction. Nucleor
shipping it is a real Tier-3 differentiator.

---

## 2. Motivation

V1 design intended this; never landed. The 12 quarantined tests
prove the spec was specified at code-level. The stale runtime never
implemented it.

For robotics: `pure fn` over `tainted<T>` validates messages without
side effects — composes cleanly with the safety story.

For ML: `pure fn` policy inference cannot accidentally log /
allocate / sleep — composes cleanly with `#[deadline]`.

---

## 3. Design

### 3.1 Effect rows

Each function carries an effect row:

```nucleor
fn f(x: i32) -> i32 + io.read + alloc { ... }
fn g(x: i32) -> i32                          // pure (empty effect row)
pure fn h(x: i32) -> i32                      // explicit pure declaration
```

Effects in stdlib:
- `io` (read, write, network, file)
- `alloc` (any allocator)
- `random` (PRNG access)
- `time.read` (clock query)
- `time.sleep` (blocking on time)
- `panic` (may panic)
- `unsafe` (unsafe ops)
- `mut.<resource>` (mutates named resource)

Custom effects: users declare `effect MyEffect { ... }` (declaration
only; no handlers in v0.6 — effect handling is v0.7+).

### 3.2 `pure` keyword

Equivalent to `+ {}`. Function has no side effects, is
deterministic. Same input → same output.

```nucleor
pure fn add(a: i32, b: i32) -> i32 { a + b }
pure fn dot(v: Vec3, w: Vec3) -> f64 { ... }
```

### 3.3 `requires` clause

Declares effects the function uses. Caller must permit them.

```nucleor
fn read_config(path: &str) -> Result<Config> requires [io.read] {
    let bytes = read_file(path)?;          // read_file requires io.read
    parse(&bytes)
}
```

### 3.4 `restricts` clause

Forbids listed effects in the callee. Useful for callbacks:

```nucleor
fn map<T, U, F>(items: &[T], f: F) -> Vec<U>
    where F: Fn(&T) -> U restricts [io]    // f cannot do IO
```

### 3.5 Inference

Like RFC-0001's attributes, effects are **inferred** for unannotated
functions. A function whose body uses `read_file` is implicitly
`+ io.read`. Callers see the inferred row.

Explicit annotation is preferred for public APIs (locks the
contract).

### 3.6 Composition with RFC-0001

Effect rows compose with RT attributes:

| Attribute / Effect | Implies |
|---|---|
| `#[no_alloc]` | `restricts [alloc]` |
| `#[no_panic]` | `restricts [panic]` |
| `pure fn` | `restricts [io, alloc, random, time, panic, unsafe]` |

So `pure fn` is approximately the strictest combo:
`#[no_alloc, no_panic]` + no IO + no time + no randomness +
deterministic.

### 3.7 Composition with `tainted<T>`

```nucleor
pure fn validate(t: tainted<Pose>) -> Result<Pose, ValidationError> { ... }
```

Pure validation strips taint; result is trustworthy. The compiler
can prove the validation is side-effect-free.

### 3.8 Composition with RFC-0031 (laws)

Algebraic laws on `pure fn` are SMT-provable (no side effects to
worry about). Property tests run cleanly.

`@law(commutative)` on a non-pure function is a warning — laws are
ill-defined when side effects exist.

### 3.9 Diagnostics

| Code | Meaning |
|---|---|
| EFF-001 | Function uses effect not in its declared row |
| EFF-002 | `pure fn` calls effectful fn |
| EFF-003 | `restricts [...]` violated |
| EFF-004 | Effect declared but not used (warning) |
| EFF-005 | Custom effect handler missing (v0.7+) |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Parser | `pure fn`, `+ effect_row`, `requires`, `restricts` | ~300 |
| Type checker | Effect inference + propagation + check | ~700 |
| Stdlib | Effect annotations on every fn | ~500 (rod-days) |
| Diagnostics | EFF-001…005 | ~200 |
| **Total** | | **~1700** |

---

## 5. Alternatives considered

- Stay with quarantine — leaves V1 design unfinished.
- Effect handlers (Koka full system) — too heavy for v0.6;
  ship row-typing only, defer handlers to v0.7+.
- Capability-based (Eff style) — equivalent power, different
  surface; row-typing is more familiar.

## 6. Open questions

1. Effect polymorphism (`fn f<E>(g: fn() -> () + E) -> () + E`) —
   ship.
2. Effect aliases (`type Net = io.network.read + io.network.write`)
   — yes.
3. Default effect row when annotation missing — inferred; warn on
   public API.
4. Effect handlers (Koka-style algebraic effects) — defer to v0.7.

## 7. Definition of done

- [ ] All effect syntax parses, type-checks
- [ ] All 12 V1 quarantined effect tests un-quarantined
- [ ] Stdlib audited for effect annotations
- [ ] CHANGELOG documents

## 8. Future extensions

- Effect handlers (v0.7)
- User-defined effect declarations + impls
- Effect-driven optimization (already partial; expand)
- Effect-typed I/O monads for testability

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~1700 fits
- [ ] Pitch survives ("Koka-style effects, pure fn first-class,
      no other systems language has this")
