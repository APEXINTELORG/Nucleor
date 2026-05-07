// rods/ml/capsule_facade — Capsule manifest contract for reproducible-build evidence (source/data/model/compiler/rod-graph hashes)
//
import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/jsonl.nr"

// capsule_facade.nr - first reproducible capsule surface.
//
// The MVP records stable run metadata and machine-readable JSONL evidence.
// SHA-256 is computed by the Python verifier until Nucleor has a runtime
// hashing helper.

#[repr(C)]
struct CapsuleManifest {
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    dtype: i64,
    rows: i64,
    cols: i64,
    policy: i64,
    seed: i64,
    input_count: i64,
    output_count: i64
}

fn capsule_manifest(
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    dtype: i64,
    rows: i64,
    cols: i64,
    policy: i64,
    seed: i64,
    input_count: i64,
    output_count: i64
) -> CapsuleManifest {
    return CapsuleManifest {
        case_name: case_name,
        suite_name: suite_name,
        nucleor_surface: nucleor_surface,
        dtype: dtype,
        rows: rows,
        cols: cols,
        policy: policy,
        seed: seed,
        input_count: input_count,
        output_count: output_count
    };
}

fn capsule_manifest_print(m: &CapsuleManifest) -> i64 {
    print("capsule manifest:");
    print("case:");
    print(m.case_name);
    print("suite:");
    print(m.suite_name);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("dtype:");
    print(dtype_name(m.dtype));
    print("shape rows cols:");
    print_int(m.rows);
    print_int(m.cols);
    print("policy:");
    print(policy_name(m.policy));
    print("seed:");
    print_int(m.seed);
    print("input_count:");
    print_int(m.input_count);
    print("output_count:");
    print_int(m.output_count);
    return 0;
}

fn capsule_manifest_emit_jsonl(m: &CapsuleManifest) -> i64 {
    emit_json_run_meta(
        m.case_name,
        m.suite_name,
        m.nucleor_surface,
        dtype_name(m.dtype),
        m.rows,
        m.cols,
        policy_name(m.policy)
    );
    emit_json_metric_i64("seed", m.seed);
    emit_json_metric_i64("input_count", m.input_count);
    emit_json_metric_i64("output_count", m.output_count);
    return 0;
}

fn capsule_seeded_output_f64(input: &TensorF64, seed: i64) -> TensorF64 {
    let scale: f64 = (seed as f64) * 0.125;
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(input) {
        data.push(input.data[i] * scale + (i as f64));
        i = i + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, data);
}

fn capsule_emit_tensor_f64(name: str, t: &TensorF64) -> i64 {
    let mut bits: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(t) {
        bits.push(f64_to_bits(t.data[i]));
        i = i + 1;
    };
    emit_json_array_f64(name, bits, t.shape.rows, t.shape.cols);
    return 0;
}

fn capsule_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}
