---
title: NUM-G1 — RFC headline does not reproduce; >6-frac-digit literals are correctly preserved via strtod escape; only int_part overflow misbehaves
severity: wrong-error
probe_file: probes/numeric/num_g1_f64_lex_truncation.nr
diagnostic_actual: build success; runtime values bit-identical to strtod for 16-digit literals. PANIC "integer overflow" at compile time for int_part >= 1e13.
diagnostic_expected: per gap RFC, silent truncation of `3.1415926535897932` to `3.141592`. Does NOT reproduce.
discovered_against: v0.4.180
commit: 53af3b53
status: NEW
---

## Repro

```nr
// probes/numeric/num_g1_f64_lex_truncation.nr
fn main() -> i32 {
    let pi_full: f64 = 3.1415926535897932;
    let pi_six:  f64 = 3.141592;
    print("pi_full:");
    print_f64(pi_full);
    print("pi_six:");
    print_f64(pi_six);
    if pi_full == pi_six {
        print("BUG: pi_full == pi_six");
    } else {
        print("OK: pi_full != pi_six");
    }
    return 0;
}
```

## Actual

```
$ bin/nucleor.exe build probes/numeric/num_g1_f64_lex_truncation.nr
  ... (no NUM-G1 audit info on v0.4.180; v0.8.44 added the audit pass)
$ ./target/num_g1_f64_lex_truncation.exe
pi_full:
3.141593       <- printed via %.6f from FULL pi (rounds 7th digit)
pi_six:
3.141592       <- printed exactly
OK: pi_full != pi_six
rc=0
```

The full-precision π is preserved at the bit level. `pi_full == pi_six` evaluates **false**. The RFC's headline ("`3.1415926535897932` silently stored as `3.141592`") does not reproduce.

## Why the RFC headline is incorrect on current source

`compiler/nucleor_s1_compiler.nr:578-589` has the escape:

```nr
let raw_frac_len: i64 = str_len(raw_frac_str);
let mut use_raw_bits: i64 = 0;
if raw_frac_len > 6 { use_raw_bits = 1; };
if str_len(exp_str) > 0 { use_raw_bits = 1; };
if use_raw_bits == 1 {
    let lit_text: str = str_concat(...);
    let bits: i64 = str_to_f64(lit_text);    // strtod: full f64 precision
    tokens.push(tok_new(124, bits, st));     // raw-bits token
} else {
    // scaled-int encoding ONLY for 1-6 frac digits with no exponent
    let encoded: i64 = int_part * 1000000 + frac_val * (1000000 / frac_div);
    tokens.push(tok_new(70, encoded, st));
}
```

`str_to_f64` is wired to `strtod` and returns the i64 bit pattern of the IEEE-754 nearest f64. For any literal with `>6` fractional digits OR an exponent, this is the path taken. The lexer is honest for these cases.

For `1-6` fractional digits with no exponent, the scaled-int path runs. Decode at runtime is `(double)scaled / 1_000_000.0` (`__nucleor_f64_from_scaled` in `stdlib/runtime/nucleor_llvm_rt.c:7473`). For decimal literals representable in 6 digits this produces the same IEEE-754 nearest value strtod would (one rounding step in the divide vs one rounding in strtod — both round to the same nearest f64).

## Real residual gap (the only NUM-G1 silent miscompute that survives)

Large `int_part` overflows the i64 multiplication in `int_part * 1000000`. Reproduced via `probes/numeric/num_g1_intpart_overflow.nr`:

```nr
let big: f64 = 10000000000000.5;   // int_part = 1e13
```

```
$ bin/nucleor.exe build probes/numeric/num_g1_intpart_overflow.nr
  source: probes/numeric/num_g1_intpart_overflow.nr (801 bytes)
  mode: fast (ownership + type)
PANIC: integer overflow
rc=127  (no .exe produced)
```

The build PANICs (rc=127, no executable). It is a **crash, not a silent miscompute**. Adopter signal exists, but:

- Diagnostic message is `PANIC: integer overflow` with no source location, no NUM-G1 code, no file:line, no hint to use a hex-float / smaller magnitude / strtod-eligible form.
- This affects any literal where `int_part >= 9_223_372_036_854_775_807 / 1_000_000 = 9_223_372_036_854` and the lexer takes the scaled path (i.e. `<= 6` frac digits, no exponent). Adding a 7th frac digit or an exponent escapes to strtod and works.

## Real residual gap #2 (Phase 1 audit-pass info diagnostic is misleading)

`v0.8.44` (commit `99bb39f1`) added an audit-pass info diagnostic that fires when source contains `>=7` fractional digits. Its text says:

> "the lexer silently truncates f64 literal fractional digits past the 6th. `3.1415926535897932` is encoded as `3.141592`."

This is **factually wrong for the current source**. `>=7` frac-digit literals take the strtod escape and are NOT truncated. The diagnostic warns about a hazard that does not exist for the literals it flags; meanwhile the real residual hazard (large int_part scaled-overflow) is unflagged.

Cross-check: tests/fixtures/v0844_num_g1_smoke.nr's three "truncated" literals would all produce bit-identical f64 to their full-precision form, not to the documented "3.141592 / 2.718281 / 1.618033" outputs. The smoke fixture asserts nothing — it just compiles for the audit print — so this divergence is invisible to CI.

## Severity

**wrong-error** (downgraded from RFC's launch-blocker silent-miscompute). The RFC mis-describes the current bug shape:

- The advertised silent miscompute does not reproduce on current source.
- A real but narrow miscompute (`int_part >= 1e13` with `<=6` frac digits) crashes loudly rather than silently.
- The Phase 1 audit-pass info shipped at v0.8.44 fires on safe literals while missing the actual surviving hazard.

Adopter trust impact is moderate: the diagnostic gives a false-positive warning that is also factually wrong about the underlying mechanism, and the surviving int_part-overflow case has poor diagnostics.

## Suggested fix

Phase 1 patch (small):

1. Re-target `count_long_float_literals` to scan for **scaled-overflow-prone** literals: int_part numeric magnitude `>= 9_223_372_036_854` with `<= 6` frac digits and no exponent. That is the actual residual NUM-G1 hazard. The `>= 7 frac digits` case is already strtod-correct.
2. Update the audit-pass info text to describe the real bug shape: "f64 literal int_part is large enough that scaled-int lex encoding will overflow at compile time. Add a 7th fractional digit (or use scientific notation `1e13`) to take the strtod path."
3. Add explicit overflow check in lexer with a proper `NUM-G1` diagnostic at source location instead of a bare `PANIC: integer overflow`.

Phase 2b (already queued): replace the scaled-int path entirely with strtod for 1-6 frac digit literals too, to retire the special-case branch. Then NUM-G1 is fully closed.

## Cross-ref

- Lex source: `compiler/nucleor_s1_compiler.nr:578-597`
- Runtime decode: `stdlib/runtime/nucleor_llvm_rt.c:7473` `__nucleor_f64_from_scaled`
- Smoke fixture (asserts nothing): `tests/fixtures/v0844_num_g1_smoke.nr`
- Audit-pass info added: commit `99bb39f1` (v0.8.44)
- Gap RFC: `docs/rfcs/gap-analyses/Nucleor_Numeric_Correctness_Gap_Analysis_and_RFC_2026-05-04.md` §NUM-G1
- Sister probe: `probes/numeric/num_g1_f64_lex_characterize.nr` (digit-by-digit equality test confirming preservation)

## Notes for main agent

The Wave-1 NUM-G1 ship sequence may need recalibration. Phase 2b "precision-preserving f64 parser" is mostly already shipped (the strtod escape). What remains:

- (a) overflow-safe scaled encoding (or remove the scaled path entirely)
- (b) accurate audit-pass info text
- (c) honest test that asserts the silent-miscompute does not occur on real adopter literals

The Phase 4 hard error gate ("hard error if precision loss is non-zero") is essentially achievable today by deleting the scaled path and routing everything to strtod — the precision loss is structurally already gone.
