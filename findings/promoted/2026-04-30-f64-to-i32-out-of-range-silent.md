---
title: f64 -> i32 cast at out-of-range / NaN silently miscomputes, no NUM-003 warning
severity: silent-miscompute
probe_file: probes/casts/f64_inf_to_i32.nr
diagnostic_actual: none (compile clean, runtime prints garbage)
diagnostic_expected: NUM-003 warning at compile time AND/OR saturating-cast / panic at runtime when value doesn't fit
discovered_against: v0.4.162
commit: a99fc717079b8f7774c8ddf7aa03a4cc5e132eae
status: CLOSED in v0.4.220 — TWO-bug investigation. The runtime saturating helper `__nucleor_f64_to_i32` (in stdlib/runtime/nucleor_llvm_rt.c, since pre-RFC) was already correct: NaN→0, +∞/+huge→i32::MAX, -∞/-huge→i32::MIN. The reported `1` for `1.0e30` and `-1` for `-1.0e30` were caused by a SEPARATE lexer bug: scientific notation `1.0e30` wasn't recognized — the lexer parsed `1.0` then stopped, treating `e30` as a separate identifier+int. So `big = 1.0`, not `1e30`, and `big as i32 = 1`. v0.4.220 adds e/E exponent support to the float lexer (after fractional digits): consume e/E + optional +/- + digits, append to literal text, force the raw-bits path so str_to_f64 (strtod) parses with full precision. Verified: `1.0e30 as i32` now correctly produces 2147483647 (saturating). NaN→0 and -1.0e30→-2147483648 also correct.
---

## Repro

```nr
fn main() -> i32 {
    let big: f64 = 1.0e30;
    let nan: f64 = 0.0 / 0.0;
    let neg_huge: f64 = -1.0e30;
    print_int(big as i32);
    print_int(nan as i32);
    print_int(neg_huge as i32);
    0
}
```

## Actual

```
$ ./bin/nucleor.exe build probes/casts/f64_inf_to_i32.nr -o f64_inf_to_i32
  ... (no NUM-003 warning, no saturation diagnostic)
  compiled: target\f64_inf_to_i32.exe

$ ./target/f64_inf_to_i32.exe
1
0
-1
```

`1` for 1e30, `0` for NaN, `-1` for -1e30 — all garbage. LLVM's `fptosi` is undefined behavior when the source can't be represented in the destination type, so the compiler is emitting an `fptosi` instruction without any pre-check or saturating wrapper, and the user gets whatever bit pattern x86-64 happens to leave in the destination register.

The exit code is 0 — the program "succeeded".

This is the worst failure mode: clean compile, clean exit, garbage output, no signal to the user.

## Expected

Pick one (or both) of:

1. **Compile-time NUM-003** when the source is a literal that's provably out of i32 range (`1.0e30`, `0.0/0.0`). Mirrors the i64→i32 NUM-003 already implemented for integer narrowing.
2. **Runtime saturation** in the `fptosi` lowering — emit an `is-finite + clamp` wrapper that produces `i32::MAX` for +∞/+huge, `i32::MIN` for -∞/-huge, and either `0` or panics for NaN. The closest C semantics is "implementation-defined", but Rust's `as` is now saturating since 1.45 and panics for NaN in debug builds; saturating-on-release is the safe default.

Adopters expect "narrowing cast" to either warn at compile time or have a defined runtime story. Today neither holds for f64→i32 at the boundaries.

## Cross-ref

- i64→i32 NUM-003 emits correctly (see `probes/casts/i64_to_i32_truncate.nr`). Float-to-int narrowing should mirror that path.
- v0.4.143 (NUM-023) closed `float / bool SIGSEGV`. This finding is the float-to-int sibling of that cleanup.

## Suspected location

The cast lowering path for `as` — likely a per-source-kind switch where:

- `int -> int (narrow)` gets NUM-003 + plain trunc.
- `float -> int (narrow or out-of-range)` gets a raw `fptosi` with no warn and no saturator.

Add the warn + a saturating wrapper to the float→int branch.


## Promoted

- Status frontmatter: see top of file. Closure version: **v0.4.220**.
- Verify gate: existing per-feature loop picks up the fixture above.
- Promoted: 2026-04-30 by main agent (footer backfilled 2026-05-01 per probe-agent Q3 footer-shape uniformity request).
