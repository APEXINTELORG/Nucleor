# RFC-0004 — `#[assume(...)]` Proof Annotations

| Field | Value |
|---|---|
| **Number** | 0004 |
| **Title** | `#[assume(...)]` — explicit proofs to silence the conservative `#[no_panic]` / WCET analyses |
| **Status** | Draft |
| **Author** | Nucleor maintainers |
| **Created** | 2026-04-22 |
| **Target release** | v0.4.0 ("Robotics Stack") |
| **Depends on** | RFC-0001 (real-time function attributes) |

---

## 1. Summary

Add an expression-level `assume!(predicate)` macro and a function-level
`#[assume(predicate)]` attribute that the type checker treats as
trusted facts in subsequent dataflow analyses (`#[no_panic]`,
`#[no_alloc]`, static WCET).

```nucleor
#[no_panic, deadline = 1ms]
fn ekf_update(state: &mut Ekf, z: &Vec<f64, Pool>) {
    assume!(z.len() == 12);                 // sensor always emits 12 elements
    assume!(state.dim == 12);

    for i in 0..12 {                        // bounds-check elided; proven safe
        let zi: f64 = z[i];                 // RT-002 would normally flag this
        // ...
    }
}
```

Without `assume!`, the conservative analysis flags `z[i]` as possibly
panicking (out-of-bounds). With `assume!(z.len() == 12)`, the proof
that `i < 12` is reachable; `z[i]` is statically safe.

`assume!` is the **escape hatch** that prevents `#[no_panic]` from
being so conservative it's unusable. It is a **trust assertion** —
the compiler does not verify the predicate at compile time. In debug
builds, it traps if violated at runtime; in release builds, it is
optimization information only.

---

## 2. Motivation

### 2.1 What's wrong without it

RFC-0001 ships `#[no_panic]` as a conservative dataflow analysis.
"Conservative" means: when the analysis can't prove an expression is
safe, it errs on "may panic" and rejects.

This produces enormous false-positive rates on real code:
- Every array index without an immediately-preceding `if i < arr.len()`
- Every division without a literal-zero check
- Every `Option::unwrap` even when the user has matched on `Some`
- Every `unreachable!()` in match arms the user knows are unreachable

The compiler is not smart enough to follow data flow across function
calls, struct-field reads, or anything beyond simple intra-block
reasoning. **Without an escape hatch, `#[no_panic]` is unusable on
real robotics code.**

### 2.2 What other languages do

| Language | Mechanism | Limitation |
|---|---|---|
| **C/C++** | `__builtin_assume(p)` (Clang), `__assume(p)` (MSVC) | Compiler hint only; no runtime check |
| **Rust** | `unsafe { core::intrinsics::assume(p) }` (nightly), `unsafe { unreachable_unchecked() }` | Unstable, footgun-prone, no debug check by default |
| **Ada/SPARK** | `pragma Assume`, plus `pragma Assert` (proven) | Gold standard. SPARK proves; Ada assumes. |
| **Frama-C** | `//@ assume P;` ACSL annotations | External tool; not part of compilation |
| **Dafny / F\*** | `assume P;` (with proof obligation) | Theorem-proving languages; not industrial |

**Nucleor's opportunity:** ship `assume!` as a debug-checked,
release-optimized proof annotation that integrates cleanly with the
language-level `#[no_panic]` / `#[deadline]` analyses. Closer to
SPARK in spirit, simpler in practice.

---

## 3. Design

### 3.1 The `assume!` expression macro

```nucleor
assume!(predicate);
```

Where `predicate` is any boolean expression. The compiler:
- **In `--profile=debug`**: emits a runtime check; if `predicate` is
  false, traps with `ASSUME-FAILED: <expression>`.
- **In `--profile=release`**: emits no code; treats the predicate as
  a trusted fact for optimization and analyses.
- **In `--profile=cert` (v0.7+)**: refuses to compile unless the
  predicate has been *proven* by an external tool (Heptane,
  Frama-C-style), or the user has explicitly opted out with
  `assume_unchecked!`.

