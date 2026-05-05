// v0.8.139 stdlib/rods/checkpoint.nr first test coverage.
//
// ML model activation checkpointing — save/restore activations
// at layer boundaries for memory-bounded training. Recompute
// forward pass segments during backward. Pre-v0.8.139: zero
// coverage.
//
// Locks four invariants:
//   1. interval=1 stores every layer; n_stored == n_calls.
//   2. interval=4 stores only layers at multiples of 4
//      (memory_saved tracks the others).
//   3. save+restore round-trip preserves f64 values (data
//      identity is the entire point of a checkpoint).
//   4. nearest_before(L) returns the largest checkpointed
//      layer ID ≤ L (drives recompute scheduling).
//
// Expected: rc=0.

import "stdlib/rods/checkpoint.nr"

fn close(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < 1e-9 { return 1; };
    return 0;
}

fn check_interval_one_stores_all() -> i64 {
    let cs: i64 = ckpt_new(1);
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(2.0));
    let mut layer: i64 = 0;
    while layer < 5 {
        ckpt_save(cs, layer, v, 2);
        layer = layer + 1;
    };
    if ckpt_n_stored(cs) != 5 { ckpt_free(cs); return 1; };
    ckpt_free(cs);
    return 0;
}

fn check_interval_four() -> i64 {
    let cs: i64 = ckpt_new(4);
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(0.5));
    let mut layer: i64 = 0;
    // 16 layers, interval=4 → store at 0, 4, 8, 12 = 4 stores
    while layer < 16 {
        ckpt_save(cs, layer, v, 1);
        layer = layer + 1;
    };
    if ckpt_n_stored(cs) != 4 { ckpt_free(cs); return 2; };
    // 12 of 16 layers were skipped — memory_saved should be > 0
    if ckpt_memory_saved(cs) == 0 { ckpt_free(cs); return 4; };
    ckpt_free(cs);
    return 0;
}

fn check_round_trip() -> i64 {
    let cs: i64 = ckpt_new(1);
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(3.14));
    v.push(f64_to_bits(2.71));
    v.push(f64_to_bits(1.41));
    ckpt_save(cs, 0, v, 3);
    let restored: i64 = ckpt_restore(cs, 0);
    if restored == 0 { ckpt_free(cs); return 8; };
    if close(vec_get(restored, 0), f64_to_bits(3.14)) != 1 { ckpt_free(cs); return 16; };
    if close(vec_get(restored, 1), f64_to_bits(2.71)) != 1 { ckpt_free(cs); return 32; };
    if close(vec_get(restored, 2), f64_to_bits(1.41)) != 1 { ckpt_free(cs); return 64; };
    ckpt_free(cs);
    return 0;
}

fn check_nearest_before() -> i64 {
    let cs: i64 = ckpt_new(4);
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(0.0));
    let mut layer: i64 = 0;
    while layer < 16 {
        ckpt_save(cs, layer, v, 1);
        layer = layer + 1;
    };
    // Stored layers: 0, 4, 8, 12. nearest_before(10) should be 8.
    if ckpt_nearest_before(cs, 10) != 8 { ckpt_free(cs); return 128; };
    if ckpt_nearest_before(cs, 4) != 4 { ckpt_free(cs); return 256; };
    if ckpt_nearest_before(cs, 15) != 12 { ckpt_free(cs); return 512; };
    ckpt_free(cs);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_interval_one_stores_all();
    fails = fails + check_interval_four();
    fails = fails + check_round_trip();
    fails = fails + check_nearest_before();
    return fails;
}
