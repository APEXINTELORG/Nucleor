// rods/overflow — RFC-0044 Phase A: per-BinOp overflow-mode
// helpers (rod-only, name-surface).
//
// The full RFC-0044 ship adds a per-BinOp `overflow_mode` IR
// field with inline-suffix source forms (`a *#wrap b`,
// `a +#sat b`, `a /#trap b`, `expr as#sat i16`) so adopters can
// mix wrapping + saturating + trapping arithmetic in a single
// expression without nesting `wrapping{}` / `saturating{}` /
// `checked{}` blocks (~150 LOC compiler-side, deferred).
//
// Phase A (this rod) lands the canonical name surface. The
// helpers wrap the existing `wrapping { ... }` /
// `saturating { ... }` block-expr forms, with explicit
// trapping helpers that detect overflow via cross-divide and
// sign checks. Adopters write `add_wrap(a, b)` /
// `mul_sat(a, b)` / `add_trap(a, b)` per-op today; Phase B
// promotes to the inline-suffix syntax with no source change
// required.
//
// Implementation notes:
// - `*_wrap` and `*_sat` use Nucleor's existing block-expr
//   intrinsics (i32-clamped at the block boundary today; full
//   i64 lowering in Phase B).
// - `*_trap` is implemented in pure Nucleor source (overflow
//   detection via sign-flip for add and cross-divide for mul)
//   and works at full i64 range today regardless of strict-
//   intrin mode.
// - Mode-dispatch helpers (`add_with_mode`, etc.) plus tag
//   constants for table-driven kernels.
//
// Sister to RFC-0043 fixed-point Phase A (v0.7.91); both ship
// in the V1.13 drift-restoration lane.
//
// Workflow today:
//
//   import "stdlib/rods/overflow.nr"
//
//   let hash: i64 = mul_wrap(seed, 2654435761);
//   let clamped: i64 = add_sat(hash, ofs);
//   let monetary: i64 = add_trap(balance, debit);   // panics on overflow

// =====================================================
// Wrapping (modular two's-complement).
// Implementation: existing `wrapping { ... }` block-expr.
// =====================================================
fn add_wrap(a: i64, b: i64) -> i64 { return wrapping { a + b }; }
fn sub_wrap(a: i64, b: i64) -> i64 { return wrapping { a - b }; }
fn mul_wrap(a: i64, b: i64) -> i64 { return wrapping { a * b }; }
fn neg_wrap(a: i64) -> i64 { return wrapping { 0 - a }; }

// =====================================================
// Saturating — clamps at the surrounding-block boundary.
// Implementation: existing `saturating { ... }` block-expr.
// =====================================================
fn add_sat(a: i64, b: i64) -> i64 { return saturating { a + b }; }
fn sub_sat(a: i64, b: i64) -> i64 { return saturating { a - b }; }
fn mul_sat(a: i64, b: i64) -> i64 { return saturating { a * b }; }

// =====================================================
// Trapping — panics on overflow. Detection in pure Nucleor
// (no extern helpers needed). Works at full i64 range.
// =====================================================
fn add_trap(a: i64, b: i64) -> i64 {
    // Two's-complement overflow check: same-sign operands with
    // opposite-sign result. Compute the wrap result first so we
    // can inspect its sign.
    let r: i64 = wrapping { a + b };
    if a >= 0 && b >= 0 && r < 0 { panic("nucleor: signed overflow in trapping add"); };
    if a < 0 && b < 0 && r >= 0 { panic("nucleor: signed overflow in trapping add"); };
    return r;
}

fn sub_trap(a: i64, b: i64) -> i64 {
    if b == 0 - 9223372036854775807 - 1 {
        panic("nucleor: signed overflow in trapping sub (b is i64::MIN)");
    };
    return add_trap(a, 0 - b);
}

fn mul_trap(a: i64, b: i64) -> i64 {
    if a == 0 { return 0; };
    if b == 0 { return 0; };
    let r: i64 = wrapping { a * b };
    // Cross-divide overflow detection: r/a should equal b in
    // non-overflow cases; mismatch means we overflowed.
    if r / a != b { panic("nucleor: signed overflow in trapping mul"); };
    return r;
}

fn neg_trap(a: i64) -> i64 {
    if a == 0 - 9223372036854775807 - 1 {
        panic("nucleor: signed overflow in trapping neg (a is i64::MIN)");
    };
    return 0 - a;
}

// =====================================================
// Mode dispatch by tag — useful for table-driven kernels
// that select the mode at runtime.
// =====================================================
fn overflow_mode_default() -> i64 { return 0; }
fn overflow_mode_wrap()    -> i64 { return 1; }
fn overflow_mode_sat()     -> i64 { return 2; }
fn overflow_mode_trap()    -> i64 { return 3; }

fn overflow_mode_name(mode: i64) -> str {
    if mode == 0 { return "default"; };
    if mode == 1 { return "wrap"; };
    if mode == 2 { return "sat"; };
    if mode == 3 { return "trap"; };
    return "unknown";
}

fn add_with_mode(mode: i64, a: i64, b: i64) -> i64 {
    if mode == 1 { return add_wrap(a, b); };
    if mode == 2 { return add_sat(a, b); };
    if mode == 3 { return add_trap(a, b); };
    return a + b;
}

fn mul_with_mode(mode: i64, a: i64, b: i64) -> i64 {
    if mode == 1 { return mul_wrap(a, b); };
    if mode == 2 { return mul_sat(a, b); };
    if mode == 3 { return mul_trap(a, b); };
    return a * b;
}

fn sub_with_mode(mode: i64, a: i64, b: i64) -> i64 {
    if mode == 1 { return sub_wrap(a, b); };
    if mode == 2 { return sub_sat(a, b); };
    if mode == 3 { return sub_trap(a, b); };
    return a - b;
}
