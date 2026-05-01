# Upgrading to v0.4.254 — RFC-0006 Design by Contract is LIVE

**TL;DR — Nucleor now has working Design by Contract.** Annotate
fns with `#[require(EXPR)]`, `#[ensure(EXPR)]`, and impl blocks
with `#[invariant(EXPR)]`. Predicates are checked at runtime in
debug builds; strip them out for production via
`NUCLEOR_DBC_MODE=release`. Five of seven CONTRACT-NNN codes
fire end-to-end.

This document covers v0.4.245 → v0.4.254 (the RFC-0006 arc).
For the v0.4.232 → v0.4.241 strict-arithmetic + diagnostic-
quality work, see `UPGRADE_v0.4.241.md`.

## Quick start

```nucleor
struct Counter { value: i64 }

#[invariant(self.value >= 0)]
impl Counter {
    fn new(initial: i64) -> Counter {
        Counter { value: initial }
    }

    #[require(amount > 0)]
    #[ensure(result == old(self.value) + amount)]
    fn add(self: Counter, amount: i64) -> i64 {
        self.value + amount
    }
}

fn main() -> i64 {
    let c: Counter = Counter::new(5);
    let v: i64 = c.add(3);
    print_int(v);
    0
}
```

This program asserts:
- The Counter's `value` never drops below 0 (invariant on entry
  + exit of every `self` method, plus exit of every constructor).
- `add` requires its `amount` parameter to be positive
  (CONTRACT-001 panic if violated).
- `add` ensures its result equals the original `value` plus
  `amount` — referencing the entry-time `self.value` via `old(...)`
  (CONTRACT-002 panic if violated).

If any assertion fails at runtime, the program prints
`CONTRACT-NNN: <message>` and exits 1.

## Three attributes

### `#[require(EXPR)]`

Precondition. Checked on FN ENTRY before the body runs.
Predicate has access to fn parameters.

```nucleor
#[require(divisor != 0)]
fn divide(numerator: i64, divisor: i64) -> i64 {
    numerator / divisor
}
```

Multiple requires per fn are conjuncted (any failure panics):

```nucleor
#[require(x > 0)]
#[require(x < 100)]
fn safe_double(x: i64) -> i64 { x * 2 }
```

A failed require prints
`CONTRACT-001: require precondition violated`.

### `#[ensure(EXPR)]`

Postcondition. Checked on FN EXIT before each `return` or tail-
expression. Predicate has access to fn parameters AND the magic
`result` binding (the return value).

```nucleor
#[ensure(result >= 0)]
fn abs(x: i64) -> i64 {
    if x < 0 { 0 - x } else { x }
}
```

Multiple ensures, mid-body returns, and bare `return;` all work:

```nucleor
#[ensure(result >= 0)]
#[ensure(result < 100)]
fn classify(x: i64) -> i64 {
    if x > 200 { return 50; };       // both ensures fire here
    if x > 100 { return 200; };       // VIOLATES second ensure
    x                                  // tail-return: both ensures fire
}
```

Use `old(EXPR)` to capture an expression's value at fn entry:

```nucleor
#[ensure(result == old(x) + 1)]
fn inc(x: i64) -> i64 { x + 1 }

#[ensure(self.value >= old(self.value))]
fn maybe_inc(self: Counter, n: i64) -> Counter { ... }
```

The compiler walks the predicate text, finds `old(EXPR)` (paren-
balanced, identifier-boundary aware so `old_value` doesn't
match), allocates a snapshot slot per occurrence, and pre-
evaluates the inner expression at fn entry. The predicate's
`old(...)` reads then resolve to a load from the snapshot slot
at fn exit.

A failed ensure prints
`CONTRACT-002: ensure postcondition violated`.

### `#[invariant(EXPR)]`

Struct invariant. Attached to an inherent or trait `impl` block.
The predicate is checked:
- On entry to every method whose first param is `self`.
- On exit from every such method (catches mutations).
- On exit from every constructor — fns whose first param is NOT
  `self` AND whose return type matches the impl's parent type
  (or is `Self`).

```nucleor
struct Counter { value: i64 }

#[invariant(self.value >= 0)]
impl Counter {
    fn new(initial: i64) -> Counter {     // ctor — exit-only check
        Counter { value: initial }
    }
    fn get(self: Counter) -> i64 {        // method — entry + exit
        self.value
    }
}
```

A failed invariant prints
`CONTRACT-003: invariant violated`.

## Build-mode strip-out — `NUCLEOR_DBC_MODE`

Set the env var at compile time:

