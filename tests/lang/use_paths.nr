// use_paths — RFC-0018 phase 1: Rust-style `use std::<rod>` syntax.
//
// The compiler rewrites `use std::foo` into the equivalent
// `import "stdlib/rods/foo.nr"` directive; identifier lookup then
// resolves to the rod's exported wrapper fns. Trailing `;` and
// nested `::` segments work.

use std::atomic;
use std::bits;
use std::math;

fn main() -> i64 {
    let mut fail: i64 = 0;

    // From stdlib/rods/atomic.nr
    let a: i64 = atomic_new(10);
    atomic_inc(a);
    atomic_inc(a);
    if atomic_load_v(a) != 12 { fail = fail + 1; print("FAIL atomic_inc"); };
    atomic_drop(a);

    // From stdlib/rods/bits.nr
    if bits_popcount(0xFF) != 8 { fail = fail + 1; print("FAIL bits_popcount"); };
    if bits_is_power_of_two(64) != 1 { fail = fail + 1; print("FAIL is_power_of_two"); };

    // From stdlib/rods/math.nr (rod re-export of compiler builtins)
    if i64_abs(0 - 7) != 7 { fail = fail + 1; print("FAIL i64_abs"); };

    if fail == 0 { print("OK use_paths"); return 0; };
    return 1;
}
