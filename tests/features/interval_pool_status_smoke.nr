// helper1 v0860 NUM-G5 - interval pool status/preflight smoke.
//
// Locks public pool introspection so callers can avoid pool exhaustion before
// constructing large interval temporaries. This avoids test-time million-loop
// exhaustion while still proving checkpoint/reset accounting and fail-closed
// preflight behavior.

import "stdlib/rods/interval.nr"

fn check_initial_status() -> i64 {
    let cp: i64 = iv_checkpoint();
    let cap: i64 = iv_pool_capacity();
    let used: i64 = iv_pool_used();
    let remaining: i64 = iv_pool_remaining();
    if cap < 1000000 { iv_reset(cp); return 1; };
    if remaining != cap - used { iv_reset(cp); return 2; };
    if iv_pool_preflight(0) != 1 { iv_reset(cp); return 4; };
    if iv_pool_preflight(1) != 1 { iv_reset(cp); return 8; };
    if iv_pool_preflight(0 - 1) != 0 { iv_reset(cp); return 16; };
    if iv_pool_preflight(remaining + 1) != 0 { iv_reset(cp); return 32; };
    iv_reset(cp);
    return 0;
}

fn check_alloc_accounting_and_reset() -> i64 {
    let cp: i64 = iv_checkpoint();
    let used0: i64 = iv_pool_used();
    let rem0: i64 = iv_pool_remaining();
    let a: i64 = iv_point(f64_to_bits(1.0));
    let b: i64 = iv_new(f64_to_bits(2.0), f64_to_bits(3.0));
    if a == 0 { iv_reset(cp); return 64; };
    if b == 0 { iv_reset(cp); return 128; };
    if iv_pool_used() != used0 + 2 { iv_reset(cp); return 256; };
    if iv_pool_remaining() != rem0 - 2 { iv_reset(cp); return 512; };
    iv_reset(cp);
    if iv_pool_used() != used0 { return 1024; };
    if iv_pool_remaining() != rem0 { return 2048; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_initial_status();
    fails = fails + check_alloc_accounting_and_reset();
    return fails;
}
