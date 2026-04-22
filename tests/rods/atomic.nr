// rods/atomic — verify rod wrapper
import "stdlib/rods/atomic.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    let a: i64 = atomic_new(0);

    // Counter pattern
    atomic_inc(a);
    atomic_inc(a);
    atomic_inc(a);
    if atomic_load_v(a) != 3 { fail = fail + 1; print("FAIL counter inc"); };
    atomic_dec(a);
    if atomic_load_v(a) != 2 { fail = fail + 1; print("FAIL counter dec"); };

    // Add: verify the new value is correct (prior-vs-new-value semantics
    // depend on platform; instead verify post-state which is the user-
    // observable contract).
    atomic_add(a, 100);
    if atomic_load_v(a) != 102 { fail = fail + 1; print("FAIL add result"); };

    // CAS success path via cas_ok
    if atomic_cas_ok(a, 102, 999) != 1 { fail = fail + 1; print("FAIL cas_ok success"); };
    if atomic_load_v(a) != 999 { fail = fail + 1; print("FAIL cas_ok new value"); };

    // CAS failure path
    if atomic_cas_ok(a, 0, 0) != 0 { fail = fail + 1; print("FAIL cas_ok failure"); };
    if atomic_load_v(a) != 999 { fail = fail + 1; print("FAIL cas_ok kept value"); };

    atomic_drop(a);

    if fail == 0 { print("OK atomic"); return 0; };
    return 1;
}
