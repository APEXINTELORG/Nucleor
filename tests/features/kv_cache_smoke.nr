// v0.8.252 stdlib/rods/kv_cache.nr first test coverage.
//
// Paged KV cache for LLM inference. Pre-v0.8.252: zero coverage.
//
// Drift fix in this ship. Pre-v0.8.252 the rod declared 4-arg
// getters (`ch, layer, head, pos`) but the C runtime took 5
// (`start_pos, end_pos`) — silent miscompute, the call site read
// garbage from the un-pushed end_pos slot and returned a Vec sized
// from random bits. Same bug class as v0.8.45 ML-1 attention2
// 6-vs-7-arg drift. Fix: rename the 5-arg form to `_range`, add a
// 4-arg single-position wrapper that calls `_range(pos, pos+1)`.
// Surfaced by probe-finding `kv_cache_arity_mismatch_2026-05-05.md`.
//
// Locks five invariants:
//
//   1. Lifecycle — `kv_new` returns a non-zero handle; `kv_free`
//      does not crash.
//   2. Initial state — `kv_seq_len(ch) == 0` and
//      `kv_blocks_used(ch) == 0` immediately after construction.
//   3. Insert advances seq_len — after inserting at pos=0,
//      `seq_len == 1`; after pos=2, `seq_len == 3`.
//   4. Single-position get — `kv_get_k(ch, l, h, pos)` returns a
//      Vec handle of length `head_dim` (was returning garbage-sized
//      Vec pre-v0.8.252).
//   5. Range get matches single-position — for the same pos,
//      `kv_get_k_range(ch, l, h, pos, pos+1)` and
//      `kv_get_k(ch, l, h, pos)` return the same length and the
//      same first element.
//
// Expected: rc=0.

import "stdlib/rods/kv_cache.nr"

fn make_vec4(a: i64, b: i64, c: i64, d: i64) -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(a);
    v.push(b);
    v.push(c);
    v.push(d);
    return v;
}

fn check_lifecycle() -> i64 {
    let ch: i64 = kv_new(2, 4, 4, 64);
    if ch == 0 { return 1; };
    kv_free(ch);
    return 0;
}

fn check_initial_state() -> i64 {
    let ch: i64 = kv_new(2, 4, 4, 64);
    if kv_seq_len(ch) != 0 { kv_free(ch); return 2; };
    if kv_blocks_used(ch) != 0 { kv_free(ch); return 4; };
    kv_free(ch);
    return 0;
}

fn check_insert_advances_seq_len() -> i64 {
    let ch: i64 = kv_new(2, 4, 4, 64);
    let k0: Vec<i64> = make_vec4(
        f64_to_bits(1.0), f64_to_bits(2.0),
        f64_to_bits(3.0), f64_to_bits(4.0));
    let v0: Vec<i64> = make_vec4(
        f64_to_bits(5.0), f64_to_bits(6.0),
        f64_to_bits(7.0), f64_to_bits(8.0));
    kv_insert(ch, 0, 0, 0, k0, v0);
    if kv_seq_len(ch) != 1 { kv_free(ch); return 8; };

    let k2: Vec<i64> = make_vec4(
        f64_to_bits(9.0), f64_to_bits(10.0),
        f64_to_bits(11.0), f64_to_bits(12.0));
    let v2: Vec<i64> = make_vec4(
        f64_to_bits(13.0), f64_to_bits(14.0),
        f64_to_bits(15.0), f64_to_bits(16.0));
    kv_insert(ch, 0, 0, 2, k2, v2);
    if kv_seq_len(ch) != 3 { kv_free(ch); return 16; };

    kv_free(ch);
    return 0;
}

fn check_single_position_get() -> i64 {
    let ch: i64 = kv_new(2, 4, 4, 64);
    let k0: Vec<i64> = make_vec4(
        f64_to_bits(1.0), f64_to_bits(2.0),
        f64_to_bits(3.0), f64_to_bits(4.0));
    let v0: Vec<i64> = make_vec4(
        f64_to_bits(5.0), f64_to_bits(6.0),
        f64_to_bits(7.0), f64_to_bits(8.0));
    kv_insert(ch, 0, 0, 0, k0, v0);

    let got_k: i64 = kv_get_k(ch, 0, 0, 0);
    if got_k == 0 { kv_free(ch); return 32; };
    if vec_len(got_k) != 4 { kv_free(ch); return 64; };

    let got_v: i64 = kv_get_v(ch, 0, 0, 0);
    if got_v == 0 { kv_free(ch); return 128; };
    if vec_len(got_v) != 4 { kv_free(ch); return 256; };

    kv_free(ch);
    return 0;
}

fn check_range_matches_single() -> i64 {
    let ch: i64 = kv_new(2, 4, 4, 64);
    let k0: Vec<i64> = make_vec4(
        f64_to_bits(1.0), f64_to_bits(2.0),
        f64_to_bits(3.0), f64_to_bits(4.0));
    let v0: Vec<i64> = make_vec4(
        f64_to_bits(5.0), f64_to_bits(6.0),
        f64_to_bits(7.0), f64_to_bits(8.0));
    kv_insert(ch, 0, 0, 0, k0, v0);

    let single_k: i64 = kv_get_k(ch, 0, 0, 0);
    let range_k:  i64 = kv_get_k_range(ch, 0, 0, 0, 1);
    if vec_len(single_k) != vec_len(range_k) { kv_free(ch); return 512; };
    if vec_get(single_k, 0) != vec_get(range_k, 0) { kv_free(ch); return 1024; };

    kv_free(ch);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_lifecycle();
    fails = fails + check_initial_state();
    fails = fails + check_insert_advances_seq_len();
    fails = fails + check_single_position_get();
    fails = fails + check_range_matches_single();
    return fails;
}