| `NUCLEOR_DBC_MODE` | require | ensure | invariant | Use case |
|---|---|---|---|---|
| `debug` (default) / unset | ✅ | ✅ | ✅ | Development; full safety |
| `safe-release` | ✅ | ❌ | ❌ | Production; only critical preconds |
| `release` | ❌ | ❌ | ❌ | Production; full perf, contracts as docs |
| `cert` | ❌ | ❌ | ❌ | Currently same as release; static-proof analysis is a future ship |

Example:

```bash
# Debug: every contract fires.
nucleor build src.nr -o app

# Release: zero contract overhead.
NUCLEOR_DBC_MODE=release nucleor build src.nr -o app

# Safe-release: keep input validation, drop output / structural checks.
NUCLEOR_DBC_MODE=safe-release nucleor build src.nr -o app
```

Skipping is at the COMPILER level — no LLVM intrinsic calls, no
panic strings, no `__nucleor_contract_*` declares get into the
output binary in release mode. Adopters get exactly the
performance characteristics they would write by hand without
contract checks.

## Migration patterns

### From `if !cond { panic("..."); }` to `#[require]`

Pre-RFC-0006 pattern:

```nucleor
fn safe_div(num: i64, den: i64) -> i64 {
    if den == 0 { panic("denominator was zero"); };
    num / den
}
```

v0.4.254+ idiom:

```nucleor
#[require(den != 0)]
fn safe_div(num: i64, den: i64) -> i64 {
    num / den
}
```

The contract version:
- Surfaces the precondition in the fn signature where adopters
  can see it without reading the body.
- Auto-strips in release builds (faster).
- Provides the canonical CONTRACT-001 message for tooling that
  parses runtime panics.

### From manual postcondition assert to `#[ensure]`

Pre-RFC-0006:

```nucleor
fn parse_int(s: str) -> i64 {
    let n: i64 = ... ;
    assert!(n >= 0);
    n
}
```

v0.4.254+:

```nucleor
#[ensure(result >= 0)]
fn parse_int(s: str) -> i64 {
    let n: i64 = ... ;
    n
}
```

### Maintaining struct invariants with `#[invariant]`

Pre-RFC-0006: scattered checks inside every method body.

v0.4.254+: single declaration on the impl block; compiler emits
checks automatically on all methods + constructors.

```nucleor
#[invariant(self.balance >= 0 && self.transactions.len() < self.tx_limit)]
impl Account { ... }
```

## What's not in v0.4.254

These spec items are deferred until a future static-analysis pass
ships:

- **Liskov inheritance checks** (CONTRACT-004 — impl-method
  weakens precondition; CONTRACT-005 — impl-method strengthens
  postcondition). Trait impls can currently violate Liskov
  silently. Affects soundness if you rely on trait contracts at
  the interface level.
- **`cert` profile static proof** (CONTRACT-007). The `cert`
  build mode currently behaves identically to `release` — it
  strips runtime checks but doesn't yet run a static-proof pass
  to verify them. Adopters targeting safety-cert workloads
  should stay on `safe-release` or `debug` until the static
  pass ships.

## Reference

- RFC: `docs/rfcs/RFC-0006-design-by-contract.md`
- CONTRACT-001..007 codes: `docs/spec/Nucleor_Error_Codes.md`
- Per-ship CHANGELOG entries: v0.4.244 (substrate) → v0.4.254
  (last ensure gap)
- Fixtures (working examples to copy from):
  - `tests/features/rfc0006_require_basic.nr`
  - `tests/features/rfc0006_ensure_basic.nr`
  - `tests/features/rfc0006_ensure_midbody.nr`
  - `tests/features/rfc0006_invariant_basic.nr`
  - `tests/features/rfc0006_invariant_ctor.nr`
  - `tests/features/rfc0006_old_expr.nr`
  - `tests/features/rfc0006_multi_attrs.nr`

## CHANGELOG window

```
v0.4.244 — substrate scanner for #[require(EXPR)]
v0.4.245 — #[require] LIVE (CONTRACT-001)
v0.4.246 — #[ensure] tail returns LIVE (CONTRACT-002)
v0.4.247 — #[ensure] mid-body returns
v0.4.248 — #[invariant] entry-emit on self-methods (CONTRACT-003)
v0.4.249 — #[invariant] exit-emit on every self-method
v0.4.250 — multiple #[require] / #[ensure] per fn
v0.4.251 — old(expr) snapshot in #[ensure]
v0.4.252 — NUCLEOR_DBC_MODE strip-out (debug/safe-release/release/cert)
v0.4.253 — #[invariant] constructor exit-emit
v0.4.254 — mid-body return multi-ensure (closes ensure coverage)
```
