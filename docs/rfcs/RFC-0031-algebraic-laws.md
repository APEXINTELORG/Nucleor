# RFC-0031 — Algebraic Laws as a Verified Rewrite System

| Field | Value |
|---|---|
| **Number** | 0031 |
| **Title** | Algebraic laws — `@law` as runtime-checkable + property-test-generable + SMT-provable |
| **Status** | Draft |
| **Author** | Nucleor maintainers |
| **Created** | 2026-04-22 |
| **Target release** | v0.5.0 |
| **Depends on** | RFC-0021 (test framework — for property tests) |

---

## 1. Summary

Today `@law(commutative, associative, identity=0)` annotations are
captured and surfaced as algebraic-law metadata. The optimizer has a
metadata-only law pass scaffold; user-law-driven rewrites, generated
property tests, and SMT proof obligations are reserved for later phases.
This RFC promotes the metadata into **verified rewrites** - each declared
law will generate:

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

Current implementation status: Phase 1 capture/scaffold work is in tree
and must remain part of the build path. The tools-suite test driver now
ships a bounded integer `nuc test --check-laws` slice for low-risk forms
(`commutative`, `associative`, `identity`, `absorbing`, `idempotent`,
`involution`, `distributive_over`) plus schema hard errors for deprecated
aliases, unsupported canonical forms, float/approximate modifiers, and
unknown law names. Optimizer rewrites, Arbitrary-driven broad property
tests, float-law tolerance, and SMT proof obligations remain
implementation work, not a deletion of the feature.

---

## 2. Motivation

Today `@law` is user-asserted metadata. It does not drive user-law
rewrites yet, so a misstated law cannot currently rewrite code, but it
also gives no property-test or proof guarantee.

Promoting `@law` to verifiable closes this gap. The target feature is
user-declared algebraic laws driving codegen plus verification.

---

## 3. Design

### 3.1 The `@law` set (canonical schema, v0.8.264)

The canonical schema below supersedes earlier informal usage.
`docs/language-reference.md`, this RFC, and `tests/attrs/laws.nr` all
agree on these names. The single source of truth is
`docs/spec/Nucleor_Algebraic_Laws_Schema.md`.

```
@law(commutative)             // f(a, b) == f(b, a)
@law(associative)             // f(f(a, b), c) == f(a, f(b, c))
@law(identity = E)            // f(a, E) == a AND f(E, a) == a
@law(idempotent)              // f(a, a) == a
@law(involution)              // f(f(a)) == a   (special case of inverse=f)
@law(absorbing = Z)           // f(a, Z) == Z AND f(Z, a) == Z
@law(distributive_over = g)   // f(a, g(b, c)) == g(f(a, b), f(a, c))
@law(inverse = g)             // g(f(a)) == a   (general inverse)
@law(fusion)                  // (f ∘ g) ∘ h == f ∘ (g ∘ h) for composable maps
```

**Renames effective v0.8.264** (R14-D5 canonical schema lock):

| Pre-canonical alias | Canonical | Reason |
|---|---|---|
| `zero = Z` | `absorbing = Z` | aligns with language-reference and existing test fixtures; "absorbing" is the standard universal-algebra term |
| `distributive` (bare) | `distributive_over = g` | the partner operator is required for the law to mean anything |

`nuc test --check-laws` emits clear diagnostics on the alias spellings
(`LAW-006`, `LAW-007`) and unknown law names (`LAW-008`). The regular
compile path still captures and reports `@law(...)` metadata without
rejecting aliases, preserving backward-compatible source parsing.

### 3.2 Property-test generation

The shipped bounded integer slice synthesizes tests for low-risk
primitive law forms without requiring the future `Arbitrary` trait:

- `commutative`
- `associative`
- `identity = E`
- `absorbing = Z`
- `idempotent`
- `involution`
- `distributive_over = g`

The full target remains: for each law, the compiler synthesizes a test that:
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

Generates law-check functions and runs them through the normal test
harness:

```
$ nuc test examples/laws.nr --check-laws
info[CHECK-LAWS]: generated bounded integer law checks
  discovered tests: 2
    __nucleor_law_check_0
    __nucleor_law_check_1
  PASS: __nucleor_law_check_0
  PASS: __nucleor_law_check_1
test result: PASS (2 tests)
```

On a generated counterexample the test emits `error[LAW-001]` and exits
nonzero. User can remove the false claim, adjust the function, or wait
for the broader `eps` / `approximate` property-test phase when the law
is intentionally approximate.

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

The current optimizer has a metadata-only `@law` pass scaffold. Later
phases must wire captured law metadata into actual rewrites, then add
the test/proof side.

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
| LAW-001 | Generated law check fails or declared law has incompatible arity |
| LAW-002 | SMT disproves law (cert profile) |
| LAW-003 | Law cited but optimizer cannot use it (signature mismatch) |
| LAW-004 | Float operation claimed exact associative (warn; future cert/profile phase) |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Bounded integer law-check synthesizer | Shipped low-risk subset behind `nuc test --check-laws` | ~300 |
| Property-test synthesizer | From `@law` to `#[test]` body | ~600 |
| `Arbitrary` trait + impls for primitives | Stdlib | ~400 |
| Z3 / CVC5 integration (cert profile) | Subprocess + SMT-LIB encoding | ~800 |
| `nuc test --check-laws` flag | CLI | shipped for bounded integer subset |
| Doc generator extension | Laws in doc HTML | ~150 |
| Diagnostics | LAW-001, LAW-004, LAW-006, LAW-007, LAW-008 shipped for `--check-laws`; LAW-002/003 future | ~200 |
| **Total** | | **~2230** |

---

## 5. Alternatives considered

- Stay user-asserted (current) — soundness gap stays open.
- Always-on property tests — slow; opt-in flag.
- Skip SMT — covers most but misses cert path.

## 6. Open questions

1. Z3 binary distribution — bundle vs require separate install?
   Recommend bundle (~30 MB).
2. Default property-test count — 1000 reasonable; configurable.
3. `@law(...)` for trait methods — yes, applies to all impls.
4. Random seed — fixed-default for reproducibility.

## 7. Definition of done

- [x] Low-risk integer forms generate bounded checks under `nuc test --check-laws`
- [x] Deprecated aliases, unsupported canonical forms, float modifiers, and unknown law names fail under `nuc test --check-laws`
- [ ] All law forms generate Arbitrary-driven property tests
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
