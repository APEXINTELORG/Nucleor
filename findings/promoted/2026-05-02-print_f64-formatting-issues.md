---
title: `print_f64` uses fixed-decimal formatting which produces broken output for extreme values: `f64::MAX` prints as a ~309-digit integer; subnormals (5e-324 etc.) print as `0.000000` losing the actual value.
severity: silent-miscompute / diagnostic-quality (print output mis-represents value at extremes)
probe_file: probes/numeric/print_f64_formatting.nr (probe-branch)
diagnostic_actual: pre-fix — 309-digit integer for f64::MAX; `0.000000` for 5e-324 (silent zero).
diagnostic_expected: scientific notation for extremes, fixed-decimal for typical magnitudes.
discovered_against: main v0.5.31 (probe rebased)
commit: probe (post-rebase) + main 0ac46486
status: CLOSED in v0.6.47 — `__nucleor_print_f64` routes by magnitude: `%.17g` for extremes (`abs < 1e-6` or `>= 1e15`), `%.6f` for typical magnitudes (legacy output preserved), explicit `0.000000` for zero.
---

## Closure (main agent v0.6.47)

`stdlib/runtime/nucleor_llvm_rt.c` `__nucleor_print_f64` — was
unconditional `printf("%.6f\n", d)`. Now:

```c
double abs_d = d < 0 ? -d : d;
if (abs_d == 0.0) {
    printf("0.000000\n");
} else if (abs_d < 1e-6 || abs_d >= 1e15) {
    printf("%.17g\n", d);   // auto-scientific, round-trip precision
} else {
    printf("%.6f\n", d);    // legacy fixed-decimal
}
```

`%.17g` is the canonical "round-trip" precision for f64 — every
distinct double has a distinct `%.17g` representation, so
adopters debugging FP values via `print_f64` get the actual
bits.

## Adopter migration

```nucleor
let mx: f64 = 1.7976931348623157e308;
print_f64(mx);
// pre-v0.6.47: 309-digit wall
// v0.6.47: 1.7976931348623157e+308

let tiny: f64 = 5e-324;
print_f64(tiny);
// pre-v0.6.47: 0.000000 (silent zero — value lost)
// v0.6.47: 4.9406564584124654e-324

let normal: f64 = 3.14159;
print_f64(normal);
// unchanged: 3.141590
```

Existing fixtures using `print_f64(<typical-magnitude>)` produce
the same output. Only extreme values switch.

## Forward-roadmap

The threshold (`1e-6 .. 1e15`) is heuristic, matching
approximately what humans read comfortably. Could be tuned via
env var (`NUCLEOR_PRINT_F64_PRECISION` etc.) in a future ship if
adopters need control.

## Promoted

- Smoke validation: 4 cases (max, smallest subnormal, typical,
  zero) all print correctly.
- Fix shipped: v0.6.47.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
