import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

// ml_data_facade_smoke — exercises the pandas-style FrameI64F64 surface
// from stdlib/rods/ml/data_facade.nr: typed-vector ingest, groupby
// sum+mean, filter-ge, values-tensor projection. Self-contained
// (inline-literal frame; no examples/fixtures/*.csv dependency).
// Deeper pandas parity rods land in subsequent batches once the
// fixture relocation completes.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // Frame: keys = [1, 1, 2, 2, 3], values = [10.0, 20.0, 30.0, 40.0, 50.0]
    // groupby(key).agg(sum, mean) -> {1: (30, 15), 2: (70, 35), 3: (50, 50)}
    let mut keys: Vec<i64> = Vec::new();
    keys.push(1); keys.push(1); keys.push(2); keys.push(2); keys.push(3);

    let mut values: Vec<f64> = Vec::new();
    values.push(10.0); values.push(20.0); values.push(30.0); values.push(40.0); values.push(50.0);

    let frame: FrameI64F64 = frame_i64_f64_from_vec("k", "v", keys, values);

    // values_tensor projection: pulls the value column into a TensorF64 (5x1).
    let vt: TensorF64 = frame_i64_f64_values_tensor(&frame);
    if vt.shape.rows != 5 { print("FAIL values_tensor rows"); fail = fail + 1; };
    if vt.shape.cols != 1 { print("FAIL values_tensor cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&vt, 0, 0), 10.0, eps) != 1 { print("FAIL values_tensor 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&vt, 4, 0), 50.0, eps) != 1 { print("FAIL values_tensor 4"); fail = fail + 1; };

    // filter_value_ge(25.0): keeps rows with value >= 25 -> 3 rows.
    let filtered: FrameI64F64 = frame_i64_f64_filter_value_ge(&frame, 25.0);
    let ft: TensorF64 = frame_i64_f64_values_tensor(&filtered);
    if ft.shape.rows != 3 { print("FAIL filter rows"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&ft, 0, 0), 30.0, eps) != 1 { print("FAIL filter 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&ft, 2, 0), 50.0, eps) != 1 { print("FAIL filter 2"); fail = fail + 1; };

    // groupby_sum_mean: produces 3 groups (keys 1, 2, 3). Direct fields:
    // groups, keys, sums, counts. mean[i] = sums[i] / counts[i].
    let grouped: GroupedI64F64 = frame_i64_f64_groupby_sum_mean(&frame);
    if grouped.groups != 3 { print("FAIL groupby groups"); fail = fail + 1; };
    if vec_get(grouped.keys, 0) != 1 { print("FAIL groupby key 0"); fail = fail + 1; };
    if vec_get(grouped.keys, 1) != 2 { print("FAIL groupby key 1"); fail = fail + 1; };
    if vec_get(grouped.keys, 2) != 3 { print("FAIL groupby key 2"); fail = fail + 1; };
    if close_f64(vec_get(grouped.sums, 0), 30.0, eps) != 1 { print("FAIL groupby sum k=1"); fail = fail + 1; };
    if close_f64(vec_get(grouped.sums, 1), 70.0, eps) != 1 { print("FAIL groupby sum k=2"); fail = fail + 1; };
    if close_f64(vec_get(grouped.sums, 2), 50.0, eps) != 1 { print("FAIL groupby sum k=3"); fail = fail + 1; };
    if vec_get(grouped.counts, 0) != 2 { print("FAIL groupby count k=1"); fail = fail + 1; };
    if vec_get(grouped.counts, 1) != 2 { print("FAIL groupby count k=2"); fail = fail + 1; };
    if vec_get(grouped.counts, 2) != 1 { print("FAIL groupby count k=3"); fail = fail + 1; };

    let manifest: ParityManifest = parity_manifest(
        "ml_data_facade_smoke",
        "internal",
        "stdlib::rods::ml::data_facade",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        5,
        2,
        eps
    );
    parity_manifest_print(&manifest);

    if fail == 0 {
        print("OK ml_data_facade_smoke");
        return 0;
    };
    print("FAIL ml_data_facade_smoke");
    return 1;
}
