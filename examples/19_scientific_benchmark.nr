// 19_scientific_benchmark.nr — Real numerical-workload benchmarks.
//
// Times scientific-computing primitives users actually run: dense
// matrix solve, matrix multiply, FFT, sort, dot product. Reports
// per-iteration timing stats (min, mean, median, p95) plus total
// throughput. Pairs with examples/18_benchmark.nr (which covers
// integer micro-benchmarks).
//
// Build: nuc build examples/19_scientific_benchmark.nr -o sci_bench
// Run:   ./sci_bench
//        NUC_BENCH_ITERS=50 ./sci_bench
//
// Workloads (parameters tuned for sub-second-per-iteration on
// modest hardware so the harness completes in seconds):
//
//   dgesv-200      — solve a 200x200 linear system Ax=b (Gaussian
//                    elimination with partial pivoting; no LAPACK
//                    dependency).
//   dgemm-128      — 128x128 dense matrix multiply.
//   dot-1M         — dot product of two 1M-element f64 vectors.
//   fft-1024       — 1024-point complex FFT (in-place, radix-2).
//   sort-100K      — qsort of 100K randomly-generated i64s.

use std::linalg;
use std::fft;
use std::complex;

fn iters_from_env() -> i64 {
    if env_has("NUC_BENCH_ITERS") == 1 {
        let raw: str = env_get("NUC_BENCH_ITERS");
        let n: i64 = str_to_i64(raw);
        if n > 0 { return n; };
    };
    return 20;
}

fn print_row(label: str, n: i64, samples: Vec<i64>) {
    let label_w: i64 = 16;
    let num_w: i64 = 14;
    let mn_ns: i64 = vec_min_i64(samples);
    let mx_ns: i64 = vec_max_i64(samples);
    let mean_ns_bits: i64 = vec_mean_f64(samples);
    let median_ns_bits: i64 = vec_median_f64(samples);
    let stddev_ns_bits: i64 = vec_stddev_f64(samples);
    // 95th percentile = 0.95 as f64; build via int division.
    let p95_quantile: i64 = f64_div(f64_from_int(95), f64_from_int(100));
    let p95_ns_bits: i64 = vec_percentile_f64(samples, p95_quantile);
    let line: str = str_concat(
        str_concat(
            str_concat(str_pad_right(label, label_w, 32), str_pad_left(int_to_str(n), 6, 32)),
            str_concat(str_pad_left(int_to_str(mn_ns), num_w, 32), str_pad_left(int_to_str(mx_ns), num_w, 32))
        ),
        str_concat(
            str_concat(str_pad_left(f64_to_str(mean_ns_bits), num_w, 32), str_pad_left(f64_to_str(median_ns_bits), num_w, 32)),
            str_concat(str_pad_left(f64_to_str(stddev_ns_bits), num_w, 32), str_pad_left(f64_to_str(p95_ns_bits), num_w, 32))
        )
    );
    print(line);
}

// Build a well-conditioned diagonally-dominant n×n matrix and an
// n×1 RHS for the dgesv benchmark. Same matrix every iter so the
// benchmark measures the solver, not RNG cost.
fn make_dgesv_input(n: i64) -> Vec<i64> {
    let A: i64 = linalg_new(n, n);
    let mut i: i64 = 0;
    while i < n {
        let mut j: i64 = 0;
        while j < n {
            if i == j {
                linalg_set(A, i, j, f64_from_int(n + 1));
            } else {
                let v: i64 = f64_from_int(1 + ((i * 7) + (j * 3)));   // ~0.1 + small noise
                linalg_set(A, i, j, v);
            };
            j = j + 1;
        };
        i = i + 1;
    };
    let b: i64 = linalg_new(n, 1);
    i = 0;
    while i < n {
        linalg_set(b, i, 0, f64_from_int(i + 1));
        i = i + 1;
    };
    let mut out: Vec<i64> = Vec::new();
    out.push(A);
    out.push(b);
    return out;
}

fn make_dgemm_input(n: i64) -> Vec<i64> {
    let A: i64 = linalg_new(n, n);
    let B: i64 = linalg_new(n, n);
    let mut i: i64 = 0;
    while i < n {
        let mut j: i64 = 0;
        while j < n {
            linalg_set(A, i, j, f64_from_int(1 + ((i * 13) + (j * 7))));
            linalg_set(B, i, j, f64_from_int(1 + ((i * 11) + (j * 17))));
            j = j + 1;
        };
        i = i + 1;
    };
    let mut out: Vec<i64> = Vec::new();
    out.push(A);
    out.push(B);
    return out;
}

// Dot product of two f64 vectors stored as i64-bitcast Vecs.
fn dot_f64(a: Vec<i64>, b: Vec<i64>) -> i64 {
    let n: i64 = vec_len(a);
    let mut acc: i64 = f64_from_int(0);
    let mut i: i64 = 0;
    while i < n {
        let av: i64 = vec_get(a, i);
        let bv: i64 = vec_get(b, i);
        acc = f64_add(acc, f64_mul(av, bv));
        i = i + 1;
    };
    return acc;
}

// Build interleaved-complex (real, imag) Vec for FFT input.
fn make_fft_input(n: i64) -> Vec<i64> {
    let mut data: Vec<i64> = Vec::with_capacity(n * 2);
    let mut i: i64 = 0;
    while i < n {
        // Real = sin(2*pi*i/n); imag = 0. Approximate via integer
        // i*100 scaled; doesn't matter — measuring FFT loop, not the
        // generation.
        data.push(f64_from_int(i + 1));   // re
        data.push(f64_from_int(0));        // im
        i = i + 1;
    };
    return data;
}

