// v0.7.92 RFC-0044 Phase A smoke fixture — per-BinOp
// overflow-mode helper surface.
//
// Validates:
//   - wrap / sat helpers compile and round-trip non-overflow values
//   - trap helpers compile and accept non-overflow inputs
//   - mode dispatch table maps to the right helper
//   - mode name lookup returns canonical strings
//
// Note: Phase A's `wrapping { ... }` / `saturating { ... }`
// block-expr lowering uses Nucleor's i32-clamped intrinsic path
// (the v0.4.105 / v0.4.239 substrate), so this fixture only
// validates the API SURFACE for non-overflow values. Phase B
// rewires the block-expr lowering for full-i64-range semantics
// per RFC-0044's mode-dispatch wire format.
import "stdlib/rods/overflow.nr"

fn main() -> i64 {
    // Wrap / sat / trap on small non-overflow values: identity-ish.
    if add_wrap(3, 4) != 7 { return 1; };
    if sub_wrap(10, 3) != 7 { return 2; };
    if mul_wrap(6, 7) != 42 { return 3; };
    if neg_wrap(5) != 0 - 5 { return 4; };

    if add_sat(3, 4) != 7 { return 5; };
    if sub_sat(10, 3) != 7 { return 6; };
    if mul_sat(6, 7) != 42 { return 7; };

    if add_trap(3, 4) != 7 { return 8; };
    if sub_trap(10, 3) != 7 { return 9; };
    if mul_trap(6, 7) != 42 { return 10; };
    if neg_trap(5) != 0 - 5 { return 11; };

    // mul_trap(0, x) and mul_trap(x, 0) short-circuit to 0
    // before the cross-divide check.
    if mul_trap(0, 9999) != 0 { return 12; };
    if mul_trap(9999, 0) != 0 { return 13; };

    // Mode dispatch — non-overflow inputs map to default-mode result.
    if add_with_mode(overflow_mode_wrap(), 3, 4) != 7 { return 14; };
    if add_with_mode(overflow_mode_sat(), 3, 4) != 7 { return 15; };
    if add_with_mode(overflow_mode_trap(), 3, 4) != 7 { return 16; };
    if add_with_mode(overflow_mode_default(), 3, 4) != 7 { return 17; };

    if mul_with_mode(overflow_mode_wrap(), 6, 7) != 42 { return 18; };
    if mul_with_mode(overflow_mode_sat(), 6, 7) != 42 { return 19; };
    if mul_with_mode(overflow_mode_trap(), 6, 7) != 42 { return 20; };

    if sub_with_mode(overflow_mode_default(), 10, 3) != 7 { return 21; };

    // Mode tag IDs are stable.
    if overflow_mode_default() != 0 { return 22; };
    if overflow_mode_wrap() != 1 { return 23; };
    if overflow_mode_sat() != 2 { return 24; };
    if overflow_mode_trap() != 3 { return 25; };

    // Mode name lookup.
    if str_eq(overflow_mode_name(0), "default") == 0 { return 26; };
    if str_eq(overflow_mode_name(1), "wrap") == 0 { return 27; };
    if str_eq(overflow_mode_name(2), "sat") == 0 { return 28; };
    if str_eq(overflow_mode_name(3), "trap") == 0 { return 29; };
    if str_eq(overflow_mode_name(99), "unknown") == 0 { return 30; };

    return 0;
}
