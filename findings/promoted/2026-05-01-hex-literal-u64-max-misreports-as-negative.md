---
title: `let h: u64 = 0xFFFFFFFFFFFFFFFF;` (u64::MAX bit pattern) incorrectly fires NUM-002 "literal -1 out of range for u64" — the parser interpreted the hex as i64-signed -1 and rejected it
severity: silent-miscompute / wrong-error (hex literal sign-interpretation gap)
probe_file: probes/numeric/hex_u64_max_misreport.nr (will be filed)
diagnostic_actual: `error[NUM-002]: numeric literal -1 out of range for declared type u64. Use a wider type or change the literal.`
diagnostic_expected: build succeeds — `0xFFFFFFFFFFFFFFFF` is a valid u64 (= u64::MAX = 18446744073709551615)
discovered_against: main v0.5.18 (probe ea1a427)
commit: probe ea1a427 + main 1b70cec
---

## Repro

```nr
fn main() -> i32 {
    let h2: u64 = 0xFFFFFFFFFFFFFFFF;
    print_int(h2 as i32);
    0
}
```

## Actual

```
error[NUM-002]: numeric literal -1 out of range for declared type u64. Use a wider type or change the literal.
  --> fn main@line 4:9
  |
4 |     let h2: u64 = 0xFFFFFFFFFFFFFFFF;
  |         ^
```

The diagnostic claims the literal is `-1`, which is the i64-signed interpretation of the all-ones bit pattern. But adopter wrote `0xFFFFFFFFFFFFFFFF` (16 hex digits = 64 bits), which IS the valid u64::MAX bit pattern.

## Compare: smaller hex works

```nr
let h: u32 = 0xFFFFFFFF;       // works — u32::MAX
let h: i64 = 0x7FFFFFFFFFFFFFFF; // works — i64::MAX
let h: u64 = 0xFFFFFFFFFFFFFFFE; // works (u64::MAX - 1, presumably)
```

Only the all-ones u64 case (interpreted as i64 -1 by the literal parser) trips up.

## Hazard tier

Wrong-error / hex-literal-interpretation. Adopter writing canonical bit-mask code:

```nr
let mask: u64 = 0xFFFFFFFFFFFFFFFF;
let result: u64 = some_value & mask;
```

…hits the false NUM-002. Workaround: use `u64::MAX` (if it exists as a constant) or `(0 as u64) - 1` (bit-pattern wrap). Both lose the canonical hex-literal readability.

## Suspected fix

The literal parser likely:
1. Parses the hex string into an i64 (max-width signed representation)
2. `0xFFFFFFFFFFFFFFFF` overflows i64 → wraps to -1 in two's complement
3. Now -1 is checked against u64's range `[0, u64::MAX]` — fails because -1 < 0

Fix: when binding type is unsigned (u8/u16/u32/u64), parse hex literals as unsigned (using uN::MAX as the upper bound and 0 as lower) rather than i64-signed.

Rust's parser does this — `0xFFFFFFFFFFFFFFFF` typed as u64 is valid; the same bare literal without a type binding picks i64 by default and overflows.

## Memory-blow-up note

Not memory-related.

## Cross-ref

- v0.4.119 — NUM-021 integer literal overflow (decimal literal > u64::MAX). The hex variant has a different parse path.
- 2026-05-01-num-019-coverage-gap-binop-vs-literal.md — sister "literal-form" gap

## Probe

Filed alongside this finding.


## Promoted

- Fix shipped: v0.5.23 — removed the `s == 2 && w == 64 &&
  lit_v < 0` reject branch in NUM-002 check (s1 line ~15333).
  Hex/oct/bin literals whose i64 reading wraps negative (like
  `0xFFFFFFFFFFFFFFFF` → i64 -1) now compile cleanly into u64
  bindings; the bit pattern IS the valid u64::MAX.
- Decimal-negative-to-u64 (`let h: u64 = -100;`) doesn't reach
  this check anyway — the `-` parses as kind-5 unary-neg on
  kind-1 literal, so the negative i64 value never appears as
  a kind-1 init for the NUM-002 check. Removing the line is
  safe.
- NUM-021 still catches decimal overflow > u64::MAX at lex time.
- Validation: `let h: u64 = 0xFFFFFFFFFFFFFFFF; print_int(h as i32);`
  builds + runs printing -1 (correct: all-ones bit pattern as
  i32). Sister hex pattern `0xDEADBEEFCAFEBABE & 0xFFFFFFFF`
  also works.
- Promoted: 2026-05-01 by main agent (probe commit ea1a427).