### 3.2 Predicate types accepted

The dataflow analysis can use predicates of these forms:

| Predicate | Used by analysis to prove |
|---|---|
| `x < N` (literal `N`) | Subsequent `arr[x]` is in-bounds if `arr.len() >= N` |
| `x >= 0` | Subsequent `arr[x]` skips negative-index check |
| `x != 0` | Subsequent `y / x` doesn't divide by zero |
| `arr.len() == N` (literal `N`) | Loop `for i in 0..N` doesn't index out-of-bounds |
| `arr.len() >= x` | Index `arr[i]` for `i < x` is safe |
| `opt.is_some()` | Subsequent `opt.unwrap()` is safe |
| `result.is_ok()` | Subsequent `result.unwrap()` is safe |
| `x == y` | Substitute `x` for `y` (or vice versa) in subsequent expressions |

Any other predicate is accepted as a runtime check but contributes
**nothing** to static analysis. The user gets a hint:
`note: predicate not in the analyzer's vocabulary; runtime-check only`.

### 3.3 The `#[assume(...)]` function attribute

For predicates that should hold throughout the entire function body,
use the attribute form:

```nucleor
#[no_panic, assume(z.len() >= 12, state.dim == 12)]
fn ekf_update(state: &mut Ekf, z: &Vec<f64, Pool>) {
    // assume! is implicit at function entry
    for i in 0..12 {
        let zi: f64 = z[i];   // safe; len >= 12 known throughout
        // ...
    }
}
```

The attribute form is sugar for adding `assume!` calls at the start
of the function body. Useful when the same precondition applies to a
whole function and the body would otherwise be cluttered.

### 3.4 Refinement types — narrow form via attribute parameters

Function parameters can carry `assume`-style refinements:

```nucleor
fn lookup(arr: &[f64; 16], i: u32 #[assume(i < 16)]) -> f64 {
    arr[i as usize]   // safe by precondition
}
```

This is sugar for adding `assume!(i < 16)` at function entry. The
caller is responsible for ensuring the precondition holds — the
compiler does **not** insert a check at the call site (unlike
contracts), since the runtime check on entry is enough for safety.

In v0.6, `#[require(predicate)]` (caller-side checked) and
`#[ensure(predicate)]` (post-condition) are added for full
design-by-contract; `assume` is the lightweight form.

### 3.5 Composition with `#[no_panic]`

`#[no_panic]`'s dataflow analysis runs after `assume!` insertion. The
analyzer maintains a fact set per program point:

```
{ z.len() >= 12,  state.dim == 12,  i < 12 }
```

Facts propagate across:
- Sequential statements (forward)
- `if x < N { … }` branches (add `x < N` inside the then-branch)
- Loop entry (add `i < N` if loop is `for i in 0..N`)
- Function calls — facts are **not** propagated across calls without
  per-callee `assume(post)` annotations (RFC-0006-territory)

When the analyzer encounters `arr[i]`, it checks if `i < arr.len()`
is in the fact set; if so, no `RT-002` is emitted.

### 3.6 The `assume_unchecked!` form

For the rare case where the user wants the runtime trap **disabled
even in debug**, use `assume_unchecked!(predicate)`:

```nucleor
assume_unchecked!(ptr != null);   // trust me; never check
```

This is a footgun and the compiler warns. Use case: extreme RT
loops where the debug-mode runtime check is itself a deadline
violation. Document and use sparingly.

### 3.7 Debug-mode runtime trap

`assume!(p)` in debug compiles to:

```
if !p {
    rt::assume_failed("p", file, line);
    /* unreachable */
}
```

`rt::assume_failed` is a single function in `runtime/assume_rt.c`:

```c
void __nucleor_assume_failed(const char* expr, const char* file, int line) {
    fprintf(stderr, "ASSUME-FAILED: %s at %s:%d\n", expr, file, line);
    abort();
}
```

In `--profile=embedded`, `abort()` is replaced by `panic_handler`
dispatch.

