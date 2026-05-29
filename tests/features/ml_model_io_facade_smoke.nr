import "stdlib/rods/ml/model_io_facade.nr"

fn main() -> i64 {
    let manifest = model_io_manifest(
        "nuc_model_loader_v0",
        "gguf_safetensors_onnx_ncap",
        "char_sentencepiece_bpe",
        "f32_f16_bf16_i8_nf4",
        "metadata_first_zero_python",
        4,
        3,
        5,
        1,
        1,
        0,
        1
    );

    model_io_manifest_print(&manifest);
    model_io_manifest_emit_jsonl(&manifest);
    model_io_manifest_emit_status(1);
    if model_io_native_available() != 0 { panic("model_io_facade falsely advertises a native backend"); };
    return 0;
}
