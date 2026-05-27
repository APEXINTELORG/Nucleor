// 10_fft.nr — Demonstrate FFT power spectrum on a sum of two sinusoids.
// Input: 256-sample signal containing 5 Hz and 13 Hz components.
// Expected: power spectrum has peaks near bins 5 and 13.

// `use std::*` would be the shorter form, but the use-std-* path has a
// known cfile-collection bug that drops rod-side C files from the clang
// link line. Explicit import composes the correct link set; tracked
// separately as a compiler issue.
import "stdlib/rods/fft.nr"
import "stdlib/rods/complex.nr"

fn ex_int_to_str(n: i64) -> str {
    if n == 0 { return "0"; };
    let mut s: str = ""; let mut v: i64 = n;
    if v < 0 { v = 0 - v; };
    while v > 0 { let d: i64 = v - (v / 10) * 10; s = str_concat(str_substring("0123456789", d, d + 1), s); v = v / 10; };
    if n < 0 { s = str_concat("-", s); };
    return s;
}

fn ex_f64_to_str(val: i64) -> str {
    let is_neg: i64 = f64_lt(val, f64_from_int(0));
    let av: i64 = f64_abs(val);
    let ip: i64 = f64_to_int(f64_floor(av));
    let frac: i64 = f64_sub(av, f64_from_int(ip));
    let fs: i64 = f64_to_int(f64_floor(f64_mul(frac, f64_from_int(1000000))));
    let mut fstr: str = ex_int_to_str(fs);
    while str_len(fstr) < 6 { fstr = str_concat("0", fstr); };
    let mut r: str = str_concat(ex_int_to_str(ip), str_concat(".", fstr));
    if is_neg == 1 { r = str_concat("-", r); };
    return r;
}

fn main() -> i64 {
    let n: i64 = 256;
    let signal: i64 = vec_new();
    let two_pi: i64 = f64_tau();
    let n_f: i64 = f64_from_int(n);

    let mut k: i64 = 0;
    while k < n {
        let kf: i64 = f64_from_int(k);
        let arg5: i64 = f64_div(f64_mul(two_pi, f64_mul(f64_from_int(5), kf)), n_f);
        let arg13: i64 = f64_div(f64_mul(two_pi, f64_mul(f64_from_int(13), kf)), n_f);
        let val: i64 = f64_add(f64_sin(arg5), f64_sin(arg13));
        vec_push(signal, val);
        k = k + 1;
    };

    let spectrum: i64 = fft_power_spectrum(signal, n);

    let mut best_bin: i64 = 0;
    let mut best_pow: i64 = f64_from_int(0);
    let mut i: i64 = 1;
    while i < n / 2 {
        let p: i64 = vec_get(spectrum, i);
        if f64_gt(p, best_pow) == 1 { best_pow = p; best_bin = i; };
        i = i + 1;
    };

    print("256-sample signal: 5 Hz + 13 Hz sinusoids");
    print(str_concat("Largest spectral bin: ", str_concat(ex_int_to_str(best_bin),
                     str_concat("  power = ", ex_f64_to_str(best_pow)))));
    return 0;
}
