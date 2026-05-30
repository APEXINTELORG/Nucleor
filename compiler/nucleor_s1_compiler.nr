// =====================================================
// Nucleor Stage 1 Compiler
// =====================================================
// A complete Nucleor compiler written in Nucleor.
// Reads a .nr source file, compiles it through:
//   source -> lex -> parse -> lower -> emit LLVM IR -> clang -> native exe
// Usage: nucleor_s1 <source.nr> <output_name>
// =====================================================
// file-wide PERF-3 suppression. The compiler builds
// AST nodes per-iteration in lex / parse / lower paths — each
// `Vec::new()` inside a `while`/`loop` is intentional (bounded
// per-token / per-stmt allocation, not a per-iteration leak).
// 56 PERF-3 sites suppressed wholesale; per-fn `#[allow_fn]` would
// be cleaner but is high-noise vs return.
#[allow(PERF-3)]

// T1.1 Phase 3c (v0.2.310): widened internal arithmetic to i64 so
// large register IDs and IR constant values (up to i64 max) are
// formatted correctly. The parameter remains `i32` for source
// compatibility; arithmetic moves to i64 to avoid Phase 1's
// narrow-as-i32 hook truncating values that exceed i32 range.
// doc-#2 §5 P1 — str_from_int(i32) signature was lying.
// Body handled i64::MIN, but the param is declared i32. Nucleor's
// i64-everywhere ABI lets i64 values flow through the i32 param at
// runtime — so the i64::MIN branch IS reachable. Added str_from_i64
// as the truthful entry point; str_from_int kept as a wrapper for
// backward compat. No call-site changes required; adopters who want
// to be type-honest can switch to str_from_i64 going forward.
#[manual_drop]
fn str_from_i64(n: i64) -> str {
    if n == 0 { return "0"; };
    if n == 1 { return "1"; } else if n == 2 { return "2"; } else if n == 3 { return "3"; }
    else if n == 4 { return "4"; } else if n == 5 { return "5"; } else if n == 6 { return "6"; }
    else if n == 7 { return "7"; } else if n == 8 { return "8"; } else if n == 9 { return "9"; };
    if n == (0 - 1) { return "-1"; } else if n == (0 - 2) { return "-2"; } else if n == (0 - 3) { return "-3"; }
    else if n == (0 - 4) { return "-4"; } else if n == (0 - 5) { return "-5"; } else if n == (0 - 6) { return "-6"; }
    else if n == (0 - 7) { return "-7"; } else if n == (0 - 8) { return "-8"; } else if n == (0 - 9) { return "-9"; };
    // handle i64::MIN specially. `0 - MIN_I64` overflows
    // back to MIN_I64 (because -MIN_I64 = MAX_I64 + 1, doesn't fit
    // in signed i64). Pre-fix, the `while val > 0` loop never executed
    // because val stayed negative — `s` ended as `""`, then the `n < 0`
    // branch prepended `"-"` and we returned just `"-"`. Any const-fold
    // that produced MIN_I64 (e.g. `i64::MAX + 1`) emitted invalid IR.
    // Detect MIN_I64 without using its literal: `n < -MAX_I64` is
    // only true when n == MIN_I64.
    let neg_max: i64 = 0 - 9223372036854775807;
    if n < neg_max { return "-9223372036854775808"; };
    let mut val: i64 = n;
    let mut is_neg: i64 = 0;
    if val < 0 { is_neg = 1; val = 0 - val; };
    let mut div: i64 = 1;
    let mut tmp: i64 = val;
    while tmp >= 10 {
        tmp = tmp / 10;
        div = div * 10;
    };
    let digits: str = "0123456789";
    let mut sb: i64 = sb_new_with_cap(21);
    if is_neg == 1 { sb_append(sb, "-"); };
    while div > 0 {
        let d: i64 = val / div;
        sb_append_char_at(sb, digits, d);
        val = val - d * div;
        div = div / 10;
    };
    return sb_to_str(sb);
}

