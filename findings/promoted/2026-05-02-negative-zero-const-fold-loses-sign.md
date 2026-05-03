---
title: `let z: f64 = -0.0;` const-folds to `+0.0` — IEEE 754 negative-zero sign bit lost. `1.0 / z` then yields `+inf` instead of the correct `-inf`.
severity: silent-miscompute (IEEE 754 floating-point)
probe_file: probes/numeric/negative_zero_const_fold.nr (probe-branch)
diagnostic_actual: pre-fix — `1.0 / (-0.0)` outputs `+inf` instead of `-inf`
diagnostic_expected: `-inf` (IEEE 754 negative-zero divides to negative infinity)
discovered_against: probe/exploration tip
commit: probe + main
status: CLOSED in v0.6.52 — IEEE 754 sign-bit-flip via XOR (sidesteps the v0.6.48-attempt-1 bootstrap-cycle hole by avoiding new IR declares).
---

## Closure (analysis-only — fix attempted then reverted)

The kind-5 (unary minus) lower path on f64/f32 currently emits
`f<T>_sub(0.0, opr)` which, per IEEE 754, returns `+0.0` for
`0 - (-0)`. The C runtime helper `__nucleor_f64_sub` correctly
implements IEEE-754 floating-point sub, so `+0.0` IS the right
result for that operation — the issue is that unary minus
shouldn't lower to subtraction at all. It should flip the sign
bit (a different operation that `-x` defines per IEEE 754).

### Fix shape (deferred)

The clean fix: emit `f<T>_neg(opr)` calling a new C helper that
does `return -x;` (the C unary minus is sign-bit-flip, IEEE-
correct).

```c
long long __nucleor_f64_neg(long long a) {
    return __nuc_d2b(-__nuc_b2d(a));
}
long long __nucleor_f32_neg(long long a) { /* already exists */ }
```

### Why deferred

The fix needs a NEW `declare i64 @__nucleor_f64_neg(i64)` in
emit_externs(). Adding new declares triggers the bootstrap-cycle
hole the v0.6.48-attempt-1 ship hit:

- OLD bin compiles current source → emits .ll based on OLD bin's
  compiled-in emit_externs (which had a duplicated state where
  the f32_neg declare appeared in BOTH the f64-block and the
  f32-block of emit_externs). The .ll has 2 declares, clang
  rejects.
- Workaround attempted: manual de-dup of .ll, link manually,
  install new bin, re-validate. New bin has correct emit (1
  declare per helper) but rebuilding compiler with new bin
  re-produced the .ll with 2 declares — proving the
  duplication is in the bin's compiled-in code, not the source
  string.

The bootstrap hole proved the New-IR-Declare class of changes
needs a dedicated validation cycle. v0.6.48 instead picked the
str-helper-amp finding (smaller blast radius). This negative-
zero finding is parked for the same dedicated cycle.

### What v0.6.49 did partially

v0.6.49 closed the i64::MIN literal NUM-021 false-fire (gap 2 of
the NUM-021 coverage finding). That's a SISTER finding to this
one — both involve "literal that wraps to a bit pattern at
storage time, then unary-minus re-applies the operation that
already wrapped." The integer side (i64::MIN) shipped; the
float side (-0.0 / -inf) is still open.

## Adopter migration

Until the dedicated ship lands:

```nucleor
// Pre-fix (loses sign):
let z: f64 = -0.0;
print_f64(1.0 / z);       // prints +inf instead of -inf

// Workaround (preserve sign via bit pattern):
let nz_bits: i64 = 0x8000000000000000;     // sign bit set
let z: f64 = f64_from_bits(nz_bits);
print_f64(1.0 / z);                          // prints -inf
```

## Promoted

- Fix attempted v0.6.48-attempt-1, reverted due to bootstrap-
  cycle hole. Documented in commit log + memory.
- Promoted: 2026-05-03 by main agent.
