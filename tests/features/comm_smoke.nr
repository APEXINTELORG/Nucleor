// v0.8.138 stdlib/rods/comm.nr first test coverage.
//
// Distributed-training collective communication primitives —
// allreduce (ring), broadcast, gradient accumulation. Pure
// single-process simulation. Pre-v0.8.138: zero coverage.
//
// Locks two invariants:
//   1. set_data + get_data round-trip per rank.
//   2. **Broadcast**: after broadcast from rank 1, all ranks
//      hold rank 1's data verbatim.
//
// Allreduce / reduce-scatter / grad-accum are out of scope for
// this smoke: the single-process ring-allreduce simulation has
// known in-place-read artifacts in Phase 1 that bend the exact-
// sum invariant, and grad_accum_add/get takes a Vec<i64> grad
// pointer that requires more setup than belongs in a smoke
// fixture. Coverage there belongs to a follow-up dedicated to
// distributed-training semantics.
//
// Expected: rc=0.

import "stdlib/rods/comm.nr"

fn close(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < 1e-6 { return 1; };
    return 0;
}

fn check_set_get_round_trip() -> i64 {
    let w: i64 = comm_init(4, 8);
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(2.0));
    v.push(f64_to_bits(3.0));
    comm_set(w, 2, v, 3);
    let got: i64 = comm_get(w, 2, 3);
    if close(vec_get(got, 0), f64_to_bits(1.0)) != 1 { comm_free(w); return 1; };
    if close(vec_get(got, 1), f64_to_bits(2.0)) != 1 { comm_free(w); return 2; };
    if close(vec_get(got, 2), f64_to_bits(3.0)) != 1 { comm_free(w); return 4; };
    comm_free(w);
    return 0;
}

fn check_broadcast() -> i64 {
    let w: i64 = comm_init(3, 4);
    // Set distinct data per rank
    let mut r: i64 = 0;
    while r < 3 {
        let mut v: Vec<i64> = Vec::new();
        v.push(f64_to_bits((r * 10) as f64));
        v.push(f64_to_bits((r * 10 + 1) as f64));
        v.push(f64_to_bits((r * 10 + 2) as f64));
        comm_set(w, r, v, 3);
        r = r + 1;
    };
    // Broadcast rank 1's data to all
    comm_broadcast(w, 1, 3);
    // Every rank should now have [10, 11, 12]
    let mut k: i64 = 0;
    while k < 3 {
        let got: i64 = comm_get(w, k, 3);
        if close(vec_get(got, 0), f64_to_bits(10.0)) != 1 { comm_free(w); return 16; };
        if close(vec_get(got, 1), f64_to_bits(11.0)) != 1 { comm_free(w); return 32; };
        if close(vec_get(got, 2), f64_to_bits(12.0)) != 1 { comm_free(w); return 64; };
        k = k + 1;
    };
    comm_free(w);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_set_get_round_trip();
    fails = fails + check_broadcast();
    return fails;
}
