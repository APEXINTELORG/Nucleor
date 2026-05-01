---
title: `let i: i64 = (1e20 as f64) as i64;` silently returns 1 (raw `fptosi` UB) — should saturate to i64::MAX or panic, matching Rust's saturating-cast semantics
severity: silent-miscompute (LLVM `fptosi` UB on out-of-range float)
probe_file: probes/numeric/float_to_int_overflow.nr (will be filed)
diagnostic_actual: build succeeds; runtime returns `1` (UB result of LLVM `fptosi` for out-of-range float; varies by platform / optimization)
diagnostic_expected: either (a) saturate `1e20 as i64` to `i64::MAX = 9223372036854775807` (matching Rust 1.45+), OR (b) panic at runtime, OR (c) compile-time const-eval check that rejects const out-of-range float-to-int conversions
discovered_against: main v0.5.18 (probe ebbcc16)
commit: probe ebbcc16 + main 1b70cec
---

## Repro

```nr
fn main() -> i32 {
    let big: f64 = 1e20;
    let i_big: i64 = big as i64;
    print_int(i_big as i32);   // prints 1 silently
    0
}
```

Output: `1`. No diagnostic.

## Reference values

- `1e20` = 100,000,000,000,000,000,000 (1.0e20)
- `i64::MAX` = 9,223,372,036,854,775,807 (≈9.22e18)
- 1e20 / i64::MAX ≈ 10.84 — value is ~11× larger than i64 can hold
- LLVM `fptosi` on out-of-range floats is UB; the actual result is platform-dependent (here: 1 on Windows x64)

## Compare: NaN cast → 0 (Rust-saturating semantics)

The companion case works correctly:

```nr
let nan: f64 = 0.0 / 0.0;
let i: i64 = nan as i64;     // returns 0 ✓ (Rust 1.45+ saturating)
```

So Nucleor implements NaN saturation but NOT magnitude saturation. The implementation is partial.

## Hazard tier

Silent-miscompute, memory-safety-adjacent. Adopter writes:

```nr
fn parse_timestamp(s: str) -> i64 {
    let f: f64 = str_to_f64(s);   // user input may be huge
    f as i64                       // ← UB if f > i64::MAX
}
```

…and gets a non-deterministic value depending on optimization level + platform. Tests on one machine may pass; production on a different machine may fail subtly.

## Suspected fix

Implement Rust's saturating cast semantics in the f64-to-iN as-cast helper:

```c
long long __nucleor_as_i64_from_f64(double f) {
    if (isnan(f)) return 0;
    if (f >= 9.223372036854776e18) return INT64_MAX;
    if (f <= -9.223372036854776e18) return INT64_MIN;
    return (long long)f;
}
```

The `as_i64` runtime helper exists (per v0.4.NNN narrow_via_as work). It currently does raw `fptosi`. Adding the saturation guards is a 4-line change.

Same fix needed for `as_i32`, `as_i16`, `as_i8`, `as_u64`, etc. — match each width's MIN/MAX.

## Memory-blow-up note

Not memory-related. UB is the hazard.

## Cross-ref

- v0.5.10 — narrow-arith iN::MIN/-1 panic (sister UB-from-LLVM-fptosi/sdiv close)
- 2026-05-01-i32-min-div-neg-one-windows-exception.md (closed v0.5.10) — sister Windows-exception-from-LLVM-UB pattern
- Rust RFC 2484 — saturating float-to-int casts (the canonical model)

## Probe

Filed alongside this finding.


## Promoted

- **Probe's diagnosis was partially incorrect** — the saturating
  f64-to-iN cast helpers (`__nucleor_f64_to_i64`,
  `__nucleor_f64_to_i32`, `__nucleor_f64_to_u32`,
  `__nucleor_f64_to_u64`) ALREADY work correctly per v0.3.211
  / v0.4.NNN narrow_via_as work. NaN→0, magnitude saturation
  to MIN/MAX. The compiler dispatches to them (s1 line ~16703).
- **The actual bug** in probe's repro: `let big: f64 = 1e20;`
  silently bound `big = 1.0`. The lexer parsed `1e20` as int
  literal `1` followed by ident `e20`. The fractional-dot
  `1.0e20` form worked because v0.4.220 added e/E exponent
  handling AFTER fractional digits.
- Fix shipped: v0.5.24 — extended the lexer to accept
  `<digits>e<+/-?><digits>` (no fractional dot) as f64 literal.
  Identifier-shaped suffixes like `e_helper` still lex as ident
  (the check requires a digit after the optional sign).
- Saturating cast was always correct: `1e20 as i64` correctly
  saturates to i64::MAX (= 9223372036854775807). Truncate to
  i32 yields -1 (low 32 bits of all-ones). Probe's "returns 1"
  was the literal value 1.0, not the saturated cast result.
- Validation: `let big: f64 = 1e20; print_f64(big);` now prints
  `100000000000000000000.000000`. `big as i64 as i32` prints
  `-1`. Sister `2.5e-2` and `1e3` also work.
- Promoted: 2026-05-01 by main agent (probe commit ebbcc16).
