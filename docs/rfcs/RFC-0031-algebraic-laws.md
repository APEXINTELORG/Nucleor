# RFC-0031 — Algebraic Laws as a Verified Rewrite System

| Field | Value |
|---|---|
| **Number** | 0031 |
| **Title** | Algebraic laws — `@law` as runtime-checkable + property-test-generable + SMT-provable |
| **Status** | Draft |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.5.0 |
| **Depends on** | RFC-0021 (test framework — for property tests) |

---

## 1. Summary

Today `@law(commutative, associative, identity=0)` annotations drive
the optimizer's algebraic-rewriting pass. This RFC promotes them to
**verified rewrites** — each declared law generates:

1. A property test (run with `nuc test --check-laws`)
2. An optimizer-pass entry (existing)
3. A documentation entry (auto)
4. (Optional) An SMT proof obligation in `--profile=cert`

```nucleor
@law(commutative, associative, identity = 0)
fn add(a: f64, b: f64) -> f64 { a + b }

#[test]
fn check_my_laws() {
    // Auto-generated:
    // - assert(add(a, b) == add(b, a)) for ~1000 random pairs
    // - assert(add(add(a, b), c) == add(a, add(b, c)))
    // - assert(add(a, 0) == a)
}
```

A rewrite the compiler depends on is now also one the user can
verify. Closes the trust loop.

---

## 2. Motivation

Today `@law` is user-asserted; the optimizer takes the user's word.
If the user mis-states (e.g., float subtraction is NOT associative),
the optimizer produces wrong results.

Promoting `@law` to verifiable closes this gap. Plus: nobody else
has user-declared algebraic laws driving codegen + verification. It's
a Nucleor-unique feature, worth investment.

---

## 3. Design

### 3.1 The `@law` set (existing)

```
@law(commutative)       // f(a, b) == f(b, a)
@law(associative)       // f(f(a, b), c) == f(a, f(b, c))
@law(identity = E)      // f(a, E) == a AND f(E, a) == a
@law(idempotent)        // f(a, a) == a
@law(distributive_over = g)   // f(a, g(b, c)) == g(f(a, b), f(a, c))
@law(inverse = g)       // g(f(a)) == a
@law(zero = Z)          // f(a, Z) == Z
```

### 3.2 Property-test generation

For each law, the compiler synthesizes a test that:
- Generates ~1000 random inputs (driven by user-supplied or
  type-default `Arbitrary` impl)
- Asserts the law holds within a tolerance (configurable for floats
  via `@law(... eps = 1e-12)`)

```nucleor
@law(commutative, eps = 1e-9)
fn dot(a: Vec3, b: Vec3) -> f64 { ... }

// Generated test:
#[test]
fn __law_commutative_dot() {
    for _ in 0..1000 {
        let a = Vec3::arbitrary();
        let b = Vec3::arbitrary();
        let lhs = dot(a, b);
        let rhs = dot(b, a);
        assert!((lhs - rhs).abs() < 1e-9);
    }
}
```

### 3.3 Run with `nuc test --check-laws`

Filters to law-generated tests:

```
$ nuc test --check-laws
  __law_commutative_add ........ ok
  __law_associative_add ........ ok
  __law_identity_add ........... ok
  __law_commutative_dot ........ ok
  __law_associative_dot ........ FAILED
    failed at iteration 437:
      lhs = 1.0000000000000002
      rhs = 0.9999999999999998
      diff = 4e-16  > eps 1e-12

test result: 4 passed; 1 failed
```

User can adjust `eps`, mark the law `@law(approximate)`, or remove
the false claim.

### 3.4 SMT-backed proof (cert profile)

In `--profile=cert`, declared laws must be **proven**, not just
property-tested. We integrate **Z3** (or **CVC5**) as an optional
backend:

```
nuc check --profile=cert
  proving __law_commutative_add ........ proven
  proving __law_associative_add ........ proven
  proving __law_commutative_dot ........ proven
  proving __law_associative_dot ........ DISPROVED
    counterexample: a = ..., b = ..., c = ...
```

For provable laws (integer arithmetic, Boolean algebra), Z3 produces
a proof. For inherently-non-provable laws (float associativity),
the user must either remove the claim or mark `@law(approximate)`
which downgrades to property-test-only.

### 3.5 Optimizer interaction

Optimizer's algebraic-rewriting pass already consumes `@law`. No
change to that pass; just adds the test+proof side.

In `--profile=cert`, optimizer rewrites are restricted to
**proven** laws only. This blocks float-arithmetic rewrites in cert
mode (already the safe default).

### 3.6 Documentation

`nuc doc` (RFC-0029) includes a "Laws" section per `@law`-annotated
function:

```
fn add(a: f64, b: f64) -> f64
  Laws:
    - commutative: add(a, b) == add(b, a)  [property-tested]
    - associative: add(add(a, b), c) == add(a, add(b, c))  [property-tested]
    - identity = 0: add(a, 0) == a  [PROVEN under integer assumption]
```

### 3.7 Diagnostics

| Code | Meaning |
|---|---|
| LAW-001 | Property test fails (with counterexample) |
| LAW-002 | SMT disproves law (cert profile) |
| LAW-003 | Law cited but optimizer cannot use it (signature mismatch) |
| LAW-004 | Float operation claimed exact associative (warn) |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Property-test synthesizer | From `@law` to `#[test]` body | ~600 |
| `Arbitrary` trait + impls for primitives | Stdlib | ~400 |
| Z3 / CVC5 integration (cert profile) | Subprocess + SMT-LIB encoding | ~800 |
| `nuc test --check-laws` flag | CLI | ~80 |
| Doc generator extension | Laws in doc HTML | ~150 |
| Diagnostics | LAW-001…004 | ~200 |
| **Total** | | **~2230** |

---

## 5. Alternatives considered

- **Stay user-asserted (current)** — soundness gap stays open.
- **Always-on property tests** — slow; opt-in flag.
- **Skip SMT** — covers most but misses cert path.

## 6. Open questions

1. Z3 binary distribution — bundle vs require separate install?
   Recommend bundle (~30 MB).
2. Default property-test count — 1000 reasonable; configurable.
3. `@law(...)` for trait methods — yes, applies to all impls.
4. Random seed — fixed-default for reproducibility.

## 7. Definition of done

- [ ] All law forms generate property tests
- [ ] `Arbitrary` trait shipped for primitives, Vec, Option, Result,
      tuples
- [ ] Z3 integration works for integer / Boolean laws
- [ ] CHANGELOG documents

## 8. Future extensions

- User-defined `Arbitrary` derive (`#[derive(Arbitrary)]`)
- Coverage-guided property testing (a la AFL)
- Lemma database — accumulate proven laws across the project
- Custom law constructors (`@law(my_special_law(args))`)

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~2230 fits
- [ ] Pitch survives ("verified algebraic rewrites — Nucleor's
      unique advantage made bulletproof")
