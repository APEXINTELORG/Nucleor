// t397_jsonl_emit.nr — v0.3.120 NUC-IMPROVE-003 fixture.
//
// Pins the `stdlib/rods/jsonl.nr` evidence-emit rod requested by
// the ML_Suite agent in NUC-IMPROVE-003. The rod produces one
// JSON object per line on stdout for Python parity runners that
// want `json.loads`-clean output instead of fragile stdout scraping.
//
// API smoke-test:
//   - emit_json_run_meta
//   - emit_json_metric_f64
//   - emit_json_metric_i64
//   - emit_json_array_i64
//   - emit_json_status
//
// Returns 0 on successful emit. The actual JSON output is captured
// by the verify gate via the rod's print(...) calls.

import "stdlib/rods/jsonl.nr"

fn main() -> i64 {
    emit_json_run_meta("smoke_test", "nucleor_ml_suite", "nuc::tensor::matmul", "f64", 2, 2, "strict");
    emit_json_metric_f64("max_abs_error", 0.0);
    emit_json_metric_i64("samples", 100);
    let mut v: Vec<i64> = Vec::new();
    v.push(1);
    v.push(2);
    v.push(3);
    v.push(4);
    emit_json_array_i64("result", v, 2, 2);
    emit_json_status(1);
    return 0;
}
