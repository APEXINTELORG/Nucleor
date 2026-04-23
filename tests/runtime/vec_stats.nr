// vec_stats — RFC-0017 stdlib enrichment.
//
//   vec_mean_f64(v)               -> i64 (f64 bits)
//   vec_median_f64(v)             -> i64 (f64 bits)
//   vec_variance_f64(v)           -> i64 (f64 bits)
//   vec_stddev_f64(v)             -> i64 (f64 bits)
//   vec_range_i64(v)              -> i64
//   vec_percentile_f64(v, p)      -> i64 (f64 bits, p in [0.0, 1.0])

fn main() -> i64 {
    let mut fail: i64 = 0;

    let v: Vec<i64> = vec_new();
    vec_push(v, 2); vec_push(v, 4); vec_push(v, 4);
    vec_push(v, 4); vec_push(v, 5); vec_push(v, 5);
    vec_push(v, 7); vec_push(v, 9);
    // Classic stats example: mean = 5.0, variance = 4.0, stddev = 2.0.

    let mean: i64 = vec_mean_f64(v);
    let expected_mean: i64 = f64_from_scaled(5000000);
    if mean != expected_mean { fail = fail + 1; print("FAIL mean"); };

    let var: i64 = vec_variance_f64(v);
    let expected_var: i64 = f64_from_scaled(4000000);
    if var != expected_var { fail = fail + 1; print("FAIL variance"); };

    let sd: i64 = vec_stddev_f64(v);
    let expected_sd: i64 = f64_from_scaled(2000000);
    if sd != expected_sd { fail = fail + 1; print("FAIL stddev"); };

    let rng: i64 = vec_range_i64(v);
    if rng != 7 { fail = fail + 1; print("FAIL range"); };

    // Median of [2,4,4,4,5,5,7,9] = (4 + 5) / 2 = 4.5
    let med: i64 = vec_median_f64(v);
    let expected_med: i64 = f64_from_scaled(4500000);
    if med != expected_med { fail = fail + 1; print("FAIL median"); };

    // Odd-length median
    let v2: Vec<i64> = vec_new();
    vec_push(v2, 1); vec_push(v2, 2); vec_push(v2, 3);
    let med2: i64 = vec_median_f64(v2);
    let expected_med2: i64 = f64_from_scaled(2000000);
    if med2 != expected_med2 { fail = fail + 1; print("FAIL median odd"); };

    // Percentile: 0% -> min, 100% -> max
    let p_min: i64 = vec_percentile_f64(v, f64_from_scaled(0));
    let expected_min: i64 = f64_from_scaled(2000000);
    if p_min != expected_min { fail = fail + 1; print("FAIL pct 0"); };
    let p_max: i64 = vec_percentile_f64(v, f64_from_scaled(1000000));
    let expected_max: i64 = f64_from_scaled(9000000);
    if p_max != expected_max { fail = fail + 1; print("FAIL pct 100"); };

    // Empty vec -> 0 / 0.0
    let empty: Vec<i64> = vec_new();
    let zero_bits: i64 = f64_from_scaled(0);
    if vec_mean_f64(empty) != zero_bits { fail = fail + 1; print("FAIL mean empty"); };
    if vec_range_i64(empty) != 0 { fail = fail + 1; print("FAIL range empty"); };

    // Source vec not mutated by median
    let med3: i64 = vec_median_f64(v);
    if med3 != expected_med { fail = fail + 1; print("FAIL median repeat"); };

    if fail == 0 { print("OK vec_stats"); return 0; };
    return 1;
}
