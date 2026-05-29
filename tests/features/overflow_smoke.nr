// v0.8.217 stdlib/rods/overflow.nr first test coverage.
//
// RFC-0044 Phase A: per-BinOp overflow-mode helpers
// (wrap/sat/trap; mode-dispatch). Pre-v0.8.217: regression gate
// token-presence gate (v0.8.181) covers import; this fixture
// guards behavior. Phase B compiler enforcement (~150 LOC) of
// inline-suffix syntax `a *#wrap b` etc. must NOT regress
// these.
//
// Locks four invariants:
//
//   1. Stable mode tags — default=0, wrap=1, sat=2, trap=3
//      (table-driven kernels depend on stability).
//   2. Trap on safe inputs returns same as plain —
//      add_trap(2, 3) == 5; mul_trap(7, 6) == 42.
//   3. Wrap on overflow modular — wrapping i32-range max + 1
//      wraps to i32::MIN. Phase A wrapping{} is i32-clamped at
//      block boundary; Phase B promotes to full i64.
//   4. Mode dispatch routes correctly — add_with_mode(wrap,
//      3, 4) == 7; mul_with_mode(trap, 7, 6) == 42; the default
//      arm (mode=0) takes the plain path.
//
// Trap-on-overflow PANICS aren't tested (that would crash the
// process); the safe-path branch covers the same code with no
// panic.
//
// Expected: rc=0.

import "stdlib/rods/overflow.nr"

fn check_mode_tags() -> i64 {
    if overflow_mode_default() != 0 { return 1; };
    if overflow_mode_wrap() != 1 { return 2; };
    if overflow_mode_sat() != 2 { return 4; };
    if overflow_mode_trap() != 3 { return 8; };
    return 0;
}

fn check_trap_safe_path() -> i64 {
    if add_trap(2, 3) != 5 { return 16; };
    if sub_trap(10, 3) != 7 { return 32; };
    if mul_trap(7, 6) != 42 { return 64; };
    if neg_trap(0 - 5) != 5 { return 128; };
    return 0;
}

fn check_wrap_modular() -> i64 {
    // Phase A wrapping{} block is i32-clamped at the boundary;
    // exercise modular arithmetic at i32 range.
    let max32: i64 = 2147483647;
    let min32: i64 = 0 - 2147483648;
    if add_wrap(max32, 1) != min32 { return 256; };
    if mul_wrap(2, 0 - 1) != (0 - 2) { return 512; };
    return 0;
}

fn check_mode_dispatch() -> i64 {
    if add_with_mode(overflow_mode_wrap(), 3, 4) != 7 { return 1024; };
    if mul_with_mode(overflow_mode_trap(), 7, 6) != 42 { return 2048; };
    if sub_with_mode(overflow_mode_sat(), 10, 3) != 7 { return 4096; };
    // Default arm: mode=0 takes plain path
    if add_with_mode(overflow_mode_default(), 3, 4) != 7 { return 8192; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_mode_tags();
    fails = fails + check_trap_safe_path();
    fails = fails + check_wrap_modular();
    fails = fails + check_mode_dispatch();
    return fails;
}