In `--profile=release`, the entire `if !p { ... }` block is omitted;
the predicate becomes pure analysis information.

### 3.8 Composition with the optimizer

`assume!(p)` in release mode lowers to LLVM's `llvm.assume(p)`
intrinsic. The LLVM optimizer uses this to:
- Eliminate redundant bounds checks
- Hoist invariant divisions when divisor is provably nonzero
- Constant-fold conditions on known-true predicates
- Specialize loop trip counts

This gives release-mode `assume!` a real performance win beyond
silencing the analyzer.

### 3.9 Diagnostics

| Code | Meaning |
|---|---|
| `ASSUME-001` | `assume!` predicate not in the analyzer's vocabulary (warning, runtime-check still happens) |
| `ASSUME-002` | `assume_unchecked!` used without justification comment (warning) |
| `ASSUME-003` | `assume!` predicate is a tautology (warning; no-op) |
| `ASSUME-004` | `assume!` contradicts a fact derivable from the type system (error; e.g., `assume!(x < 0)` when `x: u32`) |
| `ASSUME-005` | In `--profile=cert`, `assume!` not proven by external tool |

---

## 4. Implementation

### 4.1 Compiler changes

| Component | Change | LOC est. |
|---|---|---|
| Parser | `assume!` macro form, `#[assume(...)]` attribute, `#[assume(predicate)]` parameter refinement | ~120 |
| Type checker | Fact-set dataflow extension to `#[no_panic]` analysis | ~400 |
| Codegen (debug) | Emit conditional trap | ~80 |
| Codegen (release) | Lower to `llvm.assume` intrinsic | ~50 |
| Diagnostics | ASSUME-001…005 | ~150 |
| **Total** | | **~800** |

### 4.2 Runtime changes

| Component | Change | LOC est. |
|---|---|---|
| `runtime/assume_rt.c` | `__nucleor_assume_failed` trap | ~30 |
| **Total** | | **~30** |

### 4.3 Stdlib changes

Audit stdlib functions whose `#[no_panic]` analysis fails for
correct-but-non-trivial reasons. Add `#[assume(...)]` attributes to
unblock. Most stdlib panics-by-analysis are bounds-checks the author
knew were safe.

Estimated 10–20 rod functions need `assume` annotations.

### 4.4 Test plan

- **Unit tests:**
  - `tests/lang/assume_basic.nr` — `assume!(x < 16)` enables
    `arr[x]` without `RT-002`
  - `tests/lang/assume_function.nr` — function-level
    `#[assume(arr.len() >= 12)]` works
  - `tests/lang/assume_release.nr` — debug check works, release
    eliminates check
- **Negative tests:**
  - `tests/err/err_assume_contradiction.nr` —
    `assume!(x < 0)` for `x: u32` errors
  - `tests/err/err_assume_failure_runtime.nr` — debug-mode trap
    actually fires (run as a "should-fail" test)
- **Integration:**
  - `tests/features/ekf_with_assume.nr` — full EKF with assume
    annotations, builds clean under `#[no_panic]`

### 4.5 Migration

Purely additive. No existing code uses `assume!`; existing code is
unaffected. New users opt in to silence false positives.

---

## 5. Alternatives considered

### 5.1 Make the analyzer smarter

Instead of `assume!`, just teach the analyzer to track more facts
across more program structures.

**Why not (alone):** infinite work. Real programs have facts the
analyzer can never derive (sensor invariants, hardware guarantees,
external-validation-already-done). The analyzer can be made smarter,
**and** `assume!` is needed.

### 5.2 SMT solver in the compiler

Use Z3 or similar to *prove* `assume!` predicates.

**Rejected for v0.4:** SMT-in-compiler is a multi-year investment.
Defer to v0.7+ (`--profile=cert` mode). For v0.4, debug-check + release-
trust is the right level.

### 5.3 Refinement types (Liquid Haskell-style)

Promote `#[assume]` to a full refinement-type system with proof
obligations everywhere.