// v0.5 (v0.4.233 integration) — declared param widened i32 → i64.
// Nucleor's i64-everywhere ABI passes the arg as i64; the body
// forwards to `str_from_i64`. The pre-fix `i32` was a known-bug
// workaround kept after v0.4.221's phase 3c trunc-on-entry attempt
// broke self-build, and was the sole driver of the cross-width
// audit surface (1734 hits in compiler self-build, 1291 in
// tools-suite). One-line cleanup; required substrate for the
// typed-param-alloca restore below.
#[manual_drop]
fn str_from_int(n: i64) -> str {
    return str_from_i64(n);
}
#[manual_drop]
fn str_to_int(s: str) -> i64 {
    // wrap arithmetic via wrapping_mul/add so that large
    // literals like u64::MAX (18446744073709551615) parse correctly
    // under strict-arithmetic mode without panicking. The accumulator
    // is intentionally allowed to wrap into the negative i64 range
    // (the resulting bit pattern is what u64 callers want anyway).
    // also use wrapping_sub for the final neg step. Pre-fix
    // `str_to_int("-9223372036854775808")` (canonical i64::MIN as a
    // negative-prefixed decimal string) panicked under strict-intrin
    // because the digit accumulator wrapped to i64::MIN and `0 - MIN`
    // overflowed. Surfaced by const-tracker round-trip on
    // `let x: i64 = -9223372036854775808;` (sister probe finding
    // gap-2; storing the canonical literal value triggered the
    // round-trip). wrapping_sub(0, result) preserves the i64::MIN bit
    // pattern (two's complement: -i64::MIN == i64::MIN) without
    // tripping the strict-intrin trap.
    let slen: i64 = str_len(s);
    let mut result: i64 = 0;
    let mut i: i64 = 0;
    let mut neg: i64 = 0;
    if slen > 0 && str_char_at(s, 0) == 45 { neg = 1; i = 1; };
    while i < slen {
        result = wrapping_add(wrapping_mul(result, 10), str_char_at(s, i) - 48);
        i = i + 1;
    };
    if neg == 1 { return wrapping_sub(0, result); };
    return result;
}
#[manual_drop]
fn str_is_digits(s: str) -> i64 {
    let slen: i64 = str_len(s);
    if slen == 0 { return 0; };
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c < 48 || c > 57 { return 0; };
        i = i + 1;
    };
    return 1;
}

// Kept in the main file (not in s1/cli.nr) so tools/check_compiler_drift.sh's
// grep-of-main-source still finds the version label.
#[manual_drop]
fn compiler_version_label() -> str {
    return "1.2.0";
    // History: 0.2.0-v2 → 0.3.134 → 0.4.180 (caught up from 0.4.21) →
    // 0.8.322 (caught up from 0.4.180) → 0.8.323 (RFC-0063 Phase 1) →
    // 1.0.0 (RFC-0062 hard-error closure G-1..G-11) → 1.0.1
    // (hardening sweep) → 1.0.2 (label-skip cut) → 1.0.3
    // (cold-compile str_substring regression fix; 22 s → 6 s on
    // Linux, ~5.8× faster) → 1.1.0.
    // tools/check_compiler_drift.sh enforces parity with the latest
    // ## [X.Y.Z] heading in CHANGELOG.md, so this can't drift silently.
}

// =====================================================
// LEXER (extracted to compiler/s1/lex.nr)
// =====================================================
import "s1/lex.nr"

// =====================================================
// PARSER (extracted to compiler/s1/parse.nr)
// =====================================================
import "s1/parse.nr"

// =====================================================
// IR DATA STRUCTURES (extracted to compiler/s1/ir.nr)
// =====================================================
import "s1/ir.nr"

// =====================================================
// OPTIMIZER PASSES (extracted to compiler/s1/optim.nr)
// =====================================================
import "s1/optim.nr"

// =====================================================
// BUILTIN MAPPING (extracted to compiler/s1/builtins.nr)
// =====================================================
import "s1/builtins.nr"

// =====================================================
// LLVM STRING ESCAPING (extracted to compiler/s1/emit.nr)
// =====================================================
import "s1/emit.nr"

// =====================================================
// LOWERING (extracted to compiler/s1/lower.nr)
// =====================================================
import "s1/lower.nr"

// =====================================================
// S12a (extracted to compiler/s1/diag.nr)
// =====================================================
import "s1/diag.nr"

// =====================================================
// RFC-0062 G-10 Phase 2b (extracted to compiler/s1/check_eff.nr)
// =====================================================
import "s1/check_eff.nr"

// =====================================================
// OWNERSHIP CHECKER (extracted to compiler/s1/check_own.nr)
// =====================================================
import "s1/check_own.nr"

// =====================================================
// EFFECT CHECKER (extracted to compiler/s1/check_type.nr)
// =====================================================
import "s1/check_type.nr"

// =====================================================
// V2 §1.4: PARALLEL FRONTEND (extracted to compiler/s1/cache.nr)
// =====================================================
import "s1/cache.nr"

// =====================================================
// MODULE SYSTEM (extracted to compiler/s1/modules.nr)
// =====================================================
import "s1/modules.nr"

// =====================================================
// COMPILER DRIVER (extracted to compiler/s1/cli.nr)
// =====================================================
import "s1/cli.nr"
