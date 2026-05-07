import "stdlib/rods/jsonl.nr"

fn main() -> i32 {
    emit_json_run_meta(
        "jsonl_evidence_smoke",
        "nucleor_ml_suite",
        "stdlib::rods::jsonl",
        "i64",
        1,
        4,
        "strict"
    );
    emit_json_metric_i64("case_count", 120);
    emit_json_metric_f64("max_abs_error", 0.0);

    let mut ints: Vec<i64> = Vec::new();
    ints.push(1); ints.push(2); ints.push(3); ints.push(4);
    emit_json_array_i64("example_i64", ints, 1, 4);

    let mut floats: Vec<i64> = Vec::new();
    floats.push(str_to_f64("1.25"));
    floats.push(str_to_f64("-2.5"));
    floats.push(str_to_f64("3.75"));
    floats.push(str_to_f64("4.5"));
    emit_json_array_f64("example_f64", floats, 2, 2);

    emit_json_status(1);
    return 0;
}