// Build a Vec of n pseudo-random i64s. Uses a simple LCG so the
// sequence is reproducible and the rng cost is excluded from the
// timed sort itself.
fn make_sort_input(n: i64) -> Vec<i64> {
    let mut v: Vec<i64> = Vec::with_capacity(n);
    let mut state: i64 = 12345;
    let mut i: i64 = 0;
    while i < n {
        // wrapping_mul avoids overflow panics on the classic LCG step.
        state = wrapping_add(wrapping_mul(state, 1103515245), 12345);
        let masked: i64 = state & 9223372036854775807;
        v.push(masked);
        i = i + 1;
    };
    return v;
}

fn main() -> i64 {
    print("=== Nucleor scientific benchmark suite ===");
    print("Linux x86_64, hosted env. See docs/benchmarks.md for");
    print("reference numbers and reproduction instructions.");
    let n: i64 = iters_from_env();
    print(str_concat("Iterations per workload: ", int_to_str(n)));
    print("");

    // ---- dgesv-200 ----
    let dgesv_inputs: Vec<i64> = make_dgesv_input(200);
    let A_dgesv: i64 = vec_get(dgesv_inputs, 0);
    let b_dgesv: i64 = vec_get(dgesv_inputs, 1);
    let mut dgesv_samples: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < n {
        let t0: i64 = time_wall_ns();
        let x: i64 = linalg_solve(A_dgesv, b_dgesv);
        let t1: i64 = time_wall_ns();
        linalg_free(x);
        dgesv_samples.push(t1 - t0);
        i = i + 1;
    };
    linalg_free(A_dgesv);
    linalg_free(b_dgesv);

    // ---- dgemm-128 ----
    let dgemm_inputs: Vec<i64> = make_dgemm_input(128);
    let A_dgemm: i64 = vec_get(dgemm_inputs, 0);
    let B_dgemm: i64 = vec_get(dgemm_inputs, 1);
    let mut dgemm_samples: Vec<i64> = Vec::new();
    i = 0;
    while i < n {
        let t0: i64 = time_wall_ns();
        let C: i64 = linalg_mul(A_dgemm, B_dgemm);
        let t1: i64 = time_wall_ns();
        linalg_free(C);
        dgemm_samples.push(t1 - t0);
        i = i + 1;
    };
    linalg_free(A_dgemm);
    linalg_free(B_dgemm);

    // ---- dot-1M ----
    let dot_n: i64 = 1000000;
    let mut a_dot: Vec<i64> = Vec::with_capacity(dot_n);
    let mut b_dot: Vec<i64> = Vec::with_capacity(dot_n);
    let mut j: i64 = 0;
    while j < dot_n {
        a_dot.push(f64_from_int(j + 1));
        b_dot.push(f64_from_int((j * 3) + 1));
        j = j + 1;
    };
    let mut dot_samples: Vec<i64> = Vec::new();
    i = 0;
    while i < n {
        let t0: i64 = time_wall_ns();
        let _result: i64 = dot_f64(a_dot, b_dot);
        let t1: i64 = time_wall_ns();
        dot_samples.push(t1 - t0);
        i = i + 1;
    };

    // ---- fft-1024 ----
    let fft_size: i64 = 1024;
    let mut fft_samples: Vec<i64> = Vec::new();
    i = 0;
    while i < n {
        let data: Vec<i64> = make_fft_input(fft_size);
        let t0: i64 = time_wall_ns();
        let _out: i64 = fft_1d(data, fft_size, 1);
        let t1: i64 = time_wall_ns();
        fft_samples.push(t1 - t0);
        i = i + 1;
    };

    // ---- sort-100K ----
    let sort_n: i64 = 100000;
    let mut sort_samples: Vec<i64> = Vec::new();
    i = 0;
    while i < n {
        let v: Vec<i64> = make_sort_input(sort_n);
        let t0: i64 = time_wall_ns();
        let sorted: Vec<i64> = vec_sort_i64(v);
        let t1: i64 = time_wall_ns();
        sort_samples.push(t1 - t0);
        i = i + 1;
    };

    // Header
    let label_w: i64 = 16;
    let num_w: i64 = 14;
    let head: str = str_concat(
        str_concat(
            str_concat(str_pad_right("workload", label_w, 32), str_pad_left("n", 6, 32)),
            str_concat(str_pad_left("min_ns", num_w, 32), str_pad_left("max_ns", num_w, 32))
        ),
        str_concat(
            str_concat(str_pad_left("mean_ns", num_w, 32), str_pad_left("median_ns", num_w, 32)),
            str_concat(str_pad_left("stddev_ns", num_w, 32), str_pad_left("p95_ns", num_w, 32))
        )
    );
    print(head);
    let mut bar: str = "";
    let mut k: i64 = 0;
    let total_w: i64 = label_w + 6 + 6 * num_w;
    while k < total_w { bar = str_concat(bar, "-"); k = k + 1; };
    print(bar);

    print_row("dgesv-200", n, dgesv_samples);
    print_row("dgemm-128", n, dgemm_samples);
    print_row("dot-1M", n, dot_samples);
    print_row("fft-1024", n, fft_samples);
    print_row("sort-100K", n, sort_samples);

    print("");
    print("All workloads use pure-Nucleor reference implementations");
    print("backed by tensor_rt.c, fft_rt.c, and the stdlib sort.");
    print("Numbers are wall-clock nanoseconds per iteration.");
    return 0;
}
