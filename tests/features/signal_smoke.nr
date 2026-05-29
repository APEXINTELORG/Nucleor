// v0.8.170 stdlib/rods/signal.nr first test coverage.
//
// Digital Signal Processing primitives — windows, zero-crossings,
// up/down-sampling. Pre-v0.8.170: zero coverage.
//
// Locks four DSP invariants:
//   1. Hamming window length matches request — `window_hamming(64)`
//      returns a 64-element Vec.
//   2. Hann window endpoint — Hann window's first sample is 0
//      (the defining property: `0.5 * (1 - cos(0)) = 0`).
//   3. Zero crossings — alternating-sign signal [+1,-1,+1,-1]
//      has 3 zero crossings (one between each adjacent pair).
//   4. Downsample halves length — downsample by factor 2 on
//      a 10-element signal produces 5 samples.
//
// Expected: rc=0.

import "stdlib/rods/signal.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_hamming_length() -> i64 {
    let w: i64 = sig_window_hamming(64);
    if w == 0 { return 1; };
    if vec_len(w) != 64 { return 2; };
    return 0;
}

fn check_hann_endpoint() -> i64 {
    let w: i64 = sig_window_hann(8);
    if w == 0 { return 4; };
    // Hann: w[0] = 0.5 * (1 - cos(0)) = 0
    if close(vec_get(w, 0), f64_to_bits(0.0), 1e-9) != 1 { return 8; };
    return 0;
}

fn check_zero_crossings() -> i64 {
    // Alternating-sign signal: [+1, -1, +1, -1] → 3 crossings
    let mut s: Vec<i64> = Vec::new();
    s.push(f64_to_bits(1.0));
    s.push(f64_to_bits(0.0 - 1.0));
    s.push(f64_to_bits(1.0));
    s.push(f64_to_bits(0.0 - 1.0));
    let zc: i64 = sig_zero_crossings(s);
    // sig_zero_crossings returns a Vec<i64> of crossing indices.
    if vec_len(zc) != 3 { return 16; };
    return 0;
}

fn check_downsample() -> i64 {
    // 10-sample signal, factor 2 → 5 samples
    let mut s: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 10 {
        s.push(f64_to_bits(i as f64));
        i = i + 1;
    };
    let ds: i64 = sig_downsample(s, 2);
    if ds == 0 { return 32; };
    if vec_len(ds) != 5 { return 64; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_hamming_length();
    fails = fails + check_hann_endpoint();
    fails = fails + check_zero_crossings();
    fails = fails + check_downsample();
    return fails;
}
