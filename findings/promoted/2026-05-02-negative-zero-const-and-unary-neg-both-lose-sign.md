---
title: Negative-zero sign-loss extends from const-fold to unary-neg — both `let z: f64 = -0.0;` (const fold) and `let z = 0.0; let nz = -z;` (runtime unary-neg) lose the IEEE 754 negative-zero sign bit.
severity: silent-miscompute (IEEE 754 floating-point — extends sister finding's surface)
probe_file: probes/numeric/negative_zero_unary_neg.nr (probe-branch)
diagnostic_actual: pre-fix — both forms produce `+0.0` instead of `-0.0`
diagnostic_expected: `-0.0` (sign bit preserved per IEEE 754 unary-minus semantics)
discovered_against: probe/exploration tip (extends sister)
commit: probe + main
status: CLOSED in v0.6.52 — bundled with `2026-05-02-negative-zero-const-fold-loses-sign` sister fix. IEEE 754 sign-bit-flip via XOR.
---

## Closure (analysis-only — sister to the const-fold finding)

This finding extends the const-fold sister finding's surface to
the runtime unary-minus path:

- `let z: f64 = -0.0;` — const fold gets `+0.0` (the const-fold
  finding).
- `let z = 0.0; let nz = -z;` — runtime kind-5 unary-minus gets
  `+0.0` (this finding).

Both go through the same kind-5 lower at
`compiler/nucleor_s1_compiler.nr:~19424` which emits
`f<T>_sub(0.0, opr)`. The fix is identical for both: emit
`f<T>_neg(opr)` calling a new C helper that does sign-bit-flip.

See the const-fold sister finding for full deferral rationale.

## Adopter migration

Same workaround:

```nucleor
let z: f64 = 0.0;
let nz_bits: i64 = f64_to_bits(z) | 0x8000000000000000;
let nz: f64 = f64_from_bits(nz_bits);
print_f64(1.0 / nz);    // prints -inf
```

## Promoted

- Bundled with `2026-05-02-negative-zero-const-fold-loses-sign`.
- Promoted: 2026-05-03 by main agent.
