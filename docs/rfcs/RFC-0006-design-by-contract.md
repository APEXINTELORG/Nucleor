# RFC-0006 — Design by Contract: `#[require]` / `#[ensure]` / `#[invariant]`

| Field | Value |
|---|---|
| **Number** | 0006 |
| **Title** | Design by Contract — `#[require(pre)]`, `#[ensure(post)]`, `#[invariant(inv)]` |
| **Status** | Draft |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.5.0 ("Production Robotics") |
| **Depends on** | RFC-0001 (attribute infra), RFC-0004 (`assume!` is the lightweight form) |

---

## 1. Summary

Add three attributes for full design-by-contract:

```nucleor
#[require(arr.len() >= 12)]
#[ensure(result >= 0.0)]
fn norm(arr: &[f64]) -> f64 {
    let mut s: f64 = 0.0;
    for x in arr { s += x * x; }
    sqrt(s)
}

#[require(0 <= idx && idx < CAP)]
fn write_slot(buf: &mut [f64; CAP], idx: usize, val: f64) {
    buf[idx] = val;
}

struct Pid {
    kp: f64, ki: f64, kd: f64,
    integral: f64,
    last_err: f64,
}

#[invariant(self.kp >= 0.0 && self.ki >= 0.0 && self.kd >= 0.0)]
impl Pid { ... }
```

**Caller-side** runtime checks for `#[require]` (preconditions),
**callee-side** checks for `#[ensure]` (postconditions), and
**method-entry/exit** checks for `#[invariant]` (struct invariants).
Behavior per profile:

| Profile | Enforcement |
|---|---|
| `debug` | All checks active; violation aborts with diagnostic |
| `release` | Checks elided; predicates serve as `assume!` for the optimizer |
| `safe-release` | Critical checks (require) active; ensure/invariant elided |
| `cert` | Checks must be statically proven |

This is the **full version** of RFC-0004's `assume!` — DbC enforces
**caller obligations** that `assume!` cannot.

---

## 2. Motivation

`assume!` (RFC-0004) is intra-function. It says "trust me, this
holds inside this function." It cannot say "the caller must ensure
this." Real APIs need the latter: `Vec::get_unchecked(i)` is unsafe
unless the caller guarantees `i < len`.

DbC is a 50-year-old idea (Eiffel, then SPARK, then C++ contracts
proposal, then Rust contracts crate). The hard part is making it
ergonomic and integrated with the language's type system. Nucleor
ships it as first-class because it's the natural extension of
RFC-0001's other compile-time-checked properties.

Prior art:
- **Eiffel** — original DbC language (Bertrand Meyer)
- **SPARK Ada** — formally proven contracts
- **C++26 contracts** — stalled; proposed but not standardized
- **Rust contracts crate** — third-party; runtime-checked
- **Dafny / F\* / Kani** — verification-driven

---

## 3. Design

### 3.1 The three attributes

| Attribute | Semantics |
|---|---|
| `#[require(p)]` | **Caller obligation**. Predicate evaluated at call site BEFORE call. |
| `#[ensure(p)]` | **Callee obligation**. Predicate evaluated AFTER body, before return. `result` and `old(expr)` available. |
| `#[invariant(p)]` | **Struct/impl obligation**. Predicate evaluated on entry to AND exit from every public method. |

### 3.2 `#[require(p)]`

```nucleor
#[require(arr.len() >= 12)]
fn process(arr: &[f64]) { ... }

fn caller(v: &Vec<f64>) {
    process(v);    // INSERT runtime check: assert!(v.len() >= 12)
}
```

In `debug`/`safe-release`: emit `if !p { panic!("require violated"); }`
at the call site.

In `release`: emit `llvm.assume(p)` to give the optimizer the
information without runtime cost. **Caller assumes the predicate
holds.** If it doesn't, undefined behavior.

In `cert`: refuse to compile unless `p` provably holds at call site.

### 3.3 `#[ensure(p)]`

```nucleor
#[ensure(result >= 0.0)]
#[ensure(old(arr.len()) == arr.len())]   // arr length unchanged
fn norm(arr: &[f64]) -> f64 { ... }
```

`result` is the return value. `old(expr)` captures expression value
at function entry — useful for postconditions about how state changed.

In `debug`/`safe-release`: emit assertion at function exit (before
return).

In `release`: elided.

### 3.4 `#[invariant(p)]`

Applied to a struct's `impl` block:

