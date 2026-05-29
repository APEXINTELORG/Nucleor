// v0.8.140 stdlib/rods/concurrency.nr first test coverage.
//
// Structured-concurrency wrappers — channels, mutex, atomic
// counter, CPU count. Pre-v0.8.140: zero coverage.
//
// Locks four invariants (single-threaded — multi-thread spawn
// semantics are out of scope for a smoke):
//   1. Channel FIFO: send a, b, c on a capacity-N channel,
//      recv returns a, b, c in order. The defining property.
//   2. Channel length: len tracks queued-but-unreceived items.
//   3. Mutex lock/unlock: lock + unlock + relock-after-unlock
//      sequence does not deadlock or fault.
//   4. cpu_count > 0: foundational system query for any
//      worker-pool autosize logic.
//
// Multi-thread spawn / join / parallel-map require a worker fn
// pointer + actual scheduler activity; those need their own
// dedicated test infrastructure. Documented as out of scope.
//
// Expected: rc=0.

import "stdlib/rods/concurrency.nr"

fn check_channel_fifo() -> i64 {
    let ch: i64 = conc_channel(8);
    conc_send(ch, 100);
    conc_send(ch, 200);
    conc_send(ch, 300);
    if conc_recv(ch) != 100 { return 1; };
    if conc_recv(ch) != 200 { return 2; };
    if conc_recv(ch) != 300 { return 4; };
    return 0;
}

fn check_channel_len() -> i64 {
    let ch: i64 = conc_channel(8);
    if conc_channel_len(ch) != 0 { return 8; };
    conc_send(ch, 1);
    conc_send(ch, 2);
    if conc_channel_len(ch) != 2 { return 16; };
    conc_recv(ch);
    if conc_channel_len(ch) != 1 { return 32; };
    return 0;
}

fn check_mutex_cycle() -> i64 {
    let m: i64 = conc_mutex();
    conc_lock(m);
    conc_unlock(m);
    // Re-lock after unlock must succeed (would deadlock if first
    // lock left state inconsistent).
    conc_lock(m);
    conc_unlock(m);
    return 0;
}

fn check_cpu_count() -> i64 {
    let n: i64 = conc_cpu_count();
    if n < 1 { return 64; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_channel_fifo();
    fails = fails + check_channel_len();
    fails = fails + check_mutex_cycle();
    fails = fails + check_cpu_count();
    return fails;
}