**Rejected:** too heavyweight for the language's complexity budget.
SPARK and F* are the niche; we don't compete there. `assume!` is the
80/20 version.

### 5.4 No escape hatch — make users restructure code

Force users to add explicit `if i < arr.len() { … }` everywhere.

**Rejected:** that's the C/C++ status quo and the reason `#[no_panic]`
isn't usable today. Defeats the purpose.

---

## 6. Open questions

1. **Runtime check in `--profile=release` for safety-critical code?**
   Some users may want assume! to remain checked even in release for
   safety. Suggest **`--profile=safe-release`** that's like release
   but keeps `assume!` checks (still ~5× faster than debug, with
   safety).

   Recommend **add `--profile=safe-release` in v0.5**.

2. **Predicate vocabulary expansion.**
   The analyzer vocabulary in §3.2 is small. Should we ship a richer
   one (linear arithmetic over integers, set membership) in v0.4 or
   v0.5?

   Recommend **ship the minimal vocabulary in v0.4**, expand based on
   user-reported false-positive cases.

3. **`assume!` inside `#[no_alloc]`?**
   `assume!` doesn't allocate — fine. But if the predicate involves
   a method call (`assume!(some_method() > 0)`) that allocates,
   that's a violation. Worth flagging?

   Recommend **yes, treat predicate-evaluation under all the same
   attribute rules as the function body**. Side-effects in `assume!`
   predicates are bugs anyway.

4. **Cross-function fact propagation.**
   If `f()` is `#[no_panic]` and ends with `assume!(self.dim == 12)`,
   should callers of `f()` get that fact?

   Defer to **RFC-0006 `#[ensure(post)]`**. For v0.4, `assume!` is
   intra-function only.

5. **Optimizer aggression.**
   `llvm.assume` is double-edged: it can lead to surprising codegen
   if the predicate is wrong (in release, undefined behavior). Should
   the compiler limit which `assume!` predicates lower to
   `llvm.assume`?

   Recommend **lower only the §3.2 vocabulary to `llvm.assume`**;
   other predicates are runtime-check-only. Reduces UB surface.

---

## 7. Definition of done

- [ ] `assume!(p)` parses, type-checks, codegens
- [ ] `#[assume(p1, p2, ...)]` function attribute parses and acts as
      sugar for entry-block `assume!` calls
- [ ] `#[assume(p)]` parameter refinement parses
- [ ] Fact-set dataflow extension to `#[no_panic]` integrates
      `assume!` facts
- [ ] Debug-mode runtime check emits and aborts on failure
- [ ] Release-mode lowers to `llvm.assume`
- [ ] `tests/lang/assume_*.nr` and `tests/err/err_assume_*.nr` pass
- [ ] At least 10 stdlib rod functions use `#[assume(...)]` to silence
      previously-blocking false positives
- [ ] CHANGELOG documents `assume!` and its three modes (debug /
      release / cert)

---

## 8. Future extensions (out of scope)

- **`#[require(...)]` / `#[ensure(...)]`** — full design-by-contract.
  RFC-0006.
- SMT-backed proof of `assume!` predicates — `--profile=cert`.
  RFC-0009.
- Quantified predicates (`forall i in 0..n: arr[i] > 0`).
  Research; not for v0.x.
- **`prove!` macro** that requires the analyzer to derive the
  predicate (no trust). Stricter form of `assume!`. v0.7+.
- **`assume!` in `unsafe` blocks** carrying additional UB-licenses.
  Not planned.

---

## 9. Acceptance checklist

- [ ] Maintainer (Joseph Wescott) approves the design
- [ ] Compatible with RFC-0001 (RT attributes) — `assume!` integrates
      cleanly with the existing analysis
- [ ] Compatible with v0.4 release schedule
- [ ] LOC estimate (~800 compiler + ~30 runtime) fits budget
- [ ] Pitch survives ("escape hatch for the conservative #[no_panic]
      analysis, with debug check + release trust + cert proof")
