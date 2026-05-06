// v0836 C-11 - concurrency mutex destroy smoke.
//
// Locks that mutex handles allocated through conc_mutex can be explicitly
// released after normal lock/unlock cycles.

import "stdlib/rods/concurrency.nr"

fn check_single_mutex_destroy() -> i64 {
    let m: i64 = conc_mutex();
    if m == 0 { return 1; };
    conc_lock(m);
    conc_unlock(m);
    conc_mutex_destroy(m);
    return 0;
}

fn check_many_mutex_destroy_cycles() -> i64 {
    let mut i: i64 = 0;
    while i < 128 {
        let m: i64 = conc_mutex();
        if m == 0 { return 2; };
        conc_lock(m);
        conc_unlock(m);
        conc_mutex_free(m);
        i = i + 1;
    };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_single_mutex_destroy();
    fails = fails + check_many_mutex_destroy_cycles();
    return fails;
}