```nucleor
struct Counter { value: i32 }

#[invariant(self.value >= 0)]
impl Counter {
    pub fn new() -> Self { Counter { value: 0 } }
    pub fn inc(&mut self) { self.value += 1; }
    pub fn dec(&mut self) {
        if self.value > 0 { self.value -= 1; }
    }
}
```

Invariant checked on:
- Exit from every constructor (`new`, etc. — fns returning `Self`)
- Entry to every method taking `self` / `&self` / `&mut self`
- Exit from every method modifying `self`

### 3.5 Inheritance / refinement

Subtype contracts may not weaken preconditions or strengthen
postconditions (Liskov substitution). For Nucleor — no inheritance
(traits are structural), so `impl Trait for Type` must satisfy all
contracts on the trait declaration.

```nucleor
trait Norm {
    #[ensure(result >= 0.0)]
    fn norm(&self) -> f64;
}

impl Norm for Vec<f64> {
    fn norm(&self) -> f64 { ... }   // INHERITS the #[ensure]
}
```

### 3.6 Composition with RFC-0004 `assume!`

`assume!` and DbC are complementary:
- `assume!` — intra-function, lightweight
- DbC — across function boundaries, heavyweight

A function with `#[require(p)]` can use `assume!(p)` internally —
since the precondition holds, the assume is justified by the
require. The compiler can desugar this automatically.

### 3.7 Composition with RFC-0001 attributes

`#[no_panic]` interacts with DbC tricky:
- `#[require(p)]` checks may panic on violation — but only in debug.
  In release, no check, no panic.
- A `#[no_panic, require(p)]` function: the entry check is elided in
  release; the function is no-panic *if* the caller satisfies the
  require.

The compiler treats `#[require]` checks as part of the calling
convention; they live "outside" the no-panic body.

### 3.8 Diagnostics

| Code | Meaning |
|---|---|
| CONTRACT-001 | Require violation at runtime (debug-mode trap) |
| CONTRACT-002 | Ensure violation at runtime |
| CONTRACT-003 | Invariant violation |
| CONTRACT-004 | Trait impl weakens precondition (Liskov) |
| CONTRACT-005 | Trait impl strengthens postcondition (Liskov) |
| CONTRACT-006 | `old(expr)` references mutable state without snapshot |
| CONTRACT-007 | In `cert` profile, contract not statically provable |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Parser | `#[require]`, `#[ensure]`, `#[invariant]`, `old(expr)` | ~250 |
| Type checker | Liskov check for trait impls | ~200 |
| Codegen | Insert checks per profile; emit `llvm.assume` in release | ~300 |
| Stdlib | Audit existing rods; add contracts where useful | ~500 (incremental) |
| Diagnostics | CONTRACT-001…007 | ~250 |
| **Total** | | **~1500** |

---

## 5. Alternatives considered

- **`assume!` only** (RFC-0004) — insufficient; can't express caller
  obligations.
- **Runtime-checked-only contracts** — same overhead as user-written
  asserts; no analysis benefit. Rejected.
- **Verification-driven (Dafny/F\*-style)** — too heavy for v0.5.
  `cert` profile in v0.7 closes this.

## 6. Open questions

1. `old(expr)` for mutable state — copy entire `&mut self`? Recommend
   yes for simple cases, error if the snapshot is too expensive.
2. Should `#[invariant]` extend to private methods? Recommend no —
   private methods can temporarily violate.
3. Per-call-site disable (`#[allow(contract_check)]`)? Recommend yes
   for hot loops where check overhead matters even in debug.
4. Generic-over-contract — let trait define contract once, impls
   inherit? Yes per §3.5.
5. Compose with `assume!` in fn body? Yes — desugar automatically.

## 7. Definition of done

- [ ] Three attributes parse, type-check, codegen
- [ ] `old()` capture works
- [ ] Liskov check rejects bad trait impls
- [ ] All four profiles (`debug`/`release`/`safe-release`/`cert`)
      behave as specified
- [ ] CHANGELOG + a contracts user guide

## 8. Future extensions

- Quantified contracts (`forall i in 0..n: arr[i] > 0`) — v0.7
- Loop invariants (`while ... #[invariant(p)]`) — v0.7
- Frame conditions (modifies clauses) — v0.8

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] Compatible with v0.5 schedule
- [ ] LOC budget ~1500 fits
- [ ] Pitch survives ("contracts as first-class language feature, four
      enforcement profiles, integrates with assume! and Liskov")
