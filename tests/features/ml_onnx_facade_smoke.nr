import "stdlib/rods/ml/onnx_facade.nr"

fn main() -> i32 {
    let manifest: OnnxManifest = onnx_manifest(
        "tiny_onnx_encoder_fixture",
        17,
        2,
        1,
        8,
        11,
        3,
        7,
        1,
        4,
        4,
        0,
        2,
        1
    );
    onnx_manifest_print(&manifest);
    onnx_manifest_emit_jsonl(&manifest);
    onnx_manifest_emit_status(1);
    return 0;
}
