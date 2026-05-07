import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_groupby_rank_max_i64_f64",
        "pandas groupby rank method max derived f64 column with ties",
        "nuc::data::frame_i64_f64_assign_group_rank_max_value + values_tensor",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        6,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let frame: FrameI64F64 = frame_i64_f64_from_csv_f64(
        "tests/features/ml_fixtures/rank_ties_i64_f64.csv",
        "group",
        "value",
        1
    );
    let assigned: FrameI64F64F64 = frame_i64_f64_assign_group_rank_max_value(&frame, "value_group_rank_max");
    frame_i64_f64_f64_print_key_values("groupby_rank_max group value value_group_rank_max:", &assigned);

    let values: TensorF64 = frame_i64_f64_f64_values_tensor(&assigned);
    tensor_f64_print_flat("groupby_rank_max values tensor:", &values);
    print_f64(tensor_f64_sum(&values));
    return 0;
}
