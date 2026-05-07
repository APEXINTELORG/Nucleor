import "stdlib/rods/ml/backend_facade.nr"

fn main() -> i64 {
    let manifest = backend_manifest(
        "scalar_backend_smoke",
        "scalar_nucleor_facade",
        "cpu",
        "tensor_nn_ai_smoke",
        "strict_f64_f32_i64",
        1,
        0,
        1,
        1,
        0,
        0,
        1
    );

    backend_manifest_print(&manifest);
    backend_manifest_emit_jsonl(&manifest);
    backend_manifest_emit_status(1);
    return 0;
}
