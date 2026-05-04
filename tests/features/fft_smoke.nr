// v0.8.102 stdlib/rods/fft.nr first test coverage.
//
// Per the zero-coverage rod survey, fft.nr (Cooley-Tukey radix-2
// FFT, real FFT, convolution, power spectrum, correlation) had
// no existing tests. Silent regressions in spectral computations
// would invalidate any DSP / signal-processing pipeline.
//
// Locks textbook FFT invariants:
//
//   1. Forward then inverse FFT is approximately the identity:
//      ifft(fft(x)) ≈ x  (within float-arithmetic rounding).
//   2. Forward FFT of a constant input concentrates energy in
//      the DC bin (bin 0): magnitude(bin 0) is large; magnitude
//      of other bins is approximately zero.
//   3. FFT of all zeros is all zeros (zero-input).
//
// Data layout per fft_rt.c FFVec: interleaved [re0, im0, re1,
// im1, ...] in Vec<i64> of f64-bits.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/fft.nr"

fn close_loose(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let diff: f64 = af - bf;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff < 1e-6 { return 1; };
    return 0;
}

fn check_fft_zero_in_zero_out() -> i64 {
    let mut cx: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 8 {
        cx.push(f64_to_bits(0.0));   // re
        cx.push(f64_to_bits(0.0));   // im
        i = i + 1;
    };
    let result: i64 = fft_1d(cx, 4, 1);
    // result is FFVec handle; treat as Vec<i64>. All entries
    // should be ~0.
    let mut k: i64 = 0;
    while k < 8 {
        if close_loose(vec_get(result, k), f64_to_bits(0.0)) != 1 {
            return 1;
        };
        k = k + 1;
    };
    return 0;
}

fn check_fft_ifft_round_trip() -> i64 {
    // x = [1, 2, 3, 4] (real); pack as [1+0i, 2+0i, 3+0i, 4+0i]
    let mut x: Vec<i64> = Vec::new();
    x.push(f64_to_bits(1.0));   x.push(f64_to_bits(0.0));
    x.push(f64_to_bits(2.0));   x.push(f64_to_bits(0.0));
    x.push(f64_to_bits(3.0));   x.push(f64_to_bits(0.0));
    x.push(f64_to_bits(4.0));   x.push(f64_to_bits(0.0));

    // Forward FFT (forward=1).
    let fwd: i64 = fft_1d(x, 4, 1);
    // Repack the forward result into a Vec<i64> for inverse.
    let mut fwd_in: Vec<i64> = Vec::new();
    let mut k: i64 = 0;
    while k < 8 {
        fwd_in.push(vec_get(fwd, k));
        k = k + 1;
    };
    let inv: i64 = fft_1d(fwd_in, 4, 0);

    // ifft(fft(x)) should recover [1, 2, 3, 4] in the real
    // components (positions 0, 2, 4, 6).
    if close_loose(vec_get(inv, 0), f64_to_bits(1.0)) != 1 { return 2; };
    if close_loose(vec_get(inv, 2), f64_to_bits(2.0)) != 1 { return 4; };
    if close_loose(vec_get(inv, 4), f64_to_bits(3.0)) != 1 { return 8; };
    if close_loose(vec_get(inv, 6), f64_to_bits(4.0)) != 1 { return 16; };
    return 0;
}

fn check_fft_dc_concentrate() -> i64 {
    // Constant signal [5, 5, 5, 5] → all energy in DC bin.
    let mut x: Vec<i64> = Vec::new();
    x.push(f64_to_bits(5.0));   x.push(f64_to_bits(0.0));
    x.push(f64_to_bits(5.0));   x.push(f64_to_bits(0.0));
    x.push(f64_to_bits(5.0));   x.push(f64_to_bits(0.0));
    x.push(f64_to_bits(5.0));   x.push(f64_to_bits(0.0));
    let fwd: i64 = fft_1d(x, 4, 1);
    // bin 0 real should be ~ N * mean = 4 * 5 = 20
    let dc_re: f64 = f64_from_bits(vec_get(fwd, 0));
    if dc_re < 19.5 { return 32; };
    if dc_re > 20.5 { return 64; };
    // bin 1 real + im should be ~ 0
    let b1_re: f64 = f64_from_bits(vec_get(fwd, 2));
    let b1_im: f64 = f64_from_bits(vec_get(fwd, 3));
    let abs_re: f64 = if b1_re < 0.0 { 0.0 - b1_re } else { b1_re };
    let abs_im: f64 = if b1_im < 0.0 { 0.0 - b1_im } else { b1_im };
    if abs_re > 1e-6 { return 128; };
    if abs_im > 1e-6 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_fft_zero_in_zero_out();
    fails = fails + check_fft_ifft_round_trip();
    fails = fails + check_fft_dc_concentrate();
    return fails;
}
