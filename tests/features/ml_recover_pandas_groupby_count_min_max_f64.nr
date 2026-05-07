import "stdlib/rods/ml/data_facade.nr"

// ml_recover_pandas_groupby_count_min_max_f64 — struct-returning
// groupby aggregation: count + min + max per group.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // 5 rows, 2 groups: key=1 (values 10, 30), key=2 (values 20, 40, 50).
    let mut keys: Vec<i64> = Vec::new();
    keys.push(1); keys.push(2); keys.push(1); keys.push(2); keys.push(2);

    let mut values: Vec<f64> = Vec::new();
    values.push(10.0); values.push(20.0); values.push(30.0); values.push(40.0); values.push(50.0);

    let frame: FrameI64F64 = frame_i64_f64_from_vec("k", "v", keys, values);

    let stats: GroupedStatsI64F64 = frame_i64_f64_groupby_count_min_max(&frame);
    if stats.groups != 2 { print("FAIL stats groups"); fail = fail + 1; };

    // group 0: key=1, count=2, min=10, max=30
    if vec_get(stats.keys, 0) != 1 { print("FAIL k0"); fail = fail + 1; };
    if vec_get(stats.counts, 0) != 2 { print("FAIL count 0"); fail = fail + 1; };
    if close_f64(vec_get(stats.mins, 0), 10.0, eps) != 1 { print("FAIL min 0"); fail = fail + 1; };
    if close_f64(vec_get(stats.maxs, 0), 30.0, eps) != 1 { print("FAIL max 0"); fail = fail + 1; };

    // group 1: key=2, count=3, min=20, max=50
    if vec_get(stats.keys, 1) != 2 { print("FAIL k1"); fail = fail + 1; };
    if vec_get(stats.counts, 1) != 3 { print("FAIL count 1"); fail = fail + 1; };
    if close_f64(vec_get(stats.mins, 1), 20.0, eps) != 1 { print("FAIL min 1"); fail = fail + 1; };
    if close_f64(vec_get(stats.maxs, 1), 50.0, eps) != 1 { print("FAIL max 1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_pandas_groupby_count_min_max_f64"); return 0; };
    print("FAIL ml_recover_pandas_groupby_count_min_max_f64");
    return 1;
}
