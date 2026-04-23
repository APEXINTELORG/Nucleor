// 18_benchmark.nr — Micro-benchmark harness using v0.2.x time + stats helpers.
//
// Times two CPU-bound workloads (integer Fibonacci and integer-isqrt of
// random values) over N iterations each, then prints summary statistics:
// min / max / mean / median / stddev / p95 / total throughput.
//
// Demonstrates the Nucleor "stats over a vec" idiom that's actually useful:
// a benchmark report.
//
// Demonstrates:
//   v0.2.21  time_elapsed_ms, time_wall_ms (already v0.1, used as anchor)
//   v0.2.24  int_to_str, f64_to_str
//   v0.2.26  str_pad_right, str_pad_left
//   v0.2.29  random_int (alias for rng_int), rng_seed
//   v0.2.30  vec_min_i64, vec_max_i64, vec_mean_f64, vec_median_f64,
//            vec_stddev_f64, vec_percentile_f64
//   v0.1     time_wall_ns, time_monotonic_ns, i64_isqrt
//
// Build: nuc build examples/18_benchmark.nr -o benchmark
// Run:   ./benchmark.exe
//        NUC_BENCH_ITERS=200 ./benchmark.exe

fn fib(n: i64) -> i64 {
    if n < 2 { return n; };
    let mut a: i64 = 0;
    let mut b: i64 = 1;
    let mut i: i64 = 2;
    while i <= n {
        let t: i64 = a + b;
        a = b;
        b = t;
        i = i + 1;
    };
    return b;
}

fn iters_from_env() -> i64 {
    if env_has("NUC_BENCH_ITERS") == 1 {
        let raw: str = env_get("NUC_BENCH_ITERS");
        let n: i64 = str_to_i64(raw);
        if n > 0 { return n; };
    };
    return 100;
}

fn print_row(label: str, n: i64, samples: Vec<i64>) {
    let label_w: i64 = 14;
    let num_w: i64 = 12;
    // All sample values are nanoseconds; convert to microseconds for display.
    let mn_ns: i64 = vec_min_i64(samples);
    let mx_ns: i64 = vec_max_i64(samples);
    let mean_ns_bits: i64 = vec_mean_f64(samples);
    let median_ns_bits: i64 = vec_median_f64(samples);
    let stddev_ns_bits: i64 = vec_stddev_f64(samples);
    let p95_ns_bits: i64 = vec_percentile_f64(samples, f64_from_scaled(950000));

    let line: str = str_concat(
        str_concat(
            str_concat(str_pad_right(label, label_w, 32), str_pad_left(int_to_str(n), 7, 32)),
            str_concat(str_pad_left(int_to_str(mn_ns), num_w, 32), str_pad_left(int_to_str(mx_ns), num_w, 32))
        ),
        str_concat(
            str_concat(str_pad_left(f64_to_str(mean_ns_bits), num_w, 32), str_pad_left(f64_to_str(median_ns_bits), num_w, 32)),
            str_concat(str_pad_left(f64_to_str(stddev_ns_bits), num_w, 32), str_pad_left(f64_to_str(p95_ns_bits), num_w, 32))
        )
    );
    print(line);
}

fn main() -> i64 {
    print("=== Nucleor benchmark harness (v0.2.x stdlib) ===");
    rng_seed(42, 1337);

    let n: i64 = iters_from_env();
    print(str_concat(str_concat("Iterations per workload: ", int_to_str(n)), ""));
    print("");

    // Workload 1: fib(35) per iteration. Should be deterministic.
    let fib_samples: Vec<i64> = vec_new();
    let fib_start: i64 = time_wall_ms();
    let mut i: i64 = 0;
    while i < n {
        let t0: i64 = time_wall_ns();
        let _ = fib(35);
        let t1: i64 = time_wall_ns();
        vec_push(fib_samples, t1 - t0);
        i = i + 1;
    };
    let fib_total_ms: i64 = time_elapsed_ms(fib_start);

    // Workload 2: i64_isqrt of a random 64-bit-ish value per iteration.
    let isqrt_samples: Vec<i64> = vec_new();
    let isqrt_start: i64 = time_wall_ms();
    i = 0;
    while i < n {
        let v: i64 = random_int(1, 1000000000);
        let t0: i64 = time_wall_ns();
        let _ = i64_isqrt(v);
        let t1: i64 = time_wall_ns();
        vec_push(isqrt_samples, t1 - t0);
        i = i + 1;
    };
    let isqrt_total_ms: i64 = time_elapsed_ms(isqrt_start);

    // Header
    let label_w: i64 = 14;
    let num_w: i64 = 12;
    let head: str = str_concat(
        str_concat(
            str_concat(str_pad_right("workload", label_w, 32), str_pad_left("n", 7, 32)),
            str_concat(str_pad_left("min_ns", num_w, 32), str_pad_left("max_ns", num_w, 32))
        ),
        str_concat(
            str_concat(str_pad_left("mean_ns", num_w, 32), str_pad_left("median_ns", num_w, 32)),
            str_concat(str_pad_left("stddev_ns", num_w, 32), str_pad_left("p95_ns", num_w, 32))
        )
    );
    print(head);
    let mut bar: str = "";
    let mut b: i64 = 0;
    let total_w: i64 = label_w + 7 + 6 * num_w;
    while b < total_w { bar = str_concat(bar, "-"); b = b + 1; };
    print(bar);

    print_row("fib(35)", n, fib_samples);
    print_row("i64_isqrt", n, isqrt_samples);

    print("");
    print(str_concat(str_concat("fib(35) total:    ", int_to_str(fib_total_ms)), " ms"));
    print(str_concat(str_concat("i64_isqrt total:  ", int_to_str(isqrt_total_ms)), " ms"));
    return 0;
}
